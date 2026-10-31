# ADR-023: Configurations live in the platform keychain, with their keys

## Status

Accepted

## Date

2026-10-24

## Context

A configuration holds everything needed to connect: server addresses, VLESS
UUIDs, Hysteria2 and obfs passwords, AmneziaWG private and pre-shared keys, and a
subscription URL that is itself a bearer secret. These sat in a plain
`profiles.json`, while the Amnezia API key and the self-hosted token sat in the
keychain. Two stores drifted apart: a restored Android backup brought the file
back without the Keystore key, and the app showed a subscription that "lost its
key".

The keychain on Apple also answered `-25308` while the screen was locked: the
default accessibility is "when unlocked", and the hourly refresh runs during
dark wakes.

## Decision

- **The configuration list is one secure document.** `ProfileStore` keeps
  `profiles` through `SecretStore` (`SecureJsonStore`): the Keychain on Apple,
  the Keystore on Android, the DPAPI-encrypted store on Windows, the Secret
  Service on Linux, and on a Linux desktop without one the 0600 file of
  ADR-017. Tokens and Amnezia keys stay in the same store, so a configuration
  and its key are restored or lost together.
- **Readable after the first unlock, on this device only.** Apple items use
  `first_unlock_this_device`, as WireGuard's do: the overnight refresh works
  with the screen locked, and nothing syncs through iCloud Keychain behind
  ADR-020's sealed recipes.
- **An unreadable store is never overwritten.** If the read fails, the list
  loads empty and every save refuses until a read succeeds, so a locked or
  broken keychain cannot be replaced by an empty list.
- **A write that the keychain refuses is retried as delete-and-add**, which
  also replaces an item created with another accessibility.
- Rule sets, favorites, the selection and preferences stay plain JSON files:
  they hold no secrets.
- **The tunnel's copy on Apple is a keychain item too.** The rendered engine
  config, which on-demand starts read without the app, is a generic-password
  item in the access group the app and the extension share, with the same
  accessibility. The VPN profile's `providerConfiguration` carries only
  non-secret flags: on macOS it lands in a system plist every local user can
  read. This is how WireGuard keeps its tunnel config.
- **The tunnel's copy on Android stays out of backups.** `files/engine/`
  (`last_config.yaml` and the engine logs) is excluded from Auto Backup and
  device transfer.

## Invariants

- No server secret reaches the app's data directory
  (*a configuration lives in the keychain and never touches the disk*).
- A failed read never turns into an empty save
  (*a keychain that could not be read is never saved over*).

## Alternatives Considered

### Everything as plain JSON in the app sandbox

What WireGuard on Android and sing-box on iOS do. Rejected: secrets would rely
on the sandbox and disk encryption alone, and Android Auto Backup would carry
them to a cloud backup.

### `profiles.json` encrypted with a key from the keychain

What AmneziaVPN does with its server list. Rejected: one more moving part for
the same outcome — the data is only as available as the keychain key — and it
does not encrypt anything on Linux without a keyring, where AmneziaVPN stores in
the clear.

## Consequences

- Android's secure storage resets on a key it cannot decrypt, so a restored
  backup comes back with no configurations rather than half of each.
- Keychain items written before this change with the old accessibility are not
  found; there was no release, so there is no migration.
- The tunnel keeps its own copy of the selected server: the keychain item on
  Apple, `last_config.yaml` elsewhere.

## Where It Lives

- `lib/core/json_file_store.dart` — `SecureJsonStore`
- `lib/core/profile_store.dart`, `lib/core/secret_store.dart`
- `shared/apple/TunnelConfigStore.swift`
- `test/secure_profiles_test.dart`, `test/support/memory_secrets.dart`,
  `test/flutter_test_config.dart`
