# VPN Client — Specification

> Owner: vk@amnezia.org · Describes the client as it stands on 2026-08-09.
>
> This document says what the client *is*. Why it is that way lives in
> [`docs/decisions/`](decisions/README.md); the server product it can optionally
> talk to is specified in [`SPEC-SERVICE.md`](SPEC-SERVICE.md).

## 1. What this is

A Flutter VPN client for macOS, iOS and Android that establishes a system-wide
tunnel through the mihomo engine.

It is a complete product on its own. Nothing in it requires the management
service from this repository: a user who has only a subscription link or a
share link installs the client and it works. The self-hosted account is one of
three sources it serves, not its reason to exist.

### 1.1 Four domains of authority

The client serves four ways of being given a VPN, and they differ in **who has
authority over the user's access** — not in file format.

**1. Self-hosted.** The user signs in to a management service which owns
identity, access and policy. Full capability: an account with status and quota,
a centrally managed routing policy, revocation that takes effect immediately.

**2. Key subscriptions (`vpn://`).** A subscription key and an encrypted
gateway.
Unlike a panel, it publishes only *places*, and issues a server — keys, routes,
resolvers and an expiry — one at a time on request. The client shows only what
the gateway answered with: locations, an end date and a device count when they
are there, and nothing in their place when they are not. Protocols are
AmneziaWG and VLESS; a location offering both appears as two entries, because a
configuration is issued for the pairing. Free-tier keys are refused on import —
the gateway asks for a CAPTCHA before issuing one and this app cannot show it.

The gateway is Amnezia's and the domain is named after it in the code, but
**no user-visible string says so**: other providers sell the same key format
through the same gateway (`service_type: external-premium`), carrying their own
name, which is what the client displays. Everything else is worded as it is for
a panel subscription. See §9.

**3. Existing panels, via subscription links.** Marzban, 3x-ui and the rest of
that ecosystem already run people's servers, and they all speak the same one-way
contract: a URL returns a list of servers. There is no account and no policy to
receive — whoever runs that panel controls access by changing what the URL
returns.

**4. Bare configs, via share links.** A `vless://`-style link, or a file of
them, describing one server and nothing else. No origin to ask, no account, no
revocation — it carries exactly what is needed to bring up a tunnel.

Capability degrades along that order, deliberately and visibly (§4). The engine
and the tunnel are identical in all three; what differs is who decides what the
user may do. See ADR-005.

### 1.2 Guiding principles

- **One abstraction seam.** `VpnCore` keeps the platform side (Network
  Extension, VpnService) behind one class and lets the state layer be tested
  against a fake tunnel. It is not a plan to replace mihomo: the engine is
  fixed. Everything else is direct.
- **Simple, readable codebase.** Implement the requirement, not a platform.
- **The app never claims authority it does not have.** A domain that cannot tell
  us the account is expired must not show an account.
- **Nothing leaves the tunnel unless the tunnel says so.** Privacy behaviour is
  verified by packet capture, not by inspection (ADR-002).

---

## 2. Tech

Flutter (macOS, iOS), Riverpod for state, `http`, `flutter_secure_storage` for
tokens, `path_provider`, `crypto`, `yaml` (subscription parsing), `file_picker`,
`archive` + `share_plus` (log export), `flutter_svg` (brand glyphs).

```
client/
  lib/core        models, stores, VpnCore + NetworkExtensionCore, config
                  rendering, rule sets, geo databases, logging
  lib/state       Riverpod controllers
  lib/features    screens
  lib/api         management API client (self-hosted domain only)
  shared/apple    Swift shared by macOS and iOS, symlinked into both projects
  android/app     Kotlin: VpnService, the control channel, the engine AAR
  native/mihomocore   standalone Go module → MihomoCore.xcframework (Apple)
                  and mihomocore.aar via gomobile (Android); one engine
                  package under both surfaces
  design          ui-spec.html + check.js — the source of truth for UI geometry
  scripts         build.sh, leak-check.sh
  test            contract suites
```

The native module is deliberately outside the repository's Go workspace and
builds with `GOWORK=off`.

---

## 3. Tunnel architecture

On Apple the tunnel is an `NEPacketTunnelProvider` extension; mihomo is
compiled into it as a Go c-archive (`MihomoCore.xcframework`, `-tags
with_gvisor`). The host app stays sandboxed and shares an App Group with the
extension, which doubles as the engine's home directory for geo databases.
Swift shared by both platforms lives once in `client/shared/apple/` and is
symlinked into the platform projects.

