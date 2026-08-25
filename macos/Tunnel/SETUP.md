# Phase B — add the Packet Tunnel extension in Xcode (macOS)

Goal: get the `Tunnel` Network Extension target into the macOS app, linked
against `MihomoCore.xcframework`, signed under the **nethiuswork@gmail.com**
team. After this, `flutter build macos` (or building in Xcode) should compile +
link + embed the extension. (Actually *starting* the tunnel comes with Phase C.)

Identifiers used throughout:
- App: `org.annoya.test`
- Extension: `org.annoya.test.tunnel`
- App Group: `group.org.annoya.test`

## 1. Build the Go core xcframework
```sh
cd client/native/mihomocore
./build-xcframework.sh        # produces ./MihomoCore.xcframework (macos-arm64)
```

## 2. Open the macOS project in Xcode
```sh
open client/macos/Runner.xcworkspace
```
Use the **.xcworkspace** (not .xcodeproj) — it includes the Flutter pods.

## 3. Add the Network Extension target
> Labels vary slightly by Xcode version (this was written against older Xcode;
> you're on 26.4.1). Go by intent: create a **macOS app extension whose
> extension point is `com.apple.networkextension.packet-tunnel`**.

- File → New → **Target…**
- Pick the macOS template for a Network Extension. Depending on version it may be
  listed as **"Network Extension"** or you may pick a generic **"App Extension"**
  and then choose the **Packet Tunnel Provider** extension point. (The end result
  must be `NSExtensionPointIdentifier = com.apple.networkextension.packet-tunnel`
  — our `Info.plist` already sets that, so even a generic extension target works.)
- Product Name: **Tunnel**; Language: Swift.
- If a provider type is offered, choose **Packet Tunnel**.
- Team: the **nethiuswork@gmail.com** team.
- Finish. If asked to activate the new scheme, **Cancel** (keep the Runner scheme).

Xcode creates a `Tunnel/` group with generated `PacketTunnelProvider.swift`,
`Info.plist`, and an entitlements file. We replace these in step 4.

## 4. Use our source files instead of the generated ones
We already have the real files in `client/macos/Tunnel/`:
`PacketTunnelProvider.swift`, `Info.plist`, `Tunnel.entitlements`.
- Delete the generated `PacketTunnelProvider.swift` (Move to Trash), then drag
  our `PacketTunnelProvider.swift` into the Tunnel group (Target = Tunnel).
- In the **Tunnel** target → Build Settings:
  - **Info.plist File** → `Tunnel/Info.plist`
  - **Code Signing Entitlements** → `Tunnel/Tunnel.entitlements`
- Confirm the Tunnel target **Bundle Identifier** = `org.annoya.test.tunnel`.

## 5. Link MihomoCore.xcframework
- Drag `client/native/mihomocore/MihomoCore.xcframework` into the project
  (don't copy; reference in place, or copy into `macos/`). Add to target: **Tunnel**.
- Select the **Tunnel** target → **General** tab → the section for linked
  binaries (named **"Frameworks and Libraries"**, in some versions
  **"Frameworks, Libraries, and Embedded Content"**). Ensure
  `MihomoCore.xcframework` is listed; set its action to **Do Not Embed** (it's a
  static library — linked, not embedded).
- The xcframework ships a `module.modulemap`, so `import MihomoCore` resolves
  automatically. If Xcode reports "No such module", add the framework's
  `…/MihomoCore.xcframework/macos-arm64/Headers` to the Tunnel target's
  **Import Paths** (`SWIFT_INCLUDE_PATHS`) / **Header Search Paths**.

## 6. Capabilities (Signing & Capabilities tab)
Select each target → **Signing & Capabilities** → **+ Capability** (the
"+" / capability library button). On **both** `Runner` (main app) and `Tunnel`:
- **App Groups** → add `group.org.annoya.test`
- **Network Extensions** → enable **Packet Tunnel**

(Our `Tunnel.entitlements` already lists these; adding the capability in Xcode
also registers them in the App ID / provisioning profile.)

> The main app (`Runner`) entitlements still have the sandbox disabled from the
> proxy-mode MVP. Phase C switches the main app to sandbox + NE + App Group.

## 7. Embed the extension in the app
Select the **Runner** target → **Build Phases** → there must be a copy phase that
embeds the extension, named **"Embed App Extensions"** or (newer Xcode, as in the
primevpn-client reference) **"Embed Foundation Extensions"**, containing
`Tunnel.appex`. Xcode usually adds this automatically when the extension target
is created with Runner as its host app; if it's missing, add the phase (+ → New
Copy Files Phase, Destination = Plug-ins/Extensions) and add `Tunnel.appex`.

## 8. Signing
- Both targets → Signing & Capabilities → **Automatically manage signing**,
  Team = nethiuswork@gmail.com.
- Let Xcode register App IDs `org.annoya.test` and
  `org.annoya.test.tunnel` with the **App Group** and **Network
  Extensions** capabilities. If automatic signing fails on App Group/NE, create
  the App IDs + App Group manually in the Apple Developer portal, then retry.

## 9. Build to validate Phase B
- In Xcode select the **Runner** scheme → Product → Build (⌘B), or:
```sh
cd client && flutter build macos --debug
```
Success means: the extension compiles, `import MihomoCore` resolves, the static
lib links, and `Tunnel.appex` is embedded. (No tunnel runs yet — that's Phase C.)

If it builds, report back and we'll do Phase C (host `VPNManager` +
MethodChannel) and Phase D (Dart `NetworkExtensionCore` + TUN config), after
which you can actually start the tunnel.

## 10. Phase C/D — host app control (after Phase B builds)
The Dart + host-app code is already written; it just needs the new Runner Swift
files added to the **Runner** target (Flutter won't auto-add them):
- Add to the **Runner** target (drag into the Runner group, target = Runner):
  - `macos/Runner/VPN/VPNManager.swift`
  - `macos/Runner/VPN/VpnChannel.swift`
- `MainFlutterWindow.swift` already calls `VpnChannel.register(...)`.
- Runner entitlements already include Network Extension + App Group (step 6 adds
  the capability so they land in the provisioning profile).

Dart side (already done): `NetworkExtensionCore` talks to MethodChannel
`vpn/control` (start/stop/status) + EventChannel `vpn/status`; `vpnCoreProvider`
returns it on macOS/iOS. The connect flow renders a mihomo **TUN** config
(`mihomoTunConfigYaml`) and sends it to the extension.

Build & run, then in the app: Login → pick a location → Connect. macOS shows a
one-time "… would like to add VPN configurations" approval — allow it. Watch the
status; check egress with `curl https://api.ipify.org`.

## Common pitfalls
- **`No such module 'MihomoCore'`** → the xcframework isn't linked to the Tunnel
  target, or the `module.modulemap` isn't inside its `Headers/`. Re-run the
  build script; re-add the framework to the Tunnel target.
- **Undefined symbols `_MihomoStart`** → the static lib isn't linked (check
  Frameworks and Libraries on the Tunnel target).
- **Provisioning errors on App Group / NE** → register them in the portal for
  both App IDs; ensure the team is nethiuswork@gmail.com.
- **App can't find the extension at runtime** (Phase C) → bundle id mismatch
  between `NETunnelProviderProtocol.providerBundleIdentifier` and the actual
  extension bundle id `org.annoya.test.tunnel`.
