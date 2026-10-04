import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/country_flag.dart';
import '../core/norm_config.dart';
import '../core/platform_support.dart';
import '../core/rule_values.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import 'geosite_sheet.dart';
import 'routing_widgets.dart';

class RuleScreen extends StatefulWidget {
  const RuleScreen({this.initial, required this.geoReady, super.key});

  final RoutingRule? initial;
  final bool geoReady;

  @override
  State<RuleScreen> createState() => _RuleScreenState();
}

class _RuleScreenState extends State<RuleScreen> {
  late String _type = widget.initial?.type ?? 'domain-suffix';
  late String _action = widget.initial?.action ?? 'proxy';
  late bool _noResolve = widget.initial?.noResolve ?? false;
  late final TextEditingController _text = TextEditingController(
    text: takesTextValues(_type)
        ? (widget.initial?.values ?? const []).join('\n')
        : '',
  );
  late List<String> _picked = takesTextValues(_type)
      ? []
      : List.of(widget.initial?.values ?? const []);
  late ParsedRuleValues _parsed = parseRuleValues(_type, _text.text);

  static const _hints = {
    'domain-suffix': 'corp.example.com',
    'domain-keyword': 'jira',
    'domain-exact': 'wiki.example.com',
    'ip-cidr': '10.0.0.0/8',
    'process-name': 'Slack',
    'domain-regex': r'^.*\.example\.(com|net)$',
  };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

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

  List<RoutingRule>? get _result {
    if (!takesTextValues(_type)) {
      if (_picked.isEmpty) return null;
      return [
        RoutingRule(
          type: _type,
          values: _picked,
          action: _action,
          noResolve: _type == 'geoip' && _noResolve,
        ),
      ];
    }
    final p = _parsed;
    if (p.isEmpty) return null;
    return [
      if (p.values.isNotEmpty)
        RoutingRule(type: _type, values: p.values, action: _action),
      if (p.companion.isNotEmpty)
        RoutingRule(
          type: p.companionType!,
          values: p.companion,
          action: _action,
        ),
    ];
  }

  void _reparse() =>
      setState(() => _parsed = parseRuleValues(_type, _text.text));

  void _append(String more) {
    final t = more.trim();
    if (t.isEmpty) return;
    final current = _text.text;
    _text.text = current.trim().isEmpty ? t : '${current.trimRight()}\n$t';
    _reparse();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    _append(data?.text ?? '');
  }

