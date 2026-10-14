import 'package:flutter/material.dart';

import '../core/ds.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class OnDemandValuesScreen extends StatefulWidget {
  const OnDemandValuesScreen({
    super.key,
    required this.glyph,
    required this.title,
    required this.values,
    required this.unit,
    required this.addTitle,
    required this.addHint,
    required this.help,
  });

  final Glyph glyph;

  final String title;

  final List<String> values;

  final String unit;

  final String addTitle;
  final String addHint;
  final String help;

  @override
  State<OnDemandValuesScreen> createState() => _OnDemandValuesScreenState();
}

class _OnDemandValuesScreenState extends State<OnDemandValuesScreen> {
  late List<String> _values = _sorted(widget.values);
  String _query = '';

  List<String> _sorted(List<String> v) =>
      [...v]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  Future<void> _add() async {
    final value = await promptText(
      context,
      title: widget.addTitle,
      label: context.l10n.ruleValue,
      hint: widget.addHint,
      confirmLabel: context.l10n.commonAdd,
      autocorrect: false,
    );
    final v = value?.trim() ?? '';
    if (v.isEmpty || _values.contains(v)) return;
    setState(() => _values = _sorted([..._values, v]));
  }

  Widget _valueCard(String v) => DsCard(
    children: [
      DsRow(
        glyph: widget.glyph,
        title: v,
        trailing: [
          DsAction(
            glyph: Glyph.trash,
            tooltip: context.l10n.commonRemove,
            onPressed: () =>
                setState(() => _values = _values.where((x) => x != v).toList()),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _values
        : _values.where((v) => v.toLowerCase().contains(q)).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_values);
      },
      child: DsPage(
        title: widget.title,
        fab: FloatingActionButton(
          tooltip: l10n.commonAdd,
          onPressed: _add,
          child: const GlyphIcon(Glyph.plus),
        ),
        children: [
          if (_values.length >= kSearchThreshold)
            DsSearchField(
              hint: l10n.commonSearch,
              onChanged: (v) => setState(() => _query = v),
            ),
          if (_values.isEmpty)
            DsEmptyState(
              heading: l10n.onDemandNoEntries,
              title: l10n.onDemandConditionIgnored,
              hint: widget.help,
            )
          else if (shown.isEmpty)
            DsEmptyState(title: l10n.uiNothingMatches(_query))
          else
            DsGroup(
              caption: l10n.onDemandEntriesHeader(_values.length, widget.unit),
              note: widget.help,
              child: DsStack(
                gap: kNoteGap,
                children: shown.map(_valueCard).toList(),
              ),
            ),
          const SizedBox(height: kFabSize),
        ],
      ),
    );
  }
}
