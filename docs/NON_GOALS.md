# Non-Goals

What this project deliberately does not do. Written down because delivery
pressure re-proposes all of it, and because "we already considered that" is
worthless if nobody can find where.

## Product

**We are not building a consumer VPN service.** No sign-up funnel, no billing,
no server fleet of ours. This is software someone runs for their own company or
themselves.

**We do not ship a kill switch as a toggle.** `includeAllNetworks` breaks LAN
access and captive portals; the honest version is a firewall, which is separate
work. See ADR-004.

**We do not proxy third-party subscriptions through our server.** The client
fetches them directly. Routing someone's subscription traffic through
management would make it a middleman for data it has no business seeing.

**We do not fetch UI assets at runtime.** Brand glyphs are bundled. A VPN client
asking a third party for `youtube.svg` announces what the user is about to
route.

## Architecture

**We do not add abstraction seams beyond the two that exist** — `VpnCore` on the
client and `protocol.Driver` on the server. Everything else is direct and
boring. An interface with one implementation and no second one in sight is
waste.

**We do not let the engine define the app.** No mihomo type crosses the
`VpnCore` boundary; config translation lives entirely inside the core
implementation.

**We do not push from server to client.** The whole system is pull: workers
heartbeat and fetch, clients poll and refetch. No SSE, no WebSocket, no
long-lived control connection through the tunnel.

**We do not spawn or download executables at runtime.** The engine is linked
into the extension.

## Process

**We do not write migrations or backwards-compatibility shims during MVP.**
There is no production data. The VPS is wiped and redeployed, and the schema is
one consolidated migration. The rule is in `AGENTS.md`; it has no ADR yet.

**We do not build features nobody asked for.** A screen, a button, a setting or
an abstraction added "while we're here" is a maintenance cost with no
requester.

**We do not keep code "for later".** Unused code is deleted; git remembers it.

**We do not copy another project's philosophy.** Happ, Marzban, 3x-ui, NetBird,
Mullvad and Shadowrocket are read for facts — which API, which failure mode,
what they learned. What they chose to be is their business.

**We do not treat a green test suite as proof about the tunnel.** Leak claims
require packet capture. See ADR-002.

## Deferred, Not Rejected

These are wanted, just not now. Listed here so they are not mistaken for
non-goals:

- pf-based kill switch (closes the reconnect leak window — ADR-004).
- Traffic statistics in the client (`statsStream` is currently empty).
- IdP group synchronisation into user lists (ADR-006).
- Incremental user provisioning on the worker; today adding a user rewrites the
  config and restarts Xray, dropping everyone's sessions.
- Live Activity / Dynamic Island on iOS. It was designed and never built; the
  design was removed from the mockup rather than left as a promise.
- Android, Windows, Linux clients.
