# ADR-001: Run the tunnel as a Network Extension, with the engine linked in

## Status

Accepted

## Date

2026-08-09 (recorded; decided 2026-06)

## Context

The client has to carry all of the device's traffic, not just the traffic of
applications that agree to use a proxy — and it has to do so on macOS and iOS
from one codebase.

The engine is Go. So the question is twofold: which mechanism captures traffic
system-wide, and where does the engine run so that it can be handed the tunnel's
file descriptor.

## Decision

The tunnel is a `NEPacketTunnelProvider` extension, and mihomo is compiled into
it as a Go c-archive (`MihomoCore.xcframework`, `-tags with_gvisor`) rather than
shipped as a separate executable.

- The host app stays sandboxed. It shares an App Group with the extension
  (`group.org.annoya.test`), which is also the engine's home directory for the
  geo databases.
- The host learns that directory from the native side over the `shared_dir`
  channel. It cannot derive it: under the sandbox its own `HOME` points
  somewhere else.
- The extension needs `network.client` and `network.server` entitlements.
  Without them the engine's outbound dials fail with "operation not permitted".
- The engine's TUN network stack is **gVisor** in the extension and on
  Android: fully userspace, and the one stack that has worked there (see the
  `system` alternative below). The desktop service, which creates its own
  device, runs `mixed`.
- `find-process-mode` stays off unless a process rule is actually present:
  resolving the owning process of a connection triggers a system TCC prompt
  about reading other applications' data.
- The provider is derived from `Bundle.main` as `<bundle>.tunnel` rather than
  hardcoded. The App Group is a constant (`group.org.annoya.test`, in
  `PacketTunnelProvider.swift` and `VpnChannel.swift`) and has to match the
  entitlements of both targets.
- The Swift that is identical on both platforms lives once in
  `shared/apple/` and is symlinked into `macos/` and `ios/`.

### The same decision on Android (2026-08-30)

The tunnel is a `VpnService` in its own process (`:tunnel`), and the same
engine package (`native/mihomocore/engine`) is bound by gomobile
(`mihomocore.aar`, `-tags with_gvisor,cmfa`).

**The process boundary is load-bearing, not tidiness.** Android does not
require it — a VpnService runs in the app's process by default, and it did at
first. The engine is native code, so a fault in it aborts its process: in one
process that took the UI down with it, observed as an fdsan abort that
force-finished MainActivity. The app is built on the opposite assumption —
that a tunnel can die on its own and be explained afterwards (ADR-004) — and
that assumption is simply false when the reporter dies with the subject. The
split also lets Android reclaim the UI process without dropping a tunnel the
user asked to keep, which is what always-on promises. It costs an AIDL
interface (`ITunnel`) whose surface is the one the method channel already had.

The remaining differences are Android's, not ours:

- **`cmfa` build tag.** Without it mihomo's TUN listener starts a package
  manager that reads `/data/system/packages.xml` — system-only — and the
  listener dies on the first start. The tag is mihomo's own "running inside an
  Android app" switch, maintained for ClashMetaForAndroid.
- **`VpnService.protect()` instead of interface binding.** The engine's dials
  must leave outside its own tunnel. On Apple that is
  `auto-detect-interface` + per-dial binding; on Android the detector cannot
  even start (its route monitor needs a netlink socket, banned for apps since
  Android 11), and the sanctioned mechanism is `protect()`. It is installed as
  mihomo's `dialer.DefaultSocketHook`; a dial whose protect failed is refused,
  so a broken hook goes silent instead of looping. The renderer emits
  `auto-detect-interface: false` for Android.
- **The engine owns the tun fd.** `establish()` is followed by `detachFd()`:
  sing-tun wraps the fd directly (no dup) and closes it on stop, and a second
  close from our side is a process abort under fdsan, not a log line.
- **One start path.** The service reads the persisted config from disk whether
  the app started it or the system did (always-on at boot, restart after a
  kill). A start that needed the app alive would make always-on a lie — which
  is also why starting is an Intent and not a binder call.
- **Cross-process state is files, not preferences.** `MODE_MULTI_PROCESS` is
  gone and was never reliable; the disconnect reason and the log switch live in
  the engine directory, where they survive the process that wrote them.
- The engine home is the app's files directory (`files/engine`); no App Group
  exists or is needed — the `:tunnel` process belongs to the same app and
  shares its data directory.

### The same decision on Windows and Linux

The tunnel is a system service (`native/mihomocore/service`), a port of
`MihomoVpnService.kt` behind the same contract as the Apple extension and the
Android tunnel process: start, stop, reload, probes, logs, a pushed status.

- **A second start while one is up or starting is a no-op.** The app and the
  boot-time start can both ask; two engines on one adapter is what neither
  meant.
- **The service creates the tun itself** (`engine.StartOwnDevice`: Wintun on
  Windows, the kernel tun on Linux). Creating the adapter is the privileged act
  the service exists to hold; there is no host-owned fd to hand over.
