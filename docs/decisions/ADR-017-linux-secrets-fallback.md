# ADR-017: On Linux without a keyring, secrets fall back to a file only the user can read

## Status

Accepted

## Date

2026-10-03

## Context

Secrets — self-hosted tokens, `vpn://` keys, the gateway's installation id and
state — go through `flutter_secure_storage`. On Linux that is libsecret, which
needs a Secret Service on the session bus (GNOME Keyring, KWallet, KeePassXC).
Bare window managers (i3, sway) and servers often have none, and a keyring can
be locked when the session started without a password. Saving then threw, and
signing in or importing a key failed with an error nobody could act on.

A Secret Service does not separate applications: any process of the same user
can ask an unlocked keyring for the secret. What it adds over a plain file is
encryption at rest.

## Decision

- `SecretStore` (`lib/core/secret_store.dart`) wraps `flutter_secure_storage`.
  Outside Linux it passes through and hides nothing.
- On Linux a keyring error on write sends the value to `secrets.json` in the
  app's data directory: file 0600, written through a 0600 temporary file and a
  rename, directory 0700. Reads try the keyring first, then the file.
- Once a keyring accepts a write again, the value's file copy is removed, and
  the file is deleted when empty.
- File writes are serialized, so a background save (the gateway state) cannot
  overwrite a concurrent one.
- The app says once per launch, as a toast, that sign-in data is in a file only
  this account can read.

## Invariants

- The file and its directory are never wider than 0600 / 0700 —
  `test/secret_store_test.dart`.
- A keyring failure outside Linux surfaces as an error, never as a file —
  `test/secret_store_test.dart`.
- A value is not left on disk once the keyring holds it —
  `test/secret_store_test.dart`.

## Alternatives Considered

### Require a Secret Service

What the app did. Rejected: it fails exactly the users who chose a minimal
desktop, and the message cannot tell them anything they can fix in the app.

### `systemd-creds --user`

Encrypts at rest with a host or TPM-bound key. Rejected for now: user scope
needs systemd 256, which Ubuntu 22.04/24.04 and Debian 12 do not ship.

### Keep secrets in the root `anoya-tunnel` service, checked by peer UID

The only option that protects against other users and can encrypt at rest
without a keyring. Rejected for now: a protocol, `SO_PEERCRED` checks and a
migration for a case the file already covers against other users.

### Encrypt the file with a key stored next to it

Looks like encryption and protects nothing. Rejected.

## Consequences

- Without a keyring, secrets are not encrypted at rest; full-disk encryption
  covers that, and other users are kept out by file permissions.
- The app's data directory becomes 0700 the first time the file is written,
  which also closes `profiles.json` to other users.

## Where It Lives

- `lib/core/secret_store.dart`, `lib/core/profile_store.dart`
- `lib/app.dart` — the toast
- `test/secret_store_test.dart`
