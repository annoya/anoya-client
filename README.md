# VPN client (Flutter — macOS & iOS)

Cross-platform VPN client. One Flutter/Dart UI drives both macOS and iOS.

## Architecture

The app depends only on the **`VpnCore`** seam (`lib/core/vpn_core.dart`), never
on a specific engine. On macOS/iOS the implementation is **`NetworkExtensionCore`**
(`lib/core/network_extension_core.dart`): a real system-wide VPN via a
**`NEPacketTunnelProvider`** extension. The mihomo engine is compiled as a Go
c-archive (`MihomoCore.xcframework`) and linked into the extension; Dart only
renders the mihomo TUN config and sends start/stop over a MethodChannel.

- config translation: `mihomoTunConfigYaml` (`lib/core/mihomo_tun_config.dart`,
  unit-tested) — TUN inbound bound to the utun fd, `stack: gvisor` on both
  platforms, split-tunneling rules rendered from the config bundle.
- the app re-fetches its config from management before every connect.

Swapping the engine or adding a platform means writing a new `VpnCore`; no
screen or state code changes.

## Native core (Go → xcframework)

`native/mihomocore/` is a standalone Go module (mihomo pinned, CGO,
`-tags with_gvisor`). `build-xcframework.sh` builds `MihomoCore.xcframework`
with a universal `macos-arm64_x86_64` slice (set `UNIVERSAL=0` for arm64 only)
and (on a Mac with the iOS SDK) an `ios-arm64` slice.
The xcframework is **not committed** (129 MB, over GitHub's file limit) — it is
built on demand (see below).

## Shared Network Extension code

The Swift that is identical across platforms lives once in **`shared/apple/`**
(`PacketTunnelProvider.swift`, `VPNManager.swift`, `VpnChannel.swift`) and is
**symlinked** into `macos/…` and `ios/…`. Edit the file in `shared/apple/` —
both platforms pick it up. `VpnChannel.swift` uses `#if canImport(FlutterMacOS)`
so the one file compiles against FlutterMacOS (macOS) or Flutter (iOS).

## Build & run

One command handles the Go core (rebuilt only when it changed) and the
Flutter+extension build-phase quirk, then runs Flutter:

```sh
cd client
./scripts/build.sh macos          # build core if stale → flutter run -d macos
./scripts/build.sh ios            # + fixes the Flutter/extension build cycle
./scripts/build.sh macos build    # flutter build instead of run
```

Sign in with the **server address** (e.g. `https://…:8443`), **username**, and
**password** of a user from the management panel — or **Sign in with SSO** if the
server has an OIDC provider configured.

## Requirements

- Flutter 3.38+, Xcode.
- A **paid Apple Developer account** (Network Extension capability + App Group).
- iOS: a **real device** — the NE does not run in the Simulator.

Bundle ids: app `org.annoya.test`, extension `org.annoya.test.tunnel`, App
Group `group.org.annoya.test`.

## Bootstrap (one-time, already done)

The Xcode projects already contain the Tunnel extension targets, so day-to-day
you only need `build.sh`. If you ever recreate a target from scratch, see
`macos/Tunnel/SETUP.md` / `ios/Tunnel/SETUP-ios.md` and the helper scripts under
`macos/scripts/` and `ios/scripts/`.

## Amnezia Premium/Free builds

Amnezia support needs credentials that are not in this repository: the
gateway's RSA public key, its storage endpoints, and the client identity its
gateway checks before answering. Copy `client-secrets.example.json` to
`client-secrets.json` (gitignored) and build with:

```
flutter build apk --release --dart-define-from-file=client-secrets.json
```

A build without them still works — Amnezia keys are simply refused with a
message saying so, rather than failing as if the network were down.

The gateway library itself is a pinned submodule:

```
git submodule update --init --recursive
client/native/libagw/build-xcframework.sh   # macOS + iOS
client/native/libagw/build-so.sh            # Android
```
