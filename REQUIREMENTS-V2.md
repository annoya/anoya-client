# v2 Requirements — "Grown-up" Release (client)

> Status: draft for discussion · Owner: vk@amnezia.org · Last updated: 2026-07-01
>
> Positioning: **self-hosted VPN for small companies.** The admin is an IT
> person provisioning employees; users are non-technical staff. This drives
> priorities: central policy control, painless onboarding, visibility — not
> billing or reselling.
>
> This is the client half of the document. The server requirements — user
> lifecycle, traffic accounting, panel operations — live in the
> [annoya-web-panel](https://github.com/annoya/annoya-web-panel) repository's
> `REQUIREMENTS-V2.md`.
>
> References studied: [Happ](https://www.happ.su/main/dev-docs/routing)
> (remotely-delivered routing rules), [Marzban](https://github.com/Gozargah/Marzban)
> (user lifecycle model), [3x-ui](https://github.com/MHSanaei/3x-ui)
> (per-client limits & traffic accounting).

---

## 1. Split tunneling (flagship feature) — the client's half

Configured centrally on management and delivered with the config bundle. If the
server defines no policy, the client may configure rules locally.

### 1.1 What arrives

A **routing profile** attached to the user's list, with the same schema the
local editor uses:

- `mode`: `full` (everything through VPN, rules list `direct` exceptions) or
  `split` (only matching traffic through VPN — typical corporate: "only
  internal resources via VPN").
- `rules`: ordered, first-match-wins (same semantics as Happ/mihomo);
  `type` is `domain-suffix` | `domain-keyword` | `domain-exact` | `ip-cidr` |
  `process-name` (desktop only), `action` is `proxy` | `direct` | `block`.
- Profile present ⇒ **managed**: apply it and show a read-only "Managed by your
  organization" view. Profile absent ⇒ the local rules editor is enabled
  (persisted on device).

### 1.2 Rendering

- normconfig carries an optional `routing` section; the core translates it to
  mihomo rules (`DOMAIN-SUFFIX`/`IP-CIDR`/`PROCESS-NAME`/`MATCH`). The
  `VpnCore` seam stays untouched.
- Rule values are validated server-side too, and the two validations must stay
  in step — whatever the server accepts is interpolated into an engine config
  here.

### 1.3 Platform constraints (accepted)

- **iOS**: no per-app rules (process invisible to the tunnel) — domain/IP
  rules only. Per-app is desktop-only (macOS/Windows via `process-name`).
- macOS `process-name` requires mihomo `find-process-mode` on; verify it does
  not re-introduce TCC prompts before shipping (extension is sandboxed).

## 2. Client features

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
- **Onboarding**: the invite link / QR the panel issues pre-fills server
  address and login on first run (corporate-messenger style).

## 3. Explicit non-goals for v2

- Billing/payments, reseller tiers, multi-tenancy.
- Public node sharing, geo-balancing.

---

## 4. Proposed build order

| Phase | Client scope | Why first |
|---|---|---|
| **v2.0** | Split tunneling end-to-end (§1) | The feature a company actually buys; everything else decorates it |
| **v2.1** | On-demand/kill-switch + stats + connectivity check (§2) | Daily-driver quality |
| **v2.2** | iOS build | Second platform |

The server's phases for the same releases are in its own requirements file.
