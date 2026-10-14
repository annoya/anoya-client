import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ds.dart';
import '../core/log.dart';
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
    return DsPage(
      title: l10n.alwaysOnTitle,
      children: [
        DsGroup(
          note: l10n.alwaysOnNote,
          children: [
            DsRow(
              glyph: Glyph.zap,
              title: l10n.alwaysOnStartedBySystem,
              subtitle: l10n.alwaysOnStartedBySystemSubtitle,
            ),
            DsRow(
              glyph: Glyph.lock,
              title: l10n.alwaysOnBlockWithoutVpn,
              subtitle: l10n.alwaysOnBlockWithoutVpnSubtitle,
            ),
          ],
        ),
        DsButton(
          label: l10n.alwaysOnOpenSystemSettings,
          glyph: Glyph.settings,
          onPressed: _openSettings,
        ),
      ],
    );
  }
}
