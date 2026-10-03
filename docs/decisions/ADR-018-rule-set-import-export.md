# ADR-018: Rule sets export in our format only; other apps' formats are migrated in

## Status

Accepted

## Date

2026-10-03

## Context

People move rule sets between their own devices and receive them from
providers and other users. The rules they already have come from Clash or
mihomo profiles, Shadowrocket and Surge configs, and Happ routing profiles.
Each of those formats covers a different subset of what our rule sets hold:
none of them carries rules by process together with lists and regex the way we
store them.

## Decision

- **Export is ours only.** A rule set leaves as Anoya JSON with a format
  version — a file (`<name>.anoya-rules.json`, through the share sheet or a
  save dialog), or the same JSON gzipped into `anoya://ruleset/add/<base64url>`
  for the clipboard and a QR code. Nothing is lost on the way out.
- **Import is a one-way migration.** Our format comes in as is; the others are
  converted into an ordinary rule set and no link to the source is kept.
  - Clash / mihomo rules and Shadowrocket / Surge `[Rule]` lines map type for
    type. `DIRECT` → direct, `REJECT*` → block, any other policy → proxy.
    `MATCH` / `FINAL` picks the direction; with neither, the direction is
    split, as an unmatched connection goes direct in Clash.
  - Happ: `BlockSites/BlockIp`, then `ProxySites/ProxyIp`, then
    `DirectSites/DirectIp` — proxy before direct, so an exception inside a
    country sent direct still wins. Xray prefixes become our types; a bare
    domain becomes a suffix rule. `GlobalProxy` picks the direction.
- **Every import shows a preview** with what was not carried over: DNS
  servers, geo database links, `RULE-SET` lines with a URL, rule types we do
  not run. Text that is none of the four formats is refused with a toast
  naming the formats we read.
- **Import always adds a new set.**
- **One QR code or none.** A set whose link exceeds a version-40 code at
  medium error correction (2331 characters) offers no QR; the row says to
  share a file.

## Invariants

- Our format survives a round trip through file and link unchanged —
  `test/rule_set_transfer_test.dart`.
- A file from a newer format version is refused, not half-read — same test.
- Foreign imports report what they dropped — same test and
  `test/rule_set_import_export_test.dart`.

## Alternatives Considered

### Export to other apps' formats too

What some clients offer. Rejected: each target silently drops something
(processes for Happ, our list rules for Surge), and a set exported to come back
must come back whole. Other apps read their own formats; we read theirs.

### Merge an import into an existing set

Saves a step when adding rules from someone else. Rejected: an import would
then change a set already applied to configurations, possibly on a live
tunnel, without the user opening that set.

### A series of QR codes for large sets

Amnezia does this for keys. Rejected: sets move between one person's devices,
where a file is always at hand, and a series is slow to scan.

### Map a bare Happ domain to a keyword rule

Faithful to Xray, where a plain string is a substring match. Rejected: people
write `youtube.com` meaning the site and its subdomains, and a keyword would
also match `youtube.com.example`.

## Consequences

- `anoya://` links are read from the clipboard and QR codes but are not
  registered as an OS deep link; tapping one in a messenger does nothing yet.
- Lists by link (`RULE-SET`) do not migrate; they are not part of local rule
  sets.
- Import from an `https://` URL is not offered.

## Where It Lives

- `lib/core/rule_set_transfer.dart`
- `lib/features/rule_sets_screen.dart`, `rule_set_import_screen.dart`,
  `rule_set_editor_screen.dart`, `rule_set_qr_screen.dart`,
  `qr_scan_screen.dart`
- `test/rule_set_transfer_test.dart`, `test/rule_set_import_export_test.dart`
