# ADR-022: Android splits by app in two places — rules in the engine, a device list in the system

## Status

Accepted. Supersedes the `process-name` gating of ADR-003.

## Date

2026-10-24

## Context

On desktops an app is matched by a `process-name` rule: mihomo asks the OS
which process owns a connection. Android 10 closes the socket tables to apps,
so mihomo cannot find the owner itself. The VPN owner can still ask the system:
`ConnectivityManager.getConnectionOwnerUid`, API 29.

Android also has its own split: `VpnService.Builder.addDisallowedApplication`
keeps an app's traffic out of the tunnel entirely, and the app does not see a
VPN. Banking apps that refuse to run under a VPN need exactly that. But the
list is fixed when the interface is established, so it cannot change on a hot
switch (ADR-002).

## Decision

- **App rules go to the engine, as on desktops.** On Android 10+ a
  `process-name` rule matches a package name. The AAR is built with mihomo's
  `cmfa` tag, under which mihomo asks only `process.DefaultPackageNameResolver`;
  the service sets it through `engine.SetPackageLookup`, which calls
  `getConnectionOwnerUid` with the connection's ends as the app opened them
  (`RawSrcAddr`/`RawDstAddr`) and maps the UID to a package. Rules apply hot like
  any other rule.
- **Apps are picked, not typed, on Android.** The rule editor opens a picker of
  launcher apps and stores package names. A set is shared across platforms: a
  package name matches nothing on a desktop, a desktop name matches nothing on
  Android.
- **Where an app cannot be named, the type is not offered.** iOS and Android
  before 10 do not list `process-name` in the type picker. A rule of that type
  that arrived with a shared set stays in the list, inactive, and is dropped
  before rendering, never deleted.
- **"Apps outside the VPN" is a device setting, Android only.** A list of
  packages next to Local network direct, kept by the tunnel service
  (`excluded_apps` in the engine dir) and applied with
  `addDisallowedApplication` at every establish, including always-on and system
  restarts. It does not depend on the configuration, so a hot switch never makes
  it stale. Changing it while connected shows "Applies after reconnecting" and
  a "Reconnect now" that re-establishes the interface; the app never restarts the
  tunnel on its own.

## Invariants

- `process-name` is offered on desktops and Android 10+ only
  (*app rules work on desktops and Android 10+, never on iOS*,
  *where the platform cannot name the app, the type is not offered*).
- The owner is looked up by the ends the app opened, not by the engine's
  resolved destination (*TestTheAppIsAskedAboutTheConnectionAsTheAppSeesIt*).
- The exclusion list is a device setting, on Android only
  (*apps outside the VPN is an Android-only setting*); a reconnect is offered
  only while the running tunnel uses another list
  (*reconnecting is offered only when the running tunnel uses another list*).

## Alternatives Considered

### Exclusions as `process-name → direct` rules in the set

Rejected. The system list is fixed at establish, so switching to a
configuration whose set drops an app would leave that app bypassing the tunnel
against the new policy until a reconnect.

### Engine rules only

Rejected as the whole answer: an app sent `direct` by the engine still sees the
VPN, and banking apps keep refusing to work.

### Show `process-name` disabled where it cannot work

ADR-003 chose this so that people would not hunt for a feature seen on a Mac.
Reversed: a type that can never be picked is noise in a list people scan.

### `QUERY_ALL_PACKAGES` for the picker

Rejected: Google Play restricts it. A `<queries>` entry for launcher activities
lists every app a person would recognise.

## Consequences

- App rules do nothing on Android 9 and older.
- Each new connection costs one binder call for the owner, only when the set
  has app rules (`find-process-mode: strict` is rendered only then). The
  UID-to-package answer is cached for the life of the tunnel service.
- `cmfa` also disables mihomo's loopback detector; our sockets bypass the tunnel
  through `VpnService.protect`.
- An uninstalled app stays in the exclusion list under its package name.

## Where It Lives

- `native/mihomocore/engine/packages.go`, `mobile/mobile.go` — `SetPackageLookup`,
  `SetPackageResolver`
- `android/app/src/main/kotlin/org/anoya/vpn/MihomoVpnService.kt` —
  `ownerResolver`, `addDisallowedApplication`, `ACTION_RESTART`
- `android/app/src/main/kotlin/org/anoya/vpn/InstalledApps.kt`, `TunnelFiles.kt`,
  `VpnChannel.kt`
- `lib/core/platform_support.dart`, `lib/core/android_apps.dart`,
  `lib/state/excluded_apps_controller.dart`,
  `lib/features/excluded_apps_screen.dart`, `lib/features/app_picker.dart`,
  `lib/features/rule_screen.dart`
- `test/excluded_apps_test.dart`, `test/rule_screen_test.dart`,
  `test/platform_support_test.dart`, `native/mihomocore/engine/packages_test.go`
