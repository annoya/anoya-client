import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/geo_store.dart';
import '../core/geosite_index.dart';
import '../core/norm_config.dart';
import '../core/rule_set.dart';
import '../core/service_avatar.dart';
import '../core/service_catalog.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import '../state/routing_status.dart';
import 'geosite_sheet.dart';
import 'rule_dialog.dart';
import 'routing_widgets.dart';

/// Edits one global rule set: its direction and its ordered rules, geoip and
/// geosite included. Two views over the same rules — Simple picks services
/// from a catalog, Advanced lists every rule — so switching never converts
/// anything. A policy someone else authored is shown by
/// `ManagedPolicyScreen` instead.
class RuleSetEditorScreen extends ConsumerStatefulWidget {
  const RuleSetEditorScreen(this.setId, {super.key});

  final String setId;

  @override
  ConsumerState<RuleSetEditorScreen> createState() =>
      _RuleSetEditorScreenState();
}

class _RuleSetEditorScreenState extends ConsumerState<RuleSetEditorScreen> {
  late String _name = L10n.current.ruleSetSplitTunneling;
  RoutingMode _mode = RoutingMode.full;
  RuleEditor _editor = RuleEditor.simple;
  List<RoutingRule> _rules = [];
  bool _loading = true;
  bool _isDefault = false;
  bool _geoReady = false;
  bool _geoBusy = false;
  List<GeositeCategory>? _index;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final geo = await GeoStore.status();
    if (!mounted) return;
    final set = await RuleSetStore.byId(widget.setId);
    if (!mounted) return;
    _editor = set.editor;
    _geoReady = geo.downloaded;
    _loadIndex();
    setState(() {
      _name = set.name;
      _mode = set.mode;
      _rules = List.of(set.rules);
      _isDefault = set.isDefault;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    // Grab the notifiers before any await: if the user leaves the screen while
    // the writes are in flight, ref is disposed — and the announce below must
    // still run, or the system's saved tunnel config keeps the old routing.
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    final profiles = ref.read(profilesControllerProvider.notifier);
    final sets = await RuleSetStore.load();
    final updated = [
      for (final s in sets)
        s.id == widget.setId ? s.copyWith(mode: _mode, rules: _rules) : s,
    ];
    await RuleSetStore.save(updated);
    // The edited set is what some configuration routes by, so its new mode has
    // to reach both the status shown on the home screen and the config the
    // system starts from.
    revision.bump();
    await profiles.syncTunnelConfig();
  }

  /// The category names present in the local GeoSite.dat; null while loading.
  /// Simple mode uses it to hide catalog entries the database no longer has,
  /// the geosite picker to list everything it does have.
  Future<void> _loadIndex() async {
    if (!_geoReady) return;
    final index = await GeositeIndex.load();
    if (mounted) setState(() => _index = index);
  }

  // --- Simple mode ---------------------------------------------------------
  //
  // Simple is a view over the same ordered rules, not a second format. A rule
  // is "simple-representable" when it is geosite/geoip and its action matches
  // the one the direction implies (split → proxy: picked things go through the
  // VPN; full → direct: picked things bypass it). Everything else — domains,
  // ip-cidr, block, wrong-action geo rules — is out of the catalog's language
  // and is surfaced as the "Advanced rules" row instead of being hidden or
  // dropped.

  String get _expectedAction => _mode == RoutingMode.split ? 'proxy' : 'direct';

  bool _representable(RoutingRule r) =>
      (r.type == 'geosite' || r.type == 'geoip') && r.action == _expectedAction;

  int get _advancedCount => _rules.where((r) => !_representable(r)).length;

  bool _isOn(String type, String value) => _rules.any(
    (r) => _representable(r) && r.type == type && r.value == value,
  );

  Future<void> _setOn(String type, String value, bool on) async {
    setState(() {
      _rules.removeWhere(
        (r) => _representable(r) && r.type == type && r.value == value,
      );
      if (on) {
        // Appended: whatever the advanced rules say comes first, as the
        // "Advanced rules" row promises.
        _rules.add(
          RoutingRule(type: type, value: value, action: _expectedAction),
        );
      }
    });
    await _persist();
  }

  /// Flipping the direction re-tags every catalog selection with the action
  /// the new direction implies — the user changed what "selected" means, not
  /// which things are selected.
  Future<void> _setSimpleMode(RoutingMode mode) async {
    if (mode == _mode) return;
    final old = _expectedAction;
    final now = mode == RoutingMode.split ? 'proxy' : 'direct';
    setState(() {
      _mode = mode;
      _rules = [
        for (final r in _rules)
          (r.type == 'geosite' || r.type == 'geoip') && r.action == old
              ? RoutingRule(
                  type: r.type,
                  value: r.value,
                  action: now,
                  noResolve: r.noResolve,
                )
              : r,
      ];
    });
    await _persist();
  }

  /// Advanced mode changes the direction without touching the rules: there
  /// every rule carries its own action, and the user reads them as written.
  Future<void> _setMode(RoutingMode mode) async {
    setState(() => _mode = mode);
    await _persist();
  }

  Future<void> _setEditor(RuleEditor editor) async {
    if (editor == _editor) return;
    setState(() => _editor = editor);
    // A view preference, not a traffic change: saved without touching the
    // tunnel config.
    final sets = await RuleSetStore.load();
    await RuleSetStore.save([
      for (final s in sets)
        s.id == widget.setId ? s.copyWith(editor: editor) : s,
    ]);
  }

  Future<void> _addCategory() async {
    final cat = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const GeositeSheet(),
    );
    if (cat != null) await _setOn('geosite', cat, true);
  }

