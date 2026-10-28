import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/ds.dart';
import '../core/file_open.dart';
import '../core/log.dart';
import '../core/platform_support.dart';
import '../core/rule_set.dart';
import '../core/rule_set_transfer.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import '../state/routing_status.dart';
import 'qr_scan_screen.dart';
import 'rule_set_editor_screen.dart';
import 'rule_set_import_screen.dart';

class RuleSetsScreen extends ConsumerStatefulWidget {
  const RuleSetsScreen({super.key});

  @override
  ConsumerState<RuleSetsScreen> createState() => _RuleSetsScreenState();
}

class _RuleSetsScreenState extends ConsumerState<RuleSetsScreen> {
  List<RuleSet> _sets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await RuleSetStore.load();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await promptText(
      context,
      title: l10n.ruleSetNew,
      label: l10n.commonName,
      hint: l10n.ruleSetNameHint,
      confirmLabel: l10n.ruleSetCreate,
      errorOf: (value) =>
          switch (takenRuleSetName(_sets.map((s) => s.name), value)) {
            final taken? => l10n.ruleSetNameTaken(taken),
            null => null,
          },
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final set = RuleSet(
      id: 'rs${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: trimmed,
    );
    final revision = ref.read(ruleSetRevisionProvider.notifier);
    await RuleSetStore.save([..._sets, set]);
    revision.bump();
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RuleSetEditorScreen(set.id)));
    await _load();
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final from = await pickOption<_ImportFrom>(
      context,
      title: l10n.ruleSetImport,
      options: [
        if (canOpenFiles)
          Option(
            _ImportFrom.file,
            l10n.ruleSetImportFromFile,
            subtitle: l10n.ruleSetImportFromFileSubtitle,
            leading: const GlyphIcon(Glyph.folder),
          ),
        Option(
          _ImportFrom.clipboard,
          l10n.ruleSetImportFromClipboard,
          subtitle: l10n.ruleSetImportFromClipboardSubtitle,
          leading: const GlyphIcon(Glyph.clipboard),
        ),
        if (canScanQr)
          Option(
            _ImportFrom.qr,
            l10n.startScanQr,
            subtitle: l10n.ruleSetImportScanSubtitle,
            leading: const GlyphIcon(Glyph.scan),
          ),
      ],
    );
    if (from == null || !mounted) return;
    final (text, name) = switch (from) {
      _ImportFrom.file => await _readFile(),
      _ImportFrom.clipboard => (
        (await Clipboard.getData(Clipboard.kTextPlain))?.text,
        '',
      ),
      _ImportFrom.qr => (await _scan(), ''),
    };
    if (text == null || !mounted) return;
    final imported = parseRuleSetImport(text, fallbackName: name);
    if (imported == null) {
      Log.e('rule set import refused', from.name);
      showToast(context, l10n.ruleSetImportUnreadable);
      return;
    }
    final added = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RuleSetImportScreen(
          import: imported,
          takenNames: [for (final s in _sets) s.name],
        ),
      ),
    );
    await _load();
    if (added != null && mounted) {
      showToast(context, l10n.ruleSetImportAdded(added));
    }
  }

  Future<(String?, String)> _readFile() async {
    final OpenedFile? file;
    try {
      file = await openFile();
    } catch (e) {
      Log.e('rule set file not read', '$e');
      if (mounted) showErrorDialog(context, describeError(e));
      return (null, '');
    }
    if (file == null) return (null, '');
    final base = file.name
        .replaceFirst(RegExp(r'\.anoya-rules\.json$'), '')
        .replaceFirst(RegExp(r'\.[^.]+$'), '');
    return (utf8.decode(file.bytes, allowMalformed: true), base);
  }

  Future<String?> _scan() => Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => QrScanScreen(
        hint: context.l10n.ruleSetImportScanHint,
        refuse: (text) => parseRuleSetImport(text) == null
            ? L10n.current.ruleSetImportNotARuleSet
            : null,
      ),
    ),
  );

  String _subtitle(RuleSet s, Map<String, int> usage) {
    final l10n = context.l10n;
    final mode = s.mode.label;
    final rules = l10n.ruleSetRuleCount(s.rules.length);
    final used = usage[s.id] ?? 0;
    return used > 0
        ? l10n.ruleSetSummaryUsed(mode, rules, l10n.ruleSetUsedBy(used))
        : l10n.ruleSetSummary(mode, rules);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = ref.watch(profilesControllerProvider).profiles;
    final usage = <String, int>{};
    for (final p in profiles) {
      if (p.routing != null) continue;
      final id = p.ruleSetId ?? RuleSet.defaultId;
      usage[id] = (usage[id] ?? 0) + 1;
    }

    return DsPage(
      title: l10n.ruleSetsTitle,
      actions: [
        DsNavButton(
          glyph: Glyph.download,
          tooltip: l10n.ruleSetImport,
          onPressed: _loading ? null : _import,
        ),
      ],
      fab: FloatingActionButton(
        tooltip: l10n.ruleSetNew,
        onPressed: _create,
        child: const GlyphIcon(Glyph.plus),
      ),
      body: _loading ? const Center(child: DsSpinner()) : null,
      children: [
        DsStack(
          gap: kNoteGap,
          children: [
            for (final s in _sets)
              DsCard(
                children: [
                  DsRow(
                    glyph: Glyph.layers,
                    title: s.name,
                    subtitle: _subtitle(s, usage),
                    trailing: const [DsChevron()],
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RuleSetEditorScreen(s.id),
                        ),
                      );
                      await _load();
                    },
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: kFabSize),
      ],
    );
  }
}

enum _ImportFrom { file, clipboard, qr }
