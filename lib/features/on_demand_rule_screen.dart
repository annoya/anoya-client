import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/on_demand.dart';
import '../core/ui.dart';
import '../state/on_demand_controller.dart';
import 'on_demand_values_screen.dart';

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
  Timer? _debounce;

  @override
  void dispose() {
    // Flush a pending text edit instead of dropping it: leaving the screen is
    // how editing ends, not a cancel.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      ref.read(onDemandProvider.notifier).upsertRule(_rule);
    }
    _name.dispose();
    _probe.dispose();
    super.dispose();
  }

  Future<void> _update(OnDemandRule rule) async {
    _debounce?.cancel();
    setState(() => _rule = rule);
    await ref.read(onDemandProvider.notifier).upsertRule(rule);
  }

  /// Text fields go through here: every upsert writes disk AND pushes the
  /// NE profile into the system (an NEVPNManager save), and per-keystroke
  /// native saves can complete out of order — the last one to finish wins,
  /// which may be an older snapshot. Discrete controls keep the direct path.
  void _updateDebounced(OnDemandRule rule) {
    setState(() => _rule = rule);
    _debounce?.cancel();
    _debounce = Timer(kTextEditDebounce, () {
      ref.read(onDemandProvider.notifier).upsertRule(_rule);
    });
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

  /// One condition list, shown as a row with a summary; the entries live on
  /// their own screen (searchable, sorted) because a rule can easily carry a
  /// dozen SSIDs or domains.
  Widget _conditionRow({
    required String title,
    required List<String> values,
    required String unit,
    required String addTitle,
    required String addHint,
    required String help,
    required void Function(List<String>) apply,
  }) {
    return Card(
      margin: kCardMargin,
      child: ListTile(
        title: Text(title),
        subtitle: Text(values.isEmpty ? 'Any' : values.join(', '),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final updated = await Navigator.of(context).push<List<String>>(
            MaterialPageRoute(
              builder: (_) => OnDemandValuesScreen(
                title: title,
                values: values,
                unit: unit,
                addTitle: addTitle,
                addHint: addHint,
                help: help,
              ),
            ),
          );
          if (updated != null) apply(updated);
        },
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

  /// What the selected interface mode means, in the user's terms.
  String _networkHelp(OnDemandInterface selected) => switch (selected) {
        OnDemandInterface.any =>
          'The rule is checked on every network — Wi-Fi, mobile or wired.',
        OnDemandInterface.wifi =>
          'When the device joins a Wi-Fi network, the system checks the conditions below and applies the rule.',
        OnDemandInterface.cellular =>
          'When the device is on mobile data, the system checks the conditions below and applies the rule.',
        OnDemandInterface.ethernet =>
          'When the device is on a wired network, the system checks the conditions below and applies the rule.',
      };

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
                onChanged: (v) => _updateDebounced(_rule.copyWith(name: v.trim())),
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
            _hint(_networkHelp(_rule.interface)),

            const SectionHeader('CONDITIONS'),
            if (_rule.ssidsApply)
              _conditionRow(
                title: 'Wi-Fi networks',
                values: _rule.ssids,
                unit: 'NETWORKS',
                addTitle: 'Wi-Fi network',
                addHint: 'home-5G',
                help: 'Matches the network name exactly. Leave empty for any Wi-Fi.',
                apply: (v) => _update(_rule.copyWith(ssids: v)),
              ),
            _conditionRow(
              title: 'DNS search domains',
              values: _rule.dnsDomains,
              unit: 'DOMAINS',
              addTitle: 'DNS search domain',
              addHint: 'corp.example.com',
              help: 'Matches when the network’s search domain ends with an entry.',
              apply: (v) => _update(_rule.copyWith(dnsDomains: v)),
            ),
            _conditionRow(
              title: 'DNS servers',
              values: _rule.dnsServers,
              unit: 'SERVERS',
              addTitle: 'DNS server',
              addHint: '10.0.*',
              help: 'Matches the network’s DNS servers; a single “*” wildcard is allowed.',
              apply: (v) => _update(_rule.copyWith(dnsServers: v)),
            ),

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
                onChanged: (v) => _updateDebounced(_rule.copyWith(probeUrl: v.trim())),
              ),
            ),
            _hint('The rule matches only if this URL returns 200 without redirects.'),
          ],
        ),
      ),
    );
  }
}