On Android the tunnel is a `VpnService` in its own process (`:tunnel`), with
the same engine package bound by gomobile (`mihomocore.aar`, `-tags
with_gvisor,cmfa`). The app talks to it over AIDL (`ITunnel`,
`android/app/src/main/aidl/`); binder calls block, so they never run on the UI
thread, and facts that must outlive a dead tunnel process — the disconnect
reason, the log switch — are files in the shared app sandbox rather than
memory or SharedPreferences (which are not cross-process). The service establishes the tun (same addresses, routes and
MTU as the Apple settings), hands the fd to the engine — and hands the fd's
*ownership* with it: sing-tun closes it on stop, and a second close is a
process abort under fdsan. The engine's own sockets bypass the VPN through
`VpnService.protect()` installed as mihomo's socket hook, not through interface
binding (`auto-detect-interface: false` there — its route monitor needs a
netlink socket Android denies to apps). The engine home is the app's files
directory. Both natives speak one channel contract (`vpn/control`,
`vpn/status`), so a single Dart core serves all three platforms.
Rationale and constraints: ADR-001.

### 3.1 The `VpnCore` seam

Screens and state never talk to the platform directly; they go through
`VpnCore` (`client/lib/core/vpn_core.dart`), which tests replace with a fake:

| Member | Purpose |
|---|---|
| `load(NormConfig)` | hand over the current bundle |
| `connect(locationId)` / `disconnect()` | tunnel lifecycle |
| `reload(NormConfig, locationId)` | swap config under a live session (ADR-002) |
| `syncConfig(NormConfig, locationId)` | persist the config for a system-initiated start |
| `applyOnDemand(OnDemandPrefs, …)` | install auto-connect rules; returns whether the system armed |
| `removeSystemProfile()` | delete the OS VPN profile |
| `status`, `statusStream()`, `statsStream()` | state and telemetry |
| `engineVersion()` | diagnostics |

`NetworkExtensionCore` implements it for macOS, iOS, Android and Windows — the class
only speaks one control vocabulary, over the platform channels the runners
register or, on Windows, over a named pipe to the tunnel service
(`client/native/mihomocore/service`), and all four natives answer the same
contract. Config translation (bundle → mihomo YAML) lives entirely inside the
core implementation and is unit-tested
(`client/lib/core/mihomo_tun_config.dart`). Other platforms throw
`UnsupportedError` until their core is written.

`statsStream()` currently yields nothing.

### 3.2 Switching without leaks

Changing server or configuration is a hot reload of the engine under the
standing session: the NE session, the packet flow and the tunnel fd are never
touched, so the OS routing table never changes and there is no window for
traffic to escape. Nothing is excluded from the tunnel — the engine's own dial
leaves through `IP_BOUND_IF`. Full decision, rejected alternatives and
measurements: ADR-002.

IPv4 and IPv6 both have their default route claimed by the tunnel, and both are
carried: the engine runs with IPv6 on and its own v6 fake-IP pool. An unclaimed
family would keep the physical interface's route and leave in the clear; a
claimed but unhandled one would break every v6 destination. Because fake-IP
resolves back to the domain, an exit server without IPv6 still works — only
connections to literal v6 addresses need v6 at the far end.

The active configuration and the server or group it connects through survive a
restart. Both are validated on load — a configuration can be removed and a
server can disappear from the next refresh of the list it came from — and the
first-in-the-list default is what remains when either check fails.

How often a configuration re-reads itself is settable per configuration: a gear
beside the refresh button opens a field in hours — the unit the panel asks in
(`profile-update-interval`) — with "As the subscription asks" as the way back
to the source's own period. The app's five-minute floor applies to a user's
number too; there it is a courtesy to someone else's server rather than a
defence against a panel.

The session clock counts from `NEVPNConnection.connectedDate` — when the system
established the tunnel, whoever raised it. iOS starts tunnels from its own VPN
switch and from on-demand rules, so a clock stamped when the app first looked
counted from the wrong event: a session hours old read seconds. The app's own
first sighting stands in while the platform is asked, and stays if it has no
answer.

A server's row reads `VLESS · TCP · Reality` — protocol, transport, and what
protects the connection, the enumeration other clients show. The security part
is always present, including as `No TLS`: for a VPN client "not stated" and
"nothing there" are different facts. The server's address appears nowhere in
the interface, not even in a connect error, which names the server by its
label. A provider's `serverDescription` replaces the whole line.

