import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/on_demand.dart';
import '../core/ui.dart';
import '../state/on_demand_controller.dart';

/// Editor for one on-demand rule. Persists as the user edits (same convention
/// as the routing rule-set editor — no Save button); a brand-new rule is added
/// on the first change.
class OnDemandRuleScreen extends ConsumerStatefulWidget {
  const OnDemandRuleScreen({super.key, required this.rule, this.isNew = false});

  final OnDemandRule rule;
  final bool isNew;

  @override
  ConsumerState<OnDemandRuleScreen> createState() => _OnDemandRuleScreenState();
}

class _OnDemandRuleScreenState extends ConsumerState<OnDemandRuleScreen> {
  late OnDemandRule _rule = widget.rule;
  late final TextEditingController _name = TextEditingController(text: widget.rule.name);
  late final TextEditingController _probe = TextEditingController(text: widget.rule.probeUrl);

  @override
  void dispose() {
    _name.dispose();
    _probe.dispose();
    super.dispose();
  }

  Future<void> _update(OnDemandRule rule) async {
    setState(() => _rule = rule);
    await ref.read(onDemandProvider.notifier).upsertRule(rule);
  }

  Future<void> _pickAction() async {
    final picked = await pickOption<OnDemandAction>(
      context,
      title: 'Action',
      selected: _rule.action,
      options: const [
        Option(OnDemandAction.connect, 'Connect', subtitle: 'bring the tunnel up'),
        Option(OnDemandAction.disconnect, 'Disconnect', subtitle: 'tear the tunnel down'),
        Option(OnDemandAction.ignore, 'Ignore', subtitle: 'leave the tunnel as is'),
      ],
    );
    if (picked != null) await _update(_rule.copyWith(action: picked));
  }

  Future<void> _addTo(List<String> current, String title, String hint,
      void Function(List<String>) apply) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: InputDecoration(labelText: 'Value', hintText: hint),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    final v = value?.trim() ?? '';
    if (v.isEmpty || current.contains(v)) return;
    apply([...current, v]);
  }

  Widget _chips({
    required List<String> values,
    required String addTitle,
    required String addHint,
    required void Function(List<String>) apply,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...values.map((v) => InputChip(
                label: Text(v, style: const TextStyle(fontSize: 13)),
                onDeleted: () => apply(values.where((x) => x != v).toList()),
              )),
          ActionChip(
            label: const Text('+ Add', style: TextStyle(fontSize: 13)),
            onPressed: () => _addTo(values, addTitle, addHint, apply),
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  @override
  Widget build(BuildContext context) {
    // iOS matches cellular; macOS has ethernet instead.
    final mobile = Platform.isMacOS ? OnDemandInterface.ethernet : OnDemandInterface.cellular;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? 'New rule' : 'Edit rule')),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: TextField(
                controller: _name,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'Office'),
                onChanged: (v) => _update(_rule.copyWith(name: v.trim())),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: SelectField(label: 'Action', value: _rule.action.label, onTap: _pickAction),
            ),

            const SectionHeader('NETWORK'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<OnDemandInterface>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(value: OnDemandInterface.any, label: Text('Any')),
                    const ButtonSegment(value: OnDemandInterface.wifi, label: Text('Wi-Fi')),
                    ButtonSegment(value: mobile, label: Text(mobile.label)),
                  ],
                  selected: {
                    // A rule saved on the other platform maps onto this one's
                    // third segment so it stays visible/editable.
                    _rule.interface == OnDemandInterface.cellular ||
                            _rule.interface == OnDemandInterface.ethernet
                        ? mobile
                        : _rule.interface,
                  },
                  onSelectionChanged: (s) => _update(_rule.copyWith(interface: s.first)),
                ),
              ),
            ),

            const SectionHeader('WI-FI NETWORKS (SSID)'),
            _chips(
              values: _rule.ssids,
              addTitle: 'Wi-Fi network',
              addHint: 'home-5G',
              apply: (v) => _update(_rule.copyWith(ssids: v)),
            ),
            _hint('Matches the network name exactly. Leave empty for any Wi-Fi.'),

            const SectionHeader('DNS SEARCH DOMAINS'),
            _chips(
              values: _rule.dnsDomains,
              addTitle: 'DNS search domain',
              addHint: 'corp.example.com',
              apply: (v) => _update(_rule.copyWith(dnsDomains: v)),
            ),
            _hint('Matches when the network’s search domain ends with an entry.'),

            const SectionHeader('DNS SERVERS'),
            _chips(
              values: _rule.dnsServers,
              addTitle: 'DNS server',
              addHint: '10.0.*',
              apply: (v) => _update(_rule.copyWith(dnsServers: v)),
            ),
            _hint('Matches the network’s DNS servers; a single “*” wildcard is allowed.'),

            const SectionHeader('URL PROBE'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: TextField(
                controller: _probe,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'URL (optional)',
                    hintText: 'https://intranet.example.com/ping'),
                onChanged: (v) => _update(_rule.copyWith(probeUrl: v.trim())),
              ),
            ),
            _hint('The rule matches only if this URL returns 200 without redirects.'),
          ],
        ),
      ),
    );
  }
}
