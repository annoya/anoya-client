import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/corp_domains.dart';
import '../core/dns_plan.dart';
import '../core/ds.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';

class CorpDomainsScreen extends ConsumerWidget {
  const CorpDomainsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, int? index) async {
    final list = ref.read(routingPrefsProvider).corpDomains;
    final entry = await showDialog<CorpDomains>(
      context: context,
      builder: (_) =>
          _CorpDomainDialog(initial: index == null ? null : list[index]),
    );
    if (entry == null) return;
    await ref.read(routingPrefsProvider.notifier).update((p) {
      final next = [...p.corpDomains];
      if (index == null || index >= next.length) {
        next.add(entry);
      } else {
        next[index] = entry;
      }
      return p.copyWith(corpDomains: next);
    });
  }

  Future<void> _remove(WidgetRef ref, int index) =>
      ref.read(routingPrefsProvider.notifier).update((p) {
        final next = [...p.corpDomains];
        if (index < next.length) next.removeAt(index);
        return p.copyWith(corpDomains: next);
      });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final list = ref.watch(routingPrefsProvider.select((p) => p.corpDomains));
    return DsPage(
      title: l10n.settingsCorpDomains,
      gap: kNoteGap,
      children: [
        DsNote(l10n.corpDomainsHint),
        if (list.isNotEmpty)
          DsCard(
            children: [
              for (final (i, c) in list.indexed)
                DsRow(
                  glyph: Glyph.building2,
                  title: c.domains.join(' · '),
                  subtitle: c.server,
                  subtitleMaxLines: 1,
                  onTap: () => _edit(context, ref, i),
                  trailing: [
                    DsAction(
                      glyph: Glyph.x,
                      tooltip: l10n.commonRemove,
                      onPressed: () => _remove(ref, i),
                    ),
                  ],
                ),
            ],
          ),
        DsButton.secondary(
          label: l10n.corpDomainsAdd,
          glyph: Glyph.plus,
          onPressed: () => _edit(context, ref, null),
        ),
      ],
    );
  }
}

class _CorpDomainDialog extends StatefulWidget {
  const _CorpDomainDialog({this.initial});

  final CorpDomains? initial;

  @override
  State<_CorpDomainDialog> createState() => _CorpDomainDialogState();
}

class _CorpDomainDialogState extends State<_CorpDomainDialog> {
  late final _domains = TextEditingController(
    text: widget.initial?.domains.join(', ') ?? '',
  )..addListener(() => setState(() {}));
  late final _server = TextEditingController(text: widget.initial?.server ?? '')
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _domains.dispose();
    _server.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    final parsed = parseCorpDomains(_domains.text);
    if (parsed.invalid != null) {
      showToast(context, l10n.corpDomainsErrorDomain(parsed.invalid!));
      return;
    }
    final server = _server.text.trim();
    final error = dnsDefaultError(server);
    if (error != null) {
      showToast(context, error);
      return;
    }
    Navigator.of(
      context,
    ).pop(CorpDomains(domains: parsed.domains, server: server));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ds = context.ds;
    final parsed = parseCorpDomains(_domains.text);
    final server = _server.text.trim();
    final ready = parsed.domains.isNotEmpty && server.isNotEmpty;
    return DsDialog(
      title: l10n.settingsCorpDomains,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _domains,
            autofocus: true,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.corpDomainsDomainsLabel,
              hintText: 'corp.local',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _server,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.corpDomainsServerLabel,
              hintText: '10.0.0.53',
            ),
            onSubmitted: (_) {
              if (ready) _save();
            },
          ),
          if (ready && parsed.invalid == null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.corpDomainsSummary(parsed.domains.join(', '), server),
              style: DsType.small.copyWith(color: ds.text3),
            ),
          ],
        ],
      ),
      actions: [
        DsDialogAction(
          label: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DsDialogAction(
          label: l10n.commonSave,
          strong: true,
          onPressed: ready ? _save : null,
        ),
      ],
    );
  }
}
