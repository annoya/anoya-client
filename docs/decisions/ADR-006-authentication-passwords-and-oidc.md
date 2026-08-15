# ADR-006: Passwords stay; SSO is generic OIDC with the client talking to the IdP directly

## Status

Accepted

## Date

2026-08-09 (recorded; decided 2026-07)

## Context

The product targets small companies. Those that already run Google Workspace or
Microsoft Entra do not want to hand out a second set of credentials, and their
admins want an account to stop working when the employee is offboarded in the
IdP. Those that do not run an IdP must not be forced to acquire one to use a VPN.

Two questions had to be answered: which protocol, and who performs the OAuth
dance — the client or the management service.

## Decision

**Plain OIDC, one code path for every provider.** Providers are configured in
the admin panel (issuer, client id, allowed email domains, default user list),
and the service resolves endpoints and JWKS through the standard discovery
document. Google, Microsoft, Okta and Keycloak differ only by configuration.
This mirrors how NetBird does it, which was checked before committing.

**The client talks to the IdP directly** — Authorization Code with PKCE, public
client, no client secret. It returns the ID token to management, which validates
it against JWKS: issuer, audience, nonce, `email_verified`, and the domain
allowlist. On Apple platforms the browser leg is
`ASWebAuthenticationSession` returning to the custom scheme `vpnclient://auth`.

**Users are provisioned just-in-time.** A verified identity from an allowed
domain gets an account in the provider's default user list, recording
`auth_source` and `external_id` (the IdP's stable `sub`).

**Passwords remain a first-class login method.** SSO is an addition, not a
replacement.

## Invariants

- The ID token is validated server-side, always. The client's word about who it
  is means nothing.
- `email_verified` is required, and the email domain must be in the provider's
  allowlist — otherwise anyone with a Google account could enrol into someone
  else's VPN. The allowlist is mandatory for every provider and an empty one
  denies: "no domains configured" is a misconfiguration, and reading it as "no
  restriction" turns it into an open door.
- A provider's issuer must be https. Management fetches the discovery document
  and the JWKS from it, so over plaintext an on-path attacker supplies both and
  the signature check passes — against their key.
- The unauthenticated login routes are rate limited per client address. Every
  attempt costs a bcrypt hash, so this bounds both guessing and CPU exhaustion,
  and a failed lookup pays the same hashing cost as a wrong password so the
  response time does not enumerate accounts.
- Identity binding is by `sub`, not by email. Emails get reassigned.
- No client secret ships in the app. A public client has none by construction.

## Alternatives Considered

### Management performs the whole OAuth flow (server-mediated)

Rejected. It makes TLS a hard prerequisite for SSO to work at all and
complicates the return trip into the native app. Its apparent advantage —
"secrets stay on the server" — does not exist here: a native public client has
no secret to protect, and PKCE is what replaces one.

### A loopback listener for the OAuth redirect instead of a custom scheme

Rejected: `ASWebAuthenticationSession` with a custom scheme is the platform's own
answer, survives app suspension, and does not require binding a local port.

### Per-vendor integrations (a "Google" button, a "Microsoft" button)

Rejected: they differ by discovery URL and branding, not by protocol. Presets on
top of one generic implementation give the same UX without a matrix of code
paths.

### Configure providers through environment variables

Rejected: adding an IdP would mean redeploying the service. It belongs in the
panel next to users and user lists.

### Require SSO once configured, as NetBird does

Rejected: it strands local accounts and contractors who are not in the
directory.

### Sync IdP groups into user lists

Deferred, not rejected. It needs directory API credentials and a sync loop —
worth doing when a customer asks, not before.

## Consequences

- Management must reach the IdP's discovery and JWKS endpoints. It caches per
  issuer; an IdP outage blocks SSO logins but not password logins.
- JIT provisioning means the allowlist is the real access control. A wrong
  domain in that field is an open door.
- Token lifetimes differ by source: 30 days for password logins, 24 hours for
  OIDC — the IdP is the authority on session length and can revoke. Tokens
  expire outright; there is no refresh-on-use, and re-authenticating is cheap
  enough that adding one would buy nothing.

## Where It Lives

- `management/internal/oidcauth/oidcauth.go` — discovery, JWKS, claim checks.
- `management/internal/http/` — `GET /api/client/auth-config`,
  `POST /api/client/login/oidc`, admin CRUD for providers.
- `management/webui/src/pages/SSO.tsx` — provider configuration.
- `client/lib/core/oidc_login.dart` — PKCE, `ASWebAuthenticationSession` over
  the `vpn/web_auth` channel.
- `client/lib/features/sign_in_screen.dart` — the SSO button, shown only when
  the server advertises a provider.
