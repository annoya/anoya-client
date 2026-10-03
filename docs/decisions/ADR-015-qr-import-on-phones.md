# ADR-015: Configurations are scanned from QR codes on phones only, with zxing-cpp, into the link field

## Status

Accepted

## Date

2026-10-03

## Context

Panels (3x-ui, Marzban, Hiddify, Remnawave) and key-subscription providers
hand out connections as QR codes. On a phone, typing or copying a long link
off another screen is the hard part of onboarding.

Three things make the choice non-obvious:

- The app is a VPN client. A scanner library that ships Google code or phones
  home is a cost a proxy app should not pay for one onboarding step.
- One QR does not always carry one string. The key provider's app cuts a
  `vpn://` key into a series of codes shown one after another, and panels wrap
  a subscription address in a client's deep link (`happ://add/…`,
  `sing-box://import-remote-profile?url=…`).
- A QR is read off someone else's screen. What was scanned is not always what
  the user meant to add.

## Decision

- **Phones only.** Android and iOS show *Scan a QR code* on the start screen.
  macOS, Windows and Linux do not: there the QR sits in a browser window on the
  same screen and the link is copied.
- **zxing-cpp through `flutter_zxing`** decodes camera frames and picked
  images. Choosing a photo is always offered, because a QR often arrives as a
  picture in a messenger on the same phone.
- **A scan fills the field, it does not add.** The text lands in the link
  field like a paste and goes through the same recognition chip; the user
  presses Continue.
- **What a QR may carry** is what the field reads, plus:
  - client deep links, unwrapped to the address inside — the `?url=`
    parameter, or an `http(s)://` path after `<scheme>://<verb>/`. Schemes we
    read ourselves (`vless`, `vmess`, `trojan`, `ss`, `hysteria2`, `hy2`,
    `http(s)`, `vpn`) are never unwrapped. A paste goes through the same
    unwrapping.
  - a subscription key as the provider's series: base64url of
    `qint16 1984 · quint8 count · quint8 index · QByteArray part`, parts of
    850 bytes of the key without `vpn://` (amnezia-client
    `qrCodeUtils::generateQrCodeImageSeries`). Every key uses the framing,
    even a one-part one. Parts are collected in any order; a new count starts
    over; the joined key gets `vpn://` back.
- **An unusable code does not close the scanner.** It shows the field's refusal
  chip and scanning continues. A denied camera is a screen with the photo
  path, not an error dialog.

## Invariants

- The scan button exists on Android and iOS and nowhere else —
  `test/start_screen_test.dart` (*scanning a QR code*).
- A key series reassembles to the original `vpn://` key regardless of order,
  repeats and one-part keys; a count change restarts —
  `test/qr_payload_test.dart` (*an Amnezia key shown as QR codes*).
- Our own schemes are never unwrapped, even with a `url=` inside —
  `test/qr_payload_test.dart` (*a link we read ourselves is never unwrapped*).
- No user-facing text names the key's provider (ADR-009) —
  `test/amnezia_config_test.dart`.

## Alternatives Considered

### Google ML Kit (`mobile_scanner`)

Faster and more forgiving on bad frames, and the most common choice. Rejected:
Google's library inside a VPN client, 3–10 MB more on Android (or a Play
Services dependency in the unbundled form), and no Windows or Linux.

### Camera on desktops

`flutter_zxing` has a beta desktop camera. Rejected: no one points a laptop at
a QR shown in the next window, and macOS adds a camera permission prompt for
it.

### Add the configuration as soon as the code is read

One tap fewer, and what some clients do. Rejected: a QR on a shared screen or
a panel page with several codes is easy to catch by mistake, and the field
already shows exactly what was read and whether it is usable.

### Decode from a screenshot or the screen on desktops

Would give desktops a QR path. Rejected for now: copying the link is already
one step there.

## Consequences

- `flutter_zxing` compiles zxing-cpp on every platform, desktops included,
  where it is never called. `camera` and `image_picker` come with it.
- Android declares `CAMERA` with `android.hardware.camera` not required, so the
  app still installs on devices without a camera. iOS carries
  `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`.
- WireGuard/AmneziaWG configs in QR (wg-easy) are not read: the client does not
  import `.conf` at all. Self-hosted Amnezia QR bundles stay unsupported
  (ADR-009).
- Happ's encrypted `happ://crypt/…` links cannot be unwrapped and are refused.

## Where It Lives

- `lib/core/parsers/qr_payload.dart` — `QrReader`, `unwrapImportLink`
- `lib/features/qr_scan_screen.dart`, `lib/features/start_screen.dart`
- `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
- `test/qr_payload_test.dart`, `test/start_screen_test.dart`
