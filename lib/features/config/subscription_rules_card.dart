import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/provider_rule_lists.dart';
import 'provider_routing_card.dart';
import 'proxy_groups_screen.dart';

class SubscriptionRulesCard extends ConsumerStatefulWidget {
  const SubscriptionRulesCard({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<SubscriptionRulesCard> createState() =>
      _SubscriptionRulesCardState();
}

class _SubscriptionRulesCardState extends ConsumerState<SubscriptionRulesCard> {
  bool _busy = false;

  Future<void> _refresh() async {
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
    final l10n = context.l10n;
    final p = widget.profile;
    final plan = p.plan!;
    final lists = ref.watch(providerRuleListsProvider(p.id)).value;
    return DsCard(
      color: context.ds.accentSubtle,
      children: [
        DsRow(
          glyph: Glyph.split,
          title: l10n.configRuleSet,
          subtitle: [
            l10n.configRulesCount(plan.rules.length),
            if (plan.skipped > 0) l10n.configSkippedNotSupported(plan.skipped),
          ].join(' · '),
          trailing: const [DsChevron()],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubscriptionRulesScreen(profileId: p.id),
            ),
          ),
        ),
        if (plan.lists.isNotEmpty)
          DsRow(
            glyph: Glyph.database,
            title: l10n.configRuleLists,
            subtitle: ruleListsSummary(true, plan.lists.length, lists),
            trailing: [
              DsAction(
                glyph: Glyph.refreshCw,
                busy: _busy,
                tooltip: l10n.configRuleLists,
                onPressed: _refresh,
              ),
            ],
          ),
      ],
    );
  }
}

class SubscriptionRulesScreen extends ConsumerWidget {
  const SubscriptionRulesScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(
      profilesControllerProvider.select(
        (s) => s.profiles.where((p) => p.id == profileId).firstOrNull,
      ),
    );
    final plan = p?.plan;
    if (p == null || plan == null) return const DsPage();
    final l10n = context.l10n;
    return DsPage(
      title: l10n.configRuleSet,
      children: [
        DsCard(
          children: [
            for (final r in plan.rules)
              DsRow(
                title: r.isCatchAll
                    ? l10n.proxyGroupsEverythingElse
                    : r.payload,
                subtitle: l10n.rulesTarget(
                  r.type,
                  describePlanRef(r.target, p).title,
                ),
                subtitleMaxLines: 1,
              ),
          ],
        ),
        if (plan.skipped > 0) DsNote(l10n.proxyGroupsNotApplied(plan.skipped)),
      ],
    );
  }
}
