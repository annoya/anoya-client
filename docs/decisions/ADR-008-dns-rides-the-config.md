# ADR-008: DNS resolvers ride the VPN config; the OS-level DNS setting is a decoy

## Status

Accepted

## Date

2026-08-09

## Context

Apple's NetworkExtension takes the tunnel's DNS servers as part of
`setTunnelNetworkSettings`, which is installed once at start and must never be
re-applied on a live session (ADR-002: the teardown between old and new
settings is a real leak window). Read literally, that makes DNS immutable for
the life of the tunnel — the opposite of what per-config DNS needs, and the
reason this was non-obvious.

The engine dissolves the problem. mihomo's TUN inbound hijacks every packet to
port 53 (`dns-hijack: any:53`) regardless of destination address, answers from
its own resolver in fake-ip mode, and rebuilds that resolver from the `dns:`
block on every config application (`executor.ApplyConfig → updateDNS`,
carrying the fake-ip mapping cache over via `PatchFrom`). Since a config
switch is already a hot reload of the engine (ADR-002), whatever the `dns:`
block says changes with the config — no NE settings involved.

The remaining questions were where per-config DNS values can come from at all,
and how much of a foreign `dns:` block to trust. The client has three config
domains (ADR-005): the self-hosted bundle (JSON we define), subscriptions
(base64 link lists or Clash/mihomo YAML — the only subscription form that can
carry DNS), and bare share links (cannot carry DNS by format).

## Decision

**The OS-level DNS setting is a constant decoy.** `NEDNSSettings` stays at
`1.1.1.1, 8.8.8.8` with `matchDomains = [""]`; its only job is to make the OS
send DNS queries as packets into the tunnel, where the `any:53` hijack takes
them. Those addresses never receive a query.

**The real resolvers live in the engine config and travel with it.** The
config's DNS enters the pipeline at its source — the self-hosted bundle's
`dns` field (`shared/normconfig`), a Clash-YAML subscription's
`dns.nameserver` list, nothing for bare links — is persisted on the `Profile`,
carried through `NormConfig`, and rendered into the `dns:` block of the engine
YAML. Switching configs switches DNS through the same hot reload as everything
else. A refresh replaces the whole list, so a source that drops its DNS drops
ours too.

**No DNS in the config means Cloudflare DoH.** The fallback is
`https://1.1.1.1/dns-query` — encrypted, and the pre-existing behaviour.

**Only the resolvers are adopted, never the whole foreign `dns:` block.**
`enhanced-mode: fake-ip` and `fake-ip-range: 198.18.0.1/16` are app constants:
the OS caches the fake addresses the engine handed out, so a range that moved
with the config would strand every cached answer on a hot switch.

**Unusable entries are dropped, never escaped.** Nameserver strings from a
subscription are attacker-supplied text headed into an engine config we
assemble as text. Anything that could not be a nameserver — whitespace,
quotes, backslashes, non-ASCII — is discarded with a log line, the same stance
ADR-003 takes for routing rule values. If everything is dropped, the fallback
applies.

**Hostname-addressed resolvers get a plain-IP bootstrap.** A config naming its
resolver by domain (`https://dns.google/dns-query`) would need DNS to set up
DNS; the renderer detects the case and adds `default-nameserver: [1.1.1.1]`.

**The proxy's own hostname is always resolvable without the proxy.** The
renderer always emits `proxy-server-nameserver` — the same resolvers, with any
`#pin` removed. This is what mihomo uses to resolve a proxy's server address;
without the block it falls back to the main resolver
(`hub/executor/executor.go`), so a subscription pinning its resolver to the
tunnel deadlocks the whole engine. `default-nameserver` does not cover this:
the engine uses it only to resolve a *nameserver's* own hostname
(`dns/resolver.go`, where it is handed to the nameserver clients and nowhere
else).

