import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ds.dart';
import '../core/ext_logs.dart';
import '../core/log.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

const kLogViewerRefreshDelay = Duration(milliseconds: 300);

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
  Timer? _pending;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.appLog) Log.revision.addListener(_logChanged);
  }

  @override
  void dispose() {
    if (widget.appLog) Log.revision.removeListener(_logChanged);
    _pending?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _logChanged() {
    _pending ??= Timer(kLogViewerRefreshDelay, () {
      _pending = null;
      _load();
    });
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

  String? _placeholder(AppLocalizations l10n) {
    if (_content.trim().isEmpty) return l10n.logsEmpty;
    if (_content == l10n.logsNoLogYet || _content == l10n.logsNoLog) {
      return _content;
    }
    return null;
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = context.l10n.commonCopied;
    await Clipboard.setData(ClipboardData(text: _content));
    showToastWith(messenger, copied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ds = context.ds;
    final placeholder = _loading ? null : _placeholder(l10n);
    return DsPage(
      title: widget.title,
      actions: [
        DsNavButton(
          glyph: Glyph.refreshCw,
          tooltip: l10n.commonRefresh,
          onPressed: _load,
        ),
        DsNavButton(
          glyph: Glyph.copy,
          tooltip: l10n.commonCopy,
          onPressed: _loading ? null : _copy,
        ),
      ],
      body: ListView(
        controller: _scroll,
        padding: kScrollPadding,
        children: [
          if (_loading)
            const Center(child: DsSpinner())
          else if (placeholder != null)
            _EmptyLog(placeholder)
          else
            DsSurface(
              padding: const EdgeInsets.all(kCardPadding),
              child: SelectableText(
                _content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: ds.text2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(text, style: DsType.text.copyWith(color: context.ds.text2)),
  );
}