- **The app writes into the engine directory.** It downloads the geo databases
  there (`shared_dir`), so the Windows installer grants Users modify on
  `%ProgramData%\<app>\engine`; on Linux the directory is `1777`.
- **The Linux socket is world-accessible (`0666`).** No socket mode expresses
  "the console user", and a dedicated group forces a re-login after install.
  Mullvad and NetBird ship their daemon sockets the same way. The Windows pipe
  is limited to the interactive user.
- **The service runs only the shape our renderer produces.** Whoever reaches
  the socket or pipe hands a root engine its config, so the service refuses
  any top-level, `dns`, `tun` or `sniffer` key the renderer never emits, and
  any rule provider that is not `type: file` — before the config is saved or
  started, and again when a boot starts the saved one. Otherwise any local
  user could open `listeners` or `dns.listen` on every interface, add
  `iptables` rules, or have root download a provider to a path of their
  choosing. A key the renderer gains must be added here too, or the desktop
  tunnel refuses its own config (`service/config_check.go`, pinned by
  `TestOnlyTheRenderedShapeReachesTheEngine`).
- **Stopping the service takes the tunnel down.** A stopped service is not a
  VPN anyone can still rely on.

### The app does not own the tunnel (Apple)

The extension outlives the app process. On a relaunch over a live tunnel the
host has no manager yet, so every entry point first adopts the system's
profile without creating one (`VPNManager.adopt`), then reports status.

A failure inside `startTunnel` is reported to the system, not to the app: the
app only sees connecting → disconnected. `fetchLastDisconnectError` is the one
API that returns the reason; it is empty before macOS 13 / iOS 16, on an
ordinary stop, and when the extension was killed.

## Invariants

- The engine runs inside the extension process. Nothing downloads, extracts or
  spawns an engine binary at runtime.
- ~~The host app never reads the shared container directly for logs.~~
  Superseded by ADR-016: both provisioning profiles name the App Group, so
  neither side gets a TCC prompt, and the logs live there.
- Entitlements and App Group membership are part of the product, not a local
  development convenience.
- The engine opens no listener: the rendered config carries no
  `external-controller`, no `mixed-port` and no `listeners`, and everything the
  app asks the engine travels over the IPC each platform already has. mihomo's
  controller is an HTTP API with no authentication unless a secret is set,
  reachable by every process on the device and living as long as the tunnel,
  not the app (ADR-010 relies on this for the connection check).

## Alternatives Considered

### A local SOCKS/HTTP proxy with the system pointed at it

The cheapest mechanism, and what several desktop clients ship. Rejected because
it is not a VPN: anything that ignores system proxy settings escapes it, the app
must leave the sandbox to spawn the engine, and iOS has no equivalent at all —
so it would have to be replaced before the second platform.

### Ship mihomo as a bundled executable and spawn it

Rejected: it does not exist as an option on iOS, and on macOS it forces the app
out of the sandbox. Linking the engine into the extension gives one artifact,
one signature, and one lifecycle.

### Download the engine into Application Support on first run

Rejected: the engine is part of the product's trust boundary. Fetching it at
runtime means shipping an update channel, verifying signatures, and explaining
to the user why a VPN client downloads an executable.

### The `system` TUN stack instead of gVisor

Rejected: in the extension it failed to bind the fake-ip gateway, and gVisor
worked. The cause was never pinned down, and it is probably not the sandbox:
sing-tun refuses `system` only under `includeAllNetworks`, while mihomo takes
the tun address from `fake-ip-range` (`198.18.0.1/30`) and ignores
`tun.inet4-address`, so the stack listens on an address the extension never
put on the utun (`172.19.0.1`). Reopen it with that experiment if gVisor's
throughput ever matters; until then gVisor is the stack that is known to work.

## Consequences

- Two build systems are in play: Flutter for the app and a standalone Go module
  for the engine. `MihomoCore.xcframework` is over 250 MB and therefore not
  committed — it is built on demand, and a stale one silently keeps old
  behavior. See the "Which check when" section of `AGENTS.md`.
- Anything the app wants from inside the tunnel (status, hot reload; logs until ADR-016) has
  to travel over IPC. That constraint shapes ADR-002 and the logging design.
- The extension is memory-constrained on iOS (~50 MB). Measured peak is under
  30 MB during 1080p playback, so the engine fits — but the margin is small and
  large geo databases eat into it.

## Where It Lives

- `shared/apple/PacketTunnelProvider.swift` — the provider: settings, fd,
  engine start/stop, IPC.
- `shared/apple/VPNManager.swift`, `VpnChannel.swift` — the host side.
- `native/mihomocore/` — the Go module, its C surface and the
  xcframework build script.
- `lib/core/network_extension_core.dart` — the `VpnCore` implementation.
- `lib/core/mihomo_tun_config.dart` — config rendering, unit-tested.
- `native/mihomocore/service/` — the Windows and Linux service;
  `cmd/tunnel-service/` its SCM and systemd hosts;
  `windows/installer/Anoya.iss` — the engine directory's ACL.
