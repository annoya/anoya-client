# ADR-005: The client serves three domains of authority, not one backend

## Status

Accepted

## Date

2026-08-09 (recorded; decided 2026-07)

## Context

A client bound to one management service is only useful to the companies that
run that service. But the ecosystem it lands in already has two other ways of
handing someone a VPN, and a person routinely holds all three at once: a work
account on a managed server, a paid subscription from a panel like Marzban or
3x-ui, and a share link from a friend. Installing three applications for that is
absurd.

The three are not three import formats. They differ in **who has authority over
the user's access**, and everything else follows from that: whether there is an
account to display, whether a policy can be pushed, whether revocation is
possible, whether refreshing means anything at all.

## Decision

The client holds a **list of configurations**, one active, and each belongs to
one of three domains:

- **Self-hosted** — an authenticated management service owns identity, access
  and policy. Full capability: account status and quota, a managed routing
  policy that overrides local rules, immediate revocation, and a re-fetch before
  every connect so all of that is enforced at the moment it matters.
- **Subscription** — a third-party panel owns access, and the only contract is
  one-way: a URL returns a list of servers in any of the four shapes the panels
  serve (base64 URI list, Clash/mihomo YAML, Xray JSON, sing-box JSON). No account; the panel revokes by changing what the URL returns,
  so the client only polls. It may also send **routing** — as a `routing:`
  header, as a Clash `rules:` list, or in the Xray rendering of the same
  subscription — which the client applies **by default but under a switch**.
- **Link** — nobody owns anything. A `vless://` / `vmess://` / `trojan://` /
  `ss://` link is a static snapshot of one server; there is no origin to ask and
  nothing to refresh.

**A panel's routing is offered, not imposed.** It is translated into our own
rule model rather than adopted: rules with no equivalent here are dropped and
*counted*, and the count is shown, since a partial policy that reads as complete
is worse than none. The switch is the line between the domains: a self-hosted
server both sets and enforces its policy, while a panel can only change what it
returns. It has no authority over where this device's traffic goes, so the user
keeps the decision and gets their own rule set back the moment they turn the
provider's routes off. The Xray rendering is requested **by name**
(`<url>/json`, a documented panel feature), never by impersonating another
client's User-Agent.

What "no equivalent" means was settled against the engine's source
(`rules/parser.go` in the pinned mihomo), not from memory. Three different
reasons, and only one of them is a gap in this app:

- **Nothing to match.** `inboundTag`, `SRC-*`, `IN-*`, `UID`: they describe
  which of a proxy server's many inbounds a connection arrived on. We have one
  input, the tunnel interface, and DNS is hijacked in the engine. Xray's
  sniffed `protocol` has no rule form in mihomo at all.
- **The data is not here.** Xray's `ext:` names a file on the panel server's
  own disk — no address, nothing to fetch, unsupported at any setting. Clash's
  `RULE-SET` does have an address, which is why it became a decision rather
  than a limitation (below).
- **Our model was narrower than the engine.** `DOMAIN-REGEX` exists and we were
  discarding `regexp:` for nothing; it is now `domain-regex`. `DST-PORT`,
  `NETWORK`, `IP-SUFFIX` and `IP-ASN` exist too and are still unmapped —
  deliberately deferred, since each one is a rule type in the editors as well
  as the parser.

**Holding a provider's rule lists is a second, separate decision.** A
`rule-list` rule points at a file the provider hosts. Applying their rules is
one thing; keeping their files on the device and re-downloading them weekly is
another, so it has its own switch, off by default, on the configuration rather
than in global settings — trust in lists is trust in a particular provider.

The files are downloaded by the app, never by the engine, and handed over as
`type: file`. mihomo would do it itself: `loadProvider` in
`hub/executor/executor.go` runs the initial fetch inside `ApplyConfig` under a
`wg.Wait()` with a 20 s timeout per file — a stalled connect, exactly what the
geo databases taught us (ADR-003) — and since `ApplyConfig` returns nothing, a
failed fetch is only logged, leaving a rule that **silently matches nothing**.
Downloading here means the outcome is known: a list that did not arrive has its
rule left out and the screen says which list and which host.

**All four formats are read, and a body that yields nothing says which kind of
nothing it was.** Reading two of the four was invisible as a gap: an
unparseable body produced zero servers and the message "No servers found in the
subscription", which is a claim about the provider rather than about us and sent
the user to check the one thing that was fine. Which template a panel serves is
an admin's response rule keyed on User-Agent, so "ours works today" was never a
property of the client. Now: unknown format, known format with an empty list,
and known format whose every server needs a protocol we lack are three separate
sentences, because they have three different fixes.

**The app asks for the format it wants instead of hoping to be recognised.**
A panel chooses what to send by matching the client's User-Agent, so a
capability like groups otherwise depends on an admin having written a rule for
this app — measured on a live panel: our old Dart-SDK default matched one, and
renaming ourselves to `AnnoyaTest/1.0` silently dropped us to base64, losing
groups and provider routing with nothing in the code to show for it. Asking by
name (a documented feature of every panel that has renderings) removes the
dependency. It also overrides what the admin's rule intended for us, which is
the trade: we prefer a capability we can rely on over a choice made for a client
the admin may never have heard of.