A word about the copy: everything a subscription supplies is attributed to
**the subscription**, never to "your provider". ADR-005 is why — a subscription
is a feed of servers with no account behind it, so naming a company introduces a
party the model does not have, and everything the app knows arrived in the
subscription's own answer. The one place "provider" survives is the SSO
*identity provider*, which is a different thing entirely.

### 3.3 DNS

The DNS servers in the NE settings are a decoy: their only job is to steer the
OS's queries into the tunnel, where the engine's `any:53` hijack answers them
in fake-ip mode. The real resolvers live in the engine config's `dns:` block
and therefore switch with the configuration, through the same hot reload. A
configuration supplies them at its source — the self-hosted bundle's `dns`
field, a Clash-YAML subscription's `dns.nameserver`, an Xray or sing-box
body's `dns.servers` — and falls back to Cloudflare DoH
(`https://1.1.1.1/dns-query`) when it names none; share links cannot carry
DNS. Entries that could not be nameservers are dropped, never escaped into the
YAML, and hostname-addressed resolvers get a plain-IP bootstrap. When a
configuration names none, the app's own default stands in — settable in
Settings › Default DNS, pinned to the tunnel, and backed by a three-operator
bootstrap for the one job that cannot ride it: resolving the proxy's address. Fake-ip mode
and range are app constants across configurations.

Each format also says whether a query is issued locally or sent out through
the proxy — a `#pin` in Clash, a `detour` tag in sing-box, a `+local` scheme
in Xray — and that intent is translated rather than dropped, because it is
usually the reason the DNS block exists. It becomes a pin on the one outbound
the config renders. A pin naming anything else is removed (mihomo reads an
unknown one as a network interface to bind to), and a resolver the tunnel
cannot carry — plain UDP through an outbound without UDP — is dropped in
favour of the encrypted fallback rather than left to fail on every query.

Alongside that the config always carries `proxy-server-nameserver`: the same
resolvers with no pin, which is what the engine uses to resolve the proxy's
own hostname. Without it a pinned resolver deadlocks the tunnel — the query
waits on the proxy and the proxy waits on the query.

Every configuration screen carries a **ROUTING** section — one row naming the
policy in force and whose resolvers — placed above the panel's own details,
because it is the configuration's behaviour and the rest is background to it.
The row opens a page holding both halves under their own owners:
**SUBSCRIPTION ROUTING** / **ORGANIZATION ROUTING** for a policy someone else
sent, **DEVICE ROUTING** for the device's own, and a **DNS** section naming the
resolver. While a provider's routes are on, the device's card is visible but
takes no input: dimming alone left a switch that moved and changed nothing. That section opens a read-only **DNS** screen: the
resolvers in effect with their protocol, routing and origin, and — the reason
the screen exists — the ones the app refused, each with its reason in words.
Three refusals are possible: a scheme the engine would reject (which costs the
whole configuration, not the line), a plain-UDP resolver the tunnel cannot
carry, and a pin naming an outbound this config does not define. All three used
to be log lines, so a configuration could lose the DNS its provider chose and
look untouched. The screen and the renderer read the same computed plan, so the
screen cannot name a resolver the engine never received. When a resolver was
refused, the count travels back up to the configuration screen's row in words
(`DNS: 1 refused`): a refusal moved one level deeper is the same silence at a
different depth. Full decision: ADR-008.

---

## 4. Configurations

The app holds a list of configurations, one active. Each belongs to one of the
three domains of §1.1, and the domain determines what the app can offer:

| | self-hosted | subscription | link |
|---|---|---|---|
| Source of truth | a management service | a third-party panel | none — a static snapshot |
| Authentication | password or SSO, token in the Keychain | the secret in the URL | none |
| Locations | per-user credentials from the server | a list, refreshed from the URL | one server |
| Account state (status, quota, expiry) | yes | no | no |
| Managed routing policy | yes, and it wins over local rules | offered, and the user may switch it off | no |
| Refresh | before every connect, plus polling | polling | never — nothing to ask |
| Revocation | immediate, server-side | by what the panel returns next | none |
| Local rule sets apply | only when no managed policy | unless the panel's routes are on | yes |

Concretely: a link configuration shows no account card and no server picker; a
subscription shows a server picker but no account; only a self-hosted one can be
told by its server that it may no longer connect.

