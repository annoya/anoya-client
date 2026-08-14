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
  to the physical interface) unless the entry says otherwise. That is fine for
  encrypted DoH/DoT; a resolver that must be reached *through* the tunnel is
  expressed in mihomo's own syntax (`10.0.0.53#PROXY`), which passes the
  sanitizer untouched.
- The self-hosted service has the schema field (`Bundle.DNS`) but no admin
  surface that sets it yet; until that exists, self-hosted users get the
  fallback.
- Raw xray-JSON configs are not a gap here: the client does not parse that
  format at all (they fail import before DNS could matter). Supporting them
  would be a new parser feature.
- The decoy `1.1.1.1/8.8.8.8` in NEDNSSettings looks meaningful to a reader of
  the Swift code; the comment there and this record are the defence against
  someone "fixing" per-config DNS by editing it.

## Where It Lives

- Renderer (`dns` parameter, sanitation, bootstrap, fallback):
  `client/lib/core/mihomo_tun_config.dart`
- Subscription mining: `subscriptionDns` in `client/lib/core/proxy_uri.dart`
- Persistence and plumbing: `client/lib/core/profile.dart`,
  `client/lib/core/norm_config.dart`, `client/lib/core/config_source.dart`,
  `client/lib/state/profiles_controller.dart`,
  `client/lib/core/network_extension_core.dart`
- Bundle schema: `shared/normconfig/normconfig.go` (`Bundle.DNS`)
- OS-level decoy: `applyNetworkSettings` in
  `client/shared/apple/PacketTunnelProvider.swift`
- Tests: `client/test/mihomo_tun_config_test.dart`,
  `client/test/hot_switch_test.dart`
