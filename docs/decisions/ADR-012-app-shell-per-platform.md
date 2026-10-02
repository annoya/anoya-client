# ADR-012: The app shell on each platform — a window that closes to the menu bar or tray

## Status

Accepted

## Date

2026-09-23 (recorded)

## Context

The tunnel lives outside the app on every platform (ADR-001), so the app can
go away while the VPN stays up. The shell around the Flutter view — window,
menu bar or tray item, permissions, logs, packages — has to be built on that
fact, and each platform gets it wrong in its own way by default.

## Decision

### macOS: window plus menu bar item

- Closing the window keeps the app running, in the menu bar **and** the Dock
  (`AppDelegate.swift`). Quitting on close cannot coexist with a status item:
  the item would vanish with the window. A click on the Dock icon brings the
  closed window back (`applicationShouldHandleReopen`); a Dock icon that does
  nothing reads as a hung app.
- The menu is AppKit's own `NSStatusItem` + `NSMenu` (`MenuBarController.swift`).
  Show, hide and quit are handled natively with no Dart round trip, so they
  work while the Flutter isolate is busy. Connect and disconnect go to Dart,
  because a connect refreshes managed profiles, applies routing policy and
  reports errors; nothing about the tunnel is decided natively.
- Status text comes from Dart, the same sentence the home screen shows. Before
  opening, the menu sends `sync`: the session clock runs in Dart.
- Connect and Disconnect are both always present; the inapplicable one is
  disabled, not removed, so items never shift under the cursor.
- "Quitting leaves the tunnel connected" appears only while the tunnel is up,
  because quitting does not take it down.

### Windows: tray icon

- The tray menu mirrors the macOS one item for item (`tray_icon.cpp`),
  including `sync` before opening.
- Closing the window hides it to the tray; Quit is the menu's
  (`flutter_window.cpp`). A left click toggles the window, as background apps
  on Windows do.
- Pasting from clipboard history (Win+V) is repaired in the runner
  (`clipboard_history_paste.cpp`). Windows 11 pastes by injecting Ctrl+V
  without scan codes; Flutter's embedder turns that into Ctrl released before
  V is pressed, so nothing is pasted (flutter/flutter#143997). The message
  loop swallows a scan-code-less Ctrl+V and re-injects it with real scan
  codes, which Flutter reads as an ordinary Ctrl+V. Other scan-code-less keys
  pass through untouched. Drop this once the embedder is fixed.

### One running copy on every desktop

A second launch hands over to the first copy and exits: two copies would race
for the same tunnel, profiles and menu bar or tray item. The first copy shows
its window, wherever it was hidden.

- macOS: `AppDelegate` looks for another process with its bundle id before the
  window starts the engine, posts a distributed notification the first copy
  answers by showing its window, and exits.
- Windows: a session-local named mutex (`main.cpp`); the second copy posts a
  registered window message to the first copy's window and exits.
- Linux: the `GtkApplication` is unique on D-Bus; a second launch becomes an
  `activate` in the first copy, which presents the existing window.

### Linux: a plain window

No tray and no close-to-tray: closing the window quits the app, and the
tunnel, a system service, stays up (ADR-001). Reopening the app is how the
user gets the controls back.

### Desktop window size

Phone-shaped but freely resizable: macOS 400×700 (min 360×480,
`MainFlutterWindow.swift`), Linux and Windows 420×760
(`linux/runner/my_application.cc`, `windows/runner/main.cpp`). The screens are
designed for 393×852; a 1280×720 default shows one column in a field.

### Android

- Notification permission (runtime since Android 13) is asked once, on the
  first successful connect, when the foreground notification exists to be
  seen. A refusal is final (`VpnChannel.maybeAskForNotifications`). Without it
  the tunnel still runs; only the shade entry is dropped.
- A second web sign-in start cancels the pending one (`superseded`): the first
  browser tab can no longer answer anything the app waits for
  (`WebAuthChannel.kt`).
- `scripts/build-android.sh` builds one APK per ABI, named
  `<label>-<version>-<abi>.apk` from the manifest label and pubspec version.
  ABIs are pinned there (arm64-v8a, x86_64): the engine AAR has no
  armeabi-v7a, and gradle `abiFilters` are overridden by the Flutter plugin.

### Logs, on every platform

- The app reads at most the last 512 KB of a log; a log over 4 MB is halved to
  its newest half. Same numbers in `TunnelFiles.kt`,
  `shared/apple/PacketTunnelProvider.swift` and
  `native/mihomocore/service/files.go`. Nothing else prunes the engine's log,
  which it appends to for the life of the tunnel; on iOS an unbounded read
  would jetsam the extension.
- The engine runs at `debug` while logs are collected, `silent` otherwise. A
  WireGuard handshake that never completes appears only at `debug`.

### Linux packaging

`preremove` stops and disables the service before its files go. Only a dpkg
purge removes `/var/lib/anoya` (geo databases, last config); rpm and
pacman have no purge and keep it (`linux/packaging/scripts`).

## Alternatives Considered

### Quit on window close (macOS)

Rejected: incompatible with a menu bar item, and it leaves a running VPN with
no visible owner.

### An accessory (no-Dock) app

Rejected: a different product, launched and found differently — not a menu.

### Menu actions all routed through Dart

Rejected for show/hide/quit: a busy isolate would freeze the only control
left once the window is gone.

### Trim a log to exactly the cap

Rejected: once the cap is reached every new line would trigger a rotation.

### One fat APK

Rejected: each per-ABI APK is half the size and its name says which phone it
is for.

## Consequences

- Quitting the app is not disconnecting. The menu says so while it matters.
- Menu state is only as fresh as Dart's last push; `sync` on open covers the
  clock.

## Where It Lives

- `macos/Runner/AppDelegate.swift`, `MenuBarController.swift`,
  `MainFlutterWindow.swift`
- `windows/runner/tray_icon.cpp`, `flutter_window.cpp`, `main.cpp`;
  `linux/runner/my_application.cc`
- `android/app/src/main/kotlin/org/anoya/vpn/VpnChannel.kt`,
  `WebAuthChannel.kt`, `TunnelFiles.kt`
- `shared/apple/PacketTunnelProvider.swift`,
  `native/mihomocore/service/files.go`
- `linux/packaging/scripts/`, `scripts/build-android.sh`
