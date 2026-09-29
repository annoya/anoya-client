import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/country_flag.dart';
import '../core/norm_config.dart';
import '../core/platform_support.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import 'geosite_sheet.dart';

class RuleDialog extends StatefulWidget {
  const RuleDialog({this.initial, required this.geoReady, super.key});

  final RoutingRule? initial;
  final bool geoReady;

  @override
  State<RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<RuleDialog> {
  late String _type = widget.initial?.type ?? 'domain-suffix';
  late String _action = widget.initial?.action ?? 'proxy';
  late bool _noResolve = widget.initial?.noResolve ?? false;
  late final TextEditingController _value = TextEditingController(
    text: widget.initial?.value ?? '',
  );
  String? _error;

  static const _hints = {
    'domain-suffix': 'corp.example.com',
    'domain-keyword': 'jira',
    'domain-exact': 'wiki.example.com',
    'ip-cidr': '10.0.0.0/8',
    'process-name': 'Slack',
    'domain-regex': r'^.*\.example\.(com|net)$',
  };

  String? _typeDescription(String type) {
    final l10n = context.l10n;
    return switch (type) {
      'domain-suffix' => l10n.ruleTypeDomainSuffix,
      'domain-keyword' => l10n.ruleTypeDomainKeyword,
      'domain-exact' => l10n.ruleTypeDomainExact,
      'ip-cidr' => l10n.ruleTypeIpCidr,
      'process-name' => l10n.ruleTypeProcessName,
      'geoip' => l10n.ruleTypeGeoip,
      'geosite' => l10n.ruleTypeGeosite,
      'domain-regex' => l10n.ruleTypeDomainRegex,
      'rule-list' => l10n.ruleTypeRuleList,
      _ => null,
    };
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final rule = RoutingRule(
      type: _type,
      value: _type == 'geoip'
          ? _value.text.trim().toLowerCase()
          : _value.text.trim(),
      action: _action,
      noResolve: _type == 'geoip' && _noResolve,
    );
    if (!rule.isValid) {
      setState(
        () => _error = _type == 'geoip'
            ? context.l10n.rulePickCountry
            : context.l10n.ruleInvalidValue(rule.type),
      );
      return;
    }
    Navigator.of(context).pop(rule);
  }

  Future<void> _pickCountry() async {
    final code = await pickCountry(context);
    if (code != null) setState(() => _value.text = code.toLowerCase());
  }

  Future<void> _pickCategory() async {
    final cat = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const GeositeSheet(),
    );
    if (cat != null) setState(() => _value.text = cat);
  }

  Future<void> _pickType() async {
    final l10n = context.l10n;
    final picked = await pickOption<String>(
      context,
      title: l10n.ruleMatch,
      selected: _type,
      options: RoutingRule.types.where((t) => t != 'rule-list').map((t) {
        final geoLocked = (t == 'geoip' || t == 'geosite') && !widget.geoReady;
        final unsupported = t == 'process-name' && !supportsProcessRules;
        return Option(
          t,
          t,
          subtitle: unsupported
              ? l10n.ruleNotAvailableOnPlatform
              : geoLocked
              ? l10n.ruleNeedsGeoDatabases
              : _typeDescription(t),
          enabled: !geoLocked && !unsupported,
        );
      }).toList(),
    );
    if (picked == null || picked == _type) return;
    setState(() {
      _type = picked;
      _value.clear();
      _error = null;
    });
  }

  Future<void> _pickAction() async {
    final l10n = context.l10n;
    final picked = await pickOption<String>(
      context,
      title: l10n.ruleAction,
      selected: _action,
      options: [
        Option('proxy', 'proxy', subtitle: l10n.ruleActionProxyDescription),
        Option('direct', 'direct', subtitle: l10n.ruleActionDirectDescription),
        Option('block', 'block', subtitle: l10n.ruleActionBlockDescription),
      ],
    );
    if (picked != null) setState(() => _action = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.initial == null ? l10n.ruleAdd : l10n.ruleEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectField(label: l10n.ruleMatch, value: _type, onTap: _pickType),
            const SizedBox(height: 8),
            if (_type == 'geoip') ...[
              SelectField(
                label: l10n.ruleCountry,
                value: _value.text.isEmpty
                    ? l10n.ruleChoose
                    : _countryLabel(_value.text),
                trailingIcon: Icons.chevron_right,
                onTap: _pickCountry,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('no-resolve'),
                subtitle: Text(l10n.ruleNoResolveDescription),
                value: _noResolve,
                onChanged: (v) => setState(() => _noResolve = v),
              ),
            ] else if (_type == 'geosite') ...[
              SelectField(
                label: l10n.geositeCategoryLabel,
                value: _value.text.isEmpty ? l10n.ruleChoose : _value.text,
                trailingIcon: Icons.chevron_right,
                onTap: _pickCategory,
              ),
            ] else ...[
              TextField(
                controller: _value,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                // URL keyboard: Android's text one inserts a space after each full stop.
                keyboardType: TextInputType.url,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.ruleValue,
                  hintText: _hints[_type],
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 8),
            SelectField(
              label: l10n.ruleAction,
              value: _action,
              onTap: _pickAction,
            ),
            if (_summary() != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _summary()!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.error, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }

  String _countryLabel(String code) {
    final up = code.toUpperCase();
    for (final (c, name) in geoCountries()) {
      if (c == up) return '${flagEmoji(c) ?? ''}  $name ($c)';
    }
    return up;
  }

  String? _summary() {
    if (_value.text.trim().isEmpty) return null;
    final l10n = context.l10n;
    final target = switch (_type) {
      'geoip' => l10n.ruleSummaryGeoip(_countryLabel(_value.text)),
      'geosite' => l10n.ruleSummaryGeosite(_value.text),
      'process-name' => l10n.ruleSummaryProcess(_value.text),
      _ => l10n.ruleSummaryMatching(_value.text),
    };
    final verb = switch (_action) {
      'proxy' => l10n.ruleSummaryProxy,
      'direct' => l10n.ruleSummaryDirect,
      _ => l10n.ruleSummaryBlock,
    };
    return l10n.ruleSummary(
      '${target[0].toUpperCase()}${target.substring(1)}',
      verb,
    );
  }
}

Future<String?> pickCountry(BuildContext context) => pickOption<String>(
  context,
  title: context.l10n.ruleCountry,
  itemNoun: context.l10n.uiNounCountry,
  options: [
    for (final c in geoCountries())
      Option(
        c.$1,
        c.$2,
        subtitle: c.$1,
        leading: Text(
          flagEmoji(c.$1) ?? '',
          style: const TextStyle(fontSize: 22),
        ),
      ),
  ],
);
