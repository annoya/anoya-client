# ADR-019: A rule holds a list of values; long lists reach the engine as inline rule sets

## Status

Accepted

## Date

2026-10-04

## Context

The advanced editor added one domain, address or country per rule. A list of
exceptions a thousand entries long took more than a thousand taps, and once
entered it was a thousand rows to scroll, reorder and delete one by one. Such
lists usually already exist as text: sites like `iplist.opencck.org` export a
service's domains and subnets one per line or comma-separated.

## Decision

- **A rule is one match type, one action and a list of values** (`values` in
  JSON). A rule with one value behaves and looks as before. Reading still
  accepts the single `value` the server's schema and older files carry; writing
  is always `values`. The rule set file keeps format version 1 — the format had
  not shipped.
- **Text values are entered as a list.** The rule opens as a full page with a
  multi-line field, a paste icon inside it (appending, unlike the start
  screen's) and an “Add from a file…” button under it, as on the start screen. Domains, keywords and subnets split on
  lines, commas, spaces and semicolons; patterns and process names on lines
  only. Each value is tidied before it is judged: a link keeps its host (and
  drops `www.` for a suffix rule), `*.`, `+.` and a leading dot are dropped, a
  bare address gets `/32` or `/128`, `#` starts a comment. Duplicates are
  counted and dropped, unrecognised lines are listed with their line number
  and not saved; neither blocks the rest.
- **Domains and addresses travel together.** A domain rule given addresses saves
  them as an `ip-cidr` rule with the same action right after it; an `ip-cidr`
  rule given domains saves them as a `domain-suffix` rule. Both are shown before
  Save.
- **Countries and categories are multi-select**, shown as removable chips.
- **The engine gets an index, not a scan.** Several `domain-suffix`,
  `domain-exact` or `ip-cidr` values become one `RULE-SET` pointing at an
  inline provider (`type: inline`, `behavior: domain` with `+.` for suffixes,
  or `ipcidr` with `no-resolve`), named `_inline_<index>` — a name no
  provider list can take, since list names start with a letter or digit.
  Other types are written one line per value.
- **Simple mode shows single-value geo rules only.** A rule with several
  countries or categories sits under "Advanced rules".
- **Imports join neighbours.** Consecutive imported rules with the same type,
  action and `no-resolve` become one rule; rules are never joined across a
  different rule, since that would change which one matches first.

## Invariants

- A rule is valid only if every value is; one bad value drops the whole rule
  from the engine config, never part of it — `test/mihomo_tun_config_test.dart`.
- Inline lists never make the engine fetch anything —
  `native/mihomocore/engine/engine_test.go`
  (`TestInlineRuleListsParseAndMatchWithoutFetching`).
- Companion rules keep the edited rule's place in the order —
  `test/rule_set_import_export_test.dart`.

## Alternatives Considered

### Bulk-add N single-value rules

No model change. Rejected: input gets faster but the list does not — the
editor still shows a thousand rows, and mihomo tests a thousand lines in turn
for every connection instead of one lookup.

### Inline lists for every type

Rejected: mihomo has no indexed form for keywords, patterns or processes (a
`classical` provider is still a scan), and countries and categories are few.

### Refuse addresses pasted into a domain rule

Rejected: lists "for a service" mix both, and making the user split them by
hand is the work this change removes.

## Consequences

- The server's `normconfig/routing.go` still speaks single `value`. The client
  reads it; a managed policy with lists would need the server to learn
  `values` (see ADR-003's divergence note).
- Splitting on spaces means `youtube .com` becomes two values, `youtube` and
  `com`, both valid. The domain field keeps the URL keyboard, which does not
  insert a space after a full stop.
- Lists by URL (iplist's per-service links) are not fetched; text is pasted or
  loaded from a file.

## Where It Lives

- `lib/core/norm_config.dart` — `RoutingRule.values`, `isValidValue`.
- `lib/core/rule_values.dart` — parsing and tidying pasted text.
- `lib/core/mihomo_tun_config.dart` — inline providers.
- `lib/core/rule_set_transfer.dart` — `mergeAdjacentRules`.
- `lib/features/rule_screen.dart`, `routing_widgets.dart`,
  `geosite_sheet.dart`, `lib/core/ui.dart` (`pickOptions`).
- `test/rule_values_test.dart`, `test/rule_screen_test.dart`,
  `test/mihomo_tun_config_test.dart`, `test/rule_set_transfer_test.dart`.
