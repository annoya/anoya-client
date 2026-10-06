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

**Both address families are claimed, and both are carried.** `NEIPv4Settings`
and `NEIPv6Settings` each install the default route, and the engine runs with
`ipv6: true` plus its own v6 fake-IP pool. Without the v6 settings the OS keeps
the physical interface's v6 default route, and everything reaching an IPv6
address — a literal address, or an AAAA an application resolved over its own
DoH past the `:53` hijack — leaves in the clear; cellular is v6-primary, so
that is the ordinary case. Claiming the route without handling v6 in the engine
would be fail-closed rather than leaking, but it fails a lot: the fake-IP pool
refuses AAAA, so every v6 destination breaks instead of being proxied.

Enabling v6 does not depend on the exit server having it. Fake-IP maps the
answer back to the *domain*, so what leaves the device is a hostname and the
server chooses the family; only connections made to a literal v6 address need
v6 at the far end.

**Names are answered v4 only.** `dns.ipv6` stays at mihomo's default (off), so
AAAA answers are empty and apps connect through v4 fake-IPs. A fake v6 answer
makes dual-stack clients prefer v6, and on a server without v6 egress every
such connection hangs instead of falling back. The per-server alternative is
in OPEN-QUESTIONS.

This forces one engine-wide setting. `config.parseIPV6` probes the host's
interfaces and, finding no global v6 address, strips `tun.inet6-address` and
`dns.fake-ip-range6` from the parsed config — which would make the `tun`
section a function of the current network and break the invariant below the
first time a device moved between a v4-only and a v6 network. The wrapper sets
`SKIP_SYSTEM_IPV6_CHECK=1` before any config is parsed. The probe asks whether
the host has IPv6; for a VPN that supplies IPv6 over its own interface, that is
the wrong question.

**Nothing is excluded from the tunnel.** `includedRoutes = [default]` and no
`excludedRoutes` at all — not for the current server, not for any other. The
engine still reaches its server outside the tunnel, by whatever the platform
provides for that:

- **Apple:** the system routes a packet tunnel provider's own sockets outside
  the tunnel it provides. The engine's dials are left unbound and the kernel
  picks the primary interface per connection, following Wi-Fi ↔ cellular
  changes by itself. The wrapper forces `auto-detect-interface` off, so a saved
  config from an older build cannot turn mihomo's binding back on.
- **Android:** `VpnService.protect()`, see ADR-001.
- **Windows, Linux:** the engine owns the device and its routes, nothing is
  exempted by the OS, so mihomo binds each dial to the physical interface
  (`auto-detect-interface`).

Apple used to bind too (`IP_BOUND_IF` via `auto-detect-interface`). mihomo's
detector walks the routing table and takes the first default route it meets,
scoped ones included; iOS keeps a scoped default route on cellular (`pdp_ip0`)
while Wi-Fi is up, and the detector picked it — every tunnelled byte went out
over mobile data while the device sat on Wi-Fi. The binding was never what kept
those dials out of the tunnel (see Evidence), so it was removed rather than
fixed.

**A config is parsed before it is applied.** Invalid YAML is rejected and the
engine stays on the previous config; a failed switch therefore cannot take the
tunnel down.

**After a successful reload the engine closes the connections it is proxying.**
Applying a config only changes where *new* connections go; browsers and system
services hold connections open for minutes, so without this the switch appears
to do nothing.

**The fake-IP pool survives a reload** (`profile.store-fake-ip: true`, persisted
to `cache.db` in the engine home). Every apply rebuilds the pool, and without
this it comes back empty: the OS and browsers keep the `198.18.x.y` they were
handed, the engine no longer knows which domain each one meant, and sites stop
opening until those caches expire. The constant range (ADR-008) keeps the
addresses valid; this keeps what they stand for.

**ICMP forwarding is disabled** (`disable-icmp-forwarding: true`). mihomo's ICMP
path is a DIRECT outbound dialing from the physical interface: a ping entering
the tun leaves again outside it and exposes the real address. With forwarding
off the stack answers echo requests itself.

**Errors never disconnect.** The tunnel keeps running on the previous config and
the user gets a dialog.

## Invariants

- No code on the switch path calls `stop`, `start`, or
  `setTunnelNetworkSettings`, in any outcome including failure.
- The saved config — what always-on, on-demand or a boot start runs with no
  app in memory — changes on a switch only once the engine has applied it.
  A refused switch leaves the previous one on disk as well as in the engine,
  so the next system start does not bring up a config that already failed
  and that the app no longer shows. Pinned on the desktop service by
  `TestReloadKeepsTheSessionAndReportsARejectedConfig`.
- `includedRoutes` is the default route for IPv4 **and** IPv6, and
  `excludedRoutes` is empty.
- The `tun` section of the rendered config is byte-identical across locations,
  protocols and routing policies — that is what keeps mihomo from re-creating
  the TUN listener, and with it the fd and the session. (The `dns` section
  carries per-config resolvers, see ADR-008; only its fake-ip mode and range
  are constant.)