**Every format's DNS block is read, and the routing intent is translated.**
Clash already speaks mihomo's syntax and passes through as written. The two
JSON formats do not: sing-box names an outbound tag in `detour`, Xray marks a
scheme `+local`, and neither vocabulary survives into our config. Both reduce
to one question — is this query issued here, or sent out through the proxy? —
and we render exactly one outbound to answer it with. Reading a non-local
resolver as local would quietly undo the thing a DNS block is usually there to
do. Entries naming a *mechanism* (`local`, `fakeip`, `rcode://`, `dhcp://`) are
dropped rather than translated: mihomo accepts them as `udp://<word>` and they
then never answer, and `local` in particular is the tunnel's own DNS setting
inside the extension, so asking it loops back to the engine that asked.

**A `#pin` is honoured only when it names an outbound we render.** mihomo
parses the fragment as a proxy name and, failing to find one, binds the DNS
socket to a network *interface* of that name (`tunnel/dns_dialer.go`). A
provider's own group names do not survive into our config — we render `PROXY`,
`group` and `p0…pN` — so an unrecognised pin is stripped and logged, and the
resolver is kept. Only the address is held to the sanitation standard above:
pins are decoration ("🇷🇺 Direct") and judging the whole string would throw
away a good resolver over its label, silently replacing the provider's DNS
with ours.

**A resolver the tunnel cannot carry is replaced, not left to fail.** mihomo's
`udp` is off unless a proxy says otherwise, and a datagram dial through an
outbound without it is an error on every attempt — so a plain `udp://` or
`quic://` resolver pinned to such a tunnel means no DNS at all. The entry is
dropped and the encrypted fallback stands in. Unpinning it instead would be
the worse trade: a plaintext query on the local network exposes every domain
the user visits, which is what the pin was there to prevent.

**A scheme the engine does not know is dropped before it reaches the engine.**
`config.Parse` answers an unknown scheme with an error for the *whole*
document, so one `h3://` line in a subscription's DNS block would cost every
server and every rule — the tunnel simply would not start. `h3` and `h2c` are
translated (HTTP/3 is a transport choice, which mihomo spells `prefer-h3`);
anything else is dropped with a log line. The list is also deduplicated and
capped: the engine queries every resolver at once and takes the first answer,
so length is cost, not redundancy.

## Invariants

- The `tun` section of the rendered engine config is identical across
  locations, protocols, routing policies **and DNS lists** — that section is
  the engine's condition for keeping the TUN fd (and the NE session) alive
  across a reload. The `dns` section is not part of that condition.
  Pinned by `client/test/hot_switch_test.dart`.
- `enhanced-mode` and `fake-ip-range` are byte-identical whatever DNS a config
  brings. Pinned by `client/test/mihomo_tun_config_test.dart`
  ("fake-ip settings are app constants…").
- A nameserver entry that fails sanitation never appears in the rendered YAML
  in any form. Pinned by `client/test/mihomo_tun_config_test.dart`
  ("unusable dns entries are dropped, never interpolated").
- An empty or fully-rejected DNS list falls back to `https://1.1.1.1/dns-query`.
  Pinned by `client/test/mihomo_tun_config_test.dart`.
