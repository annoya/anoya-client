# ADR-002: Switch servers and configurations by reloading the engine, and keep nothing outside the tunnel

## Status

Accepted

## Date

2026-08-09

## Context

Switching server or configuration by disconnecting and reconnecting leaks. While
the tunnel is down the OS default route falls back to the physical interface and
every application's traffic leaves in the clear for the length of the reconnect
— precisely when the user is doing something deliberate about their privacy.

Underneath sits a second problem. The engine's own connection to the VPN server
must leave the machine *outside* the tunnel, or it is routed into the tunnel it
is trying to establish. There are two ways to arrange that — punch a hole in the
tunnel's routes, or bind the engine's sockets to the physical interface — and the
choice between them decides how much of the rest is possible.

## Decision

**Switching is a hot reload of the engine under a standing session.** The app
sends `reload:<yaml>` to the running extension over `sendProviderMessage`; the
extension calls into Go with the same tunnel file descriptor; mihomo parses the
new config and applies it. The NE session, the packet flow and the fd are never
touched, so the OS routing table never changes and there is no window for
traffic to escape.

**The network settings are installed once, at start, and never re-applied.**
`setTunnelNetworkSettings` tears the current settings down before installing
the new ones; on a live session that is a real leak, not a theoretical one.

**Nothing is excluded from the tunnel.** `includedRoutes = [default]` and no
`excludedRoutes` at all — not for the current server, not for any other. The
engine reaches its server because mihomo binds each outbound socket to the
physical interface (`IP_BOUND_IF`, via its own `auto-detect-interface`). A bound
socket uses that interface's scoped routing table, so the default route into
the utun is simply not consulted.

**A config is parsed before it is applied.** Invalid YAML is rejected and the
engine stays on the previous config; a failed switch therefore cannot take the
tunnel down.

**After a successful reload the engine closes the connections it is proxying.**
Applying a config only changes where *new* connections go; browsers and system
services hold connections open for minutes, so without this the switch appears
to do nothing.

**ICMP forwarding is disabled** (`disable-icmp-forwarding: true`). mihomo's ICMP
path is a DIRECT outbound dialing from the physical interface: a ping entering
the tun leaves again outside it and exposes the real address. With forwarding
off the stack answers echo requests itself.

**Errors never disconnect.** The tunnel keeps running on the previous config and
the user gets a dialog.

## Invariants

- No code on the switch path calls `stop`, `start`, or
  `setTunnelNetworkSettings`, in any outcome including failure.
- `includedRoutes` is the default route and `excludedRoutes` is empty.
- The `tun` and `dns` sections of the rendered config are byte-identical across
  locations, protocols and routing policies — that is what keeps mihomo from
  re-creating the TUN listener, and with it the fd and the session.
- If the interface binding ever fails, the tunnel goes silent rather than
  leaking. Fail-closed is the intended direction.

## Alternatives Considered

### Exclude the current server's address from the tunnel

The obvious arrangement, and the one most clients use. Rejected on three
independent counts:

1. It is a system-wide hole. Any process's traffic to that address bypasses the
   tunnel, and hosting providers put many things on one address.
2. `NEIPv4Route` only accepts numeric addresses, so the server's hostname has to
   be resolved by the system resolver *before* the tunnel is up — a plaintext
   DNS query naming the VPN server, sent in the clear.
3. It has to change whenever the server changes, which means re-applying the
   network settings on a live session — see below.

### Re-apply the network settings during a switch

Rejected: `setTunnelNetworkSettings` removes the current settings before
installing the replacements, and traffic escapes in that window. Measured at
48 leaked TCP/DNS packets per switch.

### Pre-exclude every known server so switching needs no route change

Rejected on the same grounds as the first alternative, multiplied: eight servers
in a subscription would be eight permanent holes for every process on the
machine.

### `createTCPConnection(through:)` from `NEPacketTunnelProvider`

Rejected. It is the same endpoint bypass that `IP_BOUND_IF` already provides,
but it cannot hand Go a file descriptor: it would need a Swift↔Go bridge
implementing `net.Conn` over callbacks, twice (TCP and UDP), on a deprecated
API.

### Pin the physical interface name into the config

Rejected as both unnecessary and harmful. Unnecessary: mihomo's interface
detector lives in the TUN listener, which a reload does not re-create, so it
survives the swap. Harmful: an explicit `interface-name` outranks that detector
and goes stale the moment the machine changes network — routine on iOS, where
Wi-Fi (`en0`) and cellular (`pdp_ip0`) alternate.

### Solve the switch window with a kill switch

Rejected as the wrong tool for this problem — if the session never dies there is
no window to protect. The kill-switch question is separate and has its own
answer; see ADR-004.

## Evidence

Every claim above was settled by running the tunnel, not by reading code.
`client/scripts/leak-check.sh` generates ICMP/TCP/DNS toward fixed public
addresses and captures both the physical interface and the utun, so "the OS
never gave it to the tunnel" can be told apart from "it went out both ways".

- Final run: seven consecutive switches, exit IP changing each time,
  **0 packets leaked, 0 ICMP outside, 29868 test packets inside the tunnel**,
  with no exclusions in the tunnel at all.
- Egress proof, logged by the engine after each reload:
  `[egress] finland.nexus…:443 reachable after reload, from 10.0.0.75:57441` —
  the socket's local address belongs to `en0` while the default route points
  into `utun`. That is the binding working.
- ICMP forwarding, before it was disabled: 249 packets on `en0` while 496 also
  entered the utun. The same packets on both paths is the signature of the
  engine forwarding them itself, as opposed to the OS bypassing the tunnel —
  which is how the DIRECT outbound was identified.
- Re-applying network settings on a live session: two bursts of 48 packets,
  timed exactly at the switches.

## Consequences

- Switching interrupts every connection the engine was proxying. This is
  deliberate; they live inside the tunnel, so nothing escapes while clients
  redial, and the alternative is a switch that appears not to work.
- The whole mechanism rests on one thing: mihomo binding its dials to the
  physical interface. If that ever breaks, dials loop back into the tunnel and
  die by timeout — the tunnel goes silent, which is the safe failure.
- A reload re-parses a config on every switch. Cheap in practice (~850 bytes,
  0 ms reported by the engine) but not free if the geo databases are large.
- **Known gap:** an ordinary reconnect (stop → start) still removes the routes,
  so the window this ADR closes for switching remains open for reconnects. It
  cannot be closed the same way; see ADR-004.
- The mechanism is platform-neutral by construction — the leak source is the
  death of the tunnel interface, which is universal. Android and desktop cores
  implement `VpnCore.reload` and the UI does not change. Not yet verified on a
  physical iOS device.

## Where It Lives

- `client/native/mihomocore/engine.go` — `reloadEngine`, connection closing, the
  `[egress]` probe.
- `client/shared/apple/PacketTunnelProvider.swift` — `applyNetworkSettings`
  (start only) and the `reload:` handler.
- `client/lib/state/profiles_controller.dart` — `_applySelection`.
- `client/lib/core/mihomo_tun_config.dart` — identical `tun`/`dns` sections,
  `disable-icmp-forwarding`.
- Tests: `client/test/hot_switch_test.dart` (group `leak invariants`),
  `client/native/mihomocore/engine_test.go`.
- `client/scripts/leak-check.sh` — the verification tool.
