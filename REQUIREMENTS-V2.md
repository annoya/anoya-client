# v2 Requirements — "Grown-up" Release

> Status: draft for discussion · Owner: vk@amnezia.org · Last updated: 2026-07-01
>
> Positioning: **self-hosted VPN for small companies.** The admin is an IT
> person provisioning employees; users are non-technical staff. This drives
> priorities: central policy control, painless onboarding, visibility — not
> billing or reselling.
>
> References studied: [Marzban](https://github.com/Gozargah/Marzban) (user
> lifecycle model), [3x-ui](https://github.com/MHSanaei/3x-ui) (per-client
> limits & traffic accounting), [Happ](https://www.happ.su/main/dev-docs/routing)
> (remotely-delivered routing rules).

---

## 1. Split tunneling (flagship feature)

Configured centrally on management, delivered to clients with the config
bundle. If the server defines no policy, the client may configure rules
locally.

### 1.1 Model

A **routing profile** attached to a user-list (teams get different policies).

- `mode`:
  - `full` — everything through VPN, rules list exceptions (`direct`).
  - `split` — only matching traffic through VPN, the rest goes direct
    (typical corporate: "only internal resources via VPN").
- `rules`: ordered list, first-match-wins (same semantics as Happ/mihomo):
  - `type`: `domain-suffix` | `domain-keyword` | `domain-exact` | `ip-cidr` |
    `process-name` (desktop only)
  - `action`: `proxy` | `direct` | `block`
- Profile present ⇒ **managed**: client applies it and shows a read-only
  "Managed by your organization" view. Profile absent ⇒ client-local rules
  editor is enabled (persisted on device, same schema).

### 1.2 Delivery & rendering

- normconfig gains an optional `routing` section; the client core translates
  it to mihomo rules (`DOMAIN-SUFFIX`/`IP-CIDR`/`PROCESS-NAME`/`MATCH`).
  The `VpnCore`/`ProtocolDriver` seams stay untouched.
- Admin API: CRUD for routing profiles + assignment to user-lists; simple
  rules editor in the panel (table + mode toggle), validation server-side.

### 1.3 Platform constraints (accepted)

- **iOS**: no per-app rules (process invisible to the tunnel) — domain/IP
  rules only. Per-app is desktop-only (macOS/Windows via `process-name`).
- macOS `process-name` requires mihomo `find-process-mode` on; verify it does
  not re-introduce TCC prompts before shipping (extension is sandboxed).

## 2. Control service — user management

Adopt the Marzban lifecycle model (industry standard, admins understand it):

- **Statuses**: `active | disabled | limited | expired | on_hold`.
  `limited` (quota exhausted) and `expired` (date passed) are distinct and
  set automatically; `on_hold` = expiry starts counting from first connect
  (pre-provisioned employees).
- **Per-user fields**: `data_limit`, `used_traffic`, `reset_strategy`
  (`no_reset | month`), `expire_at`, `note`, `online` / `last_online`.
- **Traffic accounting**: worker enables Xray `stats`+`api`, tags clients by
  email, queries `user>>>{email}>>>traffic>>>uplink|downlink` deltas each
  heartbeat and reports them; management aggregates and enforces statuses.
- **Onboarding**: invite link / QR that pre-fills server address + login in
  the client (corporate-messenger style first run).
- Bulk actions (disable/extend), reset usage, usage chart per user.

## 3. Control service — access & operations

- **User-list ↔ workers binding**: which lists see which locations
  (departments → servers). Today all online workers are visible to everyone.
- **TLS out of the box**: sslip.io + Caddy (or built-in autocert) — corporate
  credentials must not travel over plain HTTP. Docs + compose file.
- **Multi-admin + roles** (owner / admin / viewer), then **audit log**
  (who created/disabled/edited what, when).
- **Alerts**: webhook (and optional Telegram) for worker offline, user
  auto-disabled, cert renewal failure.
- **Backup/restore**: one-command SQLite snapshot + restore path.
- Panel dashboard: workers health, online users, traffic totals.

## 4. Client

- **Split tunneling UI** (§1): managed read-only view / local editor.
- **On-demand + kill-switch** (task #24): auto-reconnect, block-outside-VPN
  toggle (NE `includeAllNetworks` on macOS/iOS).
- **Autostart & auto-connect** on login (per-device toggle).
- **Traffic stats** (task #26): up/down speed + session totals on Home.
- **Connectivity check**: post-connect probe (captive "am I really out via
  the worker" check) + latency per location in the picker.
- **Platforms next**: iOS (reuse NE + xcframework slices), then Windows
  (mihomo service + wintun; separate track).
- Config auto-refresh stays mandatory before every connect (already done).

## 5. Compatibility (optional, later)

- **Subscription URL** per user (clash/v2ray formats) so third-party clients
  (Happ, Streisand, etc.) work; includes revoke/rotate token. Useful when a
  platform build is not ready yet.

## 6. Explicit non-goals for v2

- Billing/payments, reseller tiers, multi-tenancy.
- Public node sharing, geo-balancing.
- Protocol zoo: VLESS+Reality stays the only driver until the above ships
  (the `ProtocolDriver` seam is the extension point when needed).

---

## 7. Proposed build order

| Phase | Scope | Why first |
|---|---|---|
| **v2.0** | Split tunneling end-to-end (§1) · user lifecycle + traffic accounting (§2) · TLS (§3) | The features a company actually buys; everything else decorates them |
| **v2.1** | On-demand/kill-switch + stats + connectivity check (§4) · list↔worker binding · alerts · audit log | Daily-driver quality + ops visibility |
| **v2.2** | Multi-admin/roles · backup UX · subscription URLs · iOS build | Team scale-out + second platform |
