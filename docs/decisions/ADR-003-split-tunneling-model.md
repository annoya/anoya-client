# ADR-003: Split tunneling as reusable rule sets, opt-in per configuration

## Status

Accepted

## Date

2026-08-09

## Context

Two audiences need routing rules for opposite reasons. A company wants a policy
it controls centrally — corporate hosts through the VPN, everything else direct,
and the employee should not be able to quietly opt out. A private user wants the
opposite: their own rules, different per configuration, changed on a whim.

Both audiences reuse policies across configurations: the same "work hosts
through the VPN" list applies to the corporate profile and to the backup one,
and a user with three subscriptions does not want to retype their exceptions
three times. So the question is where a policy lives and what binds it to a
configuration.

## Decision

**Rules live in named rule sets, global to the device.** A set has a direction
(`full` — everything tunnelled, rules are exceptions; `split` — only matching
traffic tunnelled) and an ordered list of rules, first match wins. A built-in
`Default` set always exists and cannot be deleted.

**A configuration points at a set, and routing is opt-in per configuration.**
`Profile.routingEnabled` defaults to off; with it off no set is read at all and
everything goes into the tunnel. The chosen set is remembered while off and
comes back when re-enabled, so the switch is not destructive.

**A server-managed policy wins and ignores the local switch.** For self-hosted
profiles, management delivers the policy; the configuration screen shows it
read-only and offers no toggle, because a local override would silently diverge
from what the control panel reports.

**LAN access is its own device-level switch, not a rule.** Five private-range
`IP-CIDR … direct` rules are prepended to whatever policy is in force, managed
or local, whenever "Local network direct" is on. It answers a different question
("should my printer be reachable") than a routing policy does.

**Geo rules need databases, and the app owns them.** `geoip` and `geosite` rules
depend on `geoip.metadb` / `GeoSite.dat`, downloaded by the app into the App
Group container (the engine's home directory) and refreshed weekly. The engine's
own `geo-auto-update` stays off: a 20+ MB fetch during tunnel start is exactly
what must not happen. Until the databases are present, geo rules are dropped
from the rendered config, with a log line and a visibly inactive row in the UI.

**Rule types are gated by what the platform can enforce.** `process-name` asks
which local application owns a connection; only desktop can answer. On iOS and
Android the type is offered but disabled with a reason, and such rules arriving
from a desktop are shown inactive and dropped before rendering rather than
deleted from the set.

## Invariants

- Precedence is fixed: server-managed policy, else the profile's rule set if
  routing is enabled, else nothing. LAN-direct rules are prepended on top in all
  cases.
- A rule that cannot work on this device never reaches the engine config, and is
  never silently removed from the user's set either.
- `RoutingRule.isValid` mirrors the server-side validation. Values are
  interpolated into engine config text; an invalid one must not pass.

## Alternatives Considered

### Rules stored inside each configuration

Rejected: it makes reuse impossible — the same policy has to be retyped per
configuration and drifts between copies. Named, shared sets are how Happ solves
the same problem.

### Let the local switch override a server-managed policy

Rejected. The server owns that policy; a client-side "off" would contradict what
the admin sees in the panel. Considered explicitly and declined — even though in
this product the server is often the user's own.

### Fold LAN access into the rule list

Rejected: it is a device-level decision that must hold under a managed policy
too, and a user who wants their NAS reachable should not have to understand
CIDR ordering.

### Let the engine download geo databases itself

Rejected: it would fire during tunnel start, on a connection that is not up yet,
for tens of megabytes.

### Hide `process-name` entirely on mobile

Rejected: the user then hunts for a feature they saw on their Mac. Showing it
disabled with the reason costs one line and answers the question.

## Consequences

- Rule sets are global, so editing one changes every configuration using it. The
  rule-set list shows the usage count for that reason.
- A set edited *inside the editor* on a live tunnel applies from the next
  connect; only toggling routing and switching sets apply hot. Accepted for now
  — the alternative is a hot reload per keystroke-ish edit.
- The client understands rule types (`geoip`, `geosite`, `no_resolve`) that
  `shared/normconfig/routing.go` does not. A managed policy using them would
  fail server-side validation. **Known divergence, not yet resolved.**
- Geo databases are ~25 MB on disk in the shared container, and the whole simple
  editor is unusable without them.

## Where It Lives

- `client/lib/core/rule_set.dart` — sets, storage, the built-in Default.
- `client/lib/core/profile.dart` — `ruleSetId`, `routingEnabled`.
- `client/lib/state/profiles_controller.dart` — `_normConfig`: precedence, geo
  gating, platform gating, LAN rules.
- `client/lib/core/routing_prefs.dart` — device-level prefs and LAN rules.
- `client/lib/core/geo_store.dart`, `geosite_index.dart` — databases.
- `client/lib/core/platform_support.dart` — `supportsProcessRules`.
- `client/lib/core/rule_list_store.dart` — the provider's list files, on disk in
  the App Group container, refreshed weekly. Turning the switch off stops
  applying them but does not delete them: the switch promises to apply their
  rules, not to manage the disk, and deleting made changing one's mind cost the
  whole download again. The sweep for files nothing points at any more runs
  after a refresh, where a provider may genuinely have dropped a list.
- `client/lib/features/config/routing_config_screen.dart` — the page holding the
  controls for all three kinds of policy, reached by one row (`RoutingRow` in
  `config_parts.dart`) from every configuration screen. Split off because these
  controls were the largest thing on a screen that answers a different question,
  and the part fewest people open.
- `management/internal/store/routingprofiles.go`, `shared/normconfig/routing.go`
  — the server half.
- Tests: `client/test/routing_simple_test.dart`, `client/test/status_strip_test.dart`
  (group `routing switch`), `client/test/routing_v2_test.dart`.
