import 'package:flutter/material.dart';

import '../core/ui.dart';

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

  /// Search only earns its place once the list is long enough to scan.
  static const _searchThreshold = 6;

  List<String> _sorted(List<String> v) =>
      [...v]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  Future<void> _add() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.addTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: InputDecoration(labelText: 'Value', hintText: widget.addHint),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    final v = value?.trim() ?? '';
    if (v.isEmpty || _values.contains(v)) return;
    setState(() => _values = _sorted([..._values, v]));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          tooltip: 'Add',
          onPressed: _add,
          child: const Icon(Icons.add),
        ),
        body: PageBody(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (_values.length >= _searchThreshold)
                Padding(
                  padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 0),
                  child: TextField(
                    autocorrect: false,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search',
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              SectionHeader(_values.isEmpty
                  ? 'NO ENTRIES'
                  : '${_values.length} ${widget.unit} · ANY OF THEM MATCHES'),
              if (_values.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Text(
                    'The condition is ignored and the rule matches any network of the selected type.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Text('Nothing matches “$_query”.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              else
                ...shown.map((v) => Card(
                      margin: kCardMargin,
                      child: ListTile(
                        title: Text(v),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Remove',
                          onPressed: () =>
                              setState(() => _values = _values.where((x) => x != v).toList()),
                        ),
                      ),
                    )),
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
                child: Text(widget.help,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
