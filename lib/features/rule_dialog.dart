import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/country_flag.dart';
import '../core/norm_config.dart';
import '../core/platform_support.dart';
import '../core/ui.dart';
import 'geosite_sheet.dart';

/// Rule editor dialog. The value control depends on the match type: free text
/// for domains/CIDR/process, a country picker for geoip (+ no-resolve switch),
/// a category field with popular suggestions for geosite.
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
  late final TextEditingController _value =
      TextEditingController(text: widget.initial?.value ?? '');
  String? _error;

  static const _hints = {
    'domain-suffix': 'corp.example.com',
    'domain-keyword': 'jira',
    'domain-exact': 'wiki.example.com',
    'ip-cidr': '10.0.0.0/8',
    'process-name': 'Slack',
    'domain-regex': r'^.*\.example\.(com|net)$',
  };

  static const _typeDescriptions = {
    'domain-suffix': 'domain and subdomains',
    'domain-keyword': 'domain contains',
    'domain-exact': 'exact domain',
    'ip-cidr': 'IP range',
    'process-name': 'app by name',
    'geoip': 'country by IP',
    'geosite': 'domain lists',
    'domain-regex': 'domain matches a pattern',
    'rule-list': 'a list from your subscription',
  };

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final rule = RoutingRule(
      type: _type,
      value: _type == 'geoip' ? _value.text.trim().toLowerCase() : _value.text.trim(),
      action: _action,
      noResolve: _type == 'geoip' && _noResolve,
    );
    if (!rule.isValid) {
      setState(() => _error = _type == 'geoip'
          ? 'Pick a country.'
          : 'Invalid value for ${rule.type}.');
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
    final picked = await pickOption<String>(
      context,
      title: 'Match',
      selected: _type,
      // rule-list is absent by design: a list rule is only meaningful next to
      // the definition of where that list comes from, and only a provider's
      // policy carries those. Offering it here would let the user author a
      // rule that can never match.
      options: RoutingRule.types.where((t) => t != 'rule-list').map((t) {
        final geoLocked = (t == 'geoip' || t == 'geosite') && !widget.geoReady;
        final unsupported = t == 'process-name' && !supportsProcessRules;
        return Option(
          t,
          t,
          subtitle: unsupported
              ? 'not available on this platform'
              : geoLocked
                  ? 'needs geo databases'
                  : _typeDescriptions[t],
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
    final picked = await pickOption<String>(
      context,
      title: 'Action',
      selected: _action,
      options: const [
        Option('proxy', 'proxy', subtitle: 'through the VPN'),
        Option('direct', 'direct', subtitle: 'bypass the VPN'),
        Option('block', 'block', subtitle: 'drop the connection'),
      ],
    );
    if (picked != null) setState(() => _action = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add rule' : 'Edit rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectField(label: 'Match', value: _type, onTap: _pickType),
            const SizedBox(height: 8),
            if (_type == 'geoip') ...[
              SelectField(
                label: 'Country',
                value: _value.text.isEmpty ? 'Choose…' : _countryLabel(_value.text),
                trailingIcon: Icons.chevron_right,
                onTap: _pickCountry,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('no-resolve'),
                subtitle: const Text('Match only plain-IP connections, don’t resolve domains'),
                value: _noResolve,
                onChanged: (v) => setState(() => _noResolve = v),
              ),
            ] else if (_type == 'geosite') ...[
              // Picked, never typed: only what the local database really has
              // can be chosen, so a typo can't produce a category the engine
              // will fail to load.
              SelectField(
                label: 'Category',
                value: _value.text.isEmpty ? 'Choose…' : _value.text,
                trailingIcon: Icons.chevron_right,
                onTap: _pickCategory,
              ),
            ] else ...[
              TextField(
                controller: _value,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                // A URL keyboard: Android's text keyboard puts a space after
                // every full stop it sees, and "vk. ru" is not a domain. The
                // formatter is the second line of defence — a pasted value
                // with a space in it never becomes one in the rule.
                keyboardType: TextInputType.url,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                decoration: InputDecoration(labelText: 'Value', hintText: _hints[_type]),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 8),
            SelectField(label: 'Action', value: _action, onTap: _pickAction),
            if (_summary() != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_summary()!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
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

  /// Human-readable preview of what this rule will do.
  String? _summary() {
    if (_value.text.trim().isEmpty) return null;
    final target = switch (_type) {
      'geoip' => 'traffic to IPs in ${_countryLabel(_value.text)}',
      'geosite' => '"${_value.text}" domains (GeoSite list)',
      'process-name' => 'traffic of "${_value.text}"',
      _ => 'traffic matching ${_value.text}',
    };
    final verb = switch (_action) {
      'proxy' => 'goes through the VPN',
      'direct' => 'connects directly, bypassing the VPN',
      _ => 'is blocked',
    };
    return '→ ${target[0].toUpperCase()}${target.substring(1)} $verb.';
  }
}

/// Country picker for geoip rules: the shared sheet over the same
/// country/alias table the flags use (ISO code in the subtitle so it is
/// searchable by either).
Future<String?> pickCountry(BuildContext context) => pickOption<String>(
      context,
      title: 'Country',
      itemNoun: 'country',
      options: [
        for (final c in geoCountries())
          Option(c.$1, c.$2,
              subtitle: c.$1,
              leading: Text(flagEmoji(c.$1) ?? '', style: const TextStyle(fontSize: 22))),
      ],
    );
