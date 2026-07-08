# VPN client (Flutter, macOS first)

Cross-platform VPN client. macOS is the first target.

## Architecture

The app depends only on the **`VpnCore`** abstraction (`lib/core/vpn_core.dart`),
never on a specific engine. Today the only implementation is **`MihomoCore`**
(`lib/core/mihomo_core.dart`), which:

- translates the management service's normalized config bundle into mihomo YAML
  (`mihomoConfigYaml`, unit-tested in `test/mihomo_config_test.dart`),
- runs the bundled mihomo engine as a subprocess,
- points the macOS system proxy at it (best-effort).

Swapping the engine — or moving to a full Network Extension tunnel — means
writing a new `VpnCore`; no screen or state code changes.

### Tunnel mode (MVP) vs production

This MVP uses **proxy mode**: mihomo exposes a local SOCKS/HTTP proxy and the
app sets the macOS system proxy. This tunnels apps that honor the system proxy —
it is **not** a full system-wide VPN.

The production path is a **Network Extension** (`NEPacketTunnelProvider`) with
mihomo linked as a Go c-archive, captured behind the same `VpnCore` seam. That
requires a paid Apple Developer account (available) and is tracked as a later
milestone.

## Prerequisites to run

Just Flutter 3.38+ and Xcode.

The **mihomo engine is bundled** with the app (`assets/mihomo/mihomo`,
darwin-arm64). At runtime `MihomoCore` extracts it to the app-support directory,
marks it executable, and runs it — no manual install needed.

> Must be a mihomo **Alpha** build. The stable channel (1.19.x) is incompatible
> with the Reality handshake of current Xray-core (26.x) on the worker —
> connections fail with `connect error: EOF` / `REALITY: handshake did not
> complete`. The Alpha tracks the latest XTLS/Reality and interoperates.

Binary resolution order (first hit wins):
- `MIHOMO_BIN` environment variable (override, e.g. to test another build),
- the bundled engine extracted from assets,
- `/usr/local/bin/mihomo` or `/opt/homebrew/bin/mihomo`.

> To update the bundled engine, replace `assets/mihomo/mihomo` with a newer
> darwin build from https://github.com/MetaCubeX/mihomo and rebuild. For an
> Intel/universal app, bundle the matching arch.

## Run

```sh
cd client
flutter run -d macos        # or: flutter run -d macos --release
```

Then sign in with the **server address**, **username**, and **password** of a
user created in the management panel. The app fetches its config (locations,
account status) and re-fetches it before every connect, so admin-side changes
take effect immediately.

## Notes

- The dev build disables the app sandbox (see `macos/Runner/*.entitlements`) so
  the app can launch mihomo and run `networksetup`. The Network Extension build
  will re-enable the sandbox with the appropriate entitlements.
- A real tunnel needs a worker deployed on a reachable VPS (the demo worker uses
  a placeholder endpoint).
