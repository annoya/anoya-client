import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo_store.dart';
import '../core/rule_set.dart';
import '../core/rule_set_transfer.dart';
import '../core/ui.dart';
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

  Future<void> _add() async {
    final name = _name.text.trim().isEmpty
        ? context.l10n.ruleSetImportDefaultName
        : _name.text.trim();
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
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(l10n.ruleSetImportTitle),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 16),
          child: FilledButton(
            onPressed: _busy ? null : _add,
            child: Text(l10n.ruleSetImportAdd),
          ),
        ),
      ),
      body: PageBody(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 4),
              child: TextField(
                controller: _name,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l10n.commonName),
              ),
            ),
            Card(
              margin: kCardMargin,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(_sourceLabel(l10n, imported.source)),
                    subtitle: Text(
                      imported.source == RuleSetSource.anoya
                          ? l10n.ruleSetImportAsIs
                          : l10n.ruleSetImportMigrated,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.alt_route),
                    title: Text(
                      full ? l10n.ruleSetModeFull : l10n.ruleSetModeSplit,
                    ),
                    subtitle: Text(
                      full
                          ? l10n.ruleSetModeFullDescription
                          : l10n.ruleSetModeSplitDescription,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.layers_outlined),
                    title: Text(l10n.ruleSetImportRules(imported.rules.length)),
                    subtitle: counts.isEmpty ? null : Text(counts.join(' · ')),
                    trailing: imported.rules.isEmpty
                        ? null
                        : const Icon(Icons.chevron_right),
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
            ),
            if (imported.skipped.isNotEmpty) ...[
              SectionHeader(l10n.ruleSetImportSkipped),
              Card(
                margin: kCardMargin,
                child: Column(
                  children: [
                    for (final (i, part) in imported.skipped.indexed) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      _skippedTile(l10n, part),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _skippedTile(AppLocalizations l10n, SkippedPart part) {
    final (icon, title, detail) = switch (part.reason) {
      SkipReason.dns => (
        Icons.language_outlined,
        l10n.ruleSetImportSkipDns,
        l10n.ruleSetImportSkipDnsDetail,
      ),
      SkipReason.geoUrls => (
        Icons.public,
        l10n.ruleSetImportSkipGeo,
        l10n.ruleSetImportSkipGeoDetail,
      ),
      SkipReason.ruleLists => (
        Icons.link,
        l10n.ruleSetImportSkipLists(part.count),
        l10n.ruleSetImportSkipListsDetail,
      ),
      SkipReason.unsupported => (
        Icons.do_not_disturb_alt_outlined,
        l10n.ruleSetImportSkipOther(part.count),
        part.kinds.join(', '),
      ),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: detail.isEmpty ? null : Text(detail),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: PageBody(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionHeader(context.l10n.ruleSetRulesHeader),
          for (final rule in widget.import.rules)
            RuleTile(rule: rule, geoReady: _geoReady),
        ],
      ),
    ),
  );
}
