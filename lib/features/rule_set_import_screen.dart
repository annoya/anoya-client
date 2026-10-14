import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ds.dart';
import '../core/geo_store.dart';
import '../core/rule_set.dart';
import '../core/rule_set_transfer.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../state/routing_status.dart';
import 'routing_widgets.dart';

class RuleSetImportScreen extends ConsumerStatefulWidget {
  const RuleSetImportScreen({
    super.key,
    required this.import,
    this.takenNames = const [],
  });

  final RuleSetImport import;

  final List<String> takenNames;

  @override
  ConsumerState<RuleSetImportScreen> createState() =>
      _RuleSetImportScreenState();
}

class _RuleSetImportScreenState extends ConsumerState<RuleSetImportScreen> {
  late final _name = TextEditingController(
    text: uniqueRuleSetName(
      widget.import.name.isEmpty
          ? L10n.current.ruleSetImportDefaultName
          : widget.import.name,
      widget.takenNames,
    ),
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _effectiveName => _name.text.trim().isEmpty
      ? L10n.current.ruleSetImportDefaultName
      : _name.text.trim();

  String? get _taken => takenRuleSetName(widget.takenNames, _effectiveName);

  Future<void> _add() async {
    final name = _effectiveName;
    setState(() => _busy = true);
    final imported = widget.import;
    final set = RuleSet(
      id: 'rs${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: name,
      mode: imported.mode,
      rules: imported.rules,
      editor: imported.editor,
    );
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    await RuleSetStore.save([...await RuleSetStore.load(), set]);
    revision.bump();
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final imported = widget.import;
    final counts = [
      if (imported.countOf('direct') > 0)
        l10n.ruleSetImportDirect(imported.countOf('direct')),
      if (imported.countOf('proxy') > 0)
        l10n.ruleSetImportProxy(imported.countOf('proxy')),
      if (imported.countOf('block') > 0)
        l10n.ruleSetImportBlock(imported.countOf('block')),
    ];
    final full = imported.mode == RoutingMode.full;
    return DsPage(
      leading: DsLeading.close,
      title: l10n.ruleSetImportTitle,
      dock: [
        DsButton(
          label: l10n.ruleSetImportAdd,
          busy: _busy,
          onPressed: _taken != null ? null : _add,
        ),
      ],
      children: [
        DsStack(
          gap: kNoteGap,
          children: [
            TextField(
              controller: _name,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.commonName,
                errorText: switch (_taken) {
                  final taken? => l10n.ruleSetNameTaken(taken),
                  null => null,
                },
              ),
            ),
            DsCard(
              children: [
                DsRow(
                  glyph: Glyph.file,
                  title: _sourceLabel(l10n, imported.source),
                  subtitle: imported.source == RuleSetSource.anoya
                      ? l10n.ruleSetImportAsIs
                      : l10n.ruleSetImportMigrated,
                ),
                DsRow(
                  glyph: Glyph.split,
                  title: full ? l10n.ruleSetModeFull : l10n.ruleSetModeSplit,
                  subtitle: full
                      ? l10n.ruleSetModeFullDescription
                      : l10n.ruleSetModeSplitDescription,
                ),
                DsRow(
                  glyph: Glyph.list,
                  title: l10n.ruleSetImportRules(imported.rules.length),
                  subtitle: counts.isEmpty ? null : counts.join(' · '),
                  trailing: [if (imported.rules.isNotEmpty) const DsChevron()],
                  onTap: imported.rules.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _ImportedRulesScreen(
                              title: l10n.ruleSetImportRules(
                                imported.rules.length,
                              ),
                              import: imported,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            if (imported.skipped.isNotEmpty)
              DsGroup(
                caption: l10n.ruleSetImportSkipped,
                children: [
                  for (final part in imported.skipped) _skippedRow(l10n, part),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _skippedRow(AppLocalizations l10n, SkippedPart part) {
    final (glyph, title, detail) = switch (part.reason) {
      SkipReason.dns => (
        Glyph.globe,
        l10n.ruleSetImportSkipDns,
        l10n.ruleSetImportSkipDnsDetail,
      ),
      SkipReason.geoUrls => (
        Glyph.globe,
        l10n.ruleSetImportSkipGeo,
        l10n.ruleSetImportSkipGeoDetail,
      ),
      SkipReason.ruleLists => (
        Glyph.link,
        l10n.ruleSetImportSkipLists(part.count),
        l10n.ruleSetImportSkipListsDetail,
      ),
      SkipReason.unsupported => (
        Glyph.x,
        l10n.ruleSetImportSkipOther(part.count),
        part.kinds.join(', '),
      ),
    };
    return DsRow(
      glyph: glyph,
      title: title,
      subtitle: detail.isEmpty ? null : detail,
    );
  }
}

String _sourceLabel(AppLocalizations l10n, RuleSetSource source) =>
    switch (source) {
      RuleSetSource.anoya => l10n.ruleSetImportSourceAnoya,
      RuleSetSource.clash => l10n.ruleSetImportSourceClash,
      RuleSetSource.surge => l10n.ruleSetImportSourceSurge,
      RuleSetSource.happ => l10n.ruleSetImportSourceHapp,
    };

class _ImportedRulesScreen extends StatefulWidget {
  const _ImportedRulesScreen({required this.title, required this.import});

  final String title;
  final RuleSetImport import;

  @override
  State<_ImportedRulesScreen> createState() => _ImportedRulesScreenState();
}

class _ImportedRulesScreenState extends State<_ImportedRulesScreen> {
  bool _geoReady = true;

  @override
  void initState() {
    super.initState();
    GeoStore.status().then((geo) {
      if (mounted) setState(() => _geoReady = geo.downloaded);
    });
  }

  @override
  Widget build(BuildContext context) => DsPage(
    title: widget.title,
    children: [
      DsGroup(
        caption: context.l10n.ruleSetRulesHeader,
        children: [
          for (final rule in widget.import.rules)
            RuleTile(rule: rule, geoReady: _geoReady),
        ],
      ),
    ],
  );
}
