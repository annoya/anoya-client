import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ext_logs.dart';
import '../core/log.dart';
import '../l10n/l10n.dart';

/// Shows one log: the in-app log buffer (appLog) or an extension log fetched
/// over IPC by [logKey] (e.g. "tunnel", "mihomo").
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({
    super.key,
    required this.title,
    this.logKey,
    this.appLog = false,
  });

  final String title;
  final String? logKey;
  final bool appLog;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final _scroll = ScrollController();
  String _content = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.appLog) Log.revision.addListener(_load);
  }

  @override
  void dispose() {
    if (widget.appLog) Log.revision.removeListener(_load);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.appLog) {
      _set(Log.dump());
      return;
    }
    if (widget.logKey == null) {
      _set(context.l10n.logsNoLog);
      return;
    }
    setState(() => _loading = true);
    final text = await fetchExtensionLog(widget.logKey!);
    if (!mounted) return;
    setState(() => _loading = false);
    _set(text);
  }

  void _set(String text) {
    setState(() => _content = text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.commonCopy,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: _content));
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.commonCopied)),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _content.trim().isEmpty
          ? Center(child: Text(l10n.logsEmpty))
          : SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
    );
  }
}
