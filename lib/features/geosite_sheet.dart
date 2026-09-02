import 'package:flutter/material.dart';

import '../core/geosite_index.dart';
import '../core/service_avatar.dart';
import '../core/service_catalog.dart';
import '../core/ui.dart';

/// Geosite category picker: everything the local GeoSite.dat contains, with
/// the curated catalog pinned as POPULAR (same names and avatars as Simple
/// mode) and the domain count telling a service apart from a three-domain
/// list.
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
    final index = _index;
    final q = _query.trim().toLowerCase();

    final byName = {for (final c in index ?? const <GeositeCategory>[]) c.name: c};
    final popular = [
      for (final s in kServiceCatalog)
        if (byName.containsKey(s.category) &&
            (q.isEmpty || s.name.toLowerCase().contains(q) || s.category.contains(q)))
          s,
    ];
    final popularCategories = {for (final s in popular) s.category};
    final all = [
      for (final c in index ?? const <GeositeCategory>[])
        if (!popularCategories.contains(c.name) && (q.isEmpty || c.name.contains(q))) c,
    ];

    String subtitle(GeositeCategory c) =>
        '${c.domainCount} domain${c.domainCount == 1 ? '' : 's'}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * kSheetMaxHeightFraction,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Category'),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (index == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (popular.isEmpty && all.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    index.isEmpty
                        ? 'No categories — download the geo databases first.'
                        : 'Nothing matches “$_query”.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(children: [
                  if (popular.isNotEmpty) const SectionHeader('POPULAR'),
                  ...popular.map((s) {
                    final c = byName[s.category]!;
                    return ListTile(
                      leading: ServiceAvatar(s.name, category: s.category),
                      title: Text(s.name),
                      subtitle: Text('${s.category} · ${subtitle(c)}'),
                      onTap: () => Navigator.of(context).pop(s.category),
                    );
                  }),
                  SectionHeader(q.isEmpty
                      ? 'ALL · ${all.length}'
                      : 'ALL · ${all.length} OF ${index.length} MATCH'),
                  ...all.map((c) => ListTile(
                        title: Text(c.name),
                        subtitle: Text(subtitle(c)),
                        onTap: () => Navigator.of(context).pop(c.name),
                      )),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
