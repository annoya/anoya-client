import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rule_set.dart';
import '../core/ui.dart';
import '../state/profiles_controller.dart';
import '../state/routing_status.dart';
import 'routing_screen.dart';

/// Global rule sets: created here, applied per configuration (see the
/// configuration screen). Each row shows mode, rule count and how many
/// configurations use the set.
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
    final name = await promptText(context,
        title: 'New rule set', label: 'Name', hint: 'Work', confirmLabel: 'Create');
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final set = RuleSet(
      id: 'rs${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: trimmed,
    );
    // Notifier before the await: the bump must land even if the user leaves
    // the screen while the write is in flight (ref dies with the state).
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    await RuleSetStore.save([..._sets, set]);
    revision.bump();
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RoutingScreen.editSet(set.id)));
    await _load();
  }

  String _subtitle(RuleSet s, Map<String, int> usage) {
    final mode = s.mode == 'split' ? 'Split' : 'Full tunnel';
    final rules = s.rules.isEmpty ? 'no rules' : '${s.rules.length} rules';
    final used = usage[s.id] ?? 0;
    return used > 0 ? '$mode · $rules · used by $used config${used > 1 ? 's' : ''}' : '$mode · $rules';
  }

  @override
  Widget build(BuildContext context) {
    // Usage counts: profiles without an explicit set use Default.
    final profiles = ref.watch(profilesControllerProvider).profiles;
    final usage = <String, int>{};
    for (final p in profiles) {
      if (p.routing != null) continue; // managed profiles don't use local sets
      final id = p.ruleSetId ?? RuleSet.defaultId;
      usage[id] = (usage[id] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rule sets')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New rule set',
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                children: _sets
                    .map((s) => Card(
                          margin: kCardMargin,
                          child: ListTile(
                            leading: const Icon(Icons.layers_outlined),
                            title: Text(s.name),
                            subtitle: Text(_subtitle(s, usage)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => RoutingScreen.editSet(s.id)));
                              await _load();
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
    );
  }
}
