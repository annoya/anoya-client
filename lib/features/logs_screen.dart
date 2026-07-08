import 'package:flutter/material.dart';

import '../core/log.dart';
import '../core/ui.dart';
import 'log_viewer_screen.dart';

/// Logs hub (happ-style): separate entries for the tunnel log, the core
/// (mihomo) log, and the app log — each opens a viewer. The tunnel/core logs
/// live in the extension's container and are fetched over IPC (only while the
/// VPN is connected); the app log is the in-memory buffer.
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: PageBody(
        child: ListView(
          children: [
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
              size: _human(Log.sizeBytes),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LogViewerScreen(title: 'Application', appLog: true),
              )),
            ),
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

  static String _human(int bytes) {
    if (bytes < 1024) return '$bytes b';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
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
            if (size != null) Text(size!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