- `proxy-server-nameserver` is always present and never carries a pin, and no
  pin survives that names an outbound the config does not define. Pinned by
  `client/test/mihomo_tun_config_test.dart` ("resolving the proxy never needs
  the proxy", "a pin we cannot honour is dropped, its resolver kept").
- No nameserver reaches the rendered config with a scheme `config.Parse`
  rejects, whatever format it came from. Pinned by
  `client/test/dns_sources_test.dart`.
- A source that says "through the proxy" comes out pinned, and one that says
  "issued here" comes out unpinned — in every format that can say either.
  Pinned by `client/test/dns_sources_test.dart`.

## Alternatives Considered

### Re-applying NEDNSSettings on switch

Rejected. `setTunnelNetworkSettings` tears the old settings down before
installing the new ones; on a live session the OS routes fall back to the
physical interface for that window. ADR-002 exists to keep that call out of
the switching path, and DNS is not a reason to let it back in.

### Making the OS-level DNS real (no hijack, queries answered by the named servers)

Rejected. The addresses would be fixed for the tunnel's lifetime (see above),
plain UDP to third parties, and invisible to the engine's routing rules. The
hijack keeps every query inside the engine, where fake-ip needs to see it
anyway — domain-based routing works by answering DNS itself.

### Adopting the subscription's entire `dns:` block

Rejected. Fake-ip mode and range must not move between configs (cached
answers), and the block can carry listener and enhancement options we never
audited. Taking only `nameserver` keeps the trusted surface one list of
strings.

### Escaping suspicious nameserver entries instead of dropping them

Rejected. A value that needs escaping is a value we do not understand; the
YAML quoting layer protects structure, not meaning. Same reasoning as routing
rule validation (ADR-003): skip and log, never interpolate.

### A device-global DNS setting instead of per-config

Not chosen as the model: the config source is the party that knows its
resolver (a corporate resolver behind the self-hosted tunnel, a panel's DoH).
A user-facing override on top remains open — it would slot into the same
`dns` parameter of the renderer — but it is a separate feature, not this one.

## Consequences

- Resolver dials follow mihomo's defaults: direct (outside the tunnel, bound
  to the physical interface) unless the entry says otherwise. A resolver that
  must be reached *through* the tunnel is expressed in mihomo's own syntax
  (`10.0.0.53#PROXY`). This record originally claimed such an entry "passes
  the sanitizer untouched" and left it there — which was true and useless: the
  pin was honoured, the proxy's hostname then had no way to resolve, and the
  tunnel connected and carried nothing. Real subscriptions ship this (a panel
  pins `nameserver` to `#PROXY` and pairs it with its own
  `proxy-server-nameserver`, which we did not adopt). Hence the two additions
  to the Decision above.
- The self-hosted service has the schema field (`Bundle.DNS`) but no admin
  surface that sets it yet; until that exists, self-hosted users get the
  fallback.
- Every format that can carry resolvers now does: Clash `dns.nameserver`,
  Xray `dns.servers`, sing-box `dns.servers` (both schema generations), and
  the self-hosted `Bundle.DNS`. A link list has nowhere to put one and gets the
  fallback. The DNS is read by the parser that already identified the format
  and travels on `ParsedSubscription`, so the format is decided once instead of
  being guessed again from a different angle.
- `Bundle.DNS` is still never set: the schema field exists, no admin surface
  writes it, so self-hosted configurations get the fallback in practice.
- What does *not* survive the translation is the per-domain part of a JSON DNS
  block — Xray's `domains`/`expectIPs` filters, sing-box's `dns.rules`. mihomo
  expresses that as `nameserver-policy`, and adopting it would mean adopting a
  second routing language from a body we do not control. The resolver list is
  taken; the filters are not.
- The decoy `1.1.1.1/8.8.8.8` in NEDNSSettings looks meaningful to a reader of
  the Swift code; the comment there and this record are the defence against
  someone "fixing" per-config DNS by editing it.

## Where It Lives

- Renderer (`dns` parameter, sanitation, scheme check, pins, bootstrap,
  fallback): `client/lib/core/mihomo_tun_config.dart`
- Shared translation into mihomo's spelling:
  `client/lib/core/parsers/dns_servers.dart`
- Per-format mining: `_dnsServers` in `clash_config.dart`, `xray_config.dart`
  and `singbox_config.dart`; carried on `ParsedSubscription.dns`
- Persistence and plumbing: `client/lib/core/profile.dart`,
  `client/lib/core/norm_config.dart`, `client/lib/core/config_source.dart`,
  `client/lib/state/profiles_controller.dart`,
  `client/lib/core/network_extension_core.dart`
- Bundle schema: `shared/normconfig/normconfig.go` (`Bundle.DNS`)
- OS-level decoy: `applyNetworkSettings` in
  `client/shared/apple/PacketTunnelProvider.swift`
- Tests: `client/test/dns_sources_test.dart`,
  `client/test/mihomo_tun_config_test.dart`, `client/test/hot_switch_test.dart`
