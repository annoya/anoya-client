# VPN client (Flutter — macOS & iOS)

Cross-platform VPN client. One Flutter/Dart UI drives both macOS and iOS.

## Architecture

The engine is mihomo. Screens and state reach it through the **`VpnCore`**
boundary (`lib/core/vpn_core.dart`), which tests replace with a fake tunnel.
The implementation is **`NetworkExtensionCore`**
(`lib/core/network_extension_core.dart`); on macOS/iOS it drives a real
system-wide VPN via a **`NEPacketTunnelProvider`** extension, on Windows the
`AnnoyaTunnel` service over a named pipe. The mihomo engine is compiled as a Go
c-archive (`MihomoCore.xcframework`) and linked into the extension; Dart only
renders the mihomo TUN config and sends start/stop over a MethodChannel.

- config translation: `mihomoTunConfigYaml` (`lib/core/mihomo_tun_config.dart`,
  unit-tested) — TUN inbound bound to the utun fd, `stack: gvisor` on both
  platforms, split-tunneling rules rendered from the config bundle.
- the app re-fetches its config from management before every connect.

Adding a platform means a new native side behind the same `vpn/control`
channel; no screen or state code changes. Swapping the engine is not a goal.

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

### CI

`.github/workflows/build-client.yml` runs the analyzer and the tests, and
builds the Android APK and the Windows installer, on every push to `main`, on
tags and on every pull request; the builds are published as
workflow artifacts. The three jobs are independent, so a red test does not
withhold a build. Amnezia credentials come
from the `CLIENT_SECRETS_JSON` repository secret (the contents of
`client-secrets.json`); without it the builds still run.

### Windows

The tunnel is a Windows service (`native/mihomocore/cmd/tunnel-service`)
hosting the same engine; the app talks to it over a named pipe. Building the
app needs Windows and Visual Studio's C++ workload; the service cross-compiles
from anywhere:

```sh
./scripts/build-tunnel-service.sh        # build/windows/service/{tunnel-service.exe,wintun.dll}
flutter build windows                    # on Windows
ISCC.exe windows\installer\AnnoyaTest.iss /DAppVersion=1.1.0   # the setup .exe
```

The installer registers the service (`AnnoyaTunnel`, runs as SYSTEM, starts
at boot) and grants Users write access to `%ProgramData%\AnnoyaTest\engine`,
where the app downloads the geo databases and the service writes its logs.
Without the service installed the app runs, shows the tunnel as disconnected and
knocks on the pipe every few seconds; `tunnel-service.exe -console` in an
elevated prompt is the same service in the foreground, for development.

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
native/libagw/build-xcframework.sh   # macOS + iOS
native/libagw/build-so.sh            # Android
```