  Future<void> _addCountry() async {
    final code = await pickCountry(context);
    if (code != null) await _setOn('geoip', code.toLowerCase(), true);
  }

  Future<void> _deleteSet() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.ruleSetDeleteTitle(_name)),
        content: Text(l10n.ruleSetDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Same shape as _persist: notifiers first, they outlive the screen.
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    final profiles = ref.read(profilesControllerProvider.notifier);
    final sets = await RuleSetStore.load();
    await RuleSetStore.save(sets.where((s) => s.id != widget.setId).toList());
    revision.bump();
    await profiles.syncTunnelConfig();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _downloadGeo() async {
    setState(() => _geoBusy = true);
    final ready = await downloadGeoDatabases(context);
    if (!mounted) return;
    setState(() {
      _geoBusy = false;
      if (ready != null) _geoReady = ready;
    });
  }

  Future<void> _editRule([int? index]) async {
    final rule = await showDialog<RoutingRule>(
      context: context,
      builder: (_) => RuleDialog(
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
      final r = _rules.removeAt(oldIndex);
      _rules.insert(newIndex, r);
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          if (!_isDefault && !_loading)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.ruleSetDeleteTooltip,
              onPressed: _deleteSet,
            ),
        ],
      ),
      floatingActionButton: _editor == RuleEditor.simple
          ? null
          : FloatingActionButton(
              tooltip: l10n.ruleAdd,
              onPressed: () => _editRule(),
              child: const Icon(Icons.add),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageBody(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  _editorSegment(context),
                  if (_editor == RuleEditor.advanced)
                    ..._advancedChildren(context)
                  else
                    ..._simpleChildren(context),
                ],
              ),
            ),
    );
  }

  /// Simple | Advanced — two views over the same rules, so switching is always
  /// safe and never converts anything.
  Widget _editorSegment(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<RuleEditor>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: RuleEditor.simple,
              label: Text(l10n.ruleSetSimple),
            ),
            ButtonSegment(
              value: RuleEditor.advanced,
              label: Text(l10n.settingsAdvanced),
            ),
          ],
          selected: {_editor},
          onSelectionChanged: (v) => _setEditor(v.first),
        ),
      ),
    );
  }

  List<Widget> _advancedChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      if (!_geoReady && _rules.any((r) => r.needsGeoData))
        GeoDownloadBanner(
          title: l10n.ruleSetGeoNotDownloaded,
          subtitle: l10n.ruleSetGeoNotDownloadedDetail,
          busy: _geoBusy,
          onDownload: _downloadGeo,
        ),
      RoutingModeCard(mode: _mode, onChanged: _setMode),
      SectionHeader(l10n.ruleSetRulesHeader),
      if (_rules.isEmpty)
        emptyRulesNote(context, _mode)
      else
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Own handle inside each row: the default one is placed
          // outside the card, which reads as a stray control (most
          // visibly on macOS).
          buildDefaultDragHandles: false,
          onReorderItem: _reorder,
          children: [
            for (var i = 0; i < _rules.length; i++)
              // Keyed by item identity, not slot: a position key stays with
              // the index after a drop, so the settle animation targets the
              // wrong tile.
              RuleTile(
                key: ObjectKey(_rules[i]),
                rule: _rules[i],
                geoReady: _geoReady,
                onTap: () => _editRule(i),
                onRemove: () => _removeRule(i),
                reorderIndex: i,
              ),
          ],
        ),
    ];
  }

  List<Widget> _simpleChildren(BuildContext context) {
    final l10n = context.l10n;
    if (!_geoReady) {
      // The whole catalog is geosite/geoip, so without the databases there is
      // nothing to offer — the download banner IS the screen.
      return [
        GeoDownloadBanner(
          title: l10n.ruleSetDownloadSiteLists,
          subtitle: l10n.ruleSetDownloadSiteListsDetail,
          busy: _geoBusy,
          onDownload: _downloadGeoThenIndex,
        ),
        Opacity(
          opacity: 0.38,
          child: Column(children: _serviceGroups(interactive: false)),
        ),
      ];
    }

    final q = _query.trim().toLowerCase();
    final countries = [
      for (final r in _rules)
        if (_representable(r) && r.type == 'geoip') r.value,
    ];
    final selected = _rules.where(_representable).length;

    return [
      _simpleModeCard(context),
      if (_advancedCount > 0)
        Card(
          margin: kCardMargin,
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.35),
          child: ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(l10n.ruleSetAdvancedRules(_advancedCount)),
            subtitle: Text(l10n.ruleSetAdvancedRulesDetail),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _setEditor(RuleEditor.advanced),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
        child: TextField(
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.ruleSetSearchServices,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      if (q.isEmpty) ...[
        SectionHeader(l10n.ruleSetCountriesHeader),
        // Each add row leads its section — at the tail of a 30-row catalog
        // nobody would find it — and what was added sits directly beneath it,
        // where the user just looked.
        Card(
          margin: kCardMargin,
          child: Column(
            children: [
              _addRow(l10n.ruleSetAddCountry, _addCountry),
              for (final code in countries) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                _countryRow(code),
              ],
            ],
          ),
        ),
        SectionHeader(l10n.ruleSetServicesHeader),
        Card(
          margin: kCardMargin,
          child: Column(
            children: [
              _addRow(l10n.ruleSetAddCategory, _addCategory),
              for (final cat in _extraCategories('')) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                _removableRow(
                  ServiceAvatar(cat),
                  cat,
                  () => _setOn('geosite', cat, false),
                ),
              ],
            ],
          ),
        ),
      ],
      ..._serviceGroups(interactive: true, query: q),
      Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
        child: Text(
          selected == 0
              ? (_mode == RoutingMode.split
                    ? l10n.ruleSetNothingSelectedSplit
                    : l10n.ruleSetNothingSelectedFull)
              : (_mode == RoutingMode.split
                    ? l10n.ruleSetSelectedSplit(selected)
                    : l10n.ruleSetSelectedFull(selected)),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }

  /// The direction, in the words of what it does to the things you pick.
  Widget _simpleModeCard(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<RoutingMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: RoutingMode.split,
                    label: Text(l10n.ruleSetOnlySelected),
                  ),
                  ButtonSegment(
                    value: RoutingMode.full,
                    label: Text(l10n.ruleSetAllExceptSelected),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => _setSimpleMode(v.first),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _mode == RoutingMode.split
                  ? l10n.ruleSetOnlySelectedDescription
                  : l10n.ruleSetAllExceptSelectedDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadGeoThenIndex() async {
    await _downloadGeo();
    await _loadIndex();
  }

  /// The catalog groups, filtered by the search query and by what the local
  /// database actually contains. Selections made in Advanced with categories
  /// outside the catalog show up too — Simple never hides an active rule.
  List<Widget> _serviceGroups({required bool interactive, String query = ''}) {
    // Hide entries whose category vanished from the database (upstream rename):
    // a switch that can't work is worse than an absent one.
    final have = _index == null ? null : {for (final c in _index!) c.name};
    final out = <Widget>[];

    for (final group in ServiceGroup.values) {
      final services = [
        for (final s in kServiceCatalog)
          if (s.group == group &&
              (have == null || have.contains(s.category)) &&
              (query.isEmpty ||
                  s.name.toLowerCase().contains(query) ||
                  s.category.contains(query)))
            s,
      ];
      if (services.isEmpty) continue;
      out.add(SectionHeader(group.header));
      out.add(
        Card(
          margin: kCardMargin,
          child: Column(
            children: [
              for (final (i, s) in services.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: ServiceAvatar(s.name, category: s.category),
                  title: Text(s.name),
                  value: _isOn('geosite', s.category),
                  onChanged: interactive
                      ? (v) => _setOn('geosite', s.category, v)
                      : null,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Ad-hoc categories matching the search: with no query they live under the
    // Add-category row instead, next to the control that creates them.
    final extras = _extraCategories(query);
    if (query.isNotEmpty && extras.isNotEmpty) {
      out.add(SectionHeader(context.l10n.ruleSetOtherCategoriesHeader));
      out.add(
        Card(
          margin: kCardMargin,
          child: Column(
            children: [
              for (final (i, cat) in extras.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _removableRow(
                  ServiceAvatar(cat),
                  cat,
                  interactive ? () => _setOn('geosite', cat, false) : null,
                ),
              ],
            ],
          ),
        ),
      );
    }
    return out;
  }

  /// Ad-hoc geosite categories: everything selected that the catalog can't
  /// name — added through the picker here, or authored in Advanced.
  List<String> _extraCategories(String query) {
    final catalog = {for (final s in kServiceCatalog) s.category};
    return [
      for (final r in _rules)
        if (_representable(r) &&
            r.type == 'geosite' &&
            !catalog.contains(r.value) &&
            (query.isEmpty || r.value.contains(query)))
          r.value,
    ];
  }

  Widget _addRow(String label, VoidCallback onTap) => ListTile(
    leading: const Icon(Icons.add),
    title: Text(
      label,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    onTap: onTap,
  );

  /// A row the user added (country or ad-hoc category): plain entry, delete
  /// button. Not a switch — there is no "off but keep it" state for something
  /// that only exists because it was added, and the old switch's off position
  /// deleted the row anyway, which is exactly what a switch should not do.
  Widget _removableRow(Widget leading, String title, VoidCallback? onRemove) =>
      ListTile(
        leading: leading,
        title: Text(title),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: context.l10n.commonRemove,
          onPressed: onRemove,
        ),
      );

  Widget _countryRow(String code) {
    final up = code.toUpperCase();
    String name = up;
    for (final (c, n) in geoCountries()) {
      if (c == up) name = n;
    }
    return _removableRow(
      Text(flagEmoji(up) ?? '🌐', style: const TextStyle(fontSize: 22)),
      name,
      () => _setOn('geoip', code, false),
    );
  }
}
