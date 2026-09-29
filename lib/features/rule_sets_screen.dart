import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rule_set.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import '../state/routing_status.dart';
import 'rule_set_editor_screen.dart';

class RuleSetsScreen extends ConsumerStatefulWidget {
  const RuleSetsScreen({super.key});

  @override
  ConsumerState<RuleSetsScreen> createState() => _RuleSetsScreenState();
}

class _RuleSetsScreenState extends ConsumerState<RuleSetsScreen> {
  List<RuleSet> _sets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await RuleSetStore.load();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await promptText(
      context,
      title: l10n.ruleSetNew,
      label: l10n.commonName,
      hint: l10n.ruleSetNameHint,
      confirmLabel: l10n.ruleSetCreate,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final set = RuleSet(
      id: 'rs${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: trimmed,
    );
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    await RuleSetStore.save([..._sets, set]);
    revision.bump();
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RuleSetEditorScreen(set.id)));
    await _load();
  }

  String _subtitle(RuleSet s, Map<String, int> usage) {
    final l10n = context.l10n;
    final mode = s.mode.label;
    final rules = l10n.ruleSetRuleCount(s.rules.length);
    final used = usage[s.id] ?? 0;
    return used > 0
        ? l10n.ruleSetSummaryUsed(mode, rules, l10n.ruleSetUsedBy(used))
        : l10n.ruleSetSummary(mode, rules);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = ref.watch(profilesControllerProvider).profiles;
    final usage = <String, int>{};
    for (final p in profiles) {
      if (p.routing != null) continue;
      final id = p.ruleSetId ?? RuleSet.defaultId;
      usage[id] = (usage[id] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ruleSetsTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.ruleSetNew,
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                children: _sets
                    .map(
                      (s) => Card(
                        margin: kCardMargin,
                        child: ListTile(
                          leading: const Icon(Icons.layers_outlined),
                          title: Text(s.name),
                          subtitle: Text(_subtitle(s, usage)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RuleSetEditorScreen(s.id),
                              ),
                            );
                            await _load();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}