The differences live in a sealed `ConfigSource` hierarchy
(`client/lib/core/config_source.dart`), so the controller orchestrates
generically and adding a fourth domain is a subclass plus one `switch` arm.
Favourites are stored per profile, keyed `profileId/locationId`.

### 4.1 Device identification

A subscription panel that enforces a device limit identifies a device by an
`x-hwid` header (with `x-device-os`, `x-ver-os` and `x-device-model` as optional
detail), and answers 404 to a request without one. The client therefore sends
these on every subscription request — a panel that does not care ignores them.

The id is random and generated once per installation, not derived from
hardware: a panel needs only to tell devices apart, while a hardware identifier
would additionally give unrelated providers a common key for the same device.
It survives restarts, so launching the app does not consume a device slot;
reinstalling generates a new one, which does, and the configuration screen says
so rather than leaving it to be discovered at the limit.

When the panel reports that it counts devices (`x-hwid-active`), the
configuration screen shows what this device is identified as. No count is
shown, because none is sent — the panel reports only that it counts and, via
`x-hwid-max-devices-reached`, that it is full. That case is named as itself
instead of a generic refresh failure, and states that the servers already
fetched keep working.

### 4.2 Accepted inputs

- **Share links** — `vless://`, `vmess://`, `trojan://`, `ss://`,
  `hysteria2://` (and its `hy2://` alias), pasted or opened from a file
  containing several. A `vless://` or `trojan://` whose payload is base64 is
  read too, in both forms panels emit: the URI body encoded (`uuid@host:port?…`,
  the name inside or after the `#`) and, for vless, the vmess-style JSON
  object. Transports: plain tcp, tcp with an HTTP header, ws,
  httpupgrade, grpc, h2 and xhttp — each mapped to how the engine expresses it,
  which for two of them differs from the URI (an HTTP header makes it the
  engine's `http` network; httpupgrade is a websocket with the handshake
  skipped).

  A server the engine cannot run is **counted and named**, never quietly
  dropped or degraded to plain tcp: the source's own count is what the user saw
  in their provider's panel, so the configuration screen reads "294 of 306
  servers" and says which protocol or transport accounts for the difference.
- **Subscription URLs** — returning any of the four shapes the panels serve: a
  base64 list of those URIs, a Clash/mihomo YAML document, an Xray JSON
  subscription (a single config or an array of them, each naming itself in
  `remarks`) or a sing-box JSON one. A Clash document may name its servers in
  `proxy-providers` instead of carrying them; those lists are fetched over TLS,
  and one that cannot be had is counted rather than dropped.
  A server may also come with the provider's own caption
  (`serverDescription`): base64 after the name in a link's fragment
  (`#Name?serverDescription=…`), plain text in `meta` in the JSON formats. It is
  shown **in place of the protocol, never of the address** — the address is the
  only thing that tells two identically named entries apart, and a panel does
  serve those. A server without one keeps showing its protocol.
  `ss://` links carry SIP003 plugins (`obfs`, `v2ray-plugin`); a plugin the
  engine has no adapter for makes the server unsupported instead of being
  dropped, since a server expecting obfuscation refuses a plain connection.
- **A management server address** plus credentials, or SSO when the server
  advertises a provider.

Which of the four a panel serves is decided by a rule its admin wrote against
the app's User-Agent (`AnnoyaTest/<version>` — ours, never another client's
name). That makes the *amount* we get depend on somebody else's rule, so where a
panel supports it the app asks for the rendering it wants by name: after a body
that carries no groups, it tries `<url>/mihomo` (Remnawave), `<url>/clash-meta`
(Marzban — it has no "mihomo") and, for 3x-ui, the sibling path `/clash/<id>`
next to `/sub/<id>`. First one that answers with groups wins and is remembered
on the profile; a panel with none is asked once, never again, and its own body
is kept. A rendering that later dies falls back to the plain address.

A Clash subscription may also offer **groups** whose member the engine picks:
`url-test` (lowest latency), `fallback` (first that answers), `load-balance` and
`relay` (a chain). They appear in the same server picker, above the servers,
because they answer the same question. `select` groups are not carried — they
mean "let a human choose", which the picker already is. A group's members are
resolved to servers this app can actually run, and a group left with none is not
offered at all.

Choosing a group renders every member as a proxy plus the group itself; the
rules keep pointing at `PROXY`, so nothing about routing or the `tun` section
changes. Member names in the rendered config are positional (`p0…pN`) — a
provider's label is display text and must not become a YAML key. The health
check the group runs is the provider's URL (https only, else ours) at the
provider's interval, floored at five minutes: the probe runs from the user's
device, through the tunnel, once per member per round.

