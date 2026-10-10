# ADR-020: Configurations and settings sync through iCloud, sealed with a key from iCloud Keychain

## Status

Accepted

## Date

2026-10-08

## Context

People run the app on an iPhone and a Mac and set it up twice: the same
subscription, the same rule sets, the same DNS default. Everything the app keeps
is a JSON file in Application Support plus a few Keychain items, so nothing
reaches the second device unless it is typed again.

What makes this non-obvious is what a configuration carries. A self-hosted
token, a `vpn://` key and a subscription URL are each enough to use someone's
VPN; on-demand rules name their home Wi-Fi. iCloud key-value storage is not
end-to-end encrypted unless the user turned on Advanced Data Protection, so
putting these there as they are hands them to Apple. And a configuration is
mostly not the user's data at all: one real subscription is 330 KB of servers
the provider will hand any device that asks, against a 1 MB quota for the whole
store.

## Decision

- **Apple only, opt-in, per device.** A switch in Settings → General, off by
  default, absent on Android, Windows and Linux. The switch itself is not
  synced. Without an iCloud account the row is dimmed and says so.
- **Transport: `NSUbiquitousKeyValueStore`.** One key per item, so concurrent
  edits of different things on two devices do not overwrite each other:
  `app` (language, log collection), `routing` (LAN direct, DNS
  default, geo database URLs and auto-update), `check` (connection check),
  `on_demand` (the rules), `favorites`, `rule_set.<id>`, `profile.<id>`. Within
  one key the last write wins.
- **Every value is sealed.** AES-256-GCM with the item's key as associated
  data, under one random 256-bit sync key stored as a synchronizable iCloud
  Keychain item — iCloud Keychain is end-to-end encrypted in every account
  configuration. The store's `key` entry holds the key's fingerprint.
- **The key is created once, by the first device.** A device without a key
  creates one only when the store is empty, and only after waiting 15 s for
  the store's first download — a new device sees an empty store before iCloud
  has filled it. A device whose key is missing or does not match the
  fingerprint waits for the Keychain, retrying every 30 s, and sends nothing.
  An item that does not open under the key is replaced by the local copy if
  there is one, and never treated as a deletion.
- **Three-way merge.** Each device keeps a digest of every item as it last
  agreed with iCloud. Against that base, a change on one side is sent or
  applied, an item gone on one side is deleted on the other, and when both
  sides changed iCloud wins. The base is dropped when the key's fingerprint
  changes, which also covers switching to another iCloud account.
- **A configuration travels as a recipe**: what another device cannot fetch
  by itself. Type, name, server URL and token, subscription URL, the `vpn://`
  key and the service it names, the routing choices (rule set, the routing and
  provider-routing switches, refresh interval) — and the servers themselves
  only for a pasted link or pasted subscription, which have no source to
  re-read. The receiving device fetches everything else as a refresh.
- **Per device, never sent:** the appearance — a phone in dark mode and a
  Mac in light are a choice per screen, not a setting to carry —, the active
  configuration and server, auto-connect, whether on-demand is armed or paused, disconnect-on-sleep, the
  device's hardware id, the gateway installation id and state, servers the
  Amnezia gateway issued, geo databases and their download time, logs.
- **Turning it on merges.** Configurations and rule sets from both sides end
  up on both; for the single-value items what is already in iCloud wins, so a
  new device adopts the set instead of overwriting it. Turning it off deletes
  nothing on either side. While on, deleting a configuration or a rule set
  deletes it everywhere.
- **Remote changes take the local path.** An arriving change is applied
  through the same controller method a local edit uses, so a change to the
  active configuration or its rule set is a hot reload under the standing
  session (ADR-002), and a failed one leaves the tunnel running (invariant 5).

## Invariants

All pinned by `test/cloud_sync_test.dart`.

- Nothing is written to the key-value store unsealed, and a value does not
  open under another item's key or another sync key.
- Servers the Amnezia gateway issued and a subscription's fetched servers
  never appear in a recipe.
- Turning sync off removes nothing locally or remotely.
- An item that does not open is never read as a deletion.
- An arriving change to the running configuration reloads it and never stops
  the tunnel.

## Alternatives Considered

### Key-value storage without our own encryption

The obvious version. Rejected because without Advanced Data Protection Apple
holds the keys to that store, and what would sit in it is tokens, keys and
subscription URLs.

### CloudKit private database with encrypted fields

End-to-end encrypted fields and far more room. Rejected because it needs a
container, a schema deployed to production and a sync engine to drive it —
several times the native code — for data that fits in key-value storage once
fetched servers are left out.

### Everything in iCloud Keychain

End-to-end encrypted with no extra code. Rejected because the Keychain gives
no notice of a change from another device and is meant for small secrets, not
rule sets with thousands of values. It carries the one key instead.

### One file in iCloud Drive

Rejected because the whole file is one last-write-wins unit, so two devices
editing different things lose one edit, and file coordination adds more code
than the key-value store does.

### Syncing whole profiles

Rejected because servers fetched from a source are the provider's data, not the
user's, and one subscription alone is a third of the quota.

### Syncing the issued Amnezia servers

Rejected because the gateway binds an issued server to the key pair of the
device that asked for it; two devices on one WireGuard peer push each other
off.

### Syncing the active configuration and server

Rejected because it is a choice about this device, and a choice made on the
phone would hot-switch a tunnel running on the Mac.

## Consequences

- The App ID needs the iCloud capability with key-value storage, and both
  Runner targets the `com.apple.developer.ubiquity-kvstore-identifier`
  entitlement; provisioning profiles have to be regenerated.
- A configuration deleted on one device while another had sync off comes back
  when that device turns sync on again: the merge cannot tell "deleted there"
  from "added here".
- A key shared by more devices counts as more devices wherever the provider
  limits them — the same as typing it in on each.
- A device with iCloud Keychain turned off never receives the sync key and
  stays waiting; the switch row says so.
- Two devices that turn sync on for the very first time within the same few
  seconds can each create a key; whichever key the Keychain keeps, the other
  device waits on a fingerprint that never arrives. Not handled.
- Key-value storage delivers in seconds to minutes and stops at 1 MB; very
  large rule sets can run into the quota, which is logged.

## Where It Lives

- `lib/core/cloud_sync.dart` — recipes, sealing, the merge
- `lib/state/cloud_sync_controller.dart` — the switch, the key, applying changes
- `lib/core/json_file_store.dart` — `saved`, what tells sync a store changed
- `shared/apple/CloudSyncChannel.swift` — the key-value store bridge
- `ios/Runner/Runner.entitlements`, `macos/Runner/*.entitlements`
- `test/cloud_sync_test.dart`
