# AGENTS.md

Operating guide for this repository. Read this before changing anything; read
the relevant ADR in `docs/decisions/` before changing the subsystem it governs.

## Project Overview

This repository is the client half of a self-hosted VPN service, and the app
is the repository root: a Flutter app for macOS, iOS and Android that drives a
system VPN through the `VpnCore` boundary. The engine is mihomo and only
mihomo, compiled into a Network Extension (Apple) or a VpnService (Android).
Dart lives in `lib/` and `test/`, the platform projects in `macos/`, `ios/`,
`android/` and `windows/`, the Go engine wrapper in `native/`.

The server side lives in its own repository,
[annoya-web-panel](https://github.com/annoya/annoya-web-panel): `management`
(Go service + embedded React admin panel — source of truth for users, user
lists, workers and routing profiles, and what hands out client configs),
`worker` (Go agent on each VPN server, running Xray or amneziawg-go) and
`shared` (the wire contracts between them). Management's client API is the only
server surface this app talks to.

One deliberate abstraction seam on this side, and only one: `VpnCore`.
Everything else stays boring and direct. The server has its own seam,
`protocol.Driver`, in the other repository.
`VpnCore` is not there to swap the engine — mihomo is the engine, and nothing
else is planned. It exists so the state layer can be tested against a fake
tunnel, and so the platform side (Network Extension, VpnService) stays behind
one Dart class.

## Non-Negotiable Invariants

Breaking one of these is a privacy or security regression, not a bug. Each is
pinned by a test; if the test fails, revisit the ADR rather than the test.

1. **The tunnel session never drops on a config or location switch.** Switching
   is a hot reload of the engine under the standing Network Extension session.
   No `stop`/`start`, and no `setTunnelNetworkSettings` on a live session — it
   tears the current settings down before installing the new ones, and traffic
   escapes in that window. See ADR-002.
2. **Nothing is excluded from the tunnel, and both address families are
   claimed and carried.** `includedRoutes = [default]` for IPv4 *and* IPv6, no
   `excludedRoutes`, ever, and the engine handles both families rather than
   blackholing one. The engine's own dial leaves through `IP_BOUND_IF`
   (`IPV6_BOUND_IF` for v6). An excluded route is a system-wide hole for every
   process, not just ours; an unclaimed family is the same hole for everything
   that resolves to it. See ADR-002.
3. **The `tun` section of the rendered engine config is identical across
   locations, protocols and routing policies.** That is the condition under
   which mihomo keeps the TUN listener and the tunnel fd alive across a reload
   (`Tun.Equal` compares exactly that section, `dns-hijack` included). A
   per-location option sneaking in there silently turns switching into a
   session drop. In the `dns` section the resolvers ride the config (ADR-008),
   but the fake-ip mode and range are app constants — the OS caches the fake
   addresses the engine handed out. Pinned by `test/hot_switch_test.dart`
   and `test/mihomo_tun_config_test.dart`.
4. **A tunnel that stops on its own says why.** A packet-tunnel provider that
   refuses a config reports it to the *system*, never to the call that started
   it: the app sees the status fall back to disconnected and nothing else,
   which reads as a connect that hung. `VpnCore.lastDisconnectError` (the
   platform's `fetchLastDisconnectError`) is how that reason reaches the user,
   and every stop the app did not ask for goes through it. Pinned by
   `test/silent_failure_test.dart`.
5. **A failed switch never disconnects.** The tunnel keeps running on the
   previous config and the user is told. Dropping the session as error handling
   is the one thing that actually leaks.
6. **Everything interpolated into the engine config is validated first —
   values and keys alike.** Rule values go through `RoutingRule.isValid`, which
   mirrors the server-side validation in the web-panel repository (both sides
   must stay in step). Map keys from a Clash subscription go through the
   parser's key charset: keys are
   structural, so one carrying a newline adds a top-level config key
   (`external-controller` opens an unauthenticated control API). Drop, never
   escape. Pinned by `test/mihomo_tun_config_test.dart`.
7. **The engine never fetches anything while applying a config.** Geo
   databases and a provider's rule lists are downloaded by the app, into the
   App Group container, and referenced as local files. mihomo will happily do
   it itself — geo data during config *parse* (90 s per file), rule providers
   inside `ApplyConfig` under a wait group (20 s per file) — which stalls a
   connect, and then reports failure by only logging, leaving a rule that
   silently matches nothing. If it is not on disk, the rule that needs it is
   dropped and the user is told. Pinned by
   `test/mihomo_tun_config_test.dart` and
   `test/rule_list_store_test.dart`.
8. **Resolving the proxy's own address never goes through the proxy.** Panels
   pin their resolver to the tunnel (`...#PROXY`) so DNS does not leak to the
   local network, and mihomo resolves proxy hostnames with the main resolver
   unless `proxy-server-nameserver` says otherwise — so honouring that pin
   without an unpinned bootstrap deadlocks: the query waits on the tunnel, the
   tunnel waits on the query, and every dial fails with `couldn't find ip`. The
   renderer always emits `proxy-server-nameserver`, always without a pin, and
   drops any pin naming an outbound it did not render (mihomo reads an unknown
   pin as an interface to bind the socket to). `default-nameserver` is not a
   substitute: the engine uses it only to resolve a *nameserver's* own
   hostname. A scheme `config.Parse` does not know is dropped for the same
   family of reasons: the engine rejects the *whole* document over it. Pinned
   by `test/mihomo_tun_config_test.dart` and
   `test/dns_sources_test.dart`.
9. **Status reaches Dart from the platform thread only.** `onStatus` feeds the
   `vpn/status` EventChannel, and Flutter drops or crashes on a channel message
   sent from anywhere else. `VPNManager` is `@MainActor`: every method, field
   and callback of it runs on the platform thread because the compiler refuses
   anything else, and the two places that enter it from a synchronous callback
   (`NotificationCenter`, the stream handler) do so through
   `MainActor.assumeIsolated`, which traps rather than races. Do not remove the
   annotation to "fix" a build error — hop into the actor instead.
10. **A check never disconnects the tunnel.** The connection check measures and
   reports; it has false negatives (a captive portal, a blocked test host, the
   second after a switch), and acting on one would take a working VPN away
   silently. Same rule as the failed switch above, for the same reason
   (ADR-010).
11. **Logs never contain secrets.** No tokens, passwords, private keys or full
   config bodies in app, tunnel or engine logs. This includes error text that
   quotes them: subscription URLs, share links and engine parse errors are
   reduced to a host, a scheme or a redacted message before they are logged.

## Essential Commands

Run from the repository root unless noted.

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

## Which Check When

- **Touched Dart or Swift** — `flutter analyze` and `flutter test`.
- **Touched the engine wrapper (`native/mihomocore/`)** — Go tests, then
  `build-xcframework.sh`, then a macOS build. The xcframework is not committed;
  a stale one silently keeps the old behavior.
- **Touched the tunnel, routing, or anything that decides where a packet goes**
  — run `leak-check.sh` against a live tunnel and switch locations while it
  watches. A green test suite does not prove the absence of a leak.
- **Touched the UI** — update `design/ui-spec.html` *first*, run its
  validator (`design/check.js` in the browser console, 0 violations
  required), then write the code to match. Numbers in the mockup and in
  `lib/core/theme.dart` /
  `lib/core/ui.dart` are the same numbers.
- **Touched the Xcode projects, the linker flags, or anything the app reaches
  through `DynamicLibrary.process()`** — check an *archive*, not a local
  release build. `xcodebuild … archive` strips the binary and `flutter build`
  does not, so a symbol that only an archive loses looks fine right up to
  TestFlight:

  ```bash
  xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
    -configuration Release -archivePath /tmp/Check.xcarchive archive \
    CODE_SIGNING_ALLOWED=NO
  xcrun dyld_info -exports /tmp/Check.xcarchive/Products/Applications/*.app/Contents/MacOS/* \
    | grep -c agw_          # must not be 0
  ```

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
- **Every sentence the user reads lives in `lib/l10n/app_en.arb`**, with the
  other languages beside it (`app_ru.arb`, `app_zh.arb`, `app_fr.arb`,
  `app_es.arb`); `flutter gen-l10n` turns them into `AppLocalizations`.
  Widgets read `context.l10n`, code with no `BuildContext` (errors, the menu
  bar, controllers) reads `L10n.current`. A new string is a key in all five
  files, never a literal in Dart; log lines, config keys and protocol names
  stay literals.
- **Keep the code `dart format` clean.** The project was formatted once, in a
  commit listed in `.git-blame-ignore-revs`, and CI now fails on anything
  unformatted (`dart format --output=none --set-exit-if-changed lib test`).
  Format the files the change touches; do not reformat the ones it does not.
- **Committing is the user's call.** Prepare the change, propose the split, do
  not commit unless asked.
- **MVP policy: no migrations, no backwards compatibility.** There is no
  production data and no install base to keep working; stored state may be
  dropped rather than migrated, and the VPS is wiped and redeployed.
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

The engine is mihomo. The state layer reaches it through `VpnCore`
(`lib/core/vpn_core.dart`), whose one real implementation is
`NetworkExtensionCore`: on macOS and iOS a `NEPacketTunnelProvider` with the
engine linked in as a Go c-archive, on Android a `VpnService` with the engine
in-process, on Windows a service (`native/mihomocore/cmd/tunnel-service`)
hosting the engine behind a named pipe. Dart renders the mihomo config
(`lib/core/mihomo_tun_config.dart`) and sends the same commands over a
`ControlTransport` — platform channels, or the pipe; tests substitute a fake
`VpnCore`. Swift shared by both platforms lives once
in `shared/apple/` and is symlinked into `macos/` and `ios/`.

State is Riverpod; `ProfilesController` owns the configuration list, the active
profile, the selected location and the connect path.

### Server side

Documented in the
[annoya-web-panel](https://github.com/annoya/annoya-web-panel) repository. The
two facts that matter from here: it is pull only — the worker fetches its user
set, management never pushes — and protocol specifics live behind
`protocol.Driver` there, not in this app.

## Documentation Map

- `docs/decisions/` — ADRs. One per feature, with the alternatives that were
  rejected and why. Start at `docs/decisions/README.md`.
- `docs/NON_GOALS.md` — what this project deliberately does not do.
- `docs/runbook.md` — operational procedures: leak checking, builds, releases.
- `docs/SPEC-CLIENT.md` — what the client is: the three domains it serves, the
  tunnel, routing, screens, and the contract it expects from a server. The
  other side of that contract is `docs/SPEC-SERVICE.md` in the
  [annoya-web-panel](https://github.com/annoya/annoya-web-panel) repository.
- `design/ui-spec.html` — every screen drawn 1:1 in Flutter logical
  points, with `check.js` as its validator. The source of truth for UI geometry.
- `README.md`, `macos/Tunnel/SETUP.md`,
  `ios/Tunnel/SETUP-ios.md` — build and platform setup.
