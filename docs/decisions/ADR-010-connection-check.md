# ADR-010: The app verifies the tunnel carries traffic, and says so without dropping it

## Status

Accepted

## Date

2026-09-01

## Context

Every status the platforms give the app is a claim about an **interface**, not
about a path. `NEVPNStatus.connected` means the packet-tunnel provider started;
Android's `onStartCommand` means the `VpnService` established a tun. Neither
knows whether a single byte crosses to the other side.

Two failures live in that gap, and both were met in this repository rather than
imagined:

- **AmneziaWG.** The device is configured and the peer is added, but the
  handshake only begins when the first packet asks for one. A peer the server
  has forgotten — a rotated key, a config issued against an account that no
  longer holds it — never completes it. `wireguard-go` retries and stays
  silent; the engine reports nothing, because nothing failed at its level. An
  evening was spent looking for a client bug that did not exist.
- **VLESS.** The server accepts TCP and then says nothing, or closes. There is
  no session to observe: each request is its own proof.

From the outside both look identical and look fine: a green ring and a dead
internet. The user has no reason to suspect the VPN, and support is asked about
the app.

mihomo has exactly one active answer — `Proxy.URLTest`, the HTTP HEAD its
url-test groups pick members with. Reaching it is the constrained part:
ADR-001 forbids `external-controller` (an unauthenticated HTTP API inside the
extension container), so the probe has to travel the same tunnel transport
every other engine call uses.

## Decision

**Look before asking.** The engine tracks every connection it carries, so bytes
that already came *back* through the selected outbound prove the tunnel works —
proved by the user's own traffic, with nothing sent anywhere. `engine.ProxyBytes`
sums over live trackers whose chain contains the outbound. Only when that is
silent does anything leave the device.

**Counted per connection chain, never from the tunnel's totals.**
`statistic.Manager.Total()` includes everything the tunnel handled, and in split
mode much of that went out DIRECT — a number that grows steadily while the proxy
is dead.

**The active probe is mihomo's own URLTest**, against the group every rendered
config routes through (`PROXY`). Testing the group and not a member means the
probe follows whatever the engine currently picked. It answers in one string —
`ms:<delay>` or `err:<reason>` — because a delay of zero is otherwise
indistinguishable from a failure, and because both platform transports carry
strings already.

**It waits, and it does not believe the first no.** Two seconds of warm-up, then
up to three attempts. `RekeyTimeout` in amneziawg-go is five seconds — exactly
the probe's own default — so a probe fired at zero raced the handshake retry and
reported "No answer" on a server that was about to work. Only the last attempt
is published: an intermediate failure would raise the banner on the home screen
and then take it back. The button makes a single attempt, because the user asked
about *now*.

**A failure is news, not a verdict.** The tunnel is never dropped: the probe has
false negatives (an operator captive portal, a blocked test host, a second spent
switching), and killing a working tunnel over one unanswered HEAD is worse than
saying so. The home screen shows a warning banner and the ring stays green,
because the tunnel really is up.

**Success is silent** everywhere except the Advanced screen, which keeps the
last answer as a line to compare with the next one. A measured pass reads
"Answered in 143 ms"; an observed one reads "Traffic is getting through" and
carries no number, because we measured nothing.

**Settings live behind one row.** `Settings → CONNECTION → Advanced` holds the
switch, the test URL and the timeout. `expected-status` is deliberately not
exposed — its range syntax is a way to make the check silently meaningless.

## Invariants

- The probe never reaches the network except through the outbound under test.
  `URLTest` dials the adapter directly (`Proxy.DialContext`), not the rule
  engine, so no routing rule and no split-tunnel policy can send it elsewhere —
  and, for the same reason, a pass says nothing about where the user's own
  traffic goes. The screen says so in as many words.
- The `PROXY` group contains only real proxies; a group with no runnable member
  is not rendered at all. A probe can therefore never measure `DIRECT` and call
  it a working tunnel.
- Only bytes that came **back** count as passive proof. Upload alone is a
  request that may have gone nowhere — exactly what a dead tunnel looks like
  from this side. Pinned by *bytes only counted when something came back*.
- A verdict belongs to the session that produced it: the last answer is
  forgotten when the tunnel goes down, and a sequence interrupted by a
  disconnect publishes nothing. Pinned by *a measurement does not outlive the
  session it describes* and *a session that ends mid-sequence gets no verdict at
  all*.
- With the tunnel down the desktop service refuses `url_test`
  (`err:the tunnel is not running`) instead of asking the engine, which would
  answer "no outbound named PROXY" and read as a broken config
  (`native/mihomocore/service/service.go`).
