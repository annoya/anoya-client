# VPN client (Flutter — macOS & iOS)

Cross-platform VPN client. One Flutter/Dart UI drives both macOS and iOS.

## Architecture

The engine is mihomo. Screens and state reach it through the **`VpnCore`**
boundary (`lib/core/vpn_core.dart`), which tests replace with a fake tunnel.
The implementation is **`NetworkExtensionCore`**
(`lib/core/network_extension_core.dart`); on macOS/iOS it drives a real
system-wide VPN via a **`NEPacketTunnelProvider`** extension, on Windows the
`AnnoyaTunnel` service over a named pipe, on Linux the `annoyatest-tunnel`
systemd service over a unix socket. The mihomo engine is compiled as a Go
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
./scripts/build.sh macos          # build core if stale → flutter run -d macos
./scripts/build.sh ios            # + fixes the Flutter/extension build cycle
./scripts/build.sh macos build    # flutter build instead of run
```

Sign in with the **server address** (e.g. `https://…:8443`), **username**, and
**password** of a user from the management panel — or **Sign in with SSO** if the
server has an OIDC provider configured.

### CI

`.github/workflows/build-client.yml` runs the analyzer and the tests, and
builds the Android APK, the Windows installer and the Linux packages, on every
push to `main`, on tags and on every pull request; the builds are published as
workflow artifacts. The four jobs are independent, so a red test does not
withhold a build. Amnezia credentials come from four repository secrets —
`AGW_ENDPOINT`, `AGW_PUBLIC_KEY_B64`, `AGW_S3_ENDPOINTS` and
`AGW_S3_FALLBACK_ENDPOINTS` — each passed to the build as its own
`--dart-define`; without them the builds still run.

### Windows

The tunnel is a Windows service (`native/mihomocore/cmd/tunnel-service`)
hosting the same engine; the app talks to it over a named pipe. Building the
app needs Windows and Visual Studio's C++ workload; the service cross-compiles
from anywhere:

```sh
./scripts/build-tunnel-service.sh        # build/windows/service/{tunnel-service.exe,wintun.dll}
./native/libagw/build-dll.sh             # native/libagw/build/windows/libagw.dll
flutter build windows                    # on Windows
ISCC.exe windows\installer\AnnoyaTest.iss /DAppVersion=1.1.0   # the setup .exe
```

The gateway library is a DLL here rather than something linked in: a Go
c-archive has no place in the MSVC-built runner, so CMake copies
`libagw.dll` next to `AnnoyaTest.exe` when it has been built, and Windows
resolves it from the executable's own directory. A bundle without it runs and
refuses Amnezia keys, the same as a build without gateway credentials.

The installer registers the service (`AnnoyaTunnel`, runs as SYSTEM, starts
at boot) and grants Users write access to `%ProgramData%\AnnoyaTest\engine`,
where the app downloads the geo databases and the service writes its logs.
Without the service installed the app runs, shows the tunnel as disconnected and
knocks on the pipe every few seconds; `tunnel-service.exe -console` in an
elevated prompt is the same service in the foreground, for development.

### Linux

The same service (`native/mihomocore/cmd/tunnel-service`) as a systemd unit,
`annoyatest-tunnel`, running as root; the app talks to it over the unix socket
`/run/annoyatest/tunnel.sock`. The device is the kernel's tun, so there is no
driver to ship. Building the app needs a Linux host with the GTK 3 and
libsecret development headers, clang, cmake and ninja; the service
cross-compiles from anywhere:

```sh
./scripts/build-tunnel-service.sh linux   # build/linux/service/tunnel-service
./native/libagw/build-linux.sh            # native/libagw/build/linux/libagw.so (on Linux)
flutter build linux                       # on Linux
./scripts/build-linux-packages.sh         # build/linux/packages/: .deb, .rpm, Arch package, portable tar.gz
```

Sign-in tokens go through `flutter_secure_storage`, which on Linux is
libsecret: the desktop has to provide a Secret Service (GNOME Keyring or
KWallet), which every mainstream desktop does and the packages do not force.

The gateway library is a shared object in the bundle's `lib/`, opened by path
(dlopen by name would search the Flutter engine's rpath, not ours). A bundle
without it runs and refuses Amnezia keys.

The packages come from one nfpm description (`linux/packaging/nfpm.yaml`), so
Debian, Fedora and Arch users get the same install: the app under
`/opt/annoyatest`, the unit registered and started, and
`/var/lib/annoyatest/engine` created world-writable with the sticky bit — the app downloads the geo databases there while the service reads them,
as `%ProgramData%\AnnoyaTest\engine` does on Windows. For any other
distribution with systemd, the portable tar.gz carries the same files and an
`install.sh` that lays them out the same way (`uninstall.sh` reverses it).
Distributions without systemd are not covered: the service is registered
through `systemctl`. The socket is
reachable by every local user, as Mullvad's and NetBird's daemon sockets are:
Linux has no socket mode for "whoever is at the console", and a group would
cost a re-login on every install. `tunnel-service -install` as root writes the
unit and starts it (what install.sh calls); `sudo tunnel-service -console` is
the same service in the foreground.

## Requirements

- Flutter 3.47+, Xcode.
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
gateway's endpoint, its RSA public key, its storage endpoints and their
fallbacks. The client
identity the gateway is told about is no longer configuration — the app sends
its own name and version, and claims no distribution channel. Copy
`client-secrets.example.json` to `client-secrets.json` (gitignored) and build
with:

```
flutter build apk --release --dart-define-from-file=client-secrets.json
```

The same values can be passed one by one instead, which is what CI does:

```
flutter build apk --release --dart-define=AGW_ENDPOINT=… \
  --dart-define=AGW_PUBLIC_KEY_B64=… --dart-define=AGW_S3_ENDPOINTS=… \
  --dart-define=AGW_S3_FALLBACK_ENDPOINTS=…
```

A build without them still works — Amnezia keys are simply refused with a
message saying so, rather than failing as if the network were down.

The gateway library itself is a pinned submodule:

```
git submodule update --init --recursive
native/libagw/build-xcframework.sh   # macOS + iOS
native/libagw/build-so.sh            # Android
```
