import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/on_demand.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../state/on_demand_controller.dart';
import 'on_demand_rule_screen.dart';

/// System auto-connect: the enable switch plus an ordered rule list ("first
/// match wins", same pattern as the routing rule sets). The OS evaluates the
/// rules and starts/stops the tunnel by itself.
class OnDemandScreen extends ConsumerWidget {
  const OnDemandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(onDemandProvider);
    final ctrl = ref.read(onDemandProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('On demand')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add rule',
        onPressed: () => _openRule(context, ref, ctrl.newRule(), isNew: true),
        child: const Icon(Icons.add),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          children: [
            Card(
              margin: kCardMargin,
              child: SwitchListTile(
                secondary: const Icon(Icons.bolt_outlined),
                title: const Text('Enable on demand'),
                subtitle: const Text('The system applies the first matching rule'),
                value: prefs.enabled,
                onChanged: (v) => ctrl.setEnabled(v),
              ),
            ),
            const SectionHeader('RULES — FIRST MATCH WINS'),
            if (prefs.rules.isEmpty)
              Padding(
                padding: const EdgeInsets.all(kGutter),
                child: Text(
                  'No rules. Enabling on demand adds “Connect · Any network”.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (o, n) => ctrl.reorderRules(o, n),
                children: [
                  for (var i = 0; i < prefs.rules.length; i++)
                    _ruleTile(context, ref, i, prefs.rules[i]),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
              child: Text(
                'Rules are evaluated top to bottom. If none matches, the tunnel is left as is.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleTile(BuildContext context, WidgetRef ref, int index, OnDemandRule rule) {
    final cs = Theme.of(context).colorScheme;
    final actionColor = switch (rule.action) {
      OnDemandAction.connect => context.vpnColors.connected,
      OnDemandAction.disconnect => cs.error,
      OnDemandAction.ignore => context.vpnColors.direct,
    };
    final tag = switch (rule.action) {
      OnDemandAction.connect => 'CONN.',
      OnDemandAction.disconnect => 'DISC.',
      OnDemandAction.ignore => 'IGNORE',
    };
    return Card(
      key: ValueKey(rule.id),
      margin: kCardMargin,
      child: InkWell(
        onTap: () => _openRule(context, ref, rule),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            SizedBox(
              width: 46,
              child: Text(tag,
                  style: TextStyle(
                      color: actionColor, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rule.name.isNotEmpty ? rule.name : rule.action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(rule.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(onDemandProvider.notifier).removeRule(rule.id),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Icon(Icons.drag_handle, size: 20, color: cs.onSurfaceVariant),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _openRule(BuildContext context, WidgetRef ref, OnDemandRule rule, {bool isNew = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnDemandRuleScreen(rule: rule, isNew: isNew),
    ));
  }
}
