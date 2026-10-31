import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_error.dart';
import '../core/country_flag.dart';
import '../core/ds.dart';
import '../core/geo_store.dart';
import '../core/geosite_index.dart';
import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/platform_support.dart';
import '../core/rule_set.dart';
import '../core/rule_set_transfer.dart';
import '../core/service_avatar.dart';
import '../core/service_catalog.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/routing_status.dart';
import 'geosite_sheet.dart';
import 'rule_screen.dart';
import 'rule_set_qr_screen.dart';
import 'routing_widgets.dart';

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

  Future<void> _export() async {
    final l10n = context.l10n;
    final set = RuleSet(
      id: widget.setId,
      name: _name,
      mode: _mode,
      rules: _rules,
      editor: _editor,
    );
    final link = encodeRuleSetLink(set);
    final fileName = ruleSetFileName(_name);
    final fitsQr = link.length <= kRuleSetQrMaxChars;
    final to = await pickOption<_ExportTo>(
      context,
      title: l10n.ruleSetExportTitle(_name),
      options: [
        if (canShareFiles)
          Option(
            _ExportTo.share,
            l10n.ruleSetExportShare,
            subtitle: l10n.ruleSetExportShareSubtitle,
            leading: const GlyphIcon(Glyph.share),
          ),
        Option(
          _ExportTo.file,
          l10n.ruleSetExportSave,
          subtitle: fileName,
          leading: const GlyphIcon(Glyph.download),
        ),
        Option(
          _ExportTo.copy,
          l10n.ruleSetExportCopy,
          subtitle: l10n.ruleSetExportCopySubtitle,
          leading: const GlyphIcon(Glyph.copy),
        ),
        Option(
          _ExportTo.qr,
          l10n.ruleSetExportQr,
          subtitle: fitsQr
              ? l10n.ruleSetExportQrSubtitle
              : l10n.ruleSetExportQrTooLarge,
          enabled: fitsQr,
          leading: const GlyphIcon(Glyph.qrCode),
        ),
      ],
    );
    if (to == null || !mounted) return;
    try {
      switch (to) {
        case _ExportTo.share:
          final dir = await (await getTemporaryDirectory()).create(
            recursive: true,
          );
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(encodeRuleSetFile(set), flush: true);
          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)]),
          );
        case _ExportTo.file:
          final bytes = utf8.encode(encodeRuleSetFile(set));
          final writesItself = Platform.isIOS || Platform.isAndroid;
          final path = await FilePicker.platform.saveFile(
            dialogTitle: l10n.ruleSetExportSave,
            fileName: fileName,
            bytes: writesItself ? bytes : null,
          );
          if (path == null) return;
          if (!writesItself) await File(path).writeAsBytes(bytes, flush: true);
          if (mounted) showToast(context, l10n.logsSavedTo(path));
        case _ExportTo.copy:
          await Clipboard.setData(ClipboardData(text: link));
          if (mounted) showToast(context, l10n.commonCopied);
        case _ExportTo.qr:
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RuleSetQrScreen(
                name: _name,
                ruleCount: _rules.length,
                link: link,
              ),
            ),
          );
      }
    } catch (e) {
      Log.e('rule set export failed', '$e');
      if (mounted) await showErrorDialog(context, describeError(e));
    }
  }

  Future<void> _persist() async {
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    final sets = await RuleSetStore.load();
    final updated = [
      for (final s in sets)
        s.id == widget.setId ? s.copyWith(mode: _mode, rules: _rules) : s,
    ];
    await RuleSetStore.save(updated);
    revision.bump();
  }

  Future<void> _loadIndex() async {
    if (!_geoReady) return;
    final index = await GeositeIndex.load();
    if (mounted) setState(() => _index = index);
  }

  String get _expectedAction => _mode == RoutingMode.split ? 'proxy' : 'direct';

  bool _representable(RoutingRule r) =>
      (r.type == 'geosite' || r.type == 'geoip') &&
      r.values.length == 1 &&
      r.action == _expectedAction;

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
        _rules.add(
          RoutingRule(type: type, values: [value], action: _expectedAction),
        );
      }
    });
    await _persist();
  }

  bool _isServiceAddress(RoutingRule r) =>
      r.type == 'geoip' &&
      kServiceCatalog.any(
        (s) => s.geoip == r.value && _isOn('geosite', s.category),
      );

  Future<void> _setService(CatalogService s, bool on) async {
    setState(() {
      _rules.removeWhere(
        (r) =>
            _representable(r) && r.type == 'geosite' && r.value == s.category,
      );
      final tag = s.geoip;
      if (tag != null) {
        final shared = kServiceCatalog.any(
          (o) => o != s && o.geoip == tag && _isOn('geosite', o.category),
        );
        if (!shared) {
          _rules.removeWhere(
            (r) => _representable(r) && r.type == 'geoip' && r.value == tag,
          );
        }
      }
      if (on) {
        _rules.add(
          RoutingRule(
            type: 'geosite',
            values: [s.category],
            action: _expectedAction,
          ),
        );
        if (tag != null && !_isOn('geoip', tag)) {
          _rules.add(
            RoutingRule(
              type: 'geoip',
              values: [tag],
              action: _expectedAction,
              noResolve: true,
            ),
          );
        }
      }
    });
    await _persist();
  }

  Future<void> _setSimpleMode(RoutingMode mode) async {
    if (mode == _mode) return;
    final old = _expectedAction;
    final now = mode == RoutingMode.split ? 'proxy' : 'direct';
    setState(() {
      _mode = mode;
      _rules = [
        for (final r in _rules)
          (r.type == 'geosite' || r.type == 'geoip') &&
                  r.values.length == 1 &&
                  r.action == old
              ? r.copyWith(action: now)
              : r,
      ];
    });
    await _persist();
  }

  Future<void> _setMode(RoutingMode mode) async {
    setState(() => _mode = mode);
    await _persist();
  }

  Future<void> _setEditor(RuleEditor editor) async {
    if (editor == _editor) return;
    setState(() => _editor = editor);
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
    if (cat == null) return;
    final service = catalogServiceFor(cat);
    if (service != null) {
      await _setService(service, true);
    } else {
      await _setOn('geosite', cat, true);
    }
  }

  Future<void> _addCountry() async {
    final code = await pickCountry(context);
    if (code != null) await _setOn('geoip', code.toLowerCase(), true);
  }

  Future<void> _deleteSet() async {
    final l10n = context.l10n;
    final ok = await confirmAction(
      context,
      title: l10n.ruleSetDeleteTitle(_name),
      body: l10n.ruleSetDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!ok) return;
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    final sets = await RuleSetStore.load();
    await RuleSetStore.save(sets.where((s) => s.id != widget.setId).toList());
    revision.bump();
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
    final rules = await Navigator.of(context).push<List<RoutingRule>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RuleScreen(
          initial: index != null ? _rules[index] : null,
          geoReady: _geoReady,
        ),
      ),
    );
    if (rules == null || rules.isEmpty) return;
    setState(() {
      if (index != null) {
        _rules.replaceRange(index, index + 1, rules);
      } else {
        _rules.addAll(rules);
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
    final advanced = _editor == RuleEditor.advanced;
    final empty = advanced && _rules.isEmpty;
    return DsPage(
      title: _loading ? null : _name,
      actions: [
        if (!_loading)
          DsNavButton(
            glyph: Glyph.share,
            tooltip: l10n.ruleSetExport,
            onPressed: _export,
          ),
        if (!_isDefault && !_loading)
          DsNavButton(
            glyph: Glyph.trash,
            tooltip: l10n.ruleSetDeleteTooltip,
            onPressed: _deleteSet,
          ),
      ],
      fab: advanced
          ? FloatingActionButton(
              tooltip: l10n.ruleAdd,
              onPressed: () => _editRule(),
              child: const GlyphIcon(Glyph.plus),
            )
          : null,
      body: _loading
          ? const Center(child: DsSpinner())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: kScrollPadding.copyWith(bottom: 0),
                  sliver: SliverList.list(
                    children: [
                      ...gapped(
                        advanced
                            ? _advancedChildren(context)
                            : _simpleChildren(context),
                        kGroupGap,
                      ),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      kScrollPadding.left,
                      0,
                      kScrollPadding.right,
                      kScrollPadding.bottom + (advanced ? kFabSize : 0),
                    ),
                    child: empty
                        ? Center(child: emptyRulesNote(context, _mode))
                        : null,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _editorSegment(BuildContext context) {
    final l10n = context.l10n;
    return DsSegmented<RuleEditor>(
      segments: [
        (RuleEditor.simple, l10n.ruleSetSimple),
        (RuleEditor.advanced, l10n.settingsAdvanced),
      ],
      value: _editor,
      onChanged: _setEditor,
    );
  }

  List<Widget> _advancedChildren(BuildContext context) {
    final l10n = context.l10n;
    return [
      DsStack(
        children: [
          _editorSegment(context),
          if (!_geoReady && _rules.any((r) => r.needsGeoData))
            GeoDownloadBanner(
              title: l10n.ruleSetGeoNotDownloaded,
              subtitle: l10n.ruleSetGeoNotDownloadedDetail,
              busy: _geoBusy,
              onDownload: _downloadGeo,
            ),
          RoutingModeCard(mode: _mode, onChanged: _setMode),
        ],
      ),
      if (_rules.isEmpty)
        DsCaption(l10n.ruleSetRulesHeader)
      else
        DsGroup(caption: l10n.ruleSetRulesHeader, child: _rulesCard(context)),
    ];
  }

  Widget _rulesCard(BuildContext context) => DsReorderableCard<RoutingRule>(
    items: _rules,
    keyOf: ObjectKey.new,
    onReorder: _reorder,
    itemBuilder: (i, rule) => RuleTile(
      rule: rule,
      geoReady: _geoReady,
      onTap: () => _editRule(i),
      onRemove: () => _removeRule(i),
      reorderIndex: i,
    ),
  );

  List<Widget> _simpleChildren(BuildContext context) {
    final l10n = context.l10n;
    if (!_geoReady) {
      return [
        _editorSegment(context),
        GeoDownloadBanner(
          title: l10n.ruleSetDownloadSiteLists,
          subtitle: l10n.ruleSetDownloadSiteListsDetail,
          busy: _geoBusy,
          onDownload: _downloadGeoThenIndex,
        ),
        ..._serviceGroups(interactive: false),
      ];
    }

    final q = _query.trim().toLowerCase();
    final countries = [
      for (final r in _rules)
        if (_representable(r) && r.type == 'geoip' && !_isServiceAddress(r))
          r.value,
    ];
    final selected = _rules
        .where((r) => _representable(r) && !_isServiceAddress(r))
        .length;

    return [
      DsStack(
        children: [
          _editorSegment(context),
          DirectionCard<RoutingMode>(
            segments: [
              (RoutingMode.split, l10n.ruleSetOnlySelected),
              (RoutingMode.full, l10n.ruleSetAllExceptSelected),
            ],
            value: _mode,
            onChanged: _setSimpleMode,
            note: _mode == RoutingMode.split
                ? l10n.ruleSetOnlySelectedDescription
                : l10n.ruleSetAllExceptSelectedDescription,
          ),
        ],
      ),
      if (_advancedCount > 0)
        DsCard(
          color: context.ds.accentSubtle,
          children: [
            DsRow(
              glyph: Glyph.layers,
              title: l10n.ruleSetAdvancedRules(_advancedCount),
              subtitle: l10n.ruleSetAdvancedRulesDetail,
              trailing: const [DsChevron()],
              onTap: () => _setEditor(RuleEditor.advanced),
            ),
          ],
        ),
      DsSearchField(
        hint: l10n.ruleSetSearchServices,
        clearTooltip: l10n.commonClear,
        onChanged: (v) => setState(() => _query = v),
      ),
      if (q.isEmpty) ...[
        DsGroup(
          caption: l10n.ruleSetCountriesHeader,
          children: [
            _addRow(l10n.ruleSetAddCountry, _addCountry),
            for (final code in countries) _countryRow(code),
          ],
        ),
        DsGroup(
          caption: l10n.ruleSetServicesHeader,
          children: [
            _addRow(l10n.ruleSetAddCategory, _addCategory),
            for (final cat in _extraCategories(''))
              _removableRow(
                ServiceAvatar(cat),
                cat,
                () => _setOn('geosite', cat, false),
              ),
          ],
        ),
      ],
      ..._serviceGroups(interactive: true, query: q),
      DsNote(
        selected == 0
            ? (_mode == RoutingMode.split
                  ? l10n.ruleSetNothingSelectedSplit
                  : l10n.ruleSetNothingSelectedFull)
            : (_mode == RoutingMode.split
                  ? l10n.ruleSetSelectedSplit(selected)
                  : l10n.ruleSetSelectedFull(selected)),
      ),
    ];
  }

  Future<void> _downloadGeoThenIndex() async {
    await _downloadGeo();
    await _loadIndex();
  }

  List<Widget> _serviceGroups({required bool interactive, String query = ''}) {
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
      out.add(
        DsGroup(
          caption: group.header,
          children: [
            for (final s in services)
              _CatalogRow(
                service: s,
                on: _isOn('geosite', s.category),
                onChanged: interactive ? (v) => _setService(s, v) : null,
              ),
          ],
        ),
      );
    }

    final extras = _extraCategories(query);
    if (query.isNotEmpty && extras.isNotEmpty) {
      out.add(
        DsGroup(
          caption: context.l10n.ruleSetOtherCategoriesHeader,
          children: [
            for (final cat in extras)
              _removableRow(
                ServiceAvatar(cat),
                cat,
                interactive ? () => _setOn('geosite', cat, false) : null,
              ),
          ],
        ),
      );
    }
    return out;
  }

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

  Widget _addRow(String label, VoidCallback onTap) =>
      DsRow(glyph: Glyph.plusCircle, title: label, onTap: onTap);

  Widget _removableRow(Widget leading, String title, VoidCallback? onRemove) =>
      DsRow(
        leading: leading,
        title: title,
        trailing: [
          DsAction(
            glyph: Glyph.trash,
            tooltip: context.l10n.commonRemove,
            onPressed: onRemove,
          ),
        ],
      );

  Widget _countryRow(String code) {
    final up = code.toUpperCase();
    String name = up;
    for (final (c, n) in geoCountries()) {
      if (c == up) name = n;
    }
    final flag = flagForCode(up);
    return _removableRow(
      flag == null
          ? const GlyphIcon(Glyph.globe)
          : SizedBox.square(
              dimension: kRowIcon,
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 20)),
              ),
            ),
      name,
      () => _setOn('geoip', code, false),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.service, required this.on, this.onChanged});

  final CatalogService service;
  final bool on;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    Widget faded(Widget child) => change == null
        ? Opacity(opacity: kDisabledOpacity, child: child)
        : child;
    return DsRow(
      leading: faded(ServiceAvatar(service.name, category: service.category)),
      title: service.name,
      titleWidget: change == null
          ? faded(
              Text(
                service.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsType.h3.copyWith(color: context.ds.text1),
              ),
            )
          : null,
      trailing: [DsToggle(value: on, onChanged: change)],
      onTap: change == null ? null : () => change(!on),
    );
  }
}

enum _ExportTo { share, file, copy, qr }
