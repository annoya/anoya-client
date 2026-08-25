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
- The engine's TUN network stack is **gVisor**. It is fully userspace, which is
  the only thing that works inside the extension sandbox.
- `find-process-mode` stays off unless a process rule is actually present:
  resolving the owning process of a connection triggers a system TCC prompt
  about reading other applications' data.
- Bundle identifier and App Group are read from `Bundle.main`; the provider is
  derived as `<bundle>.tunnel` rather than hardcoded.
- The Swift that is identical on both platforms lives once in
  `client/shared/apple/` and is symlinked into `macos/` and `ios/`.

## Invariants

- The engine runs inside the extension process. Nothing downloads, extracts or
  spawns an engine binary at runtime.
- The host app never reads the shared container directly for logs: doing so
  triggers a TCC prompt about other applications' data. Logs travel over IPC.
- Entitlements and App Group membership are part of the product, not a local
  development convenience.

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

Rejected: it cannot bind the fake-ip gateway inside the extension sandbox.
gVisor costs some throughput in theory and is the only stack that works here.

## Consequences

- Two build systems are in play: Flutter for the app and a standalone Go module
  for the engine. `MihomoCore.xcframework` is 129 MB and therefore not
  committed — it is built on demand, and a stale one silently keeps old
  behavior. See the "Which check when" section of `AGENTS.md`.
- Anything the app wants from inside the tunnel (logs, status, hot reload) has
  to travel over IPC. That constraint shapes ADR-002 and the logging design.
- The extension is memory-constrained on iOS (~50 MB). Measured peak is under
  30 MB during 1080p playback, so the engine fits — but the margin is small and
  large geo databases eat into it.

## Where It Lives

- `client/shared/apple/PacketTunnelProvider.swift` — the provider: settings, fd,
  engine start/stop, IPC.
- `client/shared/apple/VPNManager.swift`, `VpnChannel.swift` — the host side.
- `client/native/mihomocore/` — the Go module, its C surface and the
  xcframework build script.
- `client/lib/core/network_extension_core.dart` — the `VpnCore` implementation.
- `client/lib/core/mihomo_tun_config.dart` — config rendering, unit-tested.
