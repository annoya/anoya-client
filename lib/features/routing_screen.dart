import 'package:flutter/material.dart';

import '../core/norm_config.dart';
import '../core/routing_store.dart';
import '../core/ui.dart';

/// Split-tunneling screen.
///
/// [managed] != null → the policy comes from the organization's server with
/// the config bundle: show it read-only. Otherwise this edits the
/// device-local rules (same schema), applied on the next connect.
class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key, this.managed});

  final Routing? managed;

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  String _mode = 'full';
  List<RoutingRule> _rules = [];
  bool _loading = true;

  bool get _isManaged => widget.managed != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routing = widget.managed ?? await RoutingStore.load();
    if (!mounted) return;
    setState(() {
      _mode = routing?.mode ?? 'full';
      _rules = List.of(routing?.rules ?? const []);
      _loading = false;
    });
  }

  Future<void> _persist() async {
    if (_isManaged) return;
    if (_mode == 'full' && _rules.isEmpty) {
      await RoutingStore.clear(); // back to the default "tunnel everything"
    } else {
      await RoutingStore.save(Routing(mode: _mode, rules: _rules));
    }
  }

  Future<void> _editRule([int? index]) async {
    final rule = await showDialog<RoutingRule>(
      context: context,
      builder: (_) => _RuleDialog(initial: index != null ? _rules[index] : null),
    );
    if (rule == null) return;
    setState(() {
      if (index != null) {
        _rules[index] = rule;
      } else {
        _rules.add(rule);
      }
    });
    await _persist();
  }

  Future<void> _removeRule(int index) async {
    setState(() => _rules.removeAt(index));
    await _persist();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final r = _rules.removeAt(oldIndex);
      _rules.insert(newIndex, r);
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split tunneling')),
      floatingActionButton: _isManaged
          ? null
          : FloatingActionButton(
              tooltip: 'Add rule',
              onPressed: () => _editRule(),
              child: const Icon(Icons.add),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (_isManaged) _managedBanner(context),
                _modeCard(context),
                const SectionHeader('RULES — FIRST MATCH WINS'),
                if (_rules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(kGutter),
                    child: Text(
                      _mode == 'split'
                          ? 'No rules: no traffic goes through the VPN. Add rules for what should be tunneled.'
                          : 'No rules: all traffic goes through the VPN.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else if (_isManaged)
                  ..._rules.asMap().entries.map((e) => _ruleTile(e.key, e.value))
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: true,
                    onReorder: _reorder,
                    children: [
                      for (var i = 0; i < _rules.length; i++)
                        _ruleTile(i, _rules[i], key: ValueKey('rule_$i')),
                    ],
                  ),
              ],
              ),
            ),
    );
  }

  Widget _managedBanner(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: const ListTile(
        leading: Icon(Icons.business_outlined),
        title: Text('Managed by your organization'),
        subtitle: Text('These rules are set on the server and cannot be changed here.'),
      ),
    );
  }

  Widget _modeCard(BuildContext context) {
    return Card(
      margin: kCardMargin,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'full', label: Text('Full tunnel')),
                ButtonSegment(value: 'split', label: Text('Split')),
              ],
              selected: {_mode},
              onSelectionChanged: _isManaged
                  ? null
                  : (s) async {
                      setState(() => _mode = s.first);
                      await _persist();
                    },
            ),
            const SizedBox(height: 8),
            Text(
              _mode == 'full'
                  ? 'All traffic goes through the VPN; rules define exceptions.'
                  : 'Only traffic matching the rules goes through the VPN; the rest connects directly.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleTile(int index, RoutingRule rule, {Key? key}) {
    final actionColor = switch (rule.action) {
      'proxy' => Colors.green,
      'direct' => Colors.blueGrey,
      _ => Colors.red,
    };
    return Card(
      key: key,
      margin: kCardMargin,
      child: ListTile(
        dense: true,
        title: Text(rule.value, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(rule.type),
        leading: Text(
          rule.action.toUpperCase(),
          style: TextStyle(color: actionColor, fontWeight: FontWeight.w700, fontSize: 11),
        ),
        trailing: _isManaged
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Remove',
                onPressed: () => _removeRule(index),
              ),
        onTap: _isManaged ? null : () => _editRule(index),
      ),
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({this.initial});
  final RoutingRule? initial;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late String _type = widget.initial?.type ?? 'domain-suffix';
  late String _action = widget.initial?.action ?? 'proxy';
  late final TextEditingController _value =
      TextEditingController(text: widget.initial?.value ?? '');
  String? _error;

  static const _hints = {
    'domain-suffix': 'corp.example.com',
    'domain-keyword': 'jira',
    'domain-exact': 'wiki.example.com',
    'ip-cidr': '10.0.0.0/8',
    'process-name': 'Slack',
  };

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final rule = RoutingRule(type: _type, value: _value.text.trim(), action: _action);
    if (!rule.isValid) {
      setState(() => _error = 'Invalid value for ${rule.type}.');
      return;
    }
    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add rule' : 'Edit rule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Match'),
            items: RoutingRule.types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _value,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Value', hintText: _hints[_type]),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _action,
            decoration: const InputDecoration(labelText: 'Action'),
            items: RoutingRule.actions
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _action = v ?? _action),
          ),
          if (_type == 'process-name')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Desktop only.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