While a group is selected, the home screen shows which member the engine chose,
read from the engine in process — never over `external-controller`, which would
open an unauthenticated control API inside the extension.

Unknown proxy types are rejected at parse time rather than at connect time.

When nothing usable comes out, the app says which of three things happened,
because they have three different fixes: the format was not one we read (the
provider can change the template), the format was read and lists no servers at
all (the account or its device limit is the reason), or every server in it uses
something the engine cannot run (named, with the count). Entries whose addresses
are all unroutable are not servers at all but a panel's message to a client it
does not recognise — that text is shown as text and nothing is added, unless the
device-limit headers explain them, in which case they are kept and the screen
says why.

### 4.3 Synchronisation

Self-hosted configurations re-fetch before every connect, so account status and
rotated keys are enforced at the moment it matters. The poll runs every 5
minutes, which is also the floor for how often any one source is re-read: a
subscription's panel may ask for its own cadence (`profile-update-interval`, in
**hours**) and gets it where it is slower than that floor. A manual refresh
never waits.

A source that states no cadence does not fall to that floor: it is re-read
**every hour**. That covers a panel that sends no header, one that sends a zero
in it, and a `vpn://` gateway, which has no such field at all. The floor is what
a source may ask its way down to, not what silence means — read as a schedule it
fetched somebody else's whole list 288 times a day. The gear beside the refresh
button overrides all of it, in the same unit.

Two more of the panel's own statements are honoured, within bounds the app sets:
`subscription-request-timeout` (clamped to 5–15 s) and `fallback-url` — an https
address tried once when the main one does not answer at all. A refresh that came
from the backup says so under the source, because it means the provider's main
address is unreachable from this device; the source row keeps showing the
address the user added, since that is what they chose and would share. When both
fail, the error names the main address: the backup is the provider's
arrangement, and the user has never seen it. When a poll changes the active configuration's proxy or

A tunnel that stops without being asked to explains itself. A packet-tunnel
provider that refuses a config reports the reason to the system, not to the call
that started it, so the app asks the system for it
(`fetchLastDisconnectError`, macOS 13 / iOS 16) whenever a connecting or
connected tunnel falls back to disconnected on its own. Before that, an engine
that would not run a config looked exactly like a connect that hung and then
gave up.
its managed routing policy, the tunnel re-applies it; when it reports the
account can no longer connect, or the connected server disappeared, the tunnel
disconnects. Re-applies are rate-limited so a flapping source cannot loop the
tunnel.

### 4.4 The connection check

"Connected" is a claim about an interface, not about a path. An AmneziaWG peer
whose handshake never completes and a VLESS server that accepts TCP and then
says nothing both leave a tunnel that looks up and carries nothing — the same
green ring, a dead internet, and no reason to suspect the VPN.

First it looks instead of asking. The engine tracks every connection it carries,
so bytes that already came *back* through the selected outbound prove the tunnel
works — proved by the user's own traffic, with nothing sent to a third party.
Counted per connection chain, never from the tunnel's totals: in split mode
those include traffic that went out DIRECT, which says nothing about the proxy.
Silence there is not a failure, only "nothing to look at yet".

When there is nothing to look at, the app asks the engine for one HTTP HEAD
through the outbound the tunnel routes to (`PROXY`, the group every rendered
config carries). This is mihomo's
own `Proxy.URLTest`, the mechanism url-test groups pick members with, reached
through the tunnel transport each platform already has — no `external-controller`
(ADR-001 forbids it). Default target `https://www.gstatic.com/generate_204`,
default wait 5 s, both editable; `expected-status` is not exposed, because its
range syntax is a way to make the check silently meaningless.

It runs when the session comes up — including a session the system raised by
itself, which is the one nobody is watching — and on demand from the button.
Not immediately, and not once: "connected" and "carrying traffic" are separated
by a handshake, and an AmneziaWG peer only starts one when the first packet asks
for it — with a retry at `RekeyTimeout`, five seconds, exactly the probe's own
default. The automatic check therefore waits two seconds and makes up to three
attempts, publishing only the last; the button makes one, because the user asked
about now. A newly issued `vpn://` config (ADR-009) has the same warm-up on the
server's side.

