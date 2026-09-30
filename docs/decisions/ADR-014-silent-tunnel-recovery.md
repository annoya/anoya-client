# ADR-014: A tunnel that stops answering is healed by reloading the engine on its own config

## Status

Accepted

## Date

2026-09-30

## Context

A macOS tunnel survived a night of sleep and came back dead. From the engine
log: the last byte from the server arrived during a dark wake at 07:35; from
the next dark wake at 07:53 until the user reconnected at 11:11 the engine
completed about 17 000 REALITY handshakes with the same server, wrote the
request on every one of them, and read nothing back. DNS, dialled directly,
kept answering, so the machine looked online. A reconnect with the same config
worked within four seconds.

Nothing in the extension reacted: the provider had no `sleep`/`wake` handling,
and mihomo's own reaction to a network change — flushing the interface cache
and the resolver's connections when the default interface changes — never fired,
because the interface was `en0` before and after.

What exactly went stale inside the engine is not known. What is known is that
rebuilding the engine's state on the unchanged config cured it, and that the
reconnect that did so is itself a leak (ADR-002, ADR-004).

## Decision

**Recovery is the switch path with the running config.** `engine.Recover`
re-applies the last config that was applied successfully, on the same fd, and
closes the tracked connections — exactly what a location switch does. No
`stop`/`start`, no `setTunnelNetworkSettings`. The log level is restored
afterwards, because applying a config overwrites it from the YAML.

**Two triggers.**

- `wake()` in the packet-tunnel provider, three seconds after the system
  resumes, so the physical interface has settled.
- A watchdog inside the engine, for everything `wake()` does not see — the
  failure above began during a dark wake, with the lid still closed.

**The watchdog judges only connections through `PROXY`, and only by bytes that
came back** (ADR-010). Once a second it samples the trackers whose chain holds
the group. A connection that sent something and got nothing within 5 s, or
closed without a single byte back, is unanswered. The tunnel is stalled when
nothing at all came back through `PROXY` for 15 s *and* at least 5 connections
went unanswered in that window. An idle tunnel, a tunnel with one dead
destination among live ones, and a machine without network (the dial fails, so
no tracker exists) are not stalls.

**It backs off.** After a recovery the next one waits at least a minute, then
doubles up to ten; any byte back resets the wait. A server that is really dead
gets a reload every ten minutes and a line in the log each time, not a loop.

## Invariants

- Recovery never stops the engine or re-applies the network settings; it is
  `reload` with the config the engine already runs.
- Only connections whose chain contains `PROXY` are watched; DIRECT traffic
  never keeps a dead proxy looking alive. Pinned by
  *TestOnlyConnectionsThroughTheProxyAreWatched*.
- Upload alone never counts as an answer. Pinned by the detector tests in
  `engine/watchdog_test.go`.
- `Recover` refuses when nothing is running
  (*TestRecoverWithoutARunningEngineRefuses*), so a wake after a stop cannot
  start anything.

## Alternatives Considered

### `MihomoStop` + `MihomoStart` on the same fd

Rejected: `Stop` re-creates the TUN listener empty, and sing-tun closes the
file it was given — the packet flow's own socket. The utun goes away, the
routes go with it, traffic leaves on `en0`, and the `Start` that follows gets a
dead fd.

### Restart the tunnel session (`cancelTunnelWithError`, reconnect)

Rejected: the routes are gone between stop and start. That is the reconnect
leak ADR-002 closes for switching, and the watchdog would reopen it
automatically, possibly every few minutes.

### Close connections only (sing-box's `ResetNetwork`)

Rejected as not enough on the evidence: every connection in the failed window
was new, and every one of them died. What cured it was rebuilding the engine's
state, so that is what recovery does.

### Trigger on `NWPathMonitor` as well

Not done: the observed failure had no path change to trigger on, and the
watchdog covers path changes that do break the tunnel. Can be added on the
same `Recover` if a network switch is ever seen to need it.

### Probe with `URLTest` when traffic looks silent

Rejected: a request to a third-party host the user did not ask for (ADR-010),
and it has false negatives. The user's own connections are already the probe.

## Evidence

From the engine log of the night that motivated this, per dark wake:

| minute | handshakes | reads from the server |
|---|---|---|
| 07:35 | 25 | 43 |
| 07:53 | 310 | 0 |
| 10:46 | 1814 | 0 |
| 11:10 | 3027 | 0 |
| 11:11 (after reconnect) | 1743 | 340 |

Recovery on a live stall has not been observed yet; the first `[watchdog]`
line after `[recover]` in a real log is what confirms that a reload is enough.

## Consequences

- A recovery closes every proxied connection, like a switch. They were not
  getting answers anyway.
- A recovery re-parses the config and re-reads local geo files; the engine
  still fetches nothing (AGENTS.md invariant 7).
- The watchdog lives in the engine, so Android and the Windows service run it
  too. It is the same reload those platforms already use for switching, but it
  has only been exercised on macOS.
- If the stale state is ever somewhere a reload does not rebuild, the watchdog
  will keep reloading on its back-off and the log will show it.

## Where It Lives

- `native/mihomocore/engine/watchdog.go` — the detector and its loop.
- `native/mihomocore/engine/engine.go` — `Recover`, the remembered config.
- `native/mihomocore/core.go` — `MihomoRecover`.
- `shared/apple/PacketTunnelProvider.swift` — `wake()`.
- Tests: `native/mihomocore/engine/watchdog_test.go`.
