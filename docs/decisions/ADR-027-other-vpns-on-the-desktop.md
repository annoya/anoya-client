# ADR-027: On the desktop, DNS protection is the user's choice and off by default; an AWG config's networks are server routing

## Status

Accepted. Replaces the `strict-route` part of ADR-008.

## Date

2026-10-30

## Context

Business users run a corporate VPN (NetBird, Cisco, OpenVPN) next to Anoya on
Windows. With Anoya connected, corporate resources stopped opening.

- `strict-route` was always on where the engine owns the device (Windows,
  Linux). On Windows sing-tun then installs WFP filters that block port 53 on
  every adapter except ours and the engine's own process. A corporate VPN
  resolves its names on its own adapter, so those lookups were blocked.
- ADR-008 turned it on to stop Windows asking the provider's resolver in
  parallel (Smart Multi-Homed Name Resolution). That was reasoned, not
  measured. Fake-ip answers from the engine come back first, so what the
  filters prevent is the provider seeing the names, not wrong answers.
- Clash Verge Rev, FlClash and Mihomo Party ship `strict-route` off. sing-box
  warns it can break other software on Windows.
- Amnezia's business customers point an AWG server at only some networks
  (`allowed_ips`) so other VPNs keep their traffic. We ignored the field: every
  AWG config was a full tunnel.

## Decision

- **DNS protection is a switch** under Settings → Advanced on Windows and
  Linux, off by default. On renders `strict-route: true`; off omits it. The note
  under it says what each side costs. Switching is a hot reload.
- **`allowed_ips` from an AWG config is server routing.** Anything other than
  `0.0.0.0/0` becomes provider routing: split, one `ip-cidr → proxy` rule with
  those networks (a bare address gets `/32` or `/128`; a list or a comma string
  is read; invalid entries are skipped and logged). The user sees and switches
  it like a subscription's routing. It is replaced on every issued server.
- **An explicit rule about a private subnet beats Local network direct.**
  `ip-cidr` values inside the LAN ranges go before the LAN rules, in their own
  order; the rest of the routing stays after. Otherwise a server routing
  `10.20.0.0/16` would be silently overridden.

## Invariants

- No `strict-route` unless asked for — `test/mihomo_tun_config_test.dart`
  (*leaves other adapters' DNS alone unless protection is on*).
- The switch exists only where the tunnel is ours, and starts off —
  `test/connection_check_test.dart` (*the screen*).
- A full tunnel brings no routing; a network list routes only those networks —
  `test/amnezia_config_test.dart` (*an AWG location*).
- Private subnets named by a rule are not swallowed by LAN direct —
  `test/routing_v2_test.dart` (*local network direct*).

## Alternatives Considered

### Keep protection on, add exceptions for corporate domains and subnets

Not chosen as the first step. Subnets would be `route-exclude-address`, but
corporate names still need the corporate resolver, which the WFP filters
block for everyone but the engine, and the engine binds its dials to the
physical adapter. Making it work means naming the adapter per resolver or
forking sing-tun to permit port 53 to excluded addresses. It may still come
on top of the switch.

### Turn protection off only for configs that are not a full tunnel

What WireGuard for Windows does. Rejected as the only rule: with a
subscription's or the user's routing, every packet still enters the tun, so
the corporate VPN breaks the same way.

### `allowed_ips` as tun `route-address`

Closer to WireGuard: other traffic would never reach the engine. Not chosen:
it is a second split mechanism next to routing, invisible in the routing UI,
and fake-ip addresses would need their own route. With protection off, a
corporate VPN's own routes and resolver are expected to keep working; not yet
checked on Windows with NetBird.

## Consequences

- With protection off, the provider's resolver may see the names the user
  looks up on Windows. Not measured how often.
- Corporate names still resolve only through the corporate VPN's own DNS;
  Anoya has no per-domain resolver for them.
- Gateway keys only: a `vpn://` key carrying a self-hosted AWG config is still
  not imported.

## Where It Lives

- `lib/core/routing_prefs.dart` — `dnsProtection`, `withLanDirect`, `withinLan`.
- `lib/core/mihomo_tun_config.dart` — `strictRoute`.
- `lib/core/network_extension_core.dart`, `lib/core/effective_config.dart`.
- `lib/features/advanced_connection_screen.dart`, `settings_screen.dart`.
- `lib/core/amnezia/secondary_config.dart` — `allowedIpsRouting`.
- `lib/core/amnezia/amnezia_source.dart` — routing set on issue.
