# Architecture Decision Records

One record per feature, not per micro-decision: everything decided while
building a thing belongs in that thing's ADR, including the options that were
tried and dropped.

Records are numbered in one sequence and kept in one folder, including the two
that span both products — a decision about the boundary between them belongs to
neither side alone. The **Product** column is how you filter.

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
| [007](ADR-007-worker-enrollment-and-self-recovery.md) | service | Reusable enrollment tokens so a worker recovers itself | why not single-use, rotation as revocation, what to revisit before production |

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
