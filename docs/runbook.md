# Runbook

Procedures that are easy to get wrong and expensive to rediscover. Commands
assume the repository root unless a `cd` is shown.

## Verify there is no leak

The only proof that traffic stays inside the tunnel is packet capture on the
physical interface. Run this while the tunnel is up, then switch locations and
configurations in the app while it watches.

```bash
sudo client/scripts/leak-check.sh        # until Ctrl-C
sudo client/scripts/leak-check.sh 120    # or for N seconds
```

It generates ICMP, TCP and DNS toward fixed public resolvers, captures both the
physical interface and the utun, and fails on any test packet seen outside the
tunnel. Reading the result:

- `CLEAN` — nothing escaped.
- `ICMP LEAK … also went through utun` — the engine forwarded it itself; check
  that `disable-icmp-forwarding: true` is in the config in force (reconnect to
  apply a newer one).
- `ICMP LEAK … nothing inside utun` — the OS never handed it to the tunnel: a
  routing problem, not an engine one.
- `LEAK: N TCP/UDP/DNS packets` — a real leak. Note the timestamps against what
  you were doing; bursts at switch moments mean the network settings were
  re-applied on a live session, which must never happen (ADR-002).

`1.1.1.1` is deliberately absent from the targets: it is the engine's own DoH
upstream and would produce false positives.

To confirm a switch actually took effect, watch the engine log for
`[egress] <server>:443 reachable after reload, from <local address>`. A local
address belonging to `en0` proves the socket left through the physical
interface; `172.19.0.1` would mean it went into the tunnel.

On iOS the same capture is done from a Mac with `rvictl -s <device-udid>`, which
creates a virtual interface mirroring the device's traffic; the tcpdump filters
are identical.

## Build

```bash
cd client && ./scripts/build.sh          # engine when stale, app, run
```

The Go engine is a standalone module and is **not** part of the Go workspace:

```bash
cd client/native/mihomocore
GOWORK=off go test .
./build-xcframework.sh                   # macos-arm64 + ios-arm64 + simulator
```

`MihomoCore.xcframework` is 129 MB and not committed. A stale one silently keeps
the previous engine behaviour — rebuild it after any change under
`client/native/mihomocore/`, then rebuild the app.

## Run on an iOS device

A debug Flutter build **dies immediately** when launched from the home screen:
Dart runs under JIT there, and iOS forbids JIT without an attached debugger.
That is not a bug in the app.

```bash
cd client && flutter run --release -d <device-id>   # flutter devices for ids
```

Or in Xcode: Product → Scheme → Edit Scheme → Run → Build Configuration →
Release. NetworkExtension does not work in the simulator at all; tunnel work
requires a physical device.

## Geo databases

`geoip.metadb` and `GeoSite.dat` live in the App Group container (the engine's
home directory) and are downloaded by the app, never by the engine — a 20+ MB
fetch during tunnel start is exactly what must not happen. The app refreshes
them weekly.

In the UI: Settings → GeoIP & GeoSite, or the banner in the routing editor. Geo
rules stay inactive until both files are present, and the simple routing editor
is entirely unusable without them.

## Server side

Server tests, image pushes and deploy live in the
[annoya-web-panel](https://github.com/annoya/annoya-web-panel) repository's
runbook. What matters from this side: during MVP an upgrade may wipe the
server's data volume and redeploy, so nothing the client stored about a server
survives it by contract.

## UI changes

The mockup comes first and is validated before any code:

1. Edit `client/design/ui-spec.html`.
2. Open it in a browser, run `client/design/check.js` in the console — it must
   report `{"violations":0}`.
3. Then write the code, taking the numbers from the same place
   (`client/lib/core/theme.dart`, `client/lib/core/ui.dart`).

## Reading tunnel logs

Logs from inside the extension are fetched over IPC, not by reading the shared
container — reading it from the host triggers a TCC prompt about other
applications' data. In the app: Settings → Logs, which shows the app, tunnel and
engine journals and can export all three as a zip.

If collection is switched off, the engine writes nothing at all (the level is
pushed into the running engine, not only set in the config) while console output
continues. On a live tunnel the switch takes effect immediately.
