import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_check.dart';
import '../core/ds.dart';
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

    return DsPage(
      title: l10n.settingsAdvanced,
      children: [
        DsGroup(
          caption: l10n.advancedSectionConnectionCheck,
          children: [
            DsRow(
              glyph: Glyph.activity,
              title: l10n.advancedCheckAfterConnecting,
              subtitle: l10n.advancedCheckAfterConnectingSubtitle,
              onTap: () => ctrl.setEnabled(!prefs.enabled),
              trailing: [
                DsToggle(value: prefs.enabled, onChanged: ctrl.setEnabled),
              ],
            ),
            DsRow(
              glyph: Glyph.globe,
              title: l10n.advancedTestUrl,
              subtitle: prefs.url,
              onTap: () => _editUrl(context, ctrl, prefs),
              trailing: [
                DsAction(
                  glyph: Glyph.pencil,
                  tooltip: l10n.commonEdit,
                  onPressed: () => _editUrl(context, ctrl, prefs),
                ),
              ],
            ),
            DsRow(
              glyph: Glyph.timer,
              title: l10n.advancedGiveUpAfter,
              subtitle: l10n.advancedSeconds(prefs.timeoutSeconds),
              onTap: () => _pickTimeout(context, ctrl, prefs),
              trailing: const [DsChevron(down: true)],
            ),
          ],
        ),
        DsStack(
          gap: kNoteGap,
          children: [
            DsButton(
              label: l10n.advancedTestNow,
              busy: st.running,
              onPressed: connected ? ctrl.run : null,
            ),
            if (!connected) DsNote(l10n.advancedNeedsTunnelNote),
            if (st.last == null) DsNote(l10n.advancedCheckScopeNote),
          ],
        ),
        if (st.last != null) ...[
          DsGroup(
            caption: l10n.advancedSectionLastCheck,
            child: _ResultCard(check: st.last!),
          ),
          DsNote(l10n.advancedCheckScopeNote),
        ],
      ],
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
    final ds = context.ds;
    final l10n = context.l10n;
    if (!check.passed) {
      return DsNotification(
        glyph: Glyph.alertTriangle,
        tone: DsTone.warning,
        boldTitle: true,
        title: l10n.advancedNoAnswer,
        body: l10n.advancedNoAnswerDetail(check.failure ?? ''),
      );
    }
    final ago = _ago(l10n, check.at);
    return DsCard(
      children: [
        DsRow(
          leading: GlyphIcon(Glyph.check, color: ds.success),
          title: check.observed
              ? l10n.advancedTrafficGettingThrough
              : l10n.advancedAnsweredIn(check.delayMs ?? 0),
          subtitle: check.via.isEmpty
              ? ago
              : l10n.advancedResultVia(ago, check.via),
        ),
      ],
    );
  }

  static String _ago(AppLocalizations l10n, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.commonJustNow;
    if (d.inHours < 1) return l10n.commonMinutesAgo(d.inMinutes);
    return l10n.advancedHoursAgo(d.inHours);
  }
}
