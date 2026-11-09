# ADR-029: A local DNS answers the names direct rules send past the VPN, with real addresses

## Status

Accepted.

## Date

2026-11-09

## Context

A domain routed `DIRECT` is still resolved by the configuration's resolver, which
usually rides the tunnel (ADR-008). The answer is then picked for the exit's
country: a CDN hands out a node near the VPN server, and the direct connection
goes there from the user's network.

- INCY and Happ (Xray) ship two resolvers: remote for proxied names, domestic
  for names their direct list covers. With FakeDNS on, proxied names get fake
  addresses and direct names get real ones from the domestic resolver.
- mihomo can do the same with `nameserver-policy` and `fake-ip-filter`, both of
  which accept `rule-set:<provider>` and `geosite:<tag>`, and with
  `direct-nameserver`, which `DIRECT` dials use to resolve a host.
- Rule matching resolves through the main resolver (`tunnel.go`,
  `ResolveIP`); a `DIRECT` dial resolves again through `DirectHostResolver`
  (`adapter/outbound/direct.go`). `direct-nameserver` alone fixes the dial but
  not what IP rules see, and apps still get fake addresses.
- A `rule-set:` reference to an `ipcidr` provider is a parse error for the
  whole config. A domain that fails to insert into `fake-ip-filter` is too.

## Decision

- **Settings → DNS**, one row in Routing and a screen behind it, holds every
  resolver the device decides, in three groups named by where traffic goes:
  Default DNS (through the VPN, ADR-008), Local DNS (outside the VPN), Corporate
  domains (company network, ADR-028). Each group carries a note on what it
  answers and what it costs.
- **Local DNS is off by default.** Off, the rendered config is byte-identical to
  one without the feature. Choices: Off, Cloudflare, Google, Custom… — the
  non-filtering presets; an address is held to Default DNS's rules.
- **On, every direct rule by domain names the local resolver** in
  `nameserver-policy` and `fake-ip-filter`: an inline set as
  `rule-set:_inline_N`, a single domain as `+.d` or `d`, a geosite as
  `geosite:tag`, a list whose behaviour is not `ipcidr` as `rule-set:name`. A
  subscription rule counts when its target resolves to `DIRECT` through the
  current select choices (`resolvePlanRef`); its domains are validated before
  they reach the engine.
- **`direct-nameserver` and `direct-nameserver-follow-policy: true`** cover
  direct connections the domain rules did not name, and keep corporate domains
  at their own server.
- **Corporate entries come first in `nameserver-policy`.** mihomo walks
  policies in order, so they win over the local resolver.
- Applies to every routing owner. Only the `dns` section changes: hot reload,
  no reconnect.

## Invariants

- Direct domains are asked at the local DNS and get real addresses —
  `test/local_dns_test.dart`;
  `native/mihomocore/engine/engine_test.go`
  (`TestLocalDnsAnswersDirectDomainsWithRealAddresses`).
- Corporate domains keep their own server ahead of the local DNS — both tests
  above.
- A subscription rule counts by its current choice; an address list never
  reaches the DNS section — `test/local_dns_test.dart`.
- Off means no change; the tun section never changes —
  `test/local_dns_test.dart`.
- The service accepts both keys — `native/mihomocore/service/service_test.go`
  (`TestOnlyTheRenderedShapeReachesTheEngine`).
- The screen offers only non-filtering presets and keeps the choice —
  `test/dns_settings_screen_test.dart`.

## Alternatives Considered

### `direct-nameserver` only

One key. Rejected: apps still get fake addresses, and IP rules (`GEOIP`,
subnet rules that resolve, ADR-027) still judge a direct site by the tunnel
resolver's answer.

### Turning fake-ip off, as INCY does by default

Real addresses for everything. Rejected: fake-ip mode is an app constant
(ADR-008) — the OS caches fake addresses across hot switches — and domain rules
would depend on sniffing alone.

### A local resolver per configuration

The INCY shape (both resolvers in the profile). Rejected: where the user is
decides the local resolver, not which VPN they picked; a configuration's own
resolvers already travel with it.

### Working out which direct rules a proxy rule above shadows

`fake-ip-filter` has no order, so `api.x → proxy` above `x → direct` still gives
`api.x` a local real address. Not done: the connection still goes through the
proxy, to a local address; computing shadows across rule sets, lists and
geosite is not worth that.

## Consequences

- With it on, the local network sees the names of direct sites. Their traffic
  already shows it.
- Only domain rules decide at lookup time. Process and IP rules are unknown when
  the system resolver asks; those connections get fake addresses and resolve at
  the local resolver when they dial.
- A real address is cached by the OS for its TTL. A domain that turns proxied on
  a config switch keeps arriving as a bare IP until then; the sniffer restores
  the name for TLS, HTTP and QUIC only.
- Synced and transferred with the other routing preferences, like corporate
  domains.
- A local resolver behind another VPN's adapter is out of reach (ADR-028).

## Where It Lives

- `lib/core/mihomo_tun_config.dart` — `localDns`, `_directNames`,
  `_planParts` (`directNames`).
- `lib/core/routing_prefs.dart` — `localDns` (`local_dns`);
  `lib/core/norm_config.dart`, `lib/core/effective_config.dart`,
  `lib/core/network_extension_core.dart`.
- `native/mihomocore/service/config_check.go` — accepted `dns` keys.
- `lib/features/dns_settings_screen.dart`, `settings_screen.dart`.
- `design/ui-spec.html` §3.3–3.3b, §12.7.
