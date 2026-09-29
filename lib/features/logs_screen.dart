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
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import 'log_viewer_screen.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  bool _busy = false;

  Future<void> _setCollecting(bool value) async {
    await ref.read(appPrefsProvider.notifier).setCollectLogs(value);
    await ref.read(profilesControllerProvider.notifier).syncTunnelConfig();
    await setExtensionLogging(value);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final where = await pickOption<_SaveTo>(
      context,
      title: l10n.logsSaveAll,
      options: [
        Option(
          _SaveTo.file,
          l10n.logsSaveToFile,
          subtitle: l10n.logsSaveToFileSubtitle,
        ),
        Option(_SaveTo.share, l10n.logsShare, subtitle: l10n.logsShareSubtitle),
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
          await SharePlus.instance.share(
            ShareParams(files: [XFile(archive.path)]),
          );
        case _SaveTo.file:
          // The mobile plugin needs the bytes; desktop refuses them and only returns the path.
          final writesItself = Platform.isIOS || Platform.isAndroid;
          final path = await FilePicker.platform.saveFile(
            dialogTitle: l10n.logsSaveDialogTitle,
            fileName: name,
            bytes: writesItself ? await archive.readAsBytes() : null,
          );
          if (path == null) return;
          if (!writesItself) await archive.copy(path);
          if (mounted) showToast(context, l10n.logsSavedTo(path));
      }
    } catch (e) {
      Log.e('saving logs failed', '$e');
      if (mounted) await showErrorDialog(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logsClearAllQuestion),
        content: Text(l10n.logsClearAllContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonClear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    Log.clear();
    final wiped = await clearExtensionLogs();
    if (!mounted) return;
    setState(() {});
    showToast(context, wiped ? l10n.logsCleared : l10n.logsAppLogClearedOnly);
  }

  @override
  Widget build(BuildContext context) {
    final collecting = ref.watch(appPrefsProvider).collectLogs;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logsTitle)),
      body: PageBody(
        child: ListView(
          children: [
            SectionHeader(l10n.logsSectionCollection),
            Card(
              margin: kCardMargin,
              child: SwitchListTile(
                secondary: const Icon(Icons.article_outlined),
                title: Text(l10n.logsCollect),
                subtitle: Text(l10n.logsCollectSubtitle),
                value: collecting,
                onChanged: _busy ? null : _setCollecting,
              ),
            ),
            SectionHeader(l10n.logsSectionTunnel),
            _LogTile(
              title: l10n.logsTunnel,
              subtitle: l10n.logsTunnelSubtitle,
              onTap: () => _open(context, l10n.logsTunnel, logKey: 'tunnel'),
            ),
            _LogTile(
              title: l10n.logsCore,
              subtitle: l10n.logsCoreSubtitle,
              onTap: () => _open(context, l10n.logsCore, logKey: 'mihomo'),
            ),
            SectionHeader(l10n.logsSectionApp),
            _LogTile(
              title: l10n.logsApplication,
              subtitle: l10n.logsApplicationSubtitle,
              size: formatBytes(Log.sizeBytes),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LogViewerScreen(
                    title: l10n.logsApplication,
                    appLog: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: OutlinedButton.icon(
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.archive_outlined, size: 18),
                label: Text(l10n.logsSaveAllZip),
                onPressed: _busy ? null : _save,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.logsClearAll),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogViewerScreen(title: title, logKey: logKey),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.title,
    required this.subtitle,
    this.size,
    required this.onTap,
  });
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
              Text(
                size!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

enum _SaveTo { file, share }
