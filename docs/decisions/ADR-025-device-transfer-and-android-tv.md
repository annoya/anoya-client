# ADR-025: A phone carries the setup to a TV or computer over the local network; Android TV runs the same app

## Status

Accepted

## Date

2026-10-28

## Context

Setting up a TV meant typing a subscription URL or a `vpn://` key with a
remote. A computer is easier, but the link still has to get there. iCloud sync
(ADR-020) covers only Apple devices, and Google offers nothing like it: Auto
Backup restores only at install, Block Store only during a new phone's setup,
and Drive's app folder needs a Google sign-in and a way to get an encryption key
to the second device. A TV and most computers have no camera, so the QR code
has to be on their screen, and the phone has to send.

The receiving device is usually being set up because it has no VPN yet. In the
networks this app is built for, a relay server abroad may not be reachable from
it. A transfer that never leaves the local network is not affected by that.

## Decision

- **The receiver shows a code; the phone sends.** "Receive from a phone" is on
  the start screen everywhere, and in Settings on TVs and computers. "Send to
  another device" is in Settings on phones with a camera, and the start
  screen's scanner also recognises a receive code and opens the send screen.
- **The code:** `anoya://receive?v=1&n=<device label>&t=tv|desktop|phone&a=<ipv4,…>&p=<port>&k=<x25519 public key>`.
  Addresses are the device's private IPv4 addresses (10/8, 172.16/12,
  192.168/16), without the tunnel's own 172.19.0.0/30. A fresh key pair and a
  fresh port are made each time the screen opens, and both are dropped when it
  closes.
- **The wire:** plain HTTP `POST /transfer` to the receiver. The body is
  `1 · sender public key (32) · AES-256-GCM(nonce 12 · ciphertext · tag 16)`
  over gzip(JSON), with the key derived by HKDF-SHA256 from X25519(sender,
  receiver), salted with both public keys, and the receiver's public key as
  associated data. Whoever else is on the Wi-Fi sees only ciphertext. The phone
  tries every address in the code at once, 5 s to connect each. The receiver
  answers 200 for a package that opens, 403 for one that does not (a code from
  an earlier visit), and closes its port after the first package it accepts.
- **What travels is the iCloud recipe** (ADR-020): a configuration's source,
  credentials and routing choices. Links and pasted subscriptions bring their
  servers; everything else is fetched by the receiver. Issued Amnezia servers,
  the active choice, the device's identity and its own choices (appearance,
  auto-connect, apps outside the VPN) stay behind. The phone picks
  configurations one by one, plus "Rule sets" and "Settings" (routing defaults,
  DNS, connection check). Rule sets that a picked configuration routes by
  travel even with "Rule sets" unticked.
- **Nothing lands without the receiver's confirmation.** The receiver lists
  what arrived, marking a configuration whose id it already has as an update.
  "Add" applies the package through the same controller paths as an iCloud
  change: rule sets are merged by id, the routing defaults are replaced (the
  geo download time stays local), and configurations go through
  `applyFromCloud`, so sources are fetched and an Amnezia key asks for this
  device's own server. If nothing was active, the first configuration becomes
  active.
- **The phone warns before it sends.** The send screen always says the
  transfer works only on the same network. While its own VPN is up with
  "Local network direct" off, it also says to turn that on or disconnect,
  because the tunnel would otherwise carry the LAN connection away.
- **Android TV is the same APK.** The manifest declares `LEANBACK_LAUNCHER`, a
  320×180 banner, and touchscreen and leanback as optional features. `isTv`
  comes from the UI mode or the leanback feature, through `device_info`. On a
  TV:
  - the whole app sits inside the 48/27 overscan-safe area;
  - there is no QR scanner and no file picker;
  - focus is always drawn (`FocusHighlightStrategy.alwaysTraditional`): a TV
    has no touch, so waiting for the first key press would hide it;
  - focus starts on the screen's main control (Connect, "Add a connection",
    "Receive from a phone"), and the Connect button takes it again when a
    configuration becomes active;
  - the receive screen keeps the screen awake.
