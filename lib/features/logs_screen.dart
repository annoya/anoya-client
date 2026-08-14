import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_error.dart';
import '../core/ext_logs.dart';
import '../core/log.dart';
import '../core/log_archive.dart';
import '../core/ui.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import 'log_viewer_screen.dart';

/// Logs hub (happ-style): a switch that stops every log being written, separate
/// entries for the tunnel log, the core (mihomo) log and the app log — each
/// opens a viewer — plus the two bulk actions. The tunnel/core logs live in the
/// extension's container and are fetched over IPC (only while the VPN is
/// connected); the app log is the in-memory buffer.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  bool _busy = false;

  Future<void> _setCollecting(bool value) async {
    await ref.read(appPrefsProvider.notifier).setCollectLogs(value);
    // Two places to reach: the persisted tunnel config (what the next start
    // uses) and the extension that is running right now — the engine only reads
    // its log level when a config is applied, so a live tunnel would keep
    // writing until reconnected.
    await ref.read(profilesControllerProvider.notifier).syncTunnelConfig();
    await setExtensionLogging(value);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    // Ask first, then build: no point zipping anything if the user backs out.
    final where = await pickOption<_SaveTo>(
      context,
      title: 'Save all logs',
      options: const [
        Option(_SaveTo.file, 'Save to file…', subtitle: 'Pick a folder on this device'),
        Option(_SaveTo.share, 'Share…', subtitle: 'Send the archive somewhere'),
      ],
    );
    if (where == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final archive = await buildLogArchive(now: DateTime.now());
      final name = archive.uri.pathSegments.last;
      if (!mounted) return;
      switch (where) {
        case _SaveTo.share:
          await SharePlus.instance.share(ShareParams(files: [XFile(archive.path)]));
        case _SaveTo.file:
          // The mobile plugin writes the file itself and demands the bytes; the
          // desktop one refuses them ("Bytes are not supported on macOS") and
          // only hands back the chosen path, leaving the writing to us.
          final writesItself = Platform.isIOS || Platform.isAndroid;
          final path = await FilePicker.platform.saveFile(
            dialogTitle: 'Save logs',
            fileName: name,
            bytes: writesItself ? await archive.readAsBytes() : null,
          );
          if (path == null) return; // cancelled
          if (!writesItself) await archive.copy(path);
          if (mounted) showToast(context, 'Saved to $path');
      }
    } catch (e) {
      Log.e('saving logs failed', '$e');
      if (mounted) await showErrorDialog(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text(
            'The app, tunnel and core logs will be deleted from this device. '
            'The tunnel and core logs can only be cleared while the VPN is connected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    Log.clear();
    final wiped = await clearExtensionLogs();
    if (!mounted) return;
    setState(() {});
    showToast(
        context,
        wiped
            ? 'Logs cleared.'
            : 'App log cleared. The tunnel and core logs need the VPN connected.');
  }

  @override
  Widget build(BuildContext context) {
    final collecting = ref.watch(appPrefsProvider).collectLogs;

    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: PageBody(
        child: ListView(
          children: [
            const SectionHeader('COLLECTION'),
            Card(
              margin: kCardMargin,
              child: SwitchListTile(
                secondary: const Icon(Icons.article_outlined),
                title: const Text('Collect logs'),
                subtitle: const Text('Off: the app, the tunnel and the core stop writing. '
                    'Existing files stay readable.'),
                value: collecting,
                onChanged: _busy ? null : _setCollecting,
              ),
            ),
            const SectionHeader('TUNNEL'),
            _LogTile(
              title: 'Tunnel',
              subtitle: 'Network Extension events',
              onTap: () => _open(context, 'Tunnel', logKey: 'tunnel'),
            ),
            _LogTile(
              title: 'Core (mihomo)',
              subtitle: 'Engine log: dials, DNS, routing',
              onTap: () => _open(context, 'Core (mihomo)', logKey: 'mihomo'),
            ),
            const SectionHeader('APP'),
            _LogTile(
              title: 'Application',
              subtitle: 'Client-side events',
              size: formatBytes(Log.sizeBytes),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LogViewerScreen(title: 'Application', appLog: true),
              )),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: OutlinedButton.icon(
                icon: _busy
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Save all logs (.zip)'),
                onPressed: _busy ? null : _save,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear all logs'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: _busy ? null : _clear,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, String title, {String? logKey}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LogViewerScreen(title: title, logKey: logKey),
    ));
  }

}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.title, required this.subtitle, this.size, required this.onTap});
  final String title;
  final String subtitle;
  final String? size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: kCardMargin,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (size != null)
              Text(size!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Where the log archive goes. The button offers both instead of assuming: the
/// file system for keeping it, the share sheet for sending it on.
enum _SaveTo { file, share }
