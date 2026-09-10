# ADR-009: Amnezia Premium as a fourth domain, with its transport borrowed

## Status

Accepted

## Date

2026-08-31

## Context

Amnezia sells VPN subscriptions handed out as a `vpn://` key. Supporting them
is not the same problem as supporting a panel. A panel publishes a list of
servers and the client reads it; Amnezia's gateway publishes only a list of
*places*, and issues a server — address, keys, routes, resolvers and an expiry
— one at a time, when asked. Their gateway also refuses to answer a client it
does not recognise, speaks only in RSA+AES envelopes, and, where it appears to
be blocked, expects the client to find its way around through a pool of proxies
published on S3.

Two protocols are involved: AmneziaWG, which is WireGuard with an obfuscation
layer, and VLESS, which this app already runs.

## Decision

**A fourth domain (ADR-005), not a variant of subscription.** `ProfileType.amnezia`
with all its specifics behind one nullable `Profile.amnezia` field and one
`ConfigSource` subclass. Adding it cost five `switch` arms and no new branches
anywhere else, which is the test the seam was built to pass.

**One new method on the `ConfigSource` seam: `resolveSelection`.** A source that
issues servers on demand needs somewhere to do it. The alternatives were worse:
fetching every location up front spends a device slot on places the user never
picks, and fetching at connect time inside the controller would put Amnezia's
name in code that must not know it exists.

**Location × protocol is one entry, not an entry with a protocol switch.** A
configuration is issued for the pairing, so changing either half is a round
trip to the gateway and a new key. A switch would look like a setting on the
current server; it is the choice of a different one.

**Show only what the gateway answered.** Premium carries an end date, a device
count and locations; free carries a description and nothing else. A dash where
a number would go, or "0 of 0 devices", asserts that a value exists and is
empty, which is a different claim from "they never said".

**The transport is borrowed, not reimplemented.** `libagw` — Amnezia's own Go
SDK, pinned as a submodule — is linked in. The envelope crypto would have been
a page of Dart; the censorship bypass would not, and getting it subtly wrong
would fail exactly where a user needs it most.

**The library lives in the app process on every platform**, because the engine
already holds a Go runtime in the tunnel process and two cannot share one. On
Apple it is a static archive in an xcframework, referenced once from Swift so
the linker keeps it; on Android a plain `.so` in `jniLibs`. Calls block for the
whole failover sweep, so they run in an isolate with a deadline of our own,
enforced through the library's cancel handle — a timer inside the worker would
never run, because the blocking call owns that isolate's only thread.

**Only the selected server is held, and a switch always re-asks.** Caching
more looks like a saving and is not: the account has a device limit, the
gateway rotates configs off it, and a peer the server has forgotten does not
refuse a WireGuard handshake — it ignores it. That reaches the user as a
tunnel that connects and carries nothing, which is the hardest failure in this
app to diagnose. The one place in use is kept so a connect does not pay a round
trip; everything else is a name until it is picked.

**Servers are issued when the selection changes, not when the user connects.**
The lazier version spends fewer device slots, and is wrong: the stored config
is what a system-initiated start runs — always-on, or the VPN switch in the
phone's settings — and that happens with no app in memory to fetch anything.
The config on disk must always be one the system can run alone.

**The interface never names Amnezia.** The gateway is Amnezia's and the code is
named after it, but the key format and the gateway serve resellers too: a key
can arrive carrying another provider's name and `service_type:
external-premium`, and its holder never bought anything from Amnezia. Every
user-visible string therefore reads the way a panel subscription's does —
"Subscription · 44 servers", "Renew the subscription", "Identified to your
subscription" — and the one name shown is the one the key carries, in the title
where a panel puts its host. That includes the copy rule SPEC-CLIENT §5 already
set for panels: everything is attributed to *the subscription*, never to "your
provider", because there is no company in the model to attribute it to. A wording that named Amnezia would not be a rough
edge but a false statement about who holds the user's money and who can fix
their problem.

**Amnezia Free is refused at import, not supported half-way.** Their gateway
asks for a CAPTCHA before issuing a free configuration, and this app has no
surface to show one — solving it on the user's behalf is not something to
build. A key that imported cleanly and then never connected would read as a
broken app; a refusal naming the reason sends the user to the client that does
work.

## Invariants

- The subscription key is a bearer credential: keychain only, never in
  `profiles.json`, never rendered, never logged, and no Source row shows it.
- The AmneziaWG private key is generated on the device and never sent. A
  configuration that comes back still carrying the placeholder is refused
  rather than run.
- A configuration is replaced before its stated expiry, not after: one that
  expires while the tunnel is coming up fails in the least explicable way there
  is. Changing the selection replaces it regardless of expiry.
- Obfuscation parameters are emitted exactly as issued. `version: 3` is claimed
  only when the server sent v3.1 parameters, because it selects a different
  implementation in the engine.
- The poll treats this domain like any other source: `account_info` on the
  timer, at the app's default cadence unless the user says otherwise. The
  gateway has no header to ask in, and the poll floor is a floor, not a
  schedule.
- `installation_uuid` is generated by the app and persisted in the keychain.
  The gateway's device limit counts installations, so a fresh id per request
  would exhaust a user's subscription within a day; it is never taken from
  anything the gateway returns.
- No user-facing string in the domain names Amnezia; the provider's own name
  comes from the key. Pinned by a test that reads the source files, because the
  wording is easy to reintroduce and impossible to notice while testing against
  an Amnezia key.
- Gateway credentials — endpoint, RSA public key, storage endpoints — are
  build-time configuration, never committed. A build without them refuses
  Amnezia keys with a message that says so. The client identity the gateway is
  told about is *not* configuration: the app sends its own bundle name and its
  own version and claims no distribution channel, so no build can present
  itself as somebody else's client.

## Alternatives Considered

### Reimplement the gateway transport in Dart

The envelope is RSA-PKCS1v1.5 over an AES key payload, and porting it is an
afternoon. The failover is not: it resolves an encrypted proxy list from S3,
health-checks a pool and replays the request through each candidate, with
heuristics for what "blocked" looks like. A second implementation of that would
diverge from theirs and fail in the one situation it exists for.

### Merge libagw into the engine's Go module

One artifact instead of two. It puts the gateway in the tunnel process, where
the app cannot call it without an IPC round trip for something that is ordinary
HTTPS — and on Apple would mean asking a Network Extension to make requests on
the app's behalf while the tunnel is down.

### Treat AmneziaWG as a WireGuard subscription type

Rejected implicitly by keeping `wireguard` out of `kSubscriptionProxyTypes`: a
panel listing a WireGuard server lists one we hold no key material for, while
an Amnezia gateway issues the key with the config. The renderer can emit both;
only one of them can ever work.

## Consequences

- The app carries a second Go library, and a submodule pinning someone else's
  release. Their module path does not match their repository path, so the
  dependency is a local `replace` onto the submodule rather than a `go get`.
- Two endpoints are implemented out of the fourteen their client uses. Trials,
  purchases, captchas and the services catalogue are absent; a captcha
  challenge is reported as something to resolve in Amnezia's own app.
- VLESS has been verified end to end against a live subscription. AmneziaWG
  renders correctly and the engine accepts it, but a handshake has not yet been
  observed — see OPEN-QUESTIONS.