**A subscription's groups are carried, and the engine keeps the choice.** A
`url-test` group is not something we reimplement in Dart: mihomo measures each
member through itself, switches only when a new leader beats the current one by
more than `tolerance`, re-picks per dial (so a switch never tears down live
connections) and re-checks off-schedule after repeated dial failures. Reproducing
that above the engine would be a second, worse implementation of it. What is
ours is the boundary: which groups are offered (only the ones where the engine
chooses), which members exist (only servers we can run), the interval floor, and
the fact that the picked member is displayed rather than left as "auto".

**Capability degrades along that order, deliberately and visibly.** A link shows
no account card and no server picker; a subscription shows servers but no
account; only a self-hosted configuration can be told by its server to stop
connecting. The app never pretends to know something the domain cannot tell it.

The differences live in a sealed `ConfigSource` hierarchy rather than in `if`
branches across the app: whether it can be refreshed, whether it must be
refreshed before connecting, whether it has an account, whether it has more than
one server.

**Only self-hosted refetches before every connect.** The specification called
that the core invariant; it makes sense against a management server that
enforces status and rotates keys, and no sense against a static link. Cached
data is used otherwise, with a background poll every five minutes for sources
that support it.

**The engine config renderer is generic** over proxy types and rejects what it
does not understand, rather than assuming the self-hosted VLESS+Reality shape.

## Invariants

- Adding, refreshing or removing a configuration never touches another
  configuration's stored credentials. Each self-hosted profile keeps its own JWT
  in the Keychain.
- The active configuration is always visible on the home screen, even when it is
  the only one.
- A configuration that cannot connect (inactive account, expired quota) says so
  before the tunnel is attempted.
- Routing that came from outside the device is always attributed to its source
  on screen, and a rule that could not be translated is never silently dropped:
  either it is applied or its absence is counted where the policy is summarised.
- The engine never fetches anything while applying a config. Every external
  file it reads — geo databases, rule lists — is already on disk, put there by
  the app, which is therefore the only party that has to report a failure.

## Alternatives Considered

### Serve only the self-hosted domain

Rejected: it makes the product one company's internal tool, and a client nobody
installs unless their employer tells them to. Supporting the other two domains
costs a parser and a source abstraction.

### Treat subscriptions and links as an import into one internal model

Rejected. Flattening them would mean either inventing account state that does
not exist (a fake "active" status for a link) or dropping the state that does
(quota and policy on self-hosted). The domains have genuinely different
authority and the model keeps them apart.

### One combined picker for configuration and server

Rejected: they are different questions asked at different frequencies. The home
screen has two rows.

### Branch on configuration type where needed

Rejected in favour of the sealed hierarchy after the branches started
multiplying (refresh, connect, account display, location picker visibility).

### Handle subscription formats on the server

Rejected for this half: the server does not know about a user's third-party
subscriptions, and it must not — that would make it a proxy for traffic it has
no business seeing.

## Consequences

- The product now supports protocols the server side does not provision
  (`vmess`, `trojan`, `ss` arrive through links). The `protocol.Driver` seam on
  the server is unaffected, but the client's supported set is deliberately
  wider — it has to be, because the other two domains bring whatever their
  owners chose.
- Two of the three domains cannot enforce anything, and that is not a defect to
  be fixed later. A subscription that stops working and a link that goes stale
  are the user's problem with their provider; the client's job is to say so
  clearly, not to simulate control it does not have.
- Storage grew: `profiles.json` plus one Keychain entry per self-hosted profile,
  plus favourites keyed by `profileId/locationId` (location ids are only unique
  within a profile).
- The domain model in SPEC.md §3 describes the self-hosted domain only; the
  other two have no server-side model by definition.

## Where It Lives

- `client/lib/core/profile.dart`, `config_source.dart`, `profile_store.dart`.
- `client/lib/core/routing_policy.dart` — the three policy classes.
- `client/lib/state/group_member.dart` — what a selected group resolved to.
- `client/lib/core/rule_list_store.dart` — the provider's list files.
- `client/lib/core/parsers/` — `share_link.dart` (single links),
  `clash_config.dart`, `xray_config.dart`, `singbox_config.dart`,
  `mihomo_proxy.dart` (the transport/TLS mapping all three share),
  `subscription.dart` (format dispatch + the verdict), `provider_routing.dart`
  (a panel's rules → our model).
- `client/lib/core/subscription_fetch.dart` — the fetch, the device headers and
  the routing lookup.
- `client/lib/state/profiles_controller.dart` — the list, the active profile,
  the connect path, polling.
- `client/lib/features/start_screen.dart` — the two ways in.
- Tests: `client/test/parsers_test.dart`,
  `client/test/provider_routing_test.dart`, `client/test/routing_policy_test.dart`,
  `client/test/rule_list_store_test.dart`, `client/test/formats_test.dart`,
  `client/test/proxy_groups_test.dart`,
  `client/test/config_screen_test.dart`,
  `client/test/settings_configurations_test.dart`, `client/test/home_layout_test.dart`.
