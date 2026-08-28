# VPN Client — Specification

> Owner: vk@amnezia.org · Describes the client as it stands on 2026-08-09.
>
> This document says what the client *is*. Why it is that way lives in
> [`docs/decisions/`](decisions/README.md); the server product it can optionally
> talk to is specified in [`SPEC-SERVICE.md`](SPEC-SERVICE.md).

## 1. What this is

A Flutter VPN client for macOS and iOS that establishes a system-wide tunnel
through a swappable engine.

It is a complete product on its own. Nothing in it requires the management
service from this repository: a user who has only a subscription link or a
share link installs the client and it works. The self-hosted account is one of
three sources it serves, not its reason to exist.

### 1.1 Three domains of authority

The client serves three ways of being given a VPN, and they differ in **who has
authority over the user's access** — not in file format.

**1. Self-hosted.** The user signs in to a management service which owns
identity, access and policy. Full capability: an account with status and quota,
a centrally managed routing policy, revocation that takes effect immediately.

**2. Existing panels, via subscription links.** Marzban, 3x-ui and the rest of
that ecosystem already run people's servers, and they all speak the same one-way
contract: a URL returns a list of servers. There is no account and no policy to
receive — whoever runs that panel controls access by changing what the URL
returns.

**3. Bare configs, via share links.** A `vless://`-style link, or a file of
them, describing one server and nothing else. No origin to ask, no account, no
revocation — it carries exactly what is needed to bring up a tunnel.

Capability degrades along that order, deliberately and visibly (§4). The engine
and the tunnel are identical in all three; what differs is who decides what the
user may do. See ADR-005.

### 1.2 Guiding principles

- **One abstraction seam.** `VpnCore` isolates the engine so it can be replaced
  or ported. Everything else is direct.
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
  native/mihomocore   standalone Go module → MihomoCore.xcframework
  design          ui-spec.html + check.js — the source of truth for UI geometry
  scripts         build.sh, leak-check.sh
  test            contract suites
```

The native module is deliberately outside the repository's Go workspace and
builds with `GOWORK=off`.

---

## 3. Tunnel architecture

The tunnel is an `NEPacketTunnelProvider` extension; mihomo is compiled into it
as a Go c-archive (`MihomoCore.xcframework`, `-tags with_gvisor`). The host app
stays sandboxed and shares an App Group with the extension, which doubles as the
engine's home directory for geo databases. Swift shared by both platforms lives
once in `client/shared/apple/` and is symlinked into the platform projects.
Rationale and constraints: ADR-001.

### 3.1 The `VpnCore` seam

The app never references the engine. `VpnCore`
(`client/lib/core/vpn_core.dart`):

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

`NetworkExtensionCore` implements it for macOS and iOS. Config translation
(bundle → mihomo YAML) lives entirely inside the core implementation and is
unit-tested (`client/lib/core/mihomo_tun_config.dart`). Other platforms throw
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
YAML, and hostname-addressed resolvers get a plain-IP bootstrap. Fake-ip mode
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
  containing several. Transports: plain tcp, tcp with an HTTP header, ws,
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

---

## 5. Screens

- **Start** — add a configuration: paste a link, open a file, or sign in.
- **Sign in** — password and, when the server offers it, SSO.
- **Home** — connect ring and status, a status strip (auto-connect, routing,
  logs), the configuration and server pickers, account line. The configuration
  row carries a refresh button for sources that have one — a duplicate of the
  button on the configuration screen, since that is where it lives but not where
  it is pressed. A server row reads `<protocol> · <transport> · <address>`, with
  the transport named only when there is one to choose (plain TCP and QUIC
  protocols say nothing) and a provider's `serverDescription` replacing that
  whole technical half.
- **Settings** — configurations, connection (on-demand, disconnect on sleep),
  routing (LAN direct, rule sets, geo databases), appearance and language, logs.
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
rather than looking tappable or being hidden. The app's name, version and engine
pin live in one file (`lib/core/app_version.dart`) with a test that checks them
against `pubspec.yaml`, `go.mod` and the bundle's `PRODUCT_NAME`; the
User-Agent is built from the same two strings.

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

On-demand rules (interface, SSID, DNS domains and servers, probe URL) are
compiled into `NEOnDemandRule`s and evaluated by the system. The rendered config
is persisted into `providerConfiguration` so a system-initiated start has
something to run. Intent, pause and what the OS actually armed are three
separate facts and all of them are shown. There is no kill switch. See ADR-004.

---

## 8. Diagnostics

One switch controls collection for the app, tunnel and engine journals; console
output continues regardless. Extension logs travel over IPC rather than through
the shared container, and all three can be exported as a zip.
`client/scripts/leak-check.sh` verifies on a live tunnel that nothing escapes
the physical interface.

---

## 9. What a self-hosted server must provide

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

## 10. Security

- Tokens are stored in the Keychain, one per self-hosted configuration, and
  removed with the configuration.
- No client secret ships in the app; SSO uses Authorization Code with PKCE.
- Logs never contain tokens, passwords or full config bodies.
- The client trusts no domain to be honest about its own capabilities: absence
  of account data is presented as absence, never as "active".
