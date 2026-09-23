# Architecture Decision Records

One record per feature, not per micro-decision: everything decided while
building a thing belongs in that thing's ADR, including the options that were
tried and dropped.

Records are numbered in one sequence shared with the server side. The
service-only records (007, 011, 013) live in the
[annoya-web-panel](https://github.com/annoya/annoya-web-panel) repository; the
ones marked `both` are decisions about the boundary between the two products,
so they are
kept in both repositories and must be edited in both. The **Product** column is
how you filter.

Read the ADR for a subsystem before changing it. The **Alternatives Considered**
section is the point of the document — it is what keeps a settled question from
being reopened with the same wrong answer. The **Invariants** section is what a
test protects: if one of those tests fails, revisit the decision rather than the
test.

## Records

| # | Product | Decision | Covers |
|---|---|---|---|
| [001](ADR-001-system-tunnel-via-network-extension.md) | client | Tunnel as a Network Extension, engine linked in | why not a local proxy, App Group, entitlements, gVisor, TCC |
| [002](ADR-002-seamless-switching-without-leaks.md) | client | Switching by engine reload; nothing excluded from the tunnel | reload-only path, `IP_BOUND_IF` instead of excluded routes, ICMP forwarding, connection redial, leak evidence |
| [003](ADR-003-split-tunneling-model.md) | both | Split tunneling as rule sets, opt-in per configuration | managed vs local policy, LAN switch, geo databases, platform-gated rule types |
| [004](ADR-004-on-demand-and-the-kill-switch.md) | client | On-demand auto-connect; no kill switch | intent/paused/systemArmed, persisted config, why `includeAllNetworks` was rejected |
| [005](ADR-005-multi-configuration-client.md) | client | Three domains of authority: self-hosted, subscription, link | why not one backend, capability degradation, `ConfigSource`, refetch policy |
| [006](ADR-006-authentication-passwords-and-oidc.md) | both | Passwords plus generic OIDC, client-direct with PKCE | why not server-mediated, JIT provisioning, allowlists |
| [008](ADR-008-dns-rides-the-config.md) | both | DNS resolvers ride the config; the OS-level DNS setting is a decoy | dns-hijack + fake-ip, per-source resolvers, Cloudflare DoH fallback, sanitation, bootstrap, `Bundle.DNS` |
| [009](ADR-009-amnezia-subscriptions.md) | client | Key subscriptions as a fourth domain, with the gateway transport borrowed | `vpn://` codec, servers issued on demand, location × protocol, libagw, why no provider is named in the UI |
| [010](ADR-010-connection-check.md) | client | The app verifies the tunnel carries traffic, and never drops it over the answer | passive byte counters first, mihomo `URLTest` second, handshake warm-up, why not `external-controller` |
| [012](ADR-012-app-shell-per-platform.md) | client | The window closes to the menu bar or tray; the tunnel outlives the app | macOS menu bar split, Windows tray, window size, Android notification ask, log caps, Linux purge, APK naming |

## Open Questions

[OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) holds the decisions that are *not* made
yet — the ones the code reviews surfaced and left to a product, deployment or
timing call. It is the complement of the records above: an entry leaves that
file by becoming an ADR, not by being quietly implemented.

## Writing a New One

Copy the shape of an existing record:

```
# ADR-NNN: <what was decided, as a sentence>

## Status        Accepted / Superseded by ADR-NNN
## Date
## Context       what made this non-obvious
## Decision      what we do now, whole feature
## Invariants    what must never break, and what test pins it
## Alternatives Considered   each with "Rejected because…"
## Evidence      only when settled by measurement — with the numbers
## Consequences  costs, ruled-out options, known gaps
## Where It Lives   code and test paths
```

Superseding is normal: give the old record `Superseded by ADR-NNN` and leave it
in place. The history of a decision is often the most useful part — it shows
which cheap-looking alternative was already tried.