- The `tun` section does not vary with the machine's own addresses: the
  host-IPv6 probe is disabled before the first parse. Pinned by
  `TestTunSectionDoesNotDependOnHostIPv6`.
- `dns.fake-ip-range` is part of that condition even though it sits outside
  the `tun` section: mihomo ignores `tun.inet4-address` and gives the tun the
  first /30 of the fake-ip range (`parseTun` in `config/config.go`). Moving
  `kFakeIpRange` therefore re-creates the listener on the next reload, which
  the `GetTunConf().Enable` check reports as a failed switch.
- A reload that reports success has a live TUN listener behind it. mihomo's
  `ApplyConfig` returns nothing and logs apply-stage failures instead — including
  a TUN re-creation that closed our fd and could not rebuild — so the wrapper
  checks `listener.GetTunConf().Enable` before calling a reload successful.
- After each reload the engine dials the single-server outbound over the
  physical interface and logs the result (`logProxyEgress`); nothing else tells
  a dead server from a dial that never reached the interface, since both show
  as an i/o timeout. It looks the outbound up as `proxy`, the name the renderer
  gives it, so a rename silently disables the probe (pinned by *the single
  outbound is always named "proxy"*). Proxies that dial UDP (WireGuard,
  Hysteria, TUIC) are skipped: the TCP dial is refused by design and reads as
  a network fault.
- If the engine's dials ever stop leaving outside the tunnel (the system
  exemption on Apple, `protect()` on Android, the binding on Windows and
  Linux), they loop into the tunnel and the tunnel goes silent rather than
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

Rejected. It buys nothing — the provider's ordinary sockets already leave
outside the tunnel — and it cannot hand Go a file descriptor: it would need a Swift↔Go bridge
implementing `net.Conn` over callbacks, twice (TCP and UDP), on a deprecated
API.

### Pin the physical interface name into the config

Rejected as harmful: an explicit `interface-name` goes stale the moment the
machine changes network — routine on iOS, where Wi-Fi (`en0`) and cellular
(`pdp_ip0`) alternate.

### Solve the switch window with a kill switch

Rejected as the wrong tool for this problem — if the session never dies there is
no window to protect. The kill-switch question is separate and has its own
answer; see ADR-004.

## Evidence

Every claim above was settled by running the tunnel, not by reading code.
`scripts/leak-check.sh` generates ICMP/TCP/DNS toward fixed public
addresses and captures both the physical interface and the utun, so "the OS
never gave it to the tunnel" can be told apart from "it went out both ways".

- Final run: seven consecutive switches, exit IP changing each time,
  **0 packets leaked, 0 ICMP outside, 29868 test packets inside the tunnel**,
  with no exclusions in the tunnel at all.
- Egress proof, logged by the engine after each reload:
  `[egress] finland.nexus…:443 reachable after reload, from 10.0.0.75:57441` —
  the socket's local address belongs to `en0` while the default route points
  into `utun`. This was read as the binding working, but on a Mac with `en0`
  as its only interface it cannot tell binding from the system's exemption.
- iOS, 2026-10: an unbound probe socket opened inside the extension toward
  `10.255.255.255` — covered by the tunnel's default route — got `en0`'s
  address, not the utun's. The system exempts the provider's sockets with no
  binding at all; the bound build meanwhile logged
  `default interface changed by monitor, => pdp_ip0` on Wi-Fi.
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
- The whole mechanism rests on one thing: the engine's dials leaving outside
  the tunnel without a route exclusion. If that ever breaks, dials loop back
  into the tunnel and die by timeout — the tunnel goes silent, which is the
  safe failure.
- A reload re-parses a config on every switch. Cheap in practice (~850 bytes,
  0 ms reported by the engine) but not free if the geo databases are large.
- **Known gap:** an ordinary reconnect (stop → start) still removes the routes,
  so the window this ADR closes for switching remains open for reconnects. It
  cannot be closed the same way; see ADR-004.
- The mechanism is platform-neutral by construction — the leak source is the
  death of the tunnel interface, which is universal. Android reaches the same
  engine reload through the same `vpn/control` channel and the UI does not
  change. Not yet verified on a physical iOS device.

## Where It Lives

- `native/mihomocore/engine/engine.go` — `Reload`, connection closing, the
  `[egress]` probe (`logProxyEgress`); `engine/netext_darwin.go` — unbound
  dials on Apple.
- `shared/apple/PacketTunnelProvider.swift` — `applyNetworkSettings`
  (start only) and the `reload:` handler.
- `lib/state/profiles_controller.dart` — `_applySelection`, and
  `maybeReapply` (the background poll takes the same reload-only path).
- `lib/core/mihomo_tun_config.dart` — identical `tun`/`dns` sections,
  `disable-icmp-forwarding`, `store-fake-ip`, `ipv6`.
- Tests: `test/hot_switch_test.dart` (group `leak invariants`),
  `test/mihomo_tun_config_test.dart` (*fake-IP meanings survive a hot switch*,
  *IPv6 is carried, not resolved*),
  `native/mihomocore/engine/engine_test.go`.
- `scripts/leak-check.sh` — the verification tool.
