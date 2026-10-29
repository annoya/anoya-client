# ADR-026: A Clash subscription with rules runs by its own rules or as a server list

## Status

Accepted

## Date

2026-10-30

## Context

A Clash / mihomo subscription with `rules:` is a complete design: each service
goes to the group the provider named, auto-select groups pick the server, and
the user only presses Connect. Translating it into our model — one server on
Home plus exceptions — lost that design in three measured ways on live
subscriptions:

- Rules aimed at an auto-select group went to the first server of the list.
- Rule lists were off by default, so a split kept only its plain-domain rules:
  on 4308.uk, 11 domains went through the VPN while YouTube, Telegram and
  blocked sites went direct, with the app saying Connected.
- Rule types and groups our model lacks (`AND`/`OR`/`NOT`, `DST-PORT`,
  `NETWORK`, `PROCESS-NAME-REGEX`, inline lists, nested groups) were dropped.

Mihomo clients (Clash Verge, FlClash, Stash) apply the config as written and
switch between Rule and Global. Lists are hosted on CDNs (jsDelivr, GitHub)
that are often slow or blocked in Russia without a VPN.

## Decision

- **Two modes per subscription**, shown only when its Clash body has rules the
  app can apply: *Subscription rules* (default) and *Own rules*.
- **Subscription rules pass the provider's config through, filtered.**
  Servers, groups, rules and rule lists reach mihomo as written under
  positional names (`p<i>`, `g<i>`, `l<i>`, `i<i>`); tun, DNS, inbounds and the
  controller stay ours. Left out and counted: rule types with nothing to match
  here (`SRC-*`, `IN-*`, `UID`, `SUB-RULE`), meaning-changing options (`src`),
  targets with nothing runnable, undefined lists. Groups no rule reaches are
  not rendered; loops between groups are cut; a server's `dialer-proxy` is
  kept, a group's is not (mihomo refuses it).
- **No main server in that mode.** Home shows *Proxy groups*: the catch-all
  first, then `select` groups to choose, then the rest. A choice is only among
  the group's own entries; it is rendered first in the group and stays on the
  device.
- **Own rules** is the server list with device routing; the subscription's
  rules are ignored. Device routing is locked in the other mode.
- **Lists come with the mode, after consent.** Asked once per subscription,
  naming the count and hosts; *no* means Own rules. Lists a refresh adds are
  downloaded without asking. The mode never waits: a rule whose list is not on
  disk is left out, and the missing lists are downloaded again once the tunnel
  is up and applied with a hot reload.
- **The Clash rendering is asked for before the plain address**; a plain
  address that already is Clash is remembered as `plain`.
- Profiles from before keep subscription rules only if their lists switch was
  on, or if their rules need no lists.

## Invariants

- Only reached groups render, loops are cut, unusable rules are counted —
  `test/subscription_rules_test.dart` (*reading the subscription's rules*).
- Engine names, chains, choices and missing lists render correctly —
  *handing them to the engine*.
- Lists are kept only after a yes; no means Own rules — *when it is added*.
- Old profiles migrate as above — *which mode a subscription is in*.
- Home has no server card in subscription-rules mode; the exit sheet offers
  only the subscription's entries — `test/subscription_rules_ui_test.dart`.
- The rendering comes first and the plain address is not fetched —
  `test/subscription_resilience_test.dart`.

## Alternatives Considered

### Translate Clash rules into our rule model (the previous design)

Rejected: it cannot express what the templates use, and every gap sends traffic
somewhere the provider did not intend. The model exists for editors; this mode
has no editor.

### Select groups as "services" next to a main server on Home

Built and dropped before release. Two things chose the server for the same
traffic, the user had to learn which, and Home had to switch between a server
card and a services card depending on lists and choices.

### Keep rule lists off until the user turns them on

Rejected: the default produced a half-working split that looks connected. One
question at the moment it matters replaces a switch nobody finds.

### Let mihomo download the lists

Rejected for the same reason as ADR-005: the fetch runs inside config apply,
stalls the connect, and a failure leaves a rule silently matching nothing.

### Merge the Xray rendering's servers into the Clash one

Not done: two sources for one list. In Own rules a panel whose Clash rendering
drops transports (Swaga, xhttp) shows fewer servers than its Xray rendering.

## Consequences

- One server the engine rejects (bad short id, unknown option) now fails the
  whole config, not just that server. Zero-padded short ids are kept as written
  for this reason.
- Large lists (refilter, ru-bundle) count against the iOS Network Extension
  memory limit; not measured yet.
- A group's `dialer-proxy` (4308.uk's WHITE LISTS chain) is not applied, as in
  any mihomo client.

## Where It Lives

- `lib/core/clash_plan.dart` — the plan model.
- `lib/core/parsers/clash_config.dart` — `_plan`, the filter.
- `lib/core/mihomo_tun_config.dart` — `_planParts`.
- `lib/core/effective_config.dart` — mode selection.
- `lib/core/subscription_fetch.dart` — rendering order.
- `lib/state/profiles_controller.dart` — `withModeChosen`,
  `setSubscriptionRules`, `setGroupChoice`, `_completeLists`.
- `lib/features/config/proxy_groups_screen.dart`,
  `subscription_mode.dart`, `subscription_rules_card.dart`.
