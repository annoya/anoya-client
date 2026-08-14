# AGENTS.md

Operating guide for this repository. Read this before changing anything; read
the relevant ADR in `docs/decisions/` before changing the subsystem it governs.

## Project Overview

Self-hosted VPN service, three components:

- `client/` — Flutter app for macOS and iOS. Drives a system VPN through a
  swappable core seam (`VpnCore`); the mihomo engine is compiled into a
  Network Extension.
- `management/` — Go service + embedded React admin panel. Source of truth for
  users, user lists, workers, routing profiles. Hands out client configs.
- `worker/` — Go agent on each VPN server. Runs Xray (VLESS+Reality), pulls its
  user set from management, reports liveness and traffic.
- `shared/` — Go types shared by management and worker (wire contracts,
  protocol drivers).

Two deliberate abstraction seams, and only two: `VpnCore` on the client and
`protocol.Driver` on the server. Everything else stays boring and direct.

## Non-Negotiable Invariants

Breaking one of these is a privacy or security regression, not a bug. Each is
pinned by a test; if the test fails, revisit the ADR rather than the test.

1. **The tunnel session never drops on a config or location switch.** Switching
   is a hot reload of the engine under the standing Network Extension session.
   No `stop`/`start`, and no `setTunnelNetworkSettings` on a live session — it
   tears the current settings down before installing the new ones, and traffic
   escapes in that window. See ADR-002.
2. **Nothing is excluded from the tunnel.** `includedRoutes = [default]`, no
   `excludedRoutes`, ever. The engine's own dial leaves through `IP_BOUND_IF`.
   An excluded route is a system-wide hole for every process, not just ours.
   See ADR-002.
3. **The `tun` section of the rendered engine config is identical across
   locations, protocols and routing policies.** That is the condition under
   which mihomo keeps the TUN listener and the tunnel fd alive across a reload
   (`Tun.Equal` compares exactly that section, `dns-hijack` included). A
   per-location option sneaking in there silently turns switching into a
   session drop. In the `dns` section the resolvers ride the config (ADR-008),
   but the fake-ip mode and range are app constants — the OS caches the fake
   addresses the engine handed out. Pinned by `client/test/hot_switch_test.dart`
   and `client/test/mihomo_tun_config_test.dart`.
4. **A failed switch never disconnects.** The tunnel keeps running on the
   previous config and the user is told. Dropping the session as error handling
   is the one thing that actually leaks.
5. **Rule values are validated before they reach the engine config.** They are
   interpolated into config text; `RoutingRule.isValid` mirrors the server-side
   validation and both sides must stay in step.
6. **Logs never contain secrets.** No tokens, passwords, private keys or full
   config bodies in app, tunnel or engine logs.

## Essential Commands

Run from `client/` unless noted.

```bash
flutter test                      # 100+ tests; the contract suites live here
flutter analyze                   # must be clean before any commit
flutter run -d macos              # debug run on macOS
flutter run --release -d <device> # iOS on a device: release is mandatory (JIT
                                  # is banned without a debugger, so a debug
                                  # build dies instantly off Xcode)
./scripts/build.sh                # full build incl. the Go core when stale
cd native/mihomocore && GOWORK=off go test .   # engine wrapper tests
cd native/mihomocore && ./build-xcframework.sh # rebuild MihomoCore.xcframework
sudo scripts/leak-check.sh        # leak check against a live tunnel (root)
```

Server side, from the repo root:

```bash
cd management && go test ./...
cd worker && go test ./...
scripts/push-images.sh            # multi-arch images to Docker Hub
```

## Which Check When

- **Touched Dart or Swift** — `flutter analyze` and `flutter test`.
- **Touched the engine wrapper (`client/native/mihomocore/`)** — Go tests, then
  `build-xcframework.sh`, then a macOS build. The xcframework is not committed;
  a stale one silently keeps the old behavior.
- **Touched the tunnel, routing, or anything that decides where a packet goes**
  — run `leak-check.sh` against a live tunnel and switch locations while it
  watches. A green test suite does not prove the absence of a leak.
