import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../policy_origin.dart';
import '../managed_policy_screen.dart';
import '../../state/provider_rule_lists.dart';

class ProviderRoutingCard extends ConsumerStatefulWidget {
  const ProviderRoutingCard({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<ProviderRoutingCard> createState() =>
      _ProviderRoutingCardState();
}

class _ProviderRoutingCardState extends ConsumerState<ProviderRoutingCard> {
  bool _downloading = false;

  Future<void> _setLists(bool enabled) async {
    if (enabled) setState(() => _downloading = true);
    try {
      await ref
          .read(profilesControllerProvider.notifier)
          .setProviderRuleListsEnabled(widget.profile.id, enabled);
      ref.invalidate(providerRuleListsProvider(widget.profile.id));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final routing = profile.providerRouting!;
    final on = profile.providerRoutingEnabled;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    final lists = ref.watch(providerRuleListsProvider(profile.id)).value;
    final needLists = routing.rules.where((r) => r.needsRuleList).length;
    final l10n = context.l10n;
    void setOn(bool v) => ctrl.setProviderRoutingEnabled(profile.id, v);
    return DsCard(
      color: context.ds.accentSubtle,
      children: [
        DsRow(
          glyph: Glyph.split,
          title: l10n.configRouting,
          subtitle: providerRoutingSummary(profile, lists),
          onTap: () => setOn(!on),
          trailing: [DsToggle(value: on, onChanged: setOn)],
        ),
        DsRow(
          glyph: Glyph.layers,
          title: l10n.configRuleSet,
          trailing: const [DsChevron()],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ManagedPolicyScreen(
                routing,
                origin: PolicyOrigin.provider(
                  profile.name,
                  skipped: profile.providerRoutingSkipped,
                ),
                listsAvailable: profile.providerRuleListsEnabled
                    ? (lists ?? const [])
                          .where((s) => s.available)
                          .map((s) => s.list.name)
                          .toSet()
                    : null,
              ),
            ),
          ),
        ),
        if (needLists > 0)
          DsRow(
            leading: _downloading
                ? const DsSpinner()
                : const GlyphIcon(Glyph.database),
            title: l10n.configRuleLists,
            subtitle: _downloading
                ? l10n.configDownloadingLists(needLists)
                : _listSummary(profile, needLists, lists),
            onTap: _downloading
                ? null
                : () => _setLists(!profile.providerRuleListsEnabled),
            trailing: [
              DsToggle(
                value: profile.providerRuleListsEnabled,
                onChanged: _downloading ? null : _setLists,
              ),
            ],
          ),
      ],
    );
  }
}

String providerRoutingSummary(Profile profile, List<RuleListStatus>? lists) {
  final l10n = L10n.current;
  final routing = profile.providerRouting!;
  final mode = routing.mode == 'split'
      ? l10n.ruleSetModeSplit
      : l10n.ruleSetModeFull;
  final applied = routing.rules
      .where((r) => !r.needsRuleList || _isAvailable(profile, r.value, lists))
      .length;
  final rules = applied == 0
      ? l10n.configNoExceptions
      : l10n.configRulesCount(applied);
  final parts = [l10n.ruleSetSummary(mode, rules)];
  final skipped = profile.providerRoutingSkipped;
  if (skipped > 0) parts.add(l10n.configSkippedNotSupported(skipped));
  final missing = routing.rules.length - applied;
  if (missing > 0) {
    parts.add(
      profile.providerRuleListsEnabled
          ? l10n.configListsUnavailable(missing)
          : l10n.configRulesNeedLists(missing),
    );
  }
  return parts.join(' · ');
}

bool _isAvailable(Profile p, String name, List<RuleListStatus>? lists) {
  if (!p.providerRuleListsEnabled) return false;
  if (lists == null) return true;
  return lists.any((s) => s.list.name == name && s.available);
}

String _listSummary(Profile p, int needed, List<RuleListStatus>? lists) {
  final l10n = L10n.current;
  if (!p.providerRuleListsEnabled) return l10n.configRuleListsOff(needed);
  if (lists == null) return l10n.configChecking;
  final have = lists.where((s) => s.available).toList();
  if (have.isEmpty) return l10n.configNoneDownloadedYet;
  final kb = have.fold<int>(0, (a, s) => a + s.bytes) ~/ 1024;
  final count = have.length == lists.length
      ? l10n.configListsCount(have.length)
      : l10n.configListsDownloadedOf(have.length, lists.length);
  return l10n.configListsSize(count, kb);
}

class RuleListFailureCard extends ConsumerStatefulWidget {
  const RuleListFailureCard({
    super.key,
    required this.profile,
    required this.failed,
  });

  final Profile profile;
  final List<RuleListStatus> failed;

  @override
  ConsumerState<RuleListFailureCard> createState() =>
      _RuleListFailureCardState();
}

class _RuleListFailureCardState extends ConsumerState<RuleListFailureCard> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(profilesControllerProvider.notifier)
          .syncRuleLists(widget.profile.id);
      ref.invalidate(providerRuleListsProvider(widget.profile.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.failed.length;
    final names = widget.failed.map((s) => '«${s.list.name}»').join(', ');
    final hosts = widget.failed
        .map((s) => Uri.parse(s.list.url).host)
        .toSet()
        .join(', ');
    final l10n = context.l10n;
    return DsNotification(
      title: l10n.configListsFailedTitle(n),
      body: l10n.configListsFailedDetail(n, names, hosts),
      glyph: Glyph.alertTriangle,
      tone: DsTone.warning,
      action: DsButton.tonal(
        label: l10n.commonTryAgain,
        busy: _busy,
        onPressed: _retry,
      ),
    );
  }
}
