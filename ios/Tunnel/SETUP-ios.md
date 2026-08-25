# iOS spike — build, wire, run, measure memory

Goal of this spike: get the mihomo tunnel running inside the iOS Network
Extension on a **real iPhone** and measure the extension's peak memory. The iOS
NE has a hard ~50 MB cap; we use mihomo's lighter `system` TUN stack (the iOS
xcframework slice is built without gVisor). **If it fits, we build out full iOS.
If it OOMs, we rethink the core.**

Same Apple team as macOS. Bundle ids: app `org.annoya.test`, extension
`org.annoya.test.tunnel`, App Group `group.org.annoya.test`.

## Gate 1 — does mihomo even compile for iOS?

```sh
cd client/native/mihomocore
./build-xcframework.sh          # now also builds the ios-arm64 slice
```
This must produce `MihomoCore.xcframework` with **both** `macos-arm64` and
`ios-arm64` slices (`ls MihomoCore.xcframework`). If the iOS `go build` fails on
a dependency, stop here and report the error — that's the real risk, and it
decides whether mihomo-in-NE is viable on iOS at all.

## Xcode wiring (open `client/ios/Runner.xcworkspace`)

1. **Runner target → Signing & Capabilities**: team = your Apple dev team,
   bundle id `org.annoya.test`; add capabilities **Network Extensions**
   (Packet Tunnel) and **App Groups** (`group.org.annoya.test`). Set
   `Runner/Runner.entitlements` as the target's `CODE_SIGN_ENTITLEMENTS`.

2. **Add the extension target**: File → New → Target → **Network Extension** →
   Packet Tunnel Provider. Name it `Tunnel`, bundle id
   `org.annoya.test.tunnel`, same team. Xcode generates a template
   `PacketTunnelProvider.swift`, `Info.plist`, entitlements and auto-embeds the
   appex in Runner.

3. **Swap in our sources** (the generated ones are stubs):
   - Delete the generated `PacketTunnelProvider.swift`; add
     `ios/Tunnel/PacketTunnelProvider.swift` to the **Tunnel** target.
   - Replace the generated `Info.plist`/entitlements with `ios/Tunnel/Info.plist`
     and `ios/Tunnel/Tunnel.entitlements` (or copy their contents). Ensure the
     Tunnel target's `INFOPLIST_FILE` / `CODE_SIGN_ENTITLEMENTS` point at them.
   - On the Tunnel target add capabilities **Network Extensions** + **App
     Groups** (`group.org.annoya.test`).

4. **Host-side channel** — add to the **Runner** target:
   `ios/Runner/VPN/VPNManager.swift` and `ios/Runner/VPN/VpnChannel.swift`
   (already registered in `AppDelegate.swift`).

5. **Link the engine into the Tunnel target**:
   - Add `native/mihomocore/MihomoCore.xcframework` to the **Tunnel** target
     (General → Frameworks and Libraries).
   - Tunnel target → Build Settings → Other Linker Flags: `-lresolv`
     (mihomo needs the resolver); frameworks Security + CoreFoundation are
     usually auto-linked, add them if you get `_res_9_*`/Security undefined.

## Gate 2 — run on device and measure

- Select the **Runner** scheme, a **real iPhone** (NE does NOT work in the
  Simulator), Debug build, Run.
- In the app: sign in to `https://38-99-23-137.sslip.io:8443`, pick the location,
  Connect. Approve the first-time VPN profile prompt.
- Confirm traffic actually flows (open a site) and check the tunnel/core logs.
- **Measure**: Xcode → Debug Navigator → Memory, select the **Tunnel** process
  (not Runner). Push traffic (a few parallel downloads) and note the peak.
  - Comfortably under ~50 MB → spike passes, proceed to full iOS.
  - Near/over the cap or the extension gets killed → report the peak; we switch
    tactics (tune mihomo GC / `GOMEMLIMIT`, trim features, or reconsider core).

## Notes / likely gotchas
- `mtu: 9000` (from the shared config) may be too high for iOS; if
  `setTunnelNetworkSettings` errors, we'll lower it (client-side, per platform).
- The client sends `stack: gvisor` (userspace) on iOS — the only stack that
  works in the NE sandbox; build the iOS xcframework slice WITH `with_gvisor`.
- SSO (ASWebAuthenticationSession) is intentionally out of this spike.
