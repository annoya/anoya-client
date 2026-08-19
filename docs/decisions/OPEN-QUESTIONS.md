# Open Questions

Decisions the three code reviews surfaced and left open. Each is here because
it needs a call that code cannot make on its own — a product choice, a
deployment assumption, or a trade-off worth stating out loud — not because
someone ran out of time.

This is the complement of the ADRs next to it: those record what was decided,
this records what has not been. An entry leaves this file by becoming an ADR
(or a line in one), not by being quietly implemented.

Everything the reviews found that was simply *wrong* has been fixed; nothing
below is a known defect left in place. Where a fix is obvious but the timing or
shape is a judgement call, that is said explicitly.

---

## 1. Is anything in front of management? (deployment assumption)

**Status: assumed "no", enforced in code.**

Management terminates TLS itself with autocert, so by default nothing sits in
front of it and `X-Forwarded-For` is whatever the caller typed. The login rate
limiter therefore keys on the socket peer, and the `RealIP` middleware is
deliberately absent — trusting the header would let one attacker rotate it and
bypass the limiter entirely.

If a deployment ever puts a reverse proxy, load balancer or CDN in front, this
inverts: `RemoteAddr` becomes the proxy for every request (one shared limiter
bucket for the world), and the forwarded headers become the truth. Both halves
have to change together.

**Decide when:** a deployment gains a proxy.
**Then:** re-add `middleware.RealIP` in `internal/http/server.go`, key the
limiter on it, and record in ADR-006 which header is trusted and who strips it.

---

## 2. Does a password change end existing sessions?

**Status: it does not, and that is currently unstated rather than chosen.**

Tokens carry only `realm`, `sub`, `iat`, `exp` — nothing that can be
invalidated. A stolen client token stays valid for its full 30 days across a
password reset and across `status: deactivated`, still pulling fresh locations
and credentials from `/api/client/config`.

The mechanism is a `token_version` column bumped on password change and
deactivation, put in the claims and compared on every authenticated request.
Cheap to build; the open part is the product behaviour:

- **Silent** — a reset logs every device out with no warning. Safest, and the
  usual expectation after "reset my password".
- **Only on deactivation** — a reset does not disturb working devices; only an
  admin switching an account off cuts it immediately.
- **Explicit** — a "sign out everywhere" action, separate from the reset.

**Recommendation:** silent on both. A password reset that leaves a thief signed
in is the failure people assume cannot happen.

---

## 3. Should the Xray stats API stay reachable on the host?

**Status: unresolved, blocked on how the worker is run.**

The engine's stats API listens on `127.0.0.1:10085` with no authentication, and
the worker container runs with `--network host` — so that listener is on the
*host's* loopback, not a container-private one. Any local process can call it,
including with `-reset`, which zeroes the counters between the worker's polls
and makes quota accounting silently under-count.

The exposure only matters if something else runs on that host, which for a
dedicated VPN server is unusual — but "unusual" is not "impossible", and the
worker is installed with a copy-pasted one-liner onto whatever machine the
operator has.

Fixing it means changing how the worker runs (private network namespace with
explicit port mapping, or a unix socket for the API), which touches the install
command that ADR-007's enrollment story is built around.

**Decide when:** the install story is revisited for any reason.

---

## 4. Should the client reject literal IPv6 destinations when the exit has no IPv6?

**Status: not implemented; the default behaviour is deliberate.**

The tunnel carries IPv6 end to end (ADR-002). Because fake-IP resolves back to
the domain, an exit server without IPv6 still serves everything reached by
name — the server picks the family. The one case that depends on the exit's own
IPv6 is a connection made to a **literal** v6 address: it is proxied as a v6
destination and fails at the server.

An `IP-CIDR6,::/0,REJECT` rule would turn that failure from "hangs until the
timeout" into "refused immediately", which is friendlier — but only correct
while the exit really has no IPv6, and nothing tells the client that.

**Decide when:** the self-hosted service starts recording whether a worker has
working IPv6. Then this becomes a per-configuration flag rather than a guess.

---

## 5. Threading `context` through the store layer

**Status: a known shape, not yet done.**

No store method takes a `context.Context`; every query uses the non-`Context`
variants. Request cancellation and shutdown cannot reach a query, so an
abandoned request keeps its connection, and `Close()` cannot interrupt work in
flight.

The change itself is mechanical — every signature and every call site — which
is exactly why it wants to be its own commit rather than a rider on a fix. It
pairs naturally with collapsing `ApplyTraffic`'s per-user loop into set-based
statements: both are about how long a single write holds SQLite's one writer.

**Decide when:** load makes it visible, or the next time the store is opened for
another reason. Not urgent at current scale, and doing it piecemeal is worse
than not doing it.

---

## 6. How much of the HTTP layer deserves tests

**Status: partially covered; the boundary is unsettled.**

The reviews prompted the first tests in `management/` and `worker/`, and they
cover what the reviews found: timestamp round-trips, traffic idempotency and
scoping, stats-key parsing, traffic retention. The HTTP handlers remain
untested, and ADR-006's invariants — the ID token is verified server-side,
`email_verified` is required, the domain allowlist is enforced, realms are
separated — are pinned by nothing.

That conflicts with the rule in AGENTS.md that every invariant is pinned by a
test. The open question is not *whether* but *how far*: handler tests here need
a store, and the choice is between an in-memory SQLite per test (real, slower,
catches store/handler mismatches) and an interface the handlers accept (faster,
but invents a seam nothing else needs).

**Recommendation:** real SQLite per test — the store is a file away, and the
seam would exist only for the tests.

---

## 7. The mihomo pin

**Status: known, deliberately not touched.**

`client/native/mihomocore/go.mod` pins a development snapshot rather than a
tagged release. The repository already treats this as a bug to escape, not a
decision, so it is not an ADR — but it is a decision in the sense that someone
has to pick the moment and re-verify.

Everything the reviews established about engine behaviour — `Tun.Equal`
semantics, `ApplyConfig`'s silence on apply-stage failures, `parseIPV6`'s
interface probe, the geo download during parsing — was verified against exactly
this snapshot. A bump re-opens all of it.

**Decide when:** a tagged release carries what the snapshot was taken for.
**Then:** re-run the leak check and the engine-wrapper tests before trusting the
invariants again.