The engine's failure is reported as a sentence — "The server did not answer in
time", "The server closed the connection" — not as its dial chain: Go hands back
`connect failed: dial tcp <cdn address>:443: context deadline exceeded` twice
over, once per address family, and none of that is about the user's problem. The
full text goes to the log. A
pass is silent (the tunnel coming up is already the message) and recorded on the
Advanced screen — as a delay when it was measured, as "Traffic is getting
through" when it was only observed, because a number we did not measure would be
an invention. The server is named there with the label the user's own screens
use, never the renderer's internal `proxy` / `p0`. A failure raises a warning
banner on Home. The tunnel is never dropped on a failed check: the probe
has its own false negatives, and killing a working tunnel over one unanswered
HEAD is worse than saying so.

The probe dials the outbound directly rather than through the rule engine, so
split tunnelling cannot route it away from the server under test — and, for the
same reason, a pass says nothing about where the user's own traffic goes. The
screen says so in as many words.

---

## 5. Screens

- **Start** — add a configuration: paste a link, open a file, or sign in. The
  field answers as the user types: a recognised input gets a chip naming it at
  once; text that is neither gets, 700 ms after the last change, a chip saying
  why in one phrase (an unknown scheme, a link of ours that will not parse, a
  transport the engine cannot run, a `vpn://` that is not a key) — never the
  text itself, which is the credential.
- **Sign in** — password and, when the server offers it, SSO.
- **Home** — connect ring and status, a status strip (auto-connect, routing,
  logs), the configuration and server pickers, account line. The configuration
  row carries a refresh button for sources that have one — a duplicate of the
  button on the configuration screen, since that is where it lives but not where
  it is pressed. A server row reads `<protocol> · <transport> · <address>`, with
  the transport named only when there is one to choose (plain TCP and QUIC
  protocols say nothing) and a provider's `serverDescription` replacing that
  whole technical half.
- **Settings** — configurations, connection (on-demand and disconnect-on-sleep
  on Apple; the Always-on VPN explainer on Android; **Advanced**, which holds
  the connection check), routing (LAN direct, rule sets, geo databases),
  appearance and language, logs.
- **Advanced connection** — the connection check: whether to run it after
  connecting, the URL it fetches, how long it waits, a "Test now" button and the
  last answer.
- **Configuration** — source, refresh, account and quota, routing switch and
  rule set, set active, remove.
- **Rule sets** and **Routing editor** — simple (service catalog) and advanced
  (ordered rules) views over the same rules.
- **Geo databases**, **On-demand** (rules, values), **Logs** and **Log viewer**.

Settings ends with an **About** row — the version in its subtitle, the rest on
its own screen, because settings are what the user changes and About changes
nothing. **About** shows the app's name, version and build, and the engine we
are pinned to. The engine line comes from `native/mihomocore/go.mod`, not
from the engine — mihomo carries `constant.Version = "1.10.0"` in its source and
only substitutes the real one at release build time, so asking it would report a
version we do not run. Terms of Service and Privacy Policy sit there in their own card,
dimmed and inert while their addresses are empty, saying "Not published yet"
rather than looking tappable or being hidden. The version is written in
`pubspec.yaml` and nowhere else: every platform already derives it from there,
and the app reads that same file — shipped as an asset — at startup, so a bump
is one line. The app's name and the engine pin belong to files no asset can
carry (the Xcode config and `go.mod`) and are stated in
`lib/core/app_version.dart` with a test that checks them against those two. The
User-Agent is the name and the version that was read.

On Windows the same menu lives behind a **tray icon** (`windows/runner/tray_icon.cpp`,
`Shell_NotifyIcon` and a Win32 popup menu): the same two status lines, Show/Hide,
Connect, Disconnect and Quit, composed by the same Dart code over the same
`vpn/tray` channel. A left click toggles the window, the close button hides it
into the tray, and the icon is drawn at runtime — white with a dark outline, so
it reads on a dark and a light taskbar — with the shape carrying the state:
filled for a tunnel that is up, outlined for down, outlined with a dot while
connecting.

On macOS there is also a **menu bar item** (`NSStatusItem` + `NSMenu`, drawn by
the system): a status line, show/hide the app, connect, disconnect, quit. It is
the only view of the tunnel while the window is closed, so closing the window no
longer quits — the app stays in the menu bar and the Dock. Show, hide and quit
are handled natively without a round trip to Dart; connect and disconnect are
forwarded to the app, which owns refresh-before-connect and error reporting.
State (including the item's icon, which carries status by shape because the
system tints template images itself) is composed in Dart so the menu says what
the home screen says.

