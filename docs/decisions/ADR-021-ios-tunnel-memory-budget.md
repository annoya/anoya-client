# ADR-021: The iOS tunnel holds itself under the jetsam cap instead of being killed at it

## Status

Accepted

## Date

2026-10-19

## Context

iOS kills a packet tunnel extension that passes about 50 MiB of
`phys_footprint`. Apple gives that figure for iOS 16 and says it may change.
The kill comes without `stopTunnel`, on-demand starts a new process, and the
connection timer starts over.

The engine is Go. By default the Go heap may grow to twice its live size before
a collection, and memory freed by the collector goes back to the system late.
Neither mihomo nor our engine set any limit, so nothing slowed the extension down
before iOS stopped it.

## Decision

- **Low-memory build on iOS.** The iOS slices of `MihomoCore.xcframework` build
  with mihomo's `with_low_memory` tag, which halves its relay buffers (TCP
  32 → 16 KB, UDP 16 → 8 KB). macOS has no cap and keeps the standard build.
- **A budget the engine knows.** On iOS the provider passes 50 MiB to
  `engine.SetMemoryBudget`. The Go soft limit becomes ¾ of it, so the collector
  works harder as the heap nears 37.5 MiB.
- **Pressure frees memory.** On iOS's critical memory-pressure event the
  provider calls `engine.ReleaseMemory`: memory goes back to the system, and the
  tunnel log records what it was made of — Go total, heap, stacks, heap held for
  reuse, goroutines, TCP and UDP connections — and the footprint before and
  after.
- **The watchdog guards the line.** Once a second it reads `phys_footprint`:
  - within 10 MiB of the budget it returns memory to the system, at most every
    10 s;
  - within 5 MiB it closes every tracked connection and returns memory, at most
    every 30 s, and writes one line to the tunnel log.

  Losing the open connections is the price of keeping the tunnel and its timer.

## Invariants

- Without a budget the guard does nothing, whatever the footprint
  (*TestMemoryGuardStaysOutWithoutABudgetOrAReading*). macOS, Android and the
  desktop service never set one.
- The guard releases before it sheds and does not repeat either within its pause
  (*TestMemoryGuardStepsUpOnlyNearTheBudget*).
- The Go soft limit is ¾ of the budget and is removed with it
  (*TestMemoryBudgetSetsTheGoSoftLimitToThreeQuarters*).

## Alternatives Considered

### Restart the engine at a footprint threshold

Rejected. A restart drops every connection just as shedding does, and adds a
full engine start on top. meow-ios shipped a restart at 40 MB and later removed
it.

### Cap TCP and UDP sessions, as the ProjectClash fork does

ProjectClash/Clash adds limits of 416 TCP connections and 128 UDP sessions under
`with_low_memory`. Not taken for now: it needs patches inside mihomo's tunnel,
and the pressure log will show whether connection count is what fills the
budget.

### `SetGCPercent(10)` as in sing-box

sing-box pairs a 30 MiB soft limit with GC at 10%. Not taken: the soft limit
alone already makes the collector work hard near the budget, and a permanent
10% costs CPU on every allocation even when memory is low.

## Evidence

The Oct 12–18 iPhone logs: 33 extension processes ended without `stopTunnel`,
each right after `memory pressure: critical` at about 40 MB. A fresh extension
starts at about 10 MB and reached 40 MB in 1–5 minutes. On Oct 18 between 12:29
and 13:09 UTC it was killed nine times in a row.

## Consequences

- Near the budget, open connections are closed; apps reconnect on their own.
- The 50 MiB figure is a constant. If Apple changes the cap, it has to be
  changed by hand.
- What fills the memory is still unknown; the first pressure lines from a device
  will say.

## Where It Lives

- `native/mihomocore/engine/memory.go`, `footprint_darwin.go` —
  `SetMemoryBudget`, `ReleaseMemory`, `memoryGuard`
- `native/mihomocore/engine/watchdog.go` — the once-a-second check
- `native/mihomocore/build-xcframework.sh` — `IOS_TAGS`
- `shared/apple/PacketTunnelProvider.swift` — `jetsamBudget`,
  `startMemoryPressureLog`
- `native/mihomocore/engine/memory_test.go`
