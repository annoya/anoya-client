import 'package:flutter/material.dart';

import '../core/app_error.dart';
import '../core/country_flag.dart';
import '../core/ds.dart';
import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/platform_support.dart';
import '../core/rule_set.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class DirectionCard<T> extends StatelessWidget {
  const DirectionCard({
    super.key,
    required this.segments,
    required this.value,
    required this.note,
    this.onChanged,
  });

  final List<(T, String)> segments;
  final T value;
  final String note;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => DsSurface(
    padding: const EdgeInsets.all(kCardPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSegmented<T>(
          compact: true,
          segments: segments,
          value: value,
          onChanged: onChanged,
        ),
        const SizedBox(height: kNoteGap),
        DsNote(note),
      ],
    ),
  );
}

class RoutingModeCard extends StatelessWidget {
  const RoutingModeCard({super.key, required this.mode, this.onChanged});

  final RoutingMode mode;
  final ValueChanged<RoutingMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DirectionCard<RoutingMode>(
      segments: [
        (RoutingMode.full, l10n.ruleSetModeFull),
        (RoutingMode.split, l10n.ruleSetModeSplit),
      ],
      value: mode,
      onChanged: onChanged,
      note: mode == RoutingMode.full
          ? l10n.ruleSetModeFullDescription
          : l10n.ruleSetModeSplitDescription,
    );
  }
}

Widget emptyRulesNote(BuildContext context, RoutingMode mode) => Padding(
  padding: const EdgeInsets.symmetric(vertical: kGroupGap),
  child: Text(
    mode == RoutingMode.split
        ? context.l10n.ruleSetNoRulesSplit
        : context.l10n.ruleSetNoRulesFull,
    textAlign: TextAlign.center,
    style: DsType.text.copyWith(color: context.ds.text3),
  ),
);

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
  Widget build(BuildContext context) => DsNotification(
    glyph: Glyph.cloudOff,
    title: title,
    body: subtitle,
    action: DsButton.tonal(
      label: context.l10n.ruleSetDownload,
      busy: busy,
      onPressed: onDownload,
    ),
  );
}

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

  final bool geoReady;

  final Set<String> listNames;

  final bool listsOff;

  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badge = DsBadge(
      rule.action.toUpperCase(),
      tone: switch (rule.action) {
        'proxy' => DsTone.success,
        'direct' => DsTone.neutral,
        _ => DsTone.destructive,
      },
    );
    final noDatabase = rule.needsGeoData && !geoReady;
    final unsupported = rule.type == 'process-name' && !supportsProcessRules;
    final noList = rule.needsRuleList && !listNames.contains(rule.value);
    final inactive = noDatabase || unsupported || noList;
    final title = rule.values
        .take(8)
        .map((v) => rule.type == 'geoip' ? geoipTitle(v) : v)
        .join(', ');
    final type = rule.type == 'rule-list' ? l10n.ruleKindRuleList : rule.type;
    final kind = rule.values.length > 1
        ? '$type · ${ruleValueCount(l10n, rule.type, rule.values.length)}'
        : type;
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
    final row = DsRow(
      title: title,
      titleBadge: badge,
      subtitle: subtitle,
      subtitleMaxLines: 1,
      onTap: onTap,
      trailing: [
        if (onRemove != null)
          DsAction(
            glyph: Glyph.trash,
            tooltip: l10n.commonRemove,
            onPressed: onRemove,
          ),
        if (reorderIndex != null)
          ReorderableDragStartListener(
            index: reorderIndex!,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: const DsAction(glyph: Glyph.gripVertical),
            ),
          ),
      ],
    );
    return inactive ? Opacity(opacity: kDisabledOpacity, child: row) : row;
  }
}

String geoipTitle(String code) {
  final up = code.toUpperCase();
  final flag = flagForCode(up) ?? '';
  return flag.isEmpty ? up : '$flag  $up';
}

String ruleValueCount(AppLocalizations l10n, String type, int count) =>
    switch (type) {
      'domain-keyword' => l10n.ruleCountKeywords(count),
      'domain-regex' => l10n.ruleCountPatterns(count),
      'ip-cidr' => l10n.ruleCountSubnets(count),
      'process-name' => l10n.ruleCountProcesses(count),
      'geoip' => l10n.ruleCountCountries(count),
      'geosite' => l10n.ruleCountCategories(count),
      _ => l10n.ruleCountDomains(count),
    };