`client/design/ui-spec.html` draws every screen 1:1 in Flutter logical points
and is validated by `client/design/check.js`; the numbers there and in
`client/lib/core/theme.dart` are the same numbers. A visible change starts with
the mockup, not with the code.

---

## 6. Routing

Rule sets are global to the device and applied per configuration; routing is
opt-in per configuration; a server-managed policy takes precedence and cannot be
switched off locally. LAN-direct is a separate device-level switch that applies
under any policy.

Whose rules apply is decided by one of three policy classes, not by branching:
a self-hosted server's (unswitchable), a subscription panel's (switchable), or
the device's own rule sets. See `client/lib/core/routing_policy.dart`.

A subscription's panel may send routing of its own — as a `routing:` response
header, as the `rules:` of a Clash body, or in the Xray rendering of the same
subscription, which the app requests by name (`<url>/json`) rather than by
impersonating another client. Those rules are translated into the app's model,
never adopted wholesale: what has no equivalent here (external rule files,
rules keyed on an inbound, a port or a sniffed protocol) is dropped and
counted, and the count is shown, because a partial policy presented as complete
would be worse than none. They are applied by default and attributed to the
provider on screen, but — unlike an organization's policy — the user can switch
them off, at which point the device's own rule set applies again: a panel
controls what it returns, not where this device's traffic goes (ADR-005).

Rule types are the client's own superset of the shared schema (like `geoip` and
`geosite` before them): `domain-regex` maps to the engine's `DOMAIN-REGEX`, and
`rule-list` names a file a provider hosts. Only a provider's policy can carry
`rule-list`, and only with the configuration's **rule lists** switch on — off by
default, because applying someone's rules and storing someone's files are
different decisions. The app downloads those files itself into the App Group
container and hands the engine `type: file`: mihomo's own provider fetch runs
inside config apply, 20 s per file, and reports failure only by logging, which
would stall a connect and then leave a rule that silently matches nothing. A
list that did not arrive means its rule is not applied and the screen says so.
Xray's `ext:` files stay unsupported at any setting — they live on the panel
server's disk and have no address to fetch. Geo rules require the GeoIP/GeoSite databases, which the app
downloads into the shared container and refreshes weekly — the engine never
fetches them itself. `process-name` rules work on desktop only and are dropped
before rendering elsewhere. See ADR-003.

The routing editor has two views over one rule list: **simple** (a catalog of
~34 services and countries, with direction expressed as "only selected" /
"all except selected") and **advanced** (ordered rules of every type). Switching
views converts nothing.

---

## 7. Auto-connect

Apple: on-demand rules (interface, SSID, DNS domains and servers, probe URL)
are compiled into `NEOnDemandRule`s and evaluated by the system. The rendered
config is persisted into `providerConfiguration` so a system-initiated start
has something to run. Intent, pause and what the OS actually armed are three
separate facts and all of them are shown. There is no kill switch. See ADR-004.

Android: the counterpart is the system's **Always-on VPN** — a switch the OS
owns, next to its own kill switch ("Block connections without VPN"). The app
can neither arm it nor reliably read it while the tunnel is down, so it offers
no toggle: a screen describes what the switch gives and one button opens the
system's VPN settings. The rendered config is persisted into the app's files
directory for the same reason as `providerConfiguration` on Apple — an
always-on start happens with no Flutter engine running, and it runs whatever
configuration was used last, which `syncConfig` keeps current. The on-demand
rule editor and the home "Auto" chip do not exist on Android
(`supportsOnDemand` / `supportsAlwaysOn` in
`client/lib/core/platform_support.dart`).

---

## 8. Diagnostics

One switch controls collection for the app, tunnel and engine journals; console
output continues regardless. Extension logs travel over IPC rather than through
the shared container, and all three can be exported as a zip.
`client/scripts/leak-check.sh` verifies on a live tunnel that nothing escapes
the physical interface.

---

## 9. Key subscriptions (`vpn://`)

The key is a Qt artefact and decodes like one: `vpn://` over URL-safe base64
over a zlib stream behind a four-byte prefix whose value is not to be trusted
(their premium encoder writes a constant there). The same codec unwraps the
`config` field of a gateway answer, inside which the protocol settings are a
JSON *string*. `client/lib/core/amnezia/vpn_key.dart`.

Two endpoints are used and no more — a subscription this app imports was bought
elsewhere, and an endpoint we never call is a behaviour we cannot get wrong:

