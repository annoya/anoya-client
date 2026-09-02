import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_check.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../state/connection_check_controller.dart';
import '../state/session.dart';

/// Settings for the one thing the system's "connected" cannot tell the user:
/// whether the tunnel carries traffic.
class AdvancedConnectionScreen extends ConsumerWidget {
  const AdvancedConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(connectionCheckProvider);
    final ctrl = ref.read(connectionCheckProvider.notifier);
    final connected = ref.watch(sessionProvider).connected;
    final prefs = st.prefs;

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced')),
      body: PageBody(
        child: ListView(children: [
          const SectionHeader('CONNECTION CHECK'),
          Card(
            margin: kCardMargin,
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.check_circle_outline),
                title: const Text('Check after connecting'),
                subtitle: const Text('Fetch a page through the server and time the answer'),
                value: prefs.enabled,
                onChanged: ctrl.setEnabled,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: const Text('Test URL'),
                subtitle: Text(prefs.url),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editUrl(context, ctrl, prefs),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Give up after'),
                subtitle: Text('${prefs.timeoutSeconds} seconds'),
                trailing: const Icon(Icons.expand_more),
                onTap: () => _pickTimeout(context, ctrl, prefs),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 0),
            child: FilledButton(
              // Nothing to probe with the engine stopped, and a button that
              // reports "the tunnel is not running" reads as a fault rather
              // than as the obvious.
              onPressed: (!connected || st.running) ? null : ctrl.run,
              child: st.running
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test now'),
            ),
          ),
          if (!connected)
            const SectionNote('The request goes through the running engine, '
                'so the tunnel has to be up to test it.'),
          if (st.last != null) ...[
            const SectionHeader('LAST CHECK'),
            _ResultCard(check: st.last!),
          ],
          const SectionNote('The request goes through the server itself, so routing '
              'rules do not affect it. It proves the server passes traffic — not '
              'that your traffic goes through it.'),
        ]),
      ),
    );
  }

  Future<void> _editUrl(
      BuildContext context, ConnectionCheckController ctrl, ConnectionCheckPrefs prefs) async {
    final typed = await promptText(
      context,
      title: 'Test URL',
      label: 'URL',
      confirmLabel: 'Save',
      initial: prefs.url,
      autocorrect: false,
      resetLabel: 'Use the default',
      resetValue: ConnectionCheckPrefs.defaultUrl,
    );
    if (typed == null) return;
    final trimmed = typed.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty || uri == null || !uri.isScheme('http') && !uri.isScheme('https')) {
      if (context.mounted) showToast(context, 'Enter an http:// or https:// address.');
      return;
    }
    await ctrl.setUrl(trimmed);
  }

  Future<void> _pickTimeout(
      BuildContext context, ConnectionCheckController ctrl, ConnectionCheckPrefs prefs) async {
    const choices = [3, 5, 10, 15];
    final picked = await pickOption<int>(
      context,
      title: 'Give up after',
      selected: prefs.timeoutSeconds,
      options: [for (final s in choices) Option(s, '$s seconds')],
    );
    if (picked != null) await ctrl.setTimeout(picked);
  }
}

/// The answer, kept as a line rather than announced as a toast: "143 ms" only
/// means something next to the last one, and a toast leaves nothing to compare.
///
/// Stateful for one reason: "just now" stops being true while the screen is
/// open, and a timestamp that freezes is worse than none — it dates the
/// measurement wrongly rather than vaguely.
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
    if (!check.passed) {
      return Card(
        margin: kCardMargin,
        color: warn.withValues(alpha: 0.12),
        child: ListTile(
          leading: Icon(Icons.warning_amber_outlined, color: warn),
          title: const Text('No answer'),
          subtitle: Text('${check.failure} '
              'The tunnel is up, so this is the server or the network beyond it.'),
          isThreeLine: true,
        ),
      );
    }
    final via = check.via.isEmpty ? '' : ' · through ${check.via}';
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: Icon(Icons.check_circle_outline, color: context.vpnColors.connected),
        // Two different claims, and they must not borrow each other's words:
        // one is a measurement we made, the other is traffic we watched go by.
        title: Text(check.observed
            ? 'Traffic is getting through'
            : 'Answered in ${check.delayMs} ms'),
        subtitle: Text('${_ago(check.at)}$via',
            style: TextStyle(color: cs.onSurfaceVariant)),
      ),
    );
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }
}
