# ADR-024: The tunnel notifies when it cannot help, from its own process

## Status

Accepted

## Date

2026-10-24

## Context

People found out that the server had stopped answering only by opening the app:
the in-app connection check runs only while the app is on screen, and it has
false negatives (ADR-010). The process that is always there while the tunnel
runs is the tunnel itself, and its watchdog (ADR-014) already judges the server
by real traffic once a second.

## Decision

- **Two moments, nothing else.**
  - The server stays silent after the watchdog's reload. A single silence is the
    watchdog's to heal; the engine sets `ServerSilent` only when the next stall
    of the same episode follows a reload, and clears it on the first byte back
    or on stop. In practice that is about a minute and a half after the server
    went quiet, and only while something is trying to use it.
  - The tunnel could not start when the system started it (on-demand,
    always-on, start at boot). A start the person asked for shows its error in
    the app instead.
- **One notification per episode, withdrawn by itself** once traffic returns or
  the tunnel stops. Stops the system decides on are not reported.
- **The words come from the app, in the person's language.** Every connect,
  hot switch and config sync hands the tunnel a `notice` map built by
  `tunnelNotice` from the arb strings, with the configuration name and the
  server's label — never an address. The tunnel stores it next to its config,
  so a start without the app still speaks the right language.
- **Android.** A high-importance "Connection problems" channel for the two
  notifications; the foreground notification says "Connected · {server}" and,
  while silent, "Connected · no answer from the server". The small icon is the
  cat's silhouette (`ic_notification`): Android draws small icons as a mask, so
  the coloured launcher icon would be a white square. A tap on a silence opens
  the server picker through `take_launch_action`.
- **iOS and macOS.** The network extension posts the notifications itself
  through `UNUserNotificationCenter`, so they arrive with the app closed; the
  system shows the app's icon. The texts travel in the VPN profile
  (`providerConfiguration["Notice"]`) and in the start options, and a hot switch
  sends them as a `notice:` message. The app asks for permission once, right
  after the first successful connect, and its notification delegate turns a tap
  into the same launch action.
- **Windows and Linux.** The tunnel service has no UI: it polls
  `ServerSilent` and sends `notice` events (`silent`, `answers`, `start_failed`)
  to the app, which shows them over a `vpn/notify` channel — a balloon on the
  tray icon on Windows, `org.freedesktop.Notifications` over D-Bus on Linux,
  which works without a tray. A start at boot that failed reaches the first app
  that connects. A click shows the window and opens the server picker.

## Invariants

- The first silence is not reported; one report per episode; an answer clears
  it (*TestOnlyASilenceThatOutlivesAReloadIsReported*); stopping clears it
  (*TestStoppingTheEngineClearsTheReport*).
- The notice names the server, never its address or credentials
  (*the tunnel learns what to say about this server, never its address*).

## Alternatives Considered

### Notify from the app's connection check

Rejected: it does not run with the app closed, which is exactly when the
notification matters, and a captive portal or a blocked test host would raise
false alarms.

### Notify on the first silence

Rejected: the watchdog's reload usually brings the server back within seconds,
and a notification for a problem that has already gone teaches people to ignore
the next one.

### Native string resources for the texts

Rejected: the arb files are the one place for copy; a second set in Android and
Apple resources drifts.

## Consequences

- With no traffic there is no silence to see, so a dead server at night is
  reported when something next tries to use it.
- On Windows and Linux nothing is shown while the app is not running; the
  service has no way to reach the desktop on its own.
- Posting from the Apple network extension relies on it sharing the containing
  app's notification permission; it is to be confirmed on a device.

## Where It Lives

- `native/mihomocore/engine/watchdog.go` — `silenceEpisode`, `ServerSilent`
- `lib/core/tunnel_notice.dart`, `lib/core/network_extension_core.dart`,
  `lib/state/launch_action.dart`, `lib/features/home_screen.dart`
- `android/app/src/main/kotlin/org/anoya/vpn/MihomoVpnService.kt`,
  `MainActivity.kt`, `VpnChannel.kt`, `TunnelFiles.kt`,
  `res/drawable/ic_notification.xml`
- `shared/apple/PacketTunnelProvider.swift`, `shared/apple/VPNManager.swift`,
  `shared/apple/VpnChannel.swift` (`TunnelNotifications`)
- `native/mihomocore/service/service.go` (`watchSilence`, `noticeStartFailed`),
  `lib/core/pipe_transport.dart`, `lib/state/desktop_notices.dart`,
  `windows/runner/tray_icon.cpp`, `linux/runner/notifier.cc`
- `test/tunnel_notice_test.dart`, `test/desktop_notices_test.dart`,
  `native/mihomocore/engine/watchdog_test.go`,
  `native/mihomocore/service/service_test.go`
