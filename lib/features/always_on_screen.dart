import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/log.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';

class AlwaysOnScreen extends StatelessWidget {
  const AlwaysOnScreen({super.key});

  static const _control = MethodChannel('vpn/control');

  Future<void> _openSettings() async {
    try {
      await _control.invokeMethod<void>('open_vpn_settings');
    } on PlatformException catch (e) {
      Log.e('open vpn settings failed', e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alwaysOnTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              margin: kCardMargin,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bolt_outlined),
                    title: Text(l10n.alwaysOnStartedBySystem),
                    subtitle: Text(l10n.alwaysOnStartedBySystemSubtitle),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l10n.alwaysOnBlockWithoutVpn),
                    subtitle: Text(l10n.alwaysOnBlockWithoutVpnSubtitle),
                  ),
                ],
              ),
            ),
            SectionNote(l10n.alwaysOnNote),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 0),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(l10n.alwaysOnOpenSystemSettings),
                onPressed: _openSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
