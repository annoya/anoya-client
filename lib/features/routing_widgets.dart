import 'package:flutter/material.dart';

import '../core/app_error.dart';
import '../core/country_flag.dart';
import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/platform_support.dart';
import '../core/rule_set.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

/// What the rule-set editor and the managed-policy viewer share: the same rule
/// row, the same direction card, the same download banner. A rule has to read
/// the same whoever authored it — the only difference between the two screens
/// is whether the controls do anything.

/// The direction: full tunnel with exceptions, or split with an allow-list.
/// Read-only when [onChanged] is null.
class RoutingModeCard extends StatelessWidget {
  const RoutingModeCard({super.key, required this.mode, this.onChanged});

  final RoutingMode mode;
  final ValueChanged<RoutingMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: kCardMargin,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full width, half and half, no leading check — the check would
            // shrink the labels and shift them off-centre.
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<RoutingMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: RoutingMode.full,
                    label: Text(l10n.ruleSetModeFull),
                  ),
                  ButtonSegment(
                    value: RoutingMode.split,
                    label: Text(l10n.ruleSetModeSplit),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: onChanged == null
                    ? null
                    : (s) => onChanged!(s.first),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mode == RoutingMode.full
                  ? l10n.ruleSetModeFullDescription
                  : l10n.ruleSetModeSplitDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What an empty rule list means under each direction.
Widget emptyRulesNote(BuildContext context, RoutingMode mode) => Padding(
  padding: const EdgeInsets.all(kGutter),
  child: Text(
    mode == RoutingMode.split
        ? context.l10n.ruleSetNoRulesSplit
        : context.l10n.ruleSetNoRulesFull,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
  ),
);

/// Offers the geo databases where rules need them. The wording is the
/// caller's: on the simple editor the download *is* the screen, in a rule list
/// it explains why some rows are dimmed.
class GeoDownloadBanner extends StatelessWidget {
  const GeoDownloadBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onDownload,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final warn = context.vpnColors.connecting;
    return Card(
      margin: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
      color: warn.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 12, 10),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.public_off, color: warn),
              title: Text(title),
              subtitle: Text(subtitle),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: busy ? null : onDownload,
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.ruleSetDownload),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Downloads the geo databases and says so when it fails. Answers whether they
/// are on disk afterwards; null when the download failed and nothing changed.
Future<bool?> downloadGeoDatabases(BuildContext context) async {
  try {
    await GeoStore.download();
    return (await GeoStore.status()).downloaded;
  } catch (e) {
    Log.e('geo download failed', '$e');
    if (context.mounted) {
      showToast(
        context,
        describeError(e, subject: context.l10n.geoDatabaseHostSubject).line,
      );
    }
    return null;
  }
}

/// One rule as a row: action, value, and why it is inactive when it is.
///
/// Editable when [onTap], [onRemove] and [reorderIndex] are given — the editor
/// passes all three, the viewer none. A rule that cannot match right now is
/// dimmed rather than hidden: the set may have been authored on a desktop, and
/// a row that silently disappears looks like data loss.
class RuleTile extends StatelessWidget {
  const RuleTile({
    super.key,
    required this.rule,
    required this.geoReady,
    this.listNames = const {},
    this.listsOff = false,
    this.onTap,
    this.onRemove,
    this.reorderIndex,
  });

  final RoutingRule rule;

  /// Whether the geo databases are on disk; a geo rule without them is inactive.
  final bool geoReady;

  /// Names of the rule lists this device holds. A list rule is only as good as
  /// the file behind it: hiding it would claim the policy is smaller than it
  /// is, showing it as active would claim traffic is routed when nothing
  /// matches.
  final Set<String> listNames;

  /// The user refused the lists outright, as opposed to a download that failed.
  final bool listsOff;

  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  /// The row's index in a ReorderableListView, which puts a drag handle on it.
  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actionColor = switch (rule.action) {
      'proxy' => context.vpnColors.connected,
      'direct' => context.vpnColors.direct,
      _ => Theme.of(context).colorScheme.error,
    };
    final noDatabase = rule.needsGeoData && !geoReady;
    final unsupported = rule.type == 'process-name' && !supportsProcessRules;
    final noList = rule.needsRuleList && !listNames.contains(rule.value);
    final inactive = noDatabase || unsupported || noList;
    final title = rule.type == 'geoip' ? geoipTitle(rule.value) : rule.value;
    final kind = rule.type == 'rule-list' ? l10n.ruleKindRuleList : rule.type;
    final subtitle = noDatabase
        ? l10n.ruleInactiveNoDatabase(kind)
        : unsupported
        ? l10n.ruleInactiveDesktopOnly(kind)
        : noList
        ? (listsOff
              ? l10n.ruleInactiveListsOff(kind)
              : l10n.ruleInactiveNotDownloaded(kind))
        : rule.noResolve
        ? l10n.ruleNoResolveKind(kind)
        : kind;
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: inactive ? 0.45 : 1,
      child: Card(
        margin: kCardMargin,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    rule.action.toUpperCase(),
                    style: TextStyle(
                      color: actionColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: l10n.commonRemove,
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                  ),
                if (reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "🇩🇪  DE" — the flag next to the code, or the code alone when there is none.
String geoipTitle(String code) {
  final up = code.toUpperCase();
  final flag = flagEmoji(up) ?? '';
  return flag.isEmpty ? up : '$flag  $up';
}