- The check switched off sends nothing. Pinned by *switched off, nothing is sent
  to anybody*.
- What the user reads is a sentence, not the engine's dial chain. Pinned by *the
  dial chain becomes a sentence about the server*.
- A server is named with the label the user's own screens use, never the
  renderer's internal `proxy` / `p0`.

## Alternatives Considered

### Trust the platform's connected status

Rejected because that is the bug. Both platforms report an interface; the two
failures above leave the interface perfectly healthy.

### `external-controller` and mihomo's REST API

The documented way to reach `GET /proxies/{name}/delay`. Rejected: it opens an
unauthenticated HTTP server inside the extension container, which ADR-001 rules
out for the same reason it rules it out for everything else. The Go API is one
function call away and needs no listener.

### Read the WireGuard handshake instead

`last_handshake_time_sec` is the only *definitive* answer for AWG — a fact, not
a measurement. Rejected because mihomo keeps the device unexported inside its
wireguard outbound: reading it means patching a dependency we otherwise consume
unmodified, and it answers for one protocol out of two (VLESS has no session at
all).

### Reuse the health check a url-test group already runs

For group configurations mihomo is already probing on a timer, and the results
sit in `AliveForTestUrl` / `LastDelayForTestUrl`. Rejected: the group measures
*its* URL — the provider's, or our group default — not the one the user set on
the Advanced screen, so displaying that number would attribute a measurement to
the wrong endpoint. With the passive check in place a group config rarely probes
anyway, since traffic is flowing through it.

### Probe periodically while connected

Rejected for now: a repeating request to a third-party host is a privacy cost
the user did not ask for, and the failure it would catch — a tunnel that dies
mid-session — is already visible as traffic stopping. The passive counters make
a cheap periodic version possible later without sending anything.

### Drop the tunnel when the check fails

The "kill switch" reflex. Rejected on the same grounds as ADR-004: the app must
not act on a measurement it knows to be imperfect. A false negative would
disconnect a working VPN silently, which is the failure mode the check exists to
prevent, inverted.

## Evidence

The bug that produced the retry policy, reported on a live Amnezia Premium
subscription:

- AWG: `connect failed: dial tcp 172.253.144.94:443: context deadline exceeded`
  followed by the same request's IPv6 attempt, `network is unreachable`.
- VLESS: `Head "https://www.gstatic.com/generate_204": EOF`.
- In both cases pressing **Test now** a moment later passed.

`RekeyTimeout = 5s` (`amneziawg-go/device/constants.go:19`) is exactly the
probe's default timeout, which is why the first attempt lost the race and the
second did not. Other subscriptions did not show it: their servers were not
issued seconds earlier.

## Consequences

- One HTTP HEAD per connect, to a third-party host, for users whose tunnel is
  idle at that moment. Switched off in one tap, and skipped entirely whenever
  traffic is already flowing.
- The test host's name still has to be resolved. For VLESS that happens on the
  server (the domain travels in the request); for WireGuard the engine resolves
  it locally, following the configuration's own DNS — which is outside the
  tunnel unless those resolvers are pinned to it. The HTTP request itself can
  never take that path. Making WireGuard outbounds resolve inside the tunnel
  (`remote-dns-resolve`) is open work, and is about all traffic, not this check.
- A passive pass carries no delay, so the screen has two shapes of "it works".
  That is the honest cost of not inventing a number.
- The engine surface grew by two calls on three platforms
  (`MihomoURLTest` / `MihomoProxyBytes`, their gomobile twins, and a message on
  each tunnel transport). Both block for as long as their timeout allows, so on
  Android they run off the binder caller's thread and on Apple off the
  extension's main queue.

## Where It Lives

- Engine: `native/mihomocore/engine/engine.go` (`URLTest`, `ProxyBytes`),
  exported in `core.go` (Apple) and `mobile/mobile.go` (Android).
- Transports: `shared/apple/PacketTunnelProvider.swift` (`urltest:`,
  `proxybytes`), `VPNManager.swift`, `VpnChannel.swift`;
  `android/app/src/main/aidl/org/annoya/vpn_client/ITunnel.aidl`,
  `MihomoVpnService.kt`, `VpnChannel.kt`; the desktop service's `url_test` in
  `native/mihomocore/service/service.go`.
- App: `lib/core/connection_check.dart`,
  `lib/state/connection_check_controller.dart`,
  `lib/features/advanced_connection_screen.dart`, the banner in
  `lib/features/home_screen.dart`.
- Tests: `test/connection_check_test.dart`.
- Mockup: `design/ui-spec.html` §14.
