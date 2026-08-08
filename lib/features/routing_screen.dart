import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/country_flag.dart';
import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/rule_set.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../state/profiles_controller.dart';
import '../state/routing_status.dart';

/// Rule-set editor / managed-policy viewer.
///
/// [RoutingScreen.editSet] edits one global rule set (mode + ordered rules,
/// geoip/geosite included). [RoutingScreen.managed] shows a server-delivered
/// policy read-only.
class RoutingScreen extends ConsumerStatefulWidget {
  const RoutingScreen.managed(Routing this.managedPolicy, {super.key}) : setId = null;
  const RoutingScreen.editSet(String this.setId, {super.key}) : managedPolicy = null;

  final Routing? managedPolicy;
  final String? setId;

  @override
  ConsumerState<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends ConsumerState<RoutingScreen> {
  String _name = 'Split tunneling';
  String _mode = 'full';
  List<RoutingRule> _rules = [];
  bool _loading = true;
  bool _isDefault = false;
  bool _geoReady = false;
  bool _geoBusy = false;

  bool get _isManaged => widget.managedPolicy != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final geo = await GeoStore.status();
    if (_isManaged) {
      final r = widget.managedPolicy!;
      setState(() {
        _mode = r.mode;
        _rules = List.of(r.rules);
        _geoReady = geo.downloaded;
        _loading = false;
      });
      return;
    }
    final set = await RuleSetStore.byId(widget.setId);
    if (!mounted) return;
    setState(() {
      _name = set.name;
      _mode = set.mode;
      _rules = List.of(set.rules);
      _isDefault = set.isDefault;
      _geoReady = geo.downloaded;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    if (_isManaged) return;
    final sets = await RuleSetStore.load();
    final updated = [
      for (final s in sets)
        s.id == widget.setId ? s.copyWith(mode: _mode, rules: _rules) : s,
    ];
    await RuleSetStore.save(updated);
    await _announce();
  }

  /// The edited set is what some configuration routes by, so its new mode has
  /// to reach both the status shown on the home screen and the config the
  /// system starts from.
  Future<void> _announce() async {
    ref.read(ruleSetRevisionProvider.notifier).bump();
    await ref.read(profilesControllerProvider.notifier).syncTunnelConfig();
  }

  Future<void> _deleteSet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "$_name"?'),
        content: const Text('Configurations using this set fall back to Default.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final sets = await RuleSetStore.load();
    await RuleSetStore.save(sets.where((s) => s.id != widget.setId).toList());
    await _announce();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _downloadGeo() async {
    setState(() => _geoBusy = true);
    try {
      await GeoStore.download();
      final geo = await GeoStore.status();
      if (mounted) setState(() => _geoReady = geo.downloaded);
    } catch (e) {
      Log.e('geo download failed', '$e');
      if (mounted) {
        showToast(context, describeError(e, subject: 'the database host').line);
      }
    } finally {
      if (mounted) setState(() => _geoBusy = false);
    }
  }

  Future<void> _editRule([int? index]) async {
    final rule = await showDialog<RoutingRule>(
      context: context,
      builder: (_) => _RuleDialog(
        initial: index != null ? _rules[index] : null,
        geoReady: _geoReady,
      ),
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
      appBar: AppBar(
        title: Text(_isManaged ? 'Split tunneling' : _name),
        actions: [
          if (!_isManaged && !_isDefault && !_loading)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete rule set',
              onPressed: _deleteSet,
            ),
        ],
      ),
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
                  if (!_geoReady && _hasGeoRules) _geoBanner(context),
                  _modeCard(context),
                  const SectionHeader('RULES — FIRST MATCH WINS'),
                  if (_rules.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(kGutter),
                      child: Text(
                        _mode == 'split'
                            ? 'No rules: no traffic goes through the VPN. Add rules for what should be tunneled.'
                            : 'No rules: all traffic goes through the VPN.',
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  else if (_isManaged)
                    ..._rules.asMap().entries.map((e) => _ruleTile(e.key, e.value))
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Own handle inside each row: the default one is placed
                      // outside the card, which reads as a stray control (most
                      // visibly on macOS).
                      buildDefaultDragHandles: false,
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

  bool get _hasGeoRules => _rules.any((r) => r.needsGeoData);

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

  Widget _geoBanner(BuildContext context) {
    final warn = context.vpnColors.connecting;
    return Card(
      margin: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
      color: warn.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 12, 10),
        child: Column(children: [
          ListTile(
            leading: Icon(Icons.public_off, color: warn),
            title: const Text('Geo databases not downloaded'),
            subtitle: const Text('geoip / geosite rules are inactive until then (~25 MB)'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _geoBusy ? null : _downloadGeo,
              child: _geoBusy
                  ? const SizedBox(
                      height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Download'),
            ),
          ),
        ]),
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
            // Full width, half and half, no leading check — the check would
            // shrink the labels and shift them off-centre.
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
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
            ),
            const SizedBox(height: 8),
            Text(
              _mode == 'full'
                  ? 'All traffic goes through the VPN; rules define exceptions.'
                  : 'Only traffic matching the rules goes through the VPN; the rest connects directly.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleTile(int index, RoutingRule rule, {Key? key}) {
    final actionColor = switch (rule.action) {
      'proxy' => context.vpnColors.connected,
      'direct' => context.vpnColors.direct,
      _ => Theme.of(context).colorScheme.error,
    };
    final inactive = rule.needsGeoData && !_geoReady;
    final title = rule.type == 'geoip' ? _geoipTitle(rule.value) : rule.value;
    final subtitle = inactive
        ? '${rule.type} · inactive — no database'
        : rule.noResolve
            ? '${rule.type} · no-resolve'
            : rule.type;
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      key: key,
      opacity: inactive ? 0.45 : 1,
      child: Card(
        margin: kCardMargin,
        child: InkWell(
          onTap: _isManaged ? null : () => _editRule(index),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              SizedBox(
                width: 46,
                child: Text(
                  rule.action.toUpperCase(),
                  style:
                      TextStyle(color: actionColor, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (!_isManaged) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeRule(index),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(Icons.drag_handle, size: 20, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  String _geoipTitle(String code) {
    final up = code.toUpperCase();
    final flag = flagEmoji(up) ?? '';
    return flag.isEmpty ? up : '$flag  $up';
  }
}

/// Rule editor dialog. The value control depends on the match type: free text
/// for domains/CIDR/process, a country picker for geoip (+ no-resolve switch),
/// a category field with popular suggestions for geosite.
class _RuleDialog extends StatefulWidget {
  const _RuleDialog({this.initial, required this.geoReady});

  final RoutingRule? initial;
  final bool geoReady;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
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
    'geosite': 'netflix',
  };

  static const _typeDescriptions = {
    'domain-suffix': 'domain and subdomains',
    'domain-keyword': 'domain contains',
    'domain-exact': 'exact domain',
    'ip-cidr': 'IP range',
    'process-name': 'app (desktop only)',
    'geoip': 'country by IP',
    'geosite': 'domain lists',
  };

  static const _geositeSuggestions = [
    'netflix', 'youtube', 'telegram', 'google', 'category-ads-all', 'category-ru',
  ];

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
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _CountrySheet(),
    );
    if (code != null) setState(() => _value.text = code.toLowerCase());
  }

  Future<void> _pickType() async {
    final picked = await pickOption<String>(
      context,
      title: 'Match',
      selected: _type,
      options: RoutingRule.types.map((t) {
        final geoLocked = (t == 'geoip' || t == 'geosite') && !widget.geoReady;
        return Option(
          t,
          t,
          subtitle: geoLocked ? 'needs geo databases' : _typeDescriptions[t],
          enabled: !geoLocked,
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
            ] else ...[
              TextField(
                controller: _value,
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(labelText: 'Value', hintText: _hints[_type]),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              if (_type == 'geosite')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _geositeSuggestions
                        .map((s) => ActionChip(
                              label: Text(s, style: const TextStyle(fontSize: 12)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _value.text = s),
                            ))
                        .toList(),
                  ),
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

/// Country picker for geoip rules: searchable list built from the same
/// country/alias table the flags use.
class _CountrySheet extends StatefulWidget {
  const _CountrySheet();

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = geoCountries()
        .where((c) => q.isEmpty || c.$2.toLowerCase().contains(q) || c.$1.toLowerCase() == q)
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Country', hintText: 'Name or ISO code'),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: items
                    .map((c) => ListTile(
                          leading: Text(flagEmoji(c.$1) ?? '',
                              style: const TextStyle(fontSize: 22)),
                          title: Text(c.$2),
                          subtitle: Text(c.$1),
                          onTap: () => Navigator.of(context).pop(c.$1),
                        ))
                    .toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
