# Anoya

A cross-platform VPN client for Android, iOS, macOS, Windows and Linux. One
Flutter app; the tunnel is the [mihomo](https://github.com/MetaCubeX/mihomo)
engine running inside each platform's system VPN.

It connects through:

- share links — `vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`;
- subscriptions from panels such as 3x-ui, Marzban, Remnawave and Hiddify
  (base64 link lists, Clash/mihomo, Xray JSON, sing-box);
- `vpn://` key subscriptions;
- a self-hosted management server, with password or SSO sign-in.

Links can be pasted, opened from a file or scanned from a QR code on phones.
Split tunneling and DNS are set per configuration; on-demand connection is
set once for the device.

## How it fits together

- `lib/` — the Flutter app. Screens and state reach the tunnel only through
  `VpnCore` (`lib/core/vpn_core.dart`).
- `native/mihomocore/` — the Go engine wrapper: an xcframework for Apple, an
  AAR for Android, and a tunnel service for Windows and Linux.
- `shared/apple/` — the Network Extension and the app's VPN glue, shared by
  iOS and macOS.
- `native/libagw/` — the gateway library for `vpn://` keys (a submodule).

Per platform the tunnel runs as:

| Platform | Tunnel |
|---|---|
| iOS, macOS | Network Extension (`NEPacketTunnelProvider`) |
| Android | `VpnService` |
| Windows | `AnoyaTunnel` service, over a named pipe |
| Linux | `anoya-tunnel` systemd service, over a unix socket |

## Building

You need Flutter, Go and the platform's own toolchain (Xcode, Android SDK,
Visual Studio, or GTK 3 and libsecret headers on Linux). Fetch the submodule
first:

```sh
git submodule update --init --recursive
```

| Platform | Command |
|---|---|
| macOS | `./scripts/build.sh macos` |
| iOS | `./scripts/build.sh ios` |
| Android | `native/mihomocore/build-aar.sh && native/libagw/build-so.sh && ./scripts/build-android.sh` |
| Windows | `./scripts/build-tunnel-service.sh && native/libagw/build-dll.sh`, then `flutter build windows` and the installer in `windows/installer/` |
| Linux | `./scripts/build-tunnel-service.sh linux && native/libagw/build-linux.sh`, then `flutter build linux` and `./scripts/build-linux-packages.sh` |

`scripts/build.sh` rebuilds the Go engine only when it changed. On iOS the
Network Extension needs a real device.

### `vpn://` keys

Key subscriptions need gateway credentials that are not in this repository.
Copy `client-secrets.example.json` to `client-secrets.json` and build with
`--dart-define-from-file=client-secrets.json`. Without them the app builds and
runs, and refuses `vpn://` keys with a message saying so.

## Tests

```sh
flutter analyze
flutter test
```

CI (`.github/workflows/build-client.yml`) runs both and builds Android,
Windows and Linux on every push and pull request.

## Documentation

- [`AGENTS.md`](AGENTS.md) — how to work in this repository.
- [`docs/SPEC-CLIENT.md`](docs/SPEC-CLIENT.md) — what the client does.
- [`docs/decisions/`](docs/decisions/README.md) — why it is built this way.
- [`design/ui-spec.html`](design/ui-spec.html) — every screen, 1:1.

## License

GPL-3.0 — see [`LICENSE`](LICENSE). Third-party components are listed in
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).
