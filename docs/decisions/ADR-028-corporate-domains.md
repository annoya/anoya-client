# ADR-028: Corporate domains are a device setting that resolves them at the company's DNS, with real addresses, outside the VPN

## Status

Accepted.

## Date

2026-11-08

## Context

Internal corporate names exist only in the company's DNS. With Anoya on, every
name is answered by the configuration's resolver, usually through the tunnel,
so those names fail even when the traffic itself would go direct. Excluding
corporate resources by subnet alone does not help: the name never resolves.

- Fake-ip answers apps without asking anyone. The real lookup happens at dial
  time on the configuration's resolver. A corporate name needs both a different
  resolver and, for SMB, Kerberos and most corporate software, a real address.
- mihomo has `nameserver-policy` (per-domain resolver, most specific domain
  wins, additive to `nameserver`) and `fake-ip-filter` (names answered with real
  addresses). `direct-nameserver` re-resolves only what goes `DIRECT`, after the
  app already holds a fake address — the app never sees the real one.
- Routing comes from three owners (ADR-003, ADR-005, ADR-027): device rule sets,
  a provider's routing, a subscription's own rules. A rule set is ignored when
  a provider routes.
- The engine's own DNS queries bypass the tunnel on every platform, and on
  Windows `strict-route` WFP filters permit the engine's process.

## Decision

- **Settings → Routing → Corporate domains**, next to Local network direct: a
  list of entries, each a set of domains and one DNS server. It applies to every
  configuration, under any routing owner, like Local network direct.
- **One entry renders three things.** Each domain becomes `+.<domain>` (itself
  and everything under it) in `nameserver-policy` pointing at the server with no
  pin, so it is queried directly; the same keys in `fake-ip-filter`; and one
  `domain-suffix → direct` rule ahead of every other rule, so a corporate host on
  a public address stays off the VPN too.
- **The server is an address.** A bare IP is plain DNS on 53; `tls://`,
  `https://` and the other engine schemes are accepted. A host name is refused,
  as in Default DNS (`dnsDefaultError`).
- **Input is the zone.** Commas, spaces or semicolons separate; a leading `*.`
  or `+.`, a trailing dot and case are dropped; a value that is not a domain is
  named back in a toast and nothing is saved.
- **Hot reload.** Only the `dns` section and rules change; no reconnect.
- With no entries the rendered config is byte-identical to one without the
  feature.

## Invariants

- Each domain is asked at its server and gets a real address —
  `test/corp_domains_test.dart` (*each domain is asked at its server…*);
  `native/mihomocore/engine/engine_test.go`
  (`TestCorporateDomainsAskTheirServerAndGetRealAddresses`).
- Corporate names go direct before any other rule — `test/corp_domains_test.dart`.
- The tun section does not change (ADR-002) — `test/corp_domains_test.dart`
  (*adding corporate domains leaves the tun section alone*).
- No entries, no change — `test/corp_domains_test.dart` (*without corporate
  domains the config is exactly what it was*).
- The service accepts the two keys — `native/mihomocore/service/service_test.go`
  (`TestOnlyTheRenderedShapeReachesTheEngine`).

## Alternatives Considered

### Overrides inside a rule set

The earlier spec. Rejected: a rule set applies only to configurations on device
routing, so switching to an Amnezia key with `allowed_ips` or a subscription
with its own rules would silently break internal names. The office network is a
property of the place, not of the VPN configuration.

### `direct-nameserver` (resolve `DIRECT` traffic at the system resolver)

No list to keep. Rejected: apps still get fake addresses, so software that needs
the real one breaks; the system resolver is readable only on Windows (Android
has no `resolv.conf`, the engine falls back to public resolvers); and the domain
still has to be routed `DIRECT` by some rule first.

### "The network's DNS" (`system`) instead of an address

Same platform problem as above, and on a corporate VPN adapter it is not
reachable by the engine (below).

### Route exclusion (`route-exclude-address`)

Keeps corporate subnets out of the tun entirely. Solves routes, not names, and
recreates the tun on change. Possible later, as its own device setting.

## Consequences

- A resolver reachable only through another VPN's adapter is not covered: the
  engine binds its dials to the default interface.
- No "through the tunnel" option: a corporate network behind the user's own
  server needs a `#PROXY` pin and a proxy rule. Not built.
- Setting `fake-ip-filter` replaces the engine's built-in list
  (`www.msftconnecttest.com` and two misspelled names); Windows' connectivity
  probe then goes through the tunnel, which answers it.
- Corporate entries override the user's own rules for the same domains.

## Where It Lives

- `lib/core/corp_domains.dart` — `CorpDomains`, `parseCorpDomains`, `withCorpDomains`.
- `lib/core/routing_prefs.dart` — `corpDomains` (`corp_domains`).
- `lib/core/effective_config.dart`, `lib/core/mihomo_tun_config.dart`
  (`corpDomains`), `lib/core/network_extension_core.dart`.
- `native/mihomocore/service/config_check.go` — accepted `dns` keys.
- `lib/features/corp_domains_screen.dart`, `settings_screen.dart`.
- `design/ui-spec.html` §12.4–12.6.
