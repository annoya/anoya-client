# Self-Hosted VPN Service — Specification

> Status: draft v1 · Owner: vk@amnezia.org · Last updated: 2026-06-27

## 1. Overview

A self-hosted VPN product made of three components:

1. **Client** — cross-platform Flutter app (macOS first). Establishes the VPN
   tunnel through a swappable **VPN core** (initially [mihomo](https://github.com/MetaCubeX/mihomo)).
2. **Management service** (`management`) — Go service + embedded React admin
   panel. Source of truth for users, user-lists, and workers. Hands out client
   configs and coordinates workers.
3. **Worker** (`worker`) — Go service installed on each VPN server. Runs the
   actual server-side VPN protocol (initially Xray / VLESS+Reality), pulls its
   user set from management, and reports liveness.

### 1.1 Guiding principles

- **Simple, readable codebase. No over-engineering.** Implement the ТЗ, not a
  platform. Prefer boring, well-understood patterns.
- **Two independent abstraction seams** (these are the only "framework-y" parts
  we deliberately invest in, because the whole product depends on them):
  - **Core abstraction** (client side): the app must not depend on mihomo. A
    `VpnCore` interface isolates tunnel control + config translation so the core
    can be replaced.
  - **Protocol abstraction** (management + worker side): adding a new protocol
    (e.g. AmneziaWG) must not require touching user/worker/list logic. A
    `ProtocolDriver` contract isolates server-config generation, per-user
    provisioning, and client-config generation.
- **Easy install.** Management ships as a single Docker image (Go binary with
  embedded SPA + SQLite). A worker installs via a single generated
  `docker run` command.

### 1.2 MVP scope decisions (from product owner)

| Decision | Choice |
|---|---|
| Initial protocol | **VLESS + Reality** (Xray-core on the worker), behind the protocol abstraction so AmneziaWG etc. can be added later. |
| Admin panel | **React SPA embedded** into the Go binary via `go:embed`. |
| Worker ↔ management transport | **Pull model**: worker holds an enrollment token + management URL; it heartbeats and pulls its user set. Management never initiates connections to workers. |
| Database | SQLite (single file, WAL mode). |
| Client/admin auth | JWT bearer tokens. |
| First platform | macOS. Architecture stays cross-platform. |

---

## 2. Architecture

```
                         ┌─────────────────────────────────────┐
                         │        Management service (Go)        │
                         │  ┌────────────┐   ┌────────────────┐  │
   Admin browser ───────▶│  │ Admin API  │   │  Embedded SPA  │  │
   (React SPA)           │  └────────────┘   └────────────────┘  │
                         │  ┌────────────┐   ┌────────────────┐  │
   Client app ──────────▶│  │ Client API │   │  Worker API    │◀─┼──── Worker(s)
   (Flutter+mihomo)      │  └────────────┘   └────────────────┘  │     (Go) pull
                         │            SQLite (state)             │
                         └─────────────────────────────────────┘
                                                                         │ provisions
                                                                         ▼
                                                                  Xray-core (VLESS+Reality)
                                                                         ▲
   Client app ───────────────────── VPN tunnel ──────────────────────────┘
```

- The **client** talks only to the management service for control-plane
  (login, fetch config) and directly to the **worker** for the data-plane (the
  encrypted tunnel).
- The **worker** talks only to the management service (pull). It does not talk
  to the client over a control channel — it only terminates VPN traffic.

### 2.1 Config flow (the core invariant)

> **Before every connection attempt the client re-fetches its config from
> management.** If the admin changed anything (new location, rotated Reality
> keys, revoked access, changed expiry), the client picks it up at connect time.

```
admin edits worker/user  ──▶  management DB (source of truth)
                                   │
        ┌──────────────────────────┴──────────────────────────┐
        ▼ (worker pull, ~every N s)                            ▼ (client connect)
  worker provisions Xray:                              client GET /api/client/config
   add/remove client UUIDs                              → normalized config bundle
   in the inbound                                       → VpnCore translates to mihomo
```

### 2.2 Repository layout (Go workspace + Flutter app)

```
vpn2/
├── SPEC.md
├── go.work                      # ties management + worker + shared together
├── shared/                      # Go module: shared/...
│   ├── protocol/                # ProtocolDriver contract + registry + drivers
│   │   ├── driver.go            # interface + types
│   │   ├── registry.go
│   │   └── vlessreality/        # first driver
│   ├── apitypes/                # request/response DTOs shared by mgmt & worker
│   └── normconfig/              # normalized client config model (core-agnostic)
├── management/                  # Go module: management binary
│   ├── cmd/management/main.go
│   ├── internal/
│   │   ├── http/                # routers: admin, client, worker
│   │   ├── store/               # SQLite (sqlc or stdlib), migrations
│   │   ├── auth/                # JWT, password hashing, admin bootstrap
│   │   ├── service/             # business logic (users, lists, workers)
│   │   └── webui/               # go:embed of built SPA
│   ├── webui/                   # React + Vite source (built into internal/webui/dist)
│   └── Dockerfile
├── worker/                      # Go module: worker binary
│   ├── cmd/worker/main.go
│   ├── internal/
│   │   ├── client/              # management pull client (heartbeat, fetch users)
│   │   ├── backend/             # protocol backend control (Xray process + API)
│   │   └── reconcile/           # diff desired vs actual users → apply
│   └── Dockerfile
└── client/                      # Flutter app
    ├── lib/
    │   ├── core/                # VpnCore abstraction + mihomo implementation
    │   ├── api/                 # management API client
    │   ├── features/            # login, locations, connection, account
    │   └── main.dart
    └── macos/                   # platform channel + bundled mihomo
```

`shared/` is imported by both `management` and `worker` so the protocol model
and DTOs stay in one place. The Flutter app duplicates the small normalized
config model in Dart (kept in sync manually — it is tiny and changes rarely).

---

## 3. Domain model

### 3.1 Entities

**Admin**
- `id`, `username`, `password_hash`, `created_at`.
- Bootstrapped on first run (one admin for MVP). Credentials printed to stdout
  / written to a one-time file in the data dir.

**User** (VPN end-user)
- `id`, `username` (unique login), `password_hash`, `display_name`.
- `status`: `active` | `expired` | `deactivated` (see §3.2).
- `expires_at` (nullable — null = never expires).
- `user_list_id` (FK, required) — **a user always belongs to exactly one
  user-list**. This is a hard rule, not just an MVP simplification.
- `credentials` — protocol-agnostic credential blob, e.g. `{ "uuid": "<v4>" }`
  for VLESS. Generated on create.
- `created_at`, `updated_at`.

**UserList**
- `id`, `name`, `description`.
- Has many users. Has many workers (M:N via `user_list_workers`).
- Defines **which workers (locations) its users may use**.

**Worker** (a VPN server / location)
- `id`, `name`, `location_label` (shown to user, e.g. "Amsterdam #1").
- `protocol` (e.g. `vless-reality`).
- `endpoint_host`, `endpoint_port` — public address users connect to.
- `enrollment_token` (hashed) — used once by the worker to register.
- `server_settings` (JSON) — protocol-specific server params (e.g. Reality
  private key, shortIDs, SNI/dest). Generated with sane defaults on create.
  **Reality default `dest`/`server_name` = `www.apple.com:443`** (TLS 1.3 +
  HTTP/2, globally reachable). NB: `www.microsoft.com` was tried first but its
  Akamai TLS handshake is incompatible with current Xray/mihomo Reality and
  fails; apple/google/amazon/mozilla/cloudflare all verified working.
- `client_template` (JSON) — admin-editable protocol params returned to clients
  (e.g. Reality public key, SNI, flow). Pre-filled from `server_settings`.
- `status`: `pending` (created, never enrolled) | `online` | `offline`
  (derived from last heartbeat).
- `last_seen_at`, `agent_version`, `metrics` (JSON: see §6.3).
- `created_at`, `updated_at`.

**Relationships**
- `UserList 1—N User`
- `UserList N—M Worker` (`user_list_workers`)
- A user's accessible workers = the workers attached to their user-list, minus
  offline/disabled ones at fetch time.

### 3.2 User status semantics

- `active` — can log in and fetch configs.
- `expired` — derived/explicit: `expires_at` is in the past. Login allowed (so
  the app can show "subscription expired"), but config fetch returns no
  workers / an `expired` flag. Worker provisioning removes them.
- `deactivated` — admin-disabled. Login refused. Removed from workers.

Status is computed as: `deactivated` (explicit) → else `expired` (if
`expires_at < now`) → else `active`. A nightly/15-min job materializes `expired`
for fast queries; the live check is always authoritative.

---

## 4. The two abstraction seams

### 4.1 Core abstraction (client)

The Flutter app depends on `VpnCore`, never on mihomo directly.

```dart
abstract class VpnCore {
  /// Translate the normalized config bundle into the core's native config
  /// and load it. Does not connect.
  Future<void> load(NormalizedConfig config);

  /// Bring the tunnel up for the selected location.
  Future<void> connect(String locationId);

  Future<void> disconnect();

  /// active | connecting | disconnected | error
  Stream<VpnStatus> statusStream();

  /// Optional live stats (up/down bytes, latency). May be empty.
  Stream<VpnStats> statsStream();
}
```

- `MihomoCore implements VpnCore` is the only implementation for MVP. It owns
  the mapping `NormalizedConfig → Clash/mihomo YAML` and the platform channel to
  the bundled mihomo binary / library.
- Swapping cores = writing a new `VpnCore` implementation. Nothing in the
  feature layer (login, location list, connect button) changes.
- The translation layer lives entirely inside the core implementation so that
  core-specific quirks never leak into app logic.

### 4.2 Protocol abstraction (management + worker)

Single Go interface in `shared/protocol`:

```go
type Driver interface {
    // Stable identifier, e.g. "vless-reality".
    Name() string

    // Generate default server settings for a new worker (keys, ids, ports).
    DefaultServerSettings(host string, port int) (ServerSettings, error)

    // Derive the admin-editable client template from server settings.
    DefaultClientTemplate(ServerSettings) (ClientTemplate, error)

    // Build the worker's full server config from settings + the desired user
    // set (used by the worker to (re)write its backend config).
    RenderServerConfig(ServerSettings, []User) ([]byte, error)

    // Incremental provisioning (preferred over full rewrite when the backend
    // supports a live API). Return ops the worker applies via the backend.
    DiffUsers(current, desired []User) (add, remove []User)

    // Build the normalized, core-agnostic client config for one user+worker.
    RenderClientConfig(ClientTemplate, User, Endpoint) (normconfig.Proxy, error)

    // Generate the one-line worker install command for this protocol.
    InstallCommand(InstallParams) string
}
```

- Drivers self-register into a registry (`protocol.Register(driver)`); both
  binaries import the drivers they support.
- Management uses: `DefaultServerSettings`, `DefaultClientTemplate`,
  `RenderClientConfig`, `InstallCommand`.
- Worker uses: `RenderServerConfig` / `DiffUsers` against its backend.
- Adding AmneziaWG = one new package implementing `Driver` + the matching
  `VpnCore` translation on the client. No schema or UI changes beyond a protocol
  picker.

### 4.3 Normalized client config (core-agnostic)

`normconfig` is the wire contract between management and the client. It is
deliberately close to a Clash proxy entry (so mihomo translation is trivial)
but named generically.

```jsonc
{
  "version": 1,
  "account": { "display_name": "...", "status": "active", "expires_at": "..." },
  "locations": [
    {
      "id": "worker_<id>",
      "label": "Amsterdam #1",
      "proxy": {
        "type": "vless",
        "server": "1.2.3.4",
        "port": 443,
        "uuid": "<user-uuid>",
        "tls": true,
        "reality": { "public_key": "...", "short_id": "...", "server_name": "www.apple.com" },
        "flow": "xtls-rprx-vision"
      }
    }
  ]
}
```

The `proxy` object is whatever the protocol driver emits; the client's
`VpnCore` knows how to map each `type` to its native format.

---

## 5. Management service

### 5.1 Tech

Go (std `net/http` + a light router like `chi`), SQLite (`modernc.org/sqlite`,
pure-Go, no CGO → trivial Docker build), `golang-migrate` or embedded SQL
migrations, JWT (`golang-jwt`), bcrypt for passwords. React + Vite + TypeScript
for the SPA, built and embedded with `go:embed`.

### 5.2 Bootstrap & install

- **Production (HTTPS built-in, no owned domain needed):** set `TLS_DOMAIN` to
  an sslip.io name derived from the VPS IP and expose ports 80+443:
  `docker run -v vpn-data:/data -p 80:80 -p 443:443 -e TLS_DOMAIN=38-99-23-137.sslip.io -e PUBLIC_URL=https://38-99-23-137.sslip.io vpn-management`.
  The service obtains + renews a Let's Encrypt cert via ACME (autocert, cached
  in `DATA_DIR/certs`); port 80 serves the HTTP-01 challenge and redirects to
  HTTPS. Requires port 80 reachable from the internet.
- **Local dev (plain HTTP):** `docker run -v vpn-data:/data -p 8080:8080 vpn-management`
  (no `TLS_DOMAIN`). autocert can't issue a cert for localhost, so this is the
  way to run/test without a public domain.
- On first start: create DB, run schema, generate admin `username` + random
  password, print them once to stdout and persist a marker so it is not
  regenerated. Configurable via env (`ADMIN_USERNAME`, `ADMIN_PASSWORD`) to skip
  random generation.
- Config via env: `TLS_DOMAIN` (enables HTTPS when set), `LISTEN_ADDR` (dev HTTP
  port when `TLS_DOMAIN` unset), `DATA_DIR`, `PUBLIC_URL` (used in worker
  install commands), `JWT_SECRET` (generated + persisted if absent).

### 5.3 API surface

All JSON. Three logical groups, separated by auth type.

**Admin API** (`/api/admin/*`, requires admin JWT)
- `POST /api/admin/login` → `{ token }`
- Users: `GET /users` (search via `?q=`), `POST /users`, `GET /users/{id}`,
  `PATCH /users/{id}` (edit, set status, set `expires_at`), `DELETE /users/{id}`.
- User-lists: `GET /user-lists` (`?q=`), `POST`, `GET/{id}`, `PATCH/{id}`,
  `DELETE/{id}`; manage attached workers via the list payload.
- Workers: `GET /workers` (`?q=`), `POST` (returns generated install command),
  `GET/{id}`, `PATCH/{id}` (edit name/label/`client_template`), `DELETE/{id}`,
  `POST /workers/{id}/install-command` (regenerate).
- Search is a simple `LIKE` over the relevant name fields per resource.

**Client API** (`/api/client/*`, requires user JWT)
- `POST /api/client/login` `{ server is implicit, username, password }` → `{ token, account }`.
- `GET /api/client/config` → normalized config bundle (§4.3). Computed live:
  current status, non-expired, only workers from the user's list that are
  `online`. **This is the endpoint the client calls before every connect.**

**Worker API** (`/api/worker/*`, requires worker token)
- `POST /api/worker/enroll` `{ enrollment_token }` → `{ worker_token, server_settings }`.
  One-time; marks worker enrolled, issues a long-lived worker token.
- `POST /api/worker/heartbeat` `{ metrics, agent_version }` → `{ ok, config_version }`.
- `GET /api/worker/users` → desired user set for this worker (active,
  non-expired users whose user-list includes this worker) with their protocol
  credentials. Returns an ETag/`config_version` so the worker only reconciles on
  change.

### 5.4 Validation & errors

- Consistent error envelope `{ "error": { "code", "message" } }`.
- Usernames unique; passwords min length; `expires_at` must be future on set.
- Deleting a user-list with attached users is blocked (or reassigns) — MVP:
  block with a clear error.

---

## 6. Worker service

### 6.1 Tech & responsibilities

Go binary in a Docker image that also contains **Xray-core** (the VLESS+Reality
backend). The worker:
1. On first run, calls `/api/worker/enroll` with the baked-in enrollment token,
   receives its `server_settings`, writes the Xray config, starts Xray.
2. Loops: `POST /heartbeat` (report metrics, learn `config_version`), and when
   the version changed, `GET /users`, reconcile, apply.
3. Reconciles desired vs actual users via the protocol driver
   (`DiffUsers` → add/remove client UUIDs through the Xray gRPC API, falling
   back to config rewrite + reload).

### 6.2 Backend abstraction

`worker/internal/backend` wraps the actual VPN engine behind a small interface
(`Apply(serverConfig)`, `AddUser`, `RemoveUser`, `Stats`). The Xray
implementation is the only one for MVP. This mirrors the protocol seam so a new
protocol's engine drops in cleanly.

### 6.3 Metrics (kept minimal)

Heartbeat payload: `agent_version`, `uptime_s`, `active_conns` (best-effort),
`bytes_up`/`bytes_down` (best-effort from Xray stats API), `backend_healthy`.
Management stores latest + derives `online`/`offline` (offline if no heartbeat
for `> 3× interval`).

### 6.4 Install command

Generated by the protocol driver via management, e.g.:

```bash
docker run -d --name vpn-worker --restart unless-stopped \
  --network host \
  -e MGMT_URL=https://panel.example.com \
  -e ENROLLMENT_TOKEN=<one-time-token> \
  vpn-worker:latest
```

The worker self-configures from these two env vars; everything else comes from
enrollment.

---

## 7. Client app (Flutter, macOS first)

### 7.1 Tech

Flutter 3.x. State management: `riverpod` (simple, testable). Secure storage of
tokens via `flutter_secure_storage` (Keychain on macOS). HTTP via `dio`.

### 7.2 Screens / flows

1. **Login** — fields: server address, username, password (like a corporate
   messenger). Stores `server URL + token` on success.
2. **Locations** — list of locations from `/api/client/config`; shows
   account status + expiry; lets the user pick a location.
3. **Connection** — connect/disconnect for the selected location, live status
   and (if available) up/down stats.
4. **Account** — display name, status, expiry, server address, logout.

### 7.3 Connect sequence (enforces the invariant)

```
tap Connect
  → fetch /api/client/config            (always, fresh)
  → if status != active → show message, stop
  → VpnCore.load(config)                (translate + load into core)
  → VpnCore.connect(selectedLocationId)
  → reflect VpnStatus stream in UI
```

### 7.4 macOS specifics

- **MVP (implemented): proxy mode.** `MihomoCore` runs the bundled mihomo
  binary as a subprocess exposing a local SOCKS/HTTP proxy and sets the macOS
  system proxy at it (best-effort via `networksetup`). This tunnels apps that
  honor the system proxy — not a full system-wide VPN — but exercises the entire
  pipeline (management → worker → client → mihomo) end to end. The dev build
  disables the app sandbox so the app can launch mihomo and run `networksetup`.
- **Production path (later): Network Extension** (`NEPacketTunnelProvider`) with
  mihomo linked as a Go c-archive, capturing all traffic, behind the **same
  `VpnCore` seam** — no screen/state changes. Requires the paid Apple Developer
  account (available) for the `networking.networkextension` entitlement +
  signing. This is the chosen production design (TUN+privileged-helper was
  considered and rejected).
- Other platforms (iOS/Android/Win/Linux) reuse everything above the `VpnCore`
  seam; only a new `VpnCore`/platform-channel implementation is needed later.

---

## 8. Security notes (MVP-appropriate, not over-built)

- All control-plane traffic over HTTPS (admin runs management behind TLS; the
  install command assumes `https://`).
- Passwords hashed with bcrypt. JWTs signed with a persisted secret; reasonable
  expiry + refresh-on-use for client tokens.
- Enrollment tokens are single-use and stored hashed; worker tokens are
  long-lived but revocable by deleting/rotating the worker.
- Reality private keys never leave management → worker; client only ever gets
  the public material it needs.
- No secrets in logs except the one-time admin bootstrap credentials.

---

## 9. Delivery plan (incremental, vertical slices)

Each milestone is shippable and demoable.

- **M0 — Skeleton & contracts.** Repo layout, Go workspace, `shared/protocol`
  interface + `vless-reality` driver stub, `normconfig` model, DTOs. SQLite
  schema + migrations.
- **M1 — Management core + admin auth.** Bootstrap admin, JWT, users CRUD +
  statuses + expiry, user-lists, workers CRUD with generated install command.
  Minimal React panel (login + the four list/detail screens) embedded.
- **M2 — Worker provisioning loop.** Worker enroll → run Xray VLESS+Reality →
  heartbeat → pull users → reconcile. Management worker API + online/offline.
- **M3 — Client config endpoint + Flutter app (macOS).** `/api/client/login` +
  `/api/client/config`, `VpnCore`/`MihomoCore`, login → locations → connect,
  re-fetch-before-connect.
- **M4 — Polish.** Search everywhere, edit/delete flows, metrics display, error
  states, Docker images for management + worker, docs.

---

## 10. Open items to confirm during implementation

- macOS tunnel mechanism (Network Extension vs managed TUN) — choose inside
  `MihomoCore`; does not affect the spec.
- Network Extension implementation (later milestone): gomobile/c-archive build
  of mihomo, Swift `NEPacketTunnelProvider`, app↔extension IPC, signing.
- Bundle mihomo as a **signed executable** in the app bundle
  (`Contents/Resources/` via an Xcode Copy Files phase) and run it in place,
  instead of the current MVP stopgap (Flutter asset extracted to app-support at
  runtime + `chmod +x`). Remove the asset entry and `_extractBundledBinary`.
- mihomo packaging on macOS (notarization) for distribution.

**Resolved:** a user belongs to exactly one user-list (§3.1). Reality
`dest`/SNI default = `www.microsoft.com:443`, admin-editable (§3.1 Worker).
macOS tunnel: proxy-mode MVP now, Network Extension for production (§7.4); paid
Apple Developer account available. Reality dest default = `www.apple.com`
(www.microsoft.com fails the handshake). Client engine must be mihomo **Alpha**
(stable 1.19.x incompatible with Xray 26.x Reality).
