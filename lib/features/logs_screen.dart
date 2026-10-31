import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_error.dart';
import '../core/ds.dart';
import '../core/ext_logs.dart';
import '../core/log.dart';
import '../core/log_archive.dart';
import '../core/platform_support.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';
import 'log_viewer_screen.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  bool _busy = false;
  bool _clearing = false;

  Future<void> _setCollecting(bool value) async {
    await ref.read(appPrefsProvider.notifier).setCollectLogs(value);
    await setExtensionLogging(value);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final where = canShareFiles
        ? await pickOption<_SaveTo>(
            context,
            title: l10n.logsSaveAll,
            options: [
              Option(
                _SaveTo.file,
                l10n.logsSaveToFile,
                subtitle: l10n.logsSaveToFileSubtitle,
                leading: const GlyphIcon(Glyph.folder),
              ),
              Option(
                _SaveTo.share,
                l10n.logsShare,
                subtitle: l10n.logsShareSubtitle,
                leading: const GlyphIcon(Glyph.share2),
              ),
            ],
          )
        : _SaveTo.file;
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
    final ok = await confirmAction(
      context,
      title: l10n.logsClearAllQuestion,
      body: l10n.logsClearAllContent,
      confirmLabel: l10n.commonClear,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = _clearing = true);
    Log.clear();
    final wiped = await clearExtensionLogs();
    if (!mounted) return;
    setState(() => _busy = _clearing = false);
    showToast(context, wiped ? l10n.logsCleared : l10n.logsAppLogClearedOnly);
  }

  @override
  Widget build(BuildContext context) {
    final collecting = ref.watch(appPrefsProvider).collectLogs;
    final l10n = context.l10n;

    return DsPage(
      title: l10n.logsTitle,
      children: [
        DsGroup(
          caption: l10n.logsSectionCollection,
          children: [
            DsRow(
              glyph: Glyph.fileText,
              title: l10n.logsCollect,
              subtitle: l10n.logsCollectSubtitle,
              subtitleMaxLines: 3,
              onTap: _busy ? null : () => _setCollecting(!collecting),
              trailing: [
                DsToggle(
                  value: collecting,
                  onChanged: _busy ? null : _setCollecting,
                ),
              ],
            ),
          ],
        ),
        DsGroup(
          caption: l10n.logsSectionTunnel,
          child: DsStack(
            gap: kNoteGap,
            children: [
              _LogRow(
                glyph: Glyph.network,
                title: l10n.logsTunnel,
                subtitle: l10n.logsTunnelSubtitle,
                onTap: () => _open(context, l10n.logsTunnel, logKey: 'tunnel'),
              ),
              _LogRow(
                glyph: Glyph.cpu,
                title: l10n.logsCore,
                subtitle: l10n.logsCoreSubtitle,
                onTap: () => _open(context, l10n.logsCore, logKey: 'mihomo'),
              ),
            ],
          ),
        ),
        DsGroup(
          caption: l10n.logsSectionApp,
          child: _LogRow(
            glyph: Glyph.smartphone,
            title: l10n.logsApplication,
            subtitle: l10n.logsApplicationSubtitle,
            size: formatBytes(Log.sizeBytes),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    LogViewerScreen(title: l10n.logsApplication, appLog: true),
              ),
            ),
          ),
        ),
        DsStack(
          children: [
            DsButton.secondary(
              label: l10n.logsSaveAllZip,
              glyph: Glyph.download,
              busy: _busy && !_clearing,
              onPressed: _busy ? null : _save,
            ),
            DsButton.destructive(
              label: l10n.logsClearAll,
              glyph: Glyph.trash,
              busy: _clearing,
              onPressed: _busy ? null : _clear,
            ),
          ],
        ),
      ],
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

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.glyph,
    required this.title,
    required this.subtitle,
    this.size,
    required this.onTap,
  });

  final Glyph glyph;
  final String title;
  final String subtitle;
  final String? size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DsCard(
    children: [
      DsRow(
        glyph: glyph,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        trailing: [
          if (size != null)
            Text(size!, style: DsType.small.copyWith(color: context.ds.text3)),
          const DsChevron(),
        ],
      ),
    ],
  );
}

enum _SaveTo { file, share }
