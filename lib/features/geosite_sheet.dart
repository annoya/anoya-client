import 'package:flutter/material.dart';

import '../core/ds.dart';
import '../core/geosite_index.dart';
import '../core/service_avatar.dart';
import '../core/service_catalog.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class GeositeSheet extends StatefulWidget {
  const GeositeSheet({super.key, this.selected});

  final Set<String>? selected;

  @override
  State<GeositeSheet> createState() => _GeositeSheetState();
}

class _GeositeSheetState extends State<GeositeSheet> {
  List<GeositeCategory>? _index;
  String _query = '';
  late final Set<String>? _picked = widget.selected == null
      ? null
      : {...widget.selected!};

  void _choose(String category) {
    final picked = _picked;
    if (picked == null) {
      Navigator.of(context).pop(category);
      return;
    }
    setState(
      () => picked.contains(category)
          ? picked.remove(category)
          : picked.add(category),
    );
  }

  Widget _row({
    required String category,
    required String title,
    required String subtitle,
    Widget? leading,
    required bool last,
  }) {
    final row = DsRow(
      leading: leading,
      title: title,
      subtitle: subtitle,
      subtitleMaxLines: 1,
      onTap: () => _choose(category),
      trailing: [
        if (_picked != null) DsCheck(checked: _picked.contains(category)),
      ],
    );
    if (last) return row;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.ds.borderSoft)),
      ),
      child: row,
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: DsCaption(text, strong: true),
  );

  @override
  void initState() {
    super.initState();
    GeositeIndex.load().then((index) {
      if (mounted) setState(() => _index = index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final index = _index;
    final q = _query.trim().toLowerCase();

    final byName = {
      for (final c in index ?? const <GeositeCategory>[]) c.name: c,
    };
    final popular = [
      for (final s in kServiceCatalog)
        if (byName.containsKey(s.category) &&
            (q.isEmpty ||
                s.name.toLowerCase().contains(q) ||
                s.category.contains(q)))
          s,
    ];
    final popularCategories = {for (final s in popular) s.category};
    final all = [
      for (final c in index ?? const <GeositeCategory>[])
        if (!popularCategories.contains(c.name) &&
            (q.isEmpty || c.name.contains(q)))
          c,
    ];

    String subtitle(GeositeCategory c) =>
        l10n.geositeDomainCount(c.domainCount);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * kSheetMaxHeightFraction,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: DsSearchField(
                  hint: l10n.geositeCategoryLabel,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (index == null)
                const Expanded(child: Center(child: DsSpinner()))
              else if (popular.isEmpty && all.isEmpty)
                Expanded(
                  child: Center(
                    child: DsEmptyState(
                      title: index.isEmpty
                          ? l10n.geositeNoCategories
                          : l10n.uiNothingMatches(_query),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (popular.isNotEmpty) ...[
                        _header(l10n.geositeSectionPopular),
                        for (final (i, s) in popular.indexed)
                          _row(
                            category: s.category,
                            leading: ServiceAvatar(
                              s.name,
                              category: s.category,
                            ),
                            title: s.name,
                            subtitle:
                                '${s.category} · ${subtitle(byName[s.category]!)}',
                            last: i == popular.length - 1,
                          ),
                        const SizedBox(height: kGroupGap),
                      ],
                      _header(
                        q.isEmpty
                            ? l10n.geositeSectionAll(all.length)
                            : l10n.geositeSectionAllMatch(
                                all.length,
                                index.length,
                              ),
                      ),
                      for (final (i, c) in all.indexed)
                        _row(
                          category: c.name,
                          title: c.name,
                          subtitle: subtitle(c),
                          last: i == all.length - 1,
                        ),
                    ],
                  ),
                ),
              if (_picked != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: DsButton(
                    label: l10n.uiDoneCount(_picked.length),
                    onPressed: () => Navigator.of(context).pop(_picked),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
