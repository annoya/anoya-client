# ADR-004: On-demand auto-connect, and why there is no kill switch

## Status

Accepted

## Date

2026-08-09

## Context

Two related asks, often confused with each other:

1. *"Connect automatically"* — the tunnel should come up on its own when the
   user is on an untrusted network, without opening the app.
2. *"Never let anything out unprotected"* — a kill switch: if the tunnel is not
   up, traffic must not flow at all.

Apple offers a mechanism for each: on-demand rules
(`NEOnDemandRule`, evaluated by the system) and `includeAllNetworks` (the
system drops everything that is not in the tunnel). They are frequently
presented as two settings on one screen, which is why they get conflated.

## Decision

**On-demand is implemented in full.** Rules mirror `NEOnDemandRule`: interface
kind (Wi-Fi / cellular / any), SSID list, DNS domains and servers, probe URL.
The system evaluates them; the app only compiles and installs them.

The state model has three distinct facts, deliberately kept apart:

- `enabled` — the user's intent, stored by us;
- `paused` — the user disconnected manually while on-demand was armed. A manual
  disconnect must not be undone half a second later by the system, so
  disarming happens *before* stopping the tunnel;
- `systemArmed` — what the OS reports back. Intent is not effect: the system
  only accepts on-demand once there is a tunnel configuration to start from,
  which is why the state "enabled but not yet armed" exists and is shown.

**The rendered engine config is persisted into `providerConfiguration`,** not
only passed in start options. An on-demand start comes from the OS with no
options at all; without the persisted copy the extension would have nothing to
run.

**Removing the last configuration removes the system VPN profile,** so the user
is never left with an entry in System Settings that can still auto-start.
Disarming on-demand never creates a profile — asking for VPN permission in
order to turn something off is nonsense.

**There is no kill switch.** `includeAllNetworks` is not implemented and is not
planned as a toggle.

### Android (2026-08-30)

Android has no on-demand rules to compile. Its counterpart is the system's
**Always-on VPN** switch, which lives in system settings next to the system's
own kill switch ("Block connections without VPN"), and neither can be armed or
read by the app while the tunnel is down. So on Android the app ships no rule
editor, no Auto chip, and no toggle: an explainer screen and a button into the
system's VPN settings (`AlwaysOnScreen`). The saved config that a
system-initiated start runs is kept current by the same `syncConfig` calls that
maintain `providerConfiguration` on Apple. Verified end to end: always-on
enabled in system settings brings the tunnel up at boot with the app never
opened.

## Invariants

- The three on-demand facts are never collapsed into one boolean. "Off",
  "paused", "armed but not accepted by the system" and "working" are four
  different states and the UI names all four.
- A manual disconnect always wins over on-demand until the user connects again.
- The persisted config is updated whenever the effective config changes
  (configuration added or switched, location changed, subscription refreshed,
  routing changed) — an on-demand restart must not resurrect a stale config.

## Alternatives Considered

### Ship `includeAllNetworks` as a "block traffic outside the VPN" toggle

Rejected on the merits, not for effort:

- It breaks LAN-direct entirely — printers, NAS, AirDrop.
- It makes captive portals unusable: the user cannot reach the hotel login page
  to get the connectivity the VPN needs.
- Mullvad, who did ship it, publicly document why they steer users away from it.

The honest version of this feature is a firewall (pf) that permits the tunnel
and the local network and drops the rest — and that is a different, larger
piece of work, not a checkbox.

### A single "auto-connect" switch instead of a rule editor

Rejected as too poor to be useful: "auto-connect always" and "auto-connect on
untrusted Wi-Fi" are different products, and the reference clients (Happ,
Shadowrocket) all expose rules.

### Persist the config only when arming on-demand

Rejected as redundant: the config is already written on every change that
affects it, and a second write path is one more thing to keep in step.

## Consequences

- The reconnect leak window stays open. ADR-002 closes it for switching, where
  the session survives; an ordinary stop → start still removes the routes. A pf
  kill switch is the only thing that would close it, and its acceptance test
  already exists in idea form: a socket bound to the physical interface
  (`curl --interface en0`) must be dropped by the firewall. On a healthy tunnel
  without a firewall that probe is "red" by definition, which is exactly why it
  is not part of `leak-check.sh` today.
- SSID conditions only apply on Wi-Fi or Any. When another interface is
  selected they are neither shown nor compiled, but the values are kept so
  switching back restores them.
- On-demand is an Apple mechanism. Android (always-on VPN) and desktop
  (a service) have their own equivalents; nothing in the model above is
  Apple-specific except the rule compiler.

## Where It Lives

- `client/lib/core/on_demand.dart` — the model, `statusLabel`, `armed`,
  `awaitingFirstConnect`.
- `client/lib/state/on_demand_controller.dart` — intent and platform sync.
- `client/lib/features/on_demand_screen.dart` and the rule/value screens.
- `client/shared/apple/VPNManager.swift` — `setOnDemand`, rule compilation,
  `persist` into `providerConfiguration`.
- `client/lib/features/home_screen.dart` — the `Auto` chip and the explanatory
  banner.
- Tests: `client/test/on_demand_test.dart`, `client/test/status_strip_test.dart`.
