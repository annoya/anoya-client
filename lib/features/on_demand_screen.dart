import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ds.dart';
import '../core/on_demand.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../state/on_demand_controller.dart';
import 'on_demand_rule_screen.dart';

class OnDemandScreen extends ConsumerWidget {
  const OnDemandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(onDemandProvider);
    final ctrl = ref.read(onDemandProvider.notifier);
    final l10n = context.l10n;

    return DsPage(
      title: l10n.onDemandTitle,
      fab: FloatingActionButton(
        tooltip: l10n.ruleAdd,
        onPressed: () => _openRule(context, ctrl.newRule(), isNew: true),
        child: const GlyphIcon(Glyph.plus),
      ),
      children: [
        DsCard(
          children: [
            DsRow(
              glyph: Glyph.zap,
              title: l10n.onDemandEnable,
              subtitle: l10n.onDemandEnableSubtitle,
              onTap: () => ctrl.setEnabled(!prefs.enabled),
              trailing: [
                DsToggle(value: prefs.enabled, onChanged: ctrl.setEnabled),
              ],
            ),
          ],
        ),
        if (prefs.rules.isEmpty)
          DsEmptyState(
            title: l10n.onDemandNoRules,
            hint: l10n.onDemandRulesFootnote,
          )
        else
          DsGroup(
            caption: l10n.ruleSetRulesHeader,
            note: l10n.onDemandRulesFootnote,
            child: DsReorderableCard<OnDemandRule>(
              items: prefs.rules,
              keyOf: (rule) => ValueKey(rule.id),
              onReorder: ctrl.reorderRules,
              itemBuilder: (i, rule) => _ruleRow(context, ref, i, rule),
            ),
          ),
        const SizedBox(height: kFabSize),
      ],
    );
  }

  Widget _ruleRow(
    BuildContext context,
    WidgetRef ref,
    int index,
    OnDemandRule rule,
  ) {
    final l10n = context.l10n;
    final (tag, tone) = switch (rule.action) {
      OnDemandAction.connect => (l10n.onDemandTagConnect, DsTone.success),
      OnDemandAction.disconnect => (
        l10n.onDemandTagDisconnect,
        DsTone.destructive,
      ),
      OnDemandAction.ignore => (l10n.onDemandTagIgnore, DsTone.neutral),
    };
    return DsRow(
      title: rule.name.isNotEmpty ? rule.name : rule.action.label,
      badge: DsBadge(tag, tone: tone),
      subtitle: rule.summary,
      onTap: () => _openRule(context, rule),
      trailing: [
        DsAction(
          glyph: Glyph.trash,
          tooltip: l10n.commonRemove,
          onPressed: () =>
              ref.read(onDemandProvider.notifier).removeRule(rule.id),
        ),
        ReorderableDragStartListener(
          index: index,
          child: const DsAction(glyph: Glyph.gripVertical),
        ),
      ],
    );
  }

  void _openRule(
    BuildContext context,
    OnDemandRule rule, {
    bool isNew = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnDemandRuleScreen(rule: rule, isNew: isNew),
      ),
    );
  }
}