  Future<void> _fromFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    _append(utf8.decode(bytes, allowMalformed: true));
  }

  Future<void> _pickCountries() async {
    final picked = await pickCountries(context, selected: _picked.toSet());
    if (picked != null) setState(() => _picked = picked.toList());
  }

  Future<void> _pickCategories() async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => GeositeSheet(selected: _picked.toSet()),
    );
    if (picked != null) setState(() => _picked = picked.toList());
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
      if (takesTextValues(picked) != takesTextValues(_type) ||
          !takesTextValues(picked)) {
        _text.clear();
        _picked = [];
      }
      _type = picked;
      _parsed = parseRuleValues(_type, _text.text);
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

  void _showBad() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * kSheetMaxHeightFraction,
    ),
    builder: (context) => _UnrecognizedSheet(type: _type, bad: _parsed.bad),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    final text = takesTextValues(_type);
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(widget.initial == null ? l10n.ruleAdd : l10n.ruleEdit),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: l10n.commonSave,
            onPressed: result == null
                ? null
                : () => Navigator.of(context).pop(result),
          ),
        ],
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 24),
          children: [
            SelectField(label: l10n.ruleMatch, value: _type, onTap: _pickType),
            const SizedBox(height: 8),
            SelectField(
              label: l10n.ruleAction,
              value: _action,
              onTap: _pickAction,
            ),
            const SizedBox(height: 8),
            if (text) ..._textInput(context) else ..._geoInput(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _textInput(BuildContext context) {
    final l10n = context.l10n;
    final lineOnly = _type == 'domain-regex' || _type == 'process-name';
    return [
      Stack(
        children: [
          TextField(
            controller: _text,
            autofocus: widget.initial == null,
            autocorrect: false,
            enableSuggestions: false,
            // URL keyboard: Android's text one inserts a space after each full stop.
            keyboardType: lineOnly
                ? TextInputType.multiline
                : TextInputType.url,
            textInputAction: TextInputAction.newline,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: InputDecoration(
              labelText: _valuesLabel(l10n, _type),
              alignLabelWithHint: true,
              hintText:
                  '${_hints[_type] ?? ''}\n'
                  '${lineOnly ? l10n.ruleValuesHintLines : l10n.ruleValuesHint}',
              helperText: _text.text.trim().isEmpty
                  ? _typeDescription(_type)
                  : null,
              suffixIcon: const SizedBox(width: 54),
            ),
            onChanged: (_) => _reparse(),
          ),
          PositionedDirectional(
            top: 4,
            end: 6,
            child: IconButton(
              icon: const Icon(Icons.content_paste_go),
              tooltip: l10n.ruleValuesPaste,
              onPressed: _paste,
            ),
          ),
        ],
      ),
      if (_text.text.trim().isNotEmpty) _parseCard(context),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: OutlinedButton.icon(
          onPressed: _fromFile,
          icon: const Icon(Icons.description_outlined),
          label: Text(l10n.ruleValuesFromFile),
        ),
      ),
    ];
  }

  Widget _parseCard(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final p = _parsed;
    final rows = <Widget>[
      if (p.values.isNotEmpty)
        ListTile(
          leading: Icon(Icons.check, color: context.vpnColors.connected),
          title: Text(ruleValueCount(l10n, _type, p.values.length)),
        ),
      if (p.companion.isNotEmpty)
        ListTile(
          leading: const Icon(Icons.alt_route),
          title: Text(
            ruleValueCount(l10n, p.companionType!, p.companion.length),
          ),
          subtitle: Text(l10n.ruleValuesCompanion(p.companionType!)),
        ),
      if (p.duplicates > 0)
        ListTile(
          leading: const Icon(Icons.layers_outlined),
          title: Text(l10n.ruleValuesDuplicates(p.duplicates)),
        ),
      if (p.bad.isNotEmpty)
        ListTile(
          leading: Icon(Icons.warning_amber_rounded, color: cs.error),
          title: Text(l10n.ruleValuesUnrecognized(p.bad.length)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showBad,
        ),
    ];
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            row,
          ],
        ],
      ),
    );
  }

  List<Widget> _geoInput(BuildContext context) {
    final l10n = context.l10n;
    final geoip = _type == 'geoip';
    return [
      SelectField(
        label: geoip ? l10n.ruleCountries : l10n.ruleCategories,
        value: _picked.isEmpty
            ? l10n.ruleChoose
            : l10n.ruleSelectedCount(_picked.length),
        trailingIcon: Icons.chevron_right,
        onTap: geoip ? _pickCountries : _pickCategories,
      ),
      if (_picked.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _picked)
                InputChip(
                  label: Text(geoip ? _countryChip(v) : v),
                  onDeleted: () => setState(() => _picked.remove(v)),
                  deleteButtonTooltipMessage: l10n.commonRemove,
                ),
            ],
          ),
        ),
      if (geoip)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('no-resolve'),
          subtitle: Text(l10n.ruleNoResolveDescription),
          value: _noResolve,
          onChanged: (v) => setState(() => _noResolve = v),
        ),
      if (_summary() case final s?) _hint(context, s),
    ];
  }

  Widget _hint(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  String _countryChip(String code) {
    final up = code.toUpperCase();
    final flag = flagForCode(up);
    return flag == null ? up : '$flag $up';
  }

  String? _summary() {
    if (_picked.isEmpty) return null;
    final l10n = context.l10n;
    final target = _type == 'geoip'
        ? l10n.ruleSummaryGeoip(_picked.map(countryName).join(', '))
        : l10n.ruleSummaryGeosite(_picked.join('", "'));
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

class _UnrecognizedSheet extends StatelessWidget {
  const _UnrecognizedSheet({required this.type, required this.bad});

  final String type;
  final List<BadValue> bad;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.ruleValuesUnrecognized(bad.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final b in bad)
                  ListTile(
                    title: Text(
                      b.text,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    subtitle: Text(
                      l10n.ruleValuesBadLine(b.line, switch (b.kind) {
                        BadValueKind.domain => l10n.ruleValuesNotDomain,
                        BadValueKind.address => l10n.ruleValuesNotAddress,
                        BadValueKind.other => l10n.ruleValuesNotValid(type),
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String _valuesLabel(AppLocalizations l10n, String type) => switch (type) {
  'domain-keyword' => l10n.ruleValuesKeywords,
  'domain-regex' => l10n.ruleValuesPatterns,
  'ip-cidr' => l10n.ruleValuesSubnets,
  'process-name' => l10n.ruleValuesProcesses,
  _ => l10n.ruleValuesDomains,
};

String countryName(String code) {
  final up = code.toUpperCase();
  for (final (c, name) in geoCountries()) {
    if (c == up) return name;
  }
  return up;
}

List<Option<String>> _countryOptions() => [
  for (final c in geoCountries())
    Option(
      c.$1,
      c.$2,
      subtitle: c.$1,
      leading: Text(
        flagForCode(c.$1) ?? '',
        style: const TextStyle(fontSize: 22),
      ),
    ),
];

Future<String?> pickCountry(BuildContext context) => pickOption<String>(
  context,
  title: context.l10n.ruleCountry,
  itemNoun: context.l10n.uiNounCountry,
  options: _countryOptions(),
);

Future<Set<String>?> pickCountries(
  BuildContext context, {
  Set<String> selected = const {},
}) async {
  final picked = await pickOptions<String>(
    context,
    title: context.l10n.ruleCountries,
    options: _countryOptions(),
    selected: {for (final s in selected) s.toUpperCase()},
  );
  return picked == null ? null : {for (final p in picked) p.toLowerCase()};
}
