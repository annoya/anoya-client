import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_check.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/connection_check_controller.dart';
import '../state/session.dart';

class AdvancedConnectionScreen extends ConsumerWidget {
  const AdvancedConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(connectionCheckProvider);
    final ctrl = ref.read(connectionCheckProvider.notifier);
    final connected = ref.watch(sessionProvider).connected;
    final prefs = st.prefs;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAdvanced)),
      body: PageBody(
        child: ListView(
          children: [
            SectionHeader(l10n.advancedSectionConnectionCheck),
            Card(
              margin: kCardMargin,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.check_circle_outline),
                    title: Text(l10n.advancedCheckAfterConnecting),
                    subtitle: Text(l10n.advancedCheckAfterConnectingSubtitle),
                    value: prefs.enabled,
                    onChanged: ctrl.setEnabled,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: Text(l10n.advancedTestUrl),
                    subtitle: Text(prefs.url),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => _editUrl(context, ctrl, prefs),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(l10n.advancedGiveUpAfter),
                    subtitle: Text(l10n.advancedSeconds(prefs.timeoutSeconds)),
                    trailing: const Icon(Icons.expand_more),
                    onTap: () => _pickTimeout(context, ctrl, prefs),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 0),
              child: FilledButton(
                onPressed: (!connected || st.running) ? null : ctrl.run,
                child: st.running
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.advancedTestNow),
              ),
            ),
            if (!connected) SectionNote(l10n.advancedNeedsTunnelNote),
            if (st.last != null) ...[
              SectionHeader(l10n.advancedSectionLastCheck),
              _ResultCard(check: st.last!),
            ],
            SectionNote(l10n.advancedCheckScopeNote),
          ],
        ),
      ),
    );
  }

  Future<void> _editUrl(
    BuildContext context,
    ConnectionCheckController ctrl,
    ConnectionCheckPrefs prefs,
  ) async {
    final l10n = context.l10n;
    final typed = await promptText(
      context,
      title: l10n.advancedTestUrl,
      label: l10n.advancedUrlLabel,
      confirmLabel: l10n.commonSave,
      initial: prefs.url,
      autocorrect: false,
      resetLabel: l10n.advancedUseDefault,
      resetValue: ConnectionCheckPrefs.defaultUrl,
    );
    if (typed == null) return;
    final trimmed = typed.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        uri == null ||
        !uri.isScheme('http') && !uri.isScheme('https')) {
      if (context.mounted) {
        showToast(context, l10n.advancedInvalidUrl);
      }
      return;
    }
    await ctrl.setUrl(trimmed);
  }

  Future<void> _pickTimeout(
    BuildContext context,
    ConnectionCheckController ctrl,
    ConnectionCheckPrefs prefs,
  ) async {
    const choices = [3, 5, 10, 15];
    final l10n = context.l10n;
    final picked = await pickOption<int>(
      context,
      title: l10n.advancedGiveUpAfter,
      selected: prefs.timeoutSeconds,
      options: [for (final s in choices) Option(s, l10n.advancedSeconds(s))],
    );
    if (picked != null) await ctrl.setTimeout(picked);
  }
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.check});

  final ConnectionCheck check;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.check;
    final cs = Theme.of(context).colorScheme;
    final warn = context.vpnColors.connecting;
    final l10n = context.l10n;
    if (!check.passed) {
      return Card(
        margin: kCardMargin,
        color: warn.withValues(alpha: 0.12),
        child: ListTile(
          leading: Icon(Icons.warning_amber_outlined, color: warn),
          title: Text(l10n.advancedNoAnswer),
          subtitle: Text(l10n.advancedNoAnswerDetail(check.failure ?? '')),
          isThreeLine: true,
        ),
      );
    }
    final ago = _ago(l10n, check.at);
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: Icon(
          Icons.check_circle_outline,
          color: context.vpnColors.connected,
        ),
        title: Text(
          check.observed
              ? l10n.advancedTrafficGettingThrough
              : l10n.advancedAnsweredIn(check.delayMs ?? 0),
        ),
        subtitle: Text(
          check.via.isEmpty ? ago : l10n.advancedResultVia(ago, check.via),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  static String _ago(AppLocalizations l10n, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.commonJustNow;
    if (d.inHours < 1) return l10n.commonMinutesAgo(d.inMinutes);
    return l10n.advancedHoursAgo(d.inHours);
  }
}