- `v1/account_info` on the refresh the user asks for and on the poll timer.
- `v1/config` on every change of selection, unconditionally, and otherwise
  when the config in hand is missing or near its stated expiry
  (`ConfigSource.resolveSelection`). Eagerly, on selection rather than on
  connect, because the stored config has to be runnable by the *system*: an
  always-on start, or the VPN switch in the phone's own settings, brings the
  tunnel up with no app in memory, and a place with no server behind it would
  fail there with nobody to explain it.

  Only the server in use is kept. A switch always re-asks and the previous
  place goes back to being a name, because what a place *is* belongs to the
  gateway: a config it issued earlier may since have been rotated off the
  account, and a WireGuard peer the server has forgotten is not refused — it
  is ignored, which reaches the user as a tunnel that connects and carries
  nothing. AmneziaWG is issued against a keypair
  generated on the device; the private half never leaves it and is substituted
  into what comes back.

The transport is the native `libagw` (`client/native/libagw`, a pinned
submodule of Amnezia's own SDK): RSA+AES request envelopes, and — the reason it
is a linked library rather than a page of Dart — the censorship bypass that
resolves a pool of proxies from S3 and walks it when the gateway looks blocked.
It runs in the app process on every platform, since the engine already holds a
Go runtime in the tunnel process and two cannot share one. Calls block for the
whole failover sweep, so they run in an isolate with a deadline enforced
through the library's cancel handle.

AmneziaWG renders as a mihomo `wireguard` outbound with `amnezia-wg-option`
carrying the obfuscation as issued — H1–H4 arrive as ranges, and `version: 3`
is set only when the server sent v3.1 parameters, because claiming it selects a
different implementation than the server speaks. VLESS arrives as an ordinary
Xray document and goes through the reader this app already has.

The gateway counts devices by `installation_uuid`, not by requests: the id is
minted once and kept in the keychain, so re-issuing a server costs nothing
against the subscription's device limit. Losing it is what costs a slot, which
is why it is created by the app and never derived from anything the gateway
returns. A refusal still surfaces as an error where the user asked for
something (a selection, a connect) and as a log line where they did not (a
background sync). An import whose first issue fails still adds the
subscription — the account is real and its locations are real, and refusing to
add it would leave the user with nothing over a captcha.

Issuing a server is held under the same "switching" state a hot switch uses,
because it is a gateway round trip: without it Connect is tappable before there
is anything to connect with. The wait says which wait it is — a live session is
switching servers, a dead one is still getting its first.

A failure that leaves the previous server working is a toast, not a dialog
(§9): the same event should not read one way on the home screen and another in
the configuration's own settings.

The gateway's own account of each request — direct, through which bypass proxy,
whether it fell back to storage — is logged through its callbacks. Without it,
"the gateway did not answer" reads identically whether the network is dead or
the bypass silently worked.

Failures come in two kinds, and the library tells them apart: a transport
outcome (cancelled, timeout, TLS, unreachable, undecryptable, a build without
the key) when the gateway never answered, and the gateway's own refusal — its
`http_status` and `message` in the body — when it did. The refusal is read the
way the reference client reads it (429 throttled, 409 device limit or trial
used, 404 unknown key, 501 client too old, 422 with its sentence expired, 402
the captcha family or not active), and where the gateway sent wording, that
wording wins: the same problem should read the same in two clients. The captcha codes say plainly that this app cannot show one. The
wording is provider-neutral throughout — the gateway serves resellers, and a
sentence naming Amnezia would be a false statement about who took the money;
`amnezia_config_test.dart` fails if one appears.

---

## 10. What a self-hosted server must provide

The only contract between this client and a management service is one
authenticated endpoint returning the normalized bundle (`normconfig.Bundle`,
specified in [`SPEC-SERVICE.md`](SPEC-SERVICE.md) §4):

```
GET /api/client/config → { version, account, locations[], routing? }
```

plus `POST /api/client/login`, `POST /api/client/login/oidc` and
`GET /api/client/auth-config` for authentication. `proxy` inside a location is
an open map keyed by `type`; the client maps it to whatever the active core
understands, so a server adding a protocol does not require a client change.

---

## 11. Security

- Tokens are stored in the Keychain, one per self-hosted configuration, and
  removed with the configuration.
- No client secret ships in the app; SSO uses Authorization Code with PKCE.
- Logs never contain tokens, passwords or full config bodies.
- The client trusts no domain to be honest about its own capabilities: absence
  of account data is presented as absence, never as "active".
