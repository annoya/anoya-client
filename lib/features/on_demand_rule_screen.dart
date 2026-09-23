import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/on_demand.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
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
  late final TextEditingController _name = TextEditingController(
    text: widget.rule.name,
  );
  late final TextEditingController _probe = TextEditingController(
    text: widget.rule.probeUrl,
  );
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
    final l10n = context.l10n;
    final picked = await pickOption<OnDemandAction>(
      context,
      title: l10n.ruleAction,
      selected: _rule.action,
      options: [
        Option(
          OnDemandAction.connect,
          l10n.commonConnect,
          subtitle: l10n.onDemandActionConnectSubtitle,
        ),
        Option(
          OnDemandAction.disconnect,
          l10n.commonDisconnect,
          subtitle: l10n.onDemandActionDisconnectSubtitle,
        ),
        Option(
          OnDemandAction.ignore,
          l10n.onDemandActionIgnore,
          subtitle: l10n.onDemandActionIgnoreSubtitle,
        ),
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
        subtitle: Text(
          values.isEmpty ? context.l10n.onDemandAny : values.join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  /// What the selected interface mode means, in the user's terms.
  String _networkHelp(OnDemandInterface selected) => switch (selected) {
    OnDemandInterface.any => context.l10n.onDemandNetworkHelpAny,
    OnDemandInterface.wifi => context.l10n.onDemandNetworkHelpWifi,
    OnDemandInterface.cellular => context.l10n.onDemandNetworkHelpCellular,
    OnDemandInterface.ethernet => context.l10n.onDemandNetworkHelpEthernet,
  };

  @override
  Widget build(BuildContext context) {
    // iOS matches cellular; macOS has ethernet instead.
    final mobile = Platform.isMacOS
        ? OnDemandInterface.ethernet
        : OnDemandInterface.cellular;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? l10n.onDemandNewRule : l10n.ruleEdit),
      ),
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
                decoration: InputDecoration(
                  labelText: l10n.onDemandNameOptional,
                  hintText: l10n.onDemandNameHint,
                ),
                onChanged: (v) =>
                    _updateDebounced(_rule.copyWith(name: v.trim())),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: SelectField(
                label: l10n.ruleAction,
                value: _rule.action.label,
                onTap: _pickAction,
              ),
            ),

            SectionHeader(l10n.onDemandNetworkHeader),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<OnDemandInterface>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: OnDemandInterface.any,
                      label: Text(l10n.onDemandAny),
                    ),
                    ButtonSegment(
                      value: OnDemandInterface.wifi,
                      label: Text(l10n.onDemandInterfaceWifi),
                    ),
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
                  onSelectionChanged: (s) =>
                      _update(_rule.copyWith(interface: s.first)),
                ),
              ),
            ),
            _hint(_networkHelp(_rule.interface)),

            SectionHeader(l10n.onDemandConditionsHeader),
            if (_rule.ssidsApply)
              _conditionRow(
                title: l10n.onDemandWifiNetworks,
                values: _rule.ssids,
                unit: l10n.onDemandNetworksUnit,
                addTitle: l10n.onDemandWifiNetwork,
                addHint: 'home-5G',
                help: l10n.onDemandWifiNetworksHelp,
                apply: (v) => _update(_rule.copyWith(ssids: v)),
              ),
            _conditionRow(
              title: l10n.onDemandDnsDomains,
              values: _rule.dnsDomains,
              unit: l10n.onDemandDomainsUnit,
              addTitle: l10n.onDemandDnsDomain,
              addHint: 'corp.example.com',
              help: l10n.onDemandDnsDomainsHelp,
              apply: (v) => _update(_rule.copyWith(dnsDomains: v)),
            ),
            _conditionRow(
              title: l10n.onDemandDnsServers,
              values: _rule.dnsServers,
              unit: l10n.onDemandServersUnit,
              addTitle: l10n.onDemandDnsServer,
              addHint: '10.0.*',
              help: l10n.onDemandDnsServersHelp,
              apply: (v) => _update(_rule.copyWith(dnsServers: v)),
            ),

            SectionHeader(l10n.onDemandUrlProbeHeader),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: TextField(
                controller: _probe,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.onDemandUrlOptional,
                  hintText: 'https://intranet.example.com/ping',
                ),
                onChanged: (v) =>
                    _updateDebounced(_rule.copyWith(probeUrl: v.trim())),
              ),
            ),
            _hint(l10n.onDemandUrlProbeHelp),
          ],
        ),
      ),
    );
  }
}
