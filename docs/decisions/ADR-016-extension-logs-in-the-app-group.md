# ADR-016: The tunnel's logs live in the App Group, readable with the tunnel down

## Status

Accepted. Supersedes the logging invariant of ADR-001.

## Date

2026-10-03

## Context

On Apple the extension kept `tunnel.log` and `mihomo.log` in its own caches
directory and handed them to the app over `sendProviderMessage`. The extension
exists only while the tunnel runs, so the logs were unreadable exactly when they
matter: after the tunnel dropped, when iOS killed the extension for memory, or
whenever the user was disconnected. Reading or clearing then sat out the 10 s
IPC timeout and failed.

ADR-001 kept the logs off the shared container because reaching an App Group
container on macOS popped a TCC prompt. That held while the extension was
signed with the team's wildcard profile. Both macOS profiles
(`org.annoya.test`, `org.annoya.test.tunnel`, development and App Store) and
both iOS ones now name `group.org.annoya.test` explicitly, which is what macOS
requires to skip the prompt. The app already reads and writes that container
for geo databases and rule lists, and the extension uses it as the engine's
home.

## Decision

- The extension writes both logs to `<App Group>/logs/` (raw POSIX writes, as
  before). Its caches directory is only a fallback if the container is missing.
- The app reads the last 512 KB of each log and truncates them itself, in
  `VPNManager`, with no IPC and no dependence on the tunnel's state.
- A log over 4 MB is halved when read — the engine's stdout has no other
  rotation point.
- Clearing truncates, never unlinks: the extension's stdout is `freopen`'d onto
  `mihomo.log` in append mode.
- The `log:<name>` and `clear-logs` provider messages are gone.

## Invariants

- The extension never unlinks a log; the app never unlinks one either.
- Reading logs never waits on the extension.
- Both provisioning profiles of each platform list `group.org.annoya.test`. A
  profile without it brings the TCC prompt back on macOS.

## Alternatives Considered

### Snapshot the logs over IPC when the tunnel starts stopping

No signing change. Rejected: when iOS kills the extension for memory — the most
likely way a tunnel dies on a phone — there is no stopping phase and no
snapshot.

### Defer a clear to the extension's next start

Tried as a stopgap: the clear was written into the VPN profile and applied at
the next start. Rejected once the logs moved: it fixed clearing but left the
logs unreadable while disconnected.

## Consequences

- Logs written by older builds stay in the extension's caches directory until
  the system purges it.
- Android already shared files between the app and the service and is
  unchanged. Windows and Linux read through the desktop service and are
  unchanged.

## Where It Lives

- `shared/apple/PacketTunnelProvider.swift` — `logDir`, `log`,
  `redirectStdoutToMihomoLog`
- `shared/apple/VPNManager.swift` — `fetchLog`, `clearLogs`,
  `halveIfOversized`
- `macos/Tunnel/Tunnel.entitlements`, `ios/Tunnel/Tunnel.entitlements`
