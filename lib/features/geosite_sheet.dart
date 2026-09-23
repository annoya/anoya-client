import 'package:flutter/material.dart';

import '../core/geosite_index.dart';
import '../core/service_avatar.dart';
import '../core/service_catalog.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class GeositeSheet extends StatefulWidget {
  const GeositeSheet({super.key});

  @override
  State<GeositeSheet> createState() => _GeositeSheetState();
}

class _GeositeSheetState extends State<GeositeSheet> {
  List<GeositeCategory>? _index;
  String _query = '';

  @override
  void initState() {
    super.initState();
    GeositeIndex.load().then((index) {
      if (mounted) setState(() => _index = index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        child: SizedBox(
          height: MediaQuery.of(context).size.height * kSheetMaxHeightFraction,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.geositeCategoryLabel,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (index == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (popular.isEmpty && all.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      index.isEmpty
                          ? l10n.geositeNoCategories
                          : l10n.uiNothingMatches(_query),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (popular.isNotEmpty)
                        SectionHeader(l10n.geositeSectionPopular),
                      ...popular.map((s) {
                        final c = byName[s.category]!;
                        return ListTile(
                          leading: ServiceAvatar(s.name, category: s.category),
                          title: Text(s.name),
                          subtitle: Text('${s.category} · ${subtitle(c)}'),
                          onTap: () => Navigator.of(context).pop(s.category),
                        );
                      }),
                      SectionHeader(
                        q.isEmpty
                            ? l10n.geositeSectionAll(all.length)
                            : l10n.geositeSectionAllMatch(
                                all.length,
                                index.length,
                              ),
                      ),
                      ...all.map(
                        (c) => ListTile(
                          title: Text(c.name),
                          subtitle: Text(subtitle(c)),
                          onTap: () => Navigator.of(context).pop(c.name),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