- **Touched the UI** — update `client/design/ui-spec.html` *first*, run its
  validator (`client/design/check.js` in the browser console, 0 violations
  required), then write the code to match. Numbers in the mockup and in
  `client/lib/core/theme.dart` /
  `client/lib/core/ui.dart` are the same numbers.
- **Touched anything a decision governs** — update the ADR, or write a new one
  that supersedes it.

## Repository Rules

- **Simple over clever.** Implement the requirement, not a platform. The two
  seams above are the only "framework-y" investment we make on purpose.
- **Mockup before code** for any visible change. Show it, get an explicit go
  ahead, then implement.
- **Comments explain business logic and hard-won technical decisions.** Never
  narrate what the code already says.
- **Do not add what was not asked for.** A screen, a button, or an abstraction
  nobody requested is waste, and it has to be maintained.
- **Do not start rewriting while a decision is still being discussed.**
- **Delete unused code** instead of keeping it "for later".
- **Do not run `dart format` over the project** — it rewrites lines the change
  never touched.
- **Committing is the user's call.** Prepare the change, propose the split, do
  not commit unless asked.
- **MVP policy: no migrations, no backwards compatibility.** There is no
  production data; the VPS is wiped and redeployed, and the schema is one
  consolidated migration.
- **Reference projects (Happ, Marzban, 3x-ui, NetBird, Mullvad) are sources of
  facts, not philosophies to copy.** Take the mechanism, judge it on our terms.

## Privacy And Published Artifacts

- Never commit server IPs, VPS hostnames, enrollment tokens, JWTs, admin
  passwords or private keys — including inside pasted logs and script output.
- Sanitize log excerpts before they enter docs or commit messages: replace real
  addresses with placeholders.
- Local absolute paths (`/Users/...`) do not belong in repository files. Use
  repository-relative paths.

## Verification Culture

The rules below exist because each was learned the expensive way.

- **Hypotheses about the tunnel are settled by an experiment, not by
  reasoning.** Several confident diagnoses in this project's history were wrong
  and were disproved by a single run.
- **Verify your own work before reporting it.** "Should work" is not a result.
- **After a wrong diagnosis, remove the code it produced.** Fixes built on a
  wrong model tend to survive and rot.
- **A leak is invisible from inside the app.** Only packet capture on the
  physical interface proves its absence.

## Architecture Notes

### Client

The app depends on `VpnCore` (`client/lib/core/vpn_core.dart`) and never on a
specific engine. `NetworkExtensionCore` implements it for macOS and iOS through
a `NEPacketTunnelProvider`; the mihomo engine is a Go c-archive linked into the
extension. Dart renders the engine config (`client/lib/core/mihomo_tun_config.dart`) and
sends commands over a MethodChannel. Swift shared by both platforms lives once
in `client/shared/apple/` and is symlinked into `macos/` and `ios/`.

State is Riverpod; `ProfilesController` owns the configuration list, the active
profile, the selected location and the connect path.

### Management and worker

Pull only: the worker heartbeats and fetches its user set; management never
pushes. Protocol specifics live behind `protocol.Driver` in `shared/protocol/`.

## Documentation Map

- `docs/decisions/` — ADRs. One per feature, with the alternatives that were
  rejected and why. Start at `docs/decisions/README.md`.
- `docs/NON_GOALS.md` — what this project deliberately does not do.
- `docs/runbook.md` — operational procedures: leak checking, builds, releases.
- `docs/SPEC-CLIENT.md` — what the client is: the three domains it serves, the
  tunnel, routing, screens, and the contract it expects from a server.
- `docs/SPEC-SERVICE.md` — what the server side is: domain model, protocol seam,
  API surface, install, worker loop.
- `client/design/ui-spec.html` — every screen drawn 1:1 in Flutter logical
  points, with `check.js` as its validator. The source of truth for UI geometry.
- `client/README.md`, `client/macos/Tunnel/SETUP.md`,
  `client/ios/Tunnel/SETUP-ios.md` — build and platform setup.
