import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/log.dart';
import '../core/ui.dart';

/// Android's counterpart of on-demand — described, not controlled.
///
/// The Always-on switch belongs to the system: an app can neither flip it nor
/// reliably read it while the tunnel is down, so a toggle here would be a
/// promise this screen cannot keep. What the app *can* do is say what the
/// switch gives (a tunnel the OS restarts by itself, plus the system kill
/// switch that lives next to it) and take the user to the one place it can be
/// set. The system starts whatever configuration was used last — which is why
/// the app keeps the saved config in step with the selection.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Always-on VPN')),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              margin: kCardMargin,
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.bolt_outlined),
                    title: Text('Started by the system'),
                    subtitle: Text(
                      'At boot, and again whenever the tunnel drops',
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Block connections without VPN'),
                    subtitle: Text(
                      'The system’s kill switch, on the same screen',
                    ),
                  ),
                ],
              ),
            ),
            const SectionNote(
              'Android owns this switch, so it lives in system settings: '
              'Network & internet → VPN → the gear next to this app. '
              'The system starts whatever configuration was used last.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 0),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open system VPN settings'),
                onPressed: _openSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
