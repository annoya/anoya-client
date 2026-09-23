import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../l10n/l10n.dart';

/// Editor for one condition list of an on-demand rule (Wi-Fi networks, DNS
/// search domains, DNS servers).
///
/// The list is kept sorted and has no manual ordering: the system matches when
/// *any* entry matches and the rule has a single action, so the order is not
/// observable. Priority between different actions is expressed by the order of
/// the rules themselves.
class OnDemandValuesScreen extends StatefulWidget {
  const OnDemandValuesScreen({
    super.key,
    required this.title,
    required this.values,
    required this.unit,
    required this.addTitle,
    required this.addHint,
    required this.help,
  });

  final String title;

  /// Current entries; the screen returns the edited list on pop.
  final List<String> values;

  /// What one entry is called in the section header ("networks", "domains").
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        floatingActionButton: FloatingActionButton(
          tooltip: l10n.commonAdd,
          onPressed: _add,
          child: const Icon(Icons.add),
        ),
        body: PageBody(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (_values.length >= kSearchThreshold)
                Padding(
                  padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
                  child: TextField(
                    autocorrect: false,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.commonSearch,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              SectionHeader(
                _values.isEmpty
                    ? l10n.onDemandNoEntries
                    : l10n.onDemandEntriesHeader(_values.length, widget.unit),
              ),
              if (_values.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Text(
                    l10n.onDemandConditionIgnored,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Text(
                    l10n.uiNothingMatches(_query),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                ...shown.map(
                  (v) => Card(
                    margin: kCardMargin,
                    child: ListTile(
                      title: Text(v),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: l10n.commonRemove,
                        onPressed: () => setState(
                          () => _values = _values.where((x) => x != v).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
                child: Text(
                  widget.help,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
