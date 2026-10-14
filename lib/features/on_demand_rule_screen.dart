import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ds.dart';
import '../core/on_demand.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/on_demand_controller.dart';
import 'on_demand_values_screen.dart';

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
  @override
  void dispose() {
    _name.dispose();
    _probe.dispose();
    super.dispose();
  }

  void _update(OnDemandRule rule) => setState(() => _rule = rule);

  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(onDemandProvider.notifier).upsertRule(_rule);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickAction() async {
    final l10n = context.l10n;
    final options = [
      (
        OnDemandAction.connect,
        l10n.commonConnect,
        l10n.onDemandActionConnectSubtitle,
      ),
      (
        OnDemandAction.disconnect,
        l10n.commonDisconnect,
        l10n.onDemandActionDisconnectSubtitle,
      ),
      (
        OnDemandAction.ignore,
        l10n.onDemandActionIgnore,
        l10n.onDemandActionIgnoreSubtitle,
      ),
    ];
    final picked = await showDsSheet<OnDemandAction>(
      context,
      (context) => DsSheet(
        title: l10n.ruleAction,
        children: [
          DsCard(
            children: [
              for (final (action, title, subtitle) in options)
                DsRow(
                  title: title,
                  subtitle: subtitle,
                  selected: action == _rule.action,
                  onTap: () => Navigator.of(context).pop(action),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null) _update(_rule.copyWith(action: picked));
  }

  Widget _conditionCard({
    required Glyph glyph,
    required String title,
    required List<String> values,
    required String unit,
    required String addTitle,
    required String addHint,
    required String help,
    required void Function(List<String>) apply,
  }) {
    return DsCard(
      children: [
        DsRow(
          glyph: glyph,
          title: title,
          subtitle: values.isEmpty
              ? context.l10n.onDemandAny
              : values.join(', '),
          subtitleMaxLines: 1,
          trailing: const [DsChevron()],
          onTap: () async {
            final updated = await Navigator.of(context).push<List<String>>(
              MaterialPageRoute(
                builder: (_) => OnDemandValuesScreen(
                  glyph: glyph,
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
      ],
    );
  }

  String _networkHelp(OnDemandInterface selected) => switch (selected) {
    OnDemandInterface.any => context.l10n.onDemandNetworkHelpAny,
    OnDemandInterface.wifi => context.l10n.onDemandNetworkHelpWifi,
    OnDemandInterface.cellular => context.l10n.onDemandNetworkHelpCellular,
    OnDemandInterface.ethernet => context.l10n.onDemandNetworkHelpEthernet,
  };

  @override
  Widget build(BuildContext context) {
    final mobile = Platform.isMacOS
        ? OnDemandInterface.ethernet
        : OnDemandInterface.cellular;
    final l10n = context.l10n;

    return DsPage(
      title: widget.isNew ? l10n.onDemandNewRule : l10n.ruleEdit,
      leading: DsLeading.close,
      actions: [
        DsNavButton(
          glyph: Glyph.check,
          tooltip: l10n.commonSave,
          busy: _saving,
          onPressed: _save,
        ),
      ],
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: DsStack(
            gap: kGroupGap,
            children: [
              DsStack(
                gap: kNoteGap,
                children: [
                  TextField(
                    controller: _name,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.onDemandNameOptional,
                      hintText: l10n.onDemandNameHint,
                    ),
                    onChanged: (v) => _update(_rule.copyWith(name: v.trim())),
                  ),
                  SelectField(
                    label: l10n.ruleAction,
                    value: _rule.action.label,
                    onTap: _pickAction,
                  ),
                ],
              ),
              DsGroup(
                caption: l10n.onDemandNetworkHeader,
                note: _networkHelp(_rule.interface),
                child: DsSegmented<OnDemandInterface>(
                  segments: [
                    (OnDemandInterface.any, l10n.onDemandAny),
                    (OnDemandInterface.wifi, l10n.onDemandInterfaceWifi),
                    (mobile, mobile.label),
                  ],
                  value:
                      _rule.interface == OnDemandInterface.cellular ||
                          _rule.interface == OnDemandInterface.ethernet
                      ? mobile
                      : _rule.interface,
                  onChanged: (v) => _update(_rule.copyWith(interface: v)),
                ),
              ),
              DsGroup(
                caption: l10n.onDemandConditionsHeader,
                child: DsStack(
                  gap: kNoteGap,
                  children: [
                    if (_rule.ssidsApply)
                      _conditionCard(
                        glyph: Glyph.wifi,
                        title: l10n.onDemandWifiNetworks,
                        values: _rule.ssids,
                        unit: l10n.onDemandNetworksUnit,
                        addTitle: l10n.onDemandWifiNetwork,
                        addHint: 'home-5G',
                        help: l10n.onDemandWifiNetworksHelp,
                        apply: (v) => _update(_rule.copyWith(ssids: v)),
                      ),
                    _conditionCard(
                      glyph: Glyph.globe,
                      title: l10n.onDemandDnsDomains,
                      values: _rule.dnsDomains,
                      unit: l10n.onDemandDomainsUnit,
                      addTitle: l10n.onDemandDnsDomain,
                      addHint: 'corp.example.com',
                      help: l10n.onDemandDnsDomainsHelp,
                      apply: (v) => _update(_rule.copyWith(dnsDomains: v)),
                    ),
                    _conditionCard(
                      glyph: Glyph.server,
                      title: l10n.onDemandDnsServers,
                      values: _rule.dnsServers,
                      unit: l10n.onDemandServersUnit,
                      addTitle: l10n.onDemandDnsServer,
                      addHint: '10.0.*',
                      help: l10n.onDemandDnsServersHelp,
                      apply: (v) => _update(_rule.copyWith(dnsServers: v)),
                    ),
                  ],
                ),
              ),
              DsGroup(
                caption: l10n.onDemandUrlProbeHeader,
                note: l10n.onDemandUrlProbeHelp,
                child: TextField(
                  controller: _probe,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.onDemandUrlOptional,
                    hintText: 'https://intranet.example.com/ping',
                  ),
                  onChanged: (v) => _update(_rule.copyWith(probeUrl: v.trim())),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