- **Layouts and focus on TV and other wide screens.**
  - A landscape screen lower than 600 (a TV, a phone on its side, a short
    desktop window) lays Home out in two columns, the hero beside the cards.
    The receive screen does the same with its code beside the steps.
  - Keyboard and D-pad focus is the DS ring plus the hover layer, so it reads
    across a room.
- **Platform permissions.**
  - iOS and macOS declare `NSLocalNetworkUsageDescription`, and the sandboxed
    macOS build gets `network.server`.
  - The Windows installer allows Anoya through the firewall on private
    networks only.

## Invariants

All pinned by `test/device_transfer_test.dart` unless noted.

- A package opens only under the key in the code it was sealed to, and a
  tampered one does not open.
- The code never offers the tunnel's own address, loopback, link-local or a
  public address.
- A receiver takes one package and closes. A package sealed to an older code
  is refused, and the current code stays usable.
- A picked configuration's rule set travels with it.
- Applying a package twice updates the same configuration instead of adding a
  second one, and the first one arriving on an empty device becomes active.
- On a TV the start screen offers no camera and no file, and focus starts on
  "Receive from a phone" (`test/start_screen_test.dart`).

## Alternatives Considered

### A relay server

What a QR-based transfer usually uses. Rejected for now:
- the receiving device has no VPN yet, and a relay abroad may be blocked
  exactly where the app is needed;
- it is one more service to run.

The code and the sealed package would not change if one is added later as a
second delivery path.

### Google Drive app folder, like iCloud sync

The real counterpart to ADR-020. Rejected for now because it needs a Google
sign-in on a TV and a separate way to share the encryption key. A Drive
transport would still need a pairing step like this one.

### Putting the configuration in the QR itself

Rejected:
- a subscription with its servers does not fit one code;
- a TV cannot read a code shown by the phone, so the data would have to go
  the other way anyway.

### A short code typed on the phone (PAKE)

It would work between two devices without cameras. Rejected because it needs
the same transport and a password-authenticated key exchange, for the rare
computer-to-computer case.

### A separate Android TV app or a leanback UI

Rejected: every screen would be built twice. The phone layout already fits
the 560 column, and only Home needs a second arrangement.

## Consequences

- Both devices have to be on one network without client isolation. Guest Wi-Fi
  and a phone on mobile data fail with "Couldn't reach …".
- On Windows, a network the system calls public blocks the receiver.
- An Amnezia key moved this way counts as one more device against its limit, as
  typing it would.
- A TV has no browser for SSO sign-in. Self-hosted servers that only offer
  SSO have to be transferred from a phone.
- Flutter has no 32-bit x86 release engine, so x86 Android TV boxes are not
  supported.

## Where It Lives

- `lib/core/device_transfer.dart` — the code, sealing, receiver and sender,
  the package
- `lib/state/transfer_inbox.dart` — applying a package
- `lib/features/receive_screen.dart`, `lib/features/send_screen.dart`,
  `lib/features/qr_code_view.dart`, `lib/features/qr_scan_screen.dart`,
  `lib/features/start_screen.dart`, `lib/features/settings_screen.dart`
- `lib/core/platform_support.dart` (`isTv`, `canScanQr`, `canOpenFiles`),
  `lib/core/ui.dart` (`isWideLandscape`, `kTvSafeArea`),
  `lib/features/home_screen.dart`, `lib/app.dart`
- `android/app/src/main/AndroidManifest.xml`, `res/drawable-xhdpi/tv_banner.png`,
  `VpnChannel.kt` (`device_info.tv`, `keep_screen_on`)
- `ios/Runner/Info.plist`, `macos/Runner/Info.plist`,
  `macos/Runner/Release.entitlements`, `windows/installer/Anoya.iss`
- `design/ui-spec.html` §15
- `test/device_transfer_test.dart`, `test/start_screen_test.dart`,
  `test/home_layout_test.dart`
