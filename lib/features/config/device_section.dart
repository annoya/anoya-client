import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/device_identity.dart';
import '../../core/ds.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';

class ThisDeviceSection extends StatelessWidget {
  const ThisDeviceSection({super.key, required this.counted});

  final bool counted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<DeviceIdentity>(
      future: DeviceIdentityStore.load(),
      builder: (context, snap) {
        final id = snap.data;
        if (id == null) return const SizedBox.shrink();
        return DeviceSection(
          spaced: true,
          label: id.label,
          labelSubtitle: counted
              ? l10n.configDeviceIdentifiedSubtitle
              : l10n.configDeviceSentSubtitle,
          idTitle: l10n.configDeviceHwid,
          idValue: id.hwid,
          hint: counted
              ? l10n.configDeviceHintPanel
              : l10n.configDeviceHintPanelUncounted,
        );
      },
    );
  }
}

class DeviceSection extends StatelessWidget {
  const DeviceSection({
    super.key,
    required this.label,
    required this.labelSubtitle,
    required this.idTitle,
    required this.idValue,
    required this.hint,
    this.spaced = false,
  });

  final String label;
  final String labelSubtitle;
  final String idTitle;
  final String idValue;
  final String hint;

  final bool spaced;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: spaced ? kGroupGap : 0),
    child: _group(context),
  );

  Widget _group(BuildContext context) => DsGroup(
    caption: context.l10n.configSectionThisDevice,
    note: hint,
    children: [
      DsRow(
        glyph: Glyph.lock,
        title: label,
        subtitle: labelSubtitle,
        subtitleMaxLines: 1,
      ),
      IdentifierRow(title: idTitle, value: idValue),
    ],
  );
}

class IdentifierRow extends StatelessWidget {
  const IdentifierRow({super.key, required this.title, required this.value});

  final String title;
  final String value;

  static String shorten(String v) =>
      v.length <= 24 ? v : '${v.substring(0, 12)}…${v.substring(v.length - 8)}';

  @override
  Widget build(BuildContext context) {
    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        showToast(context, context.l10n.configCopiedTitle(title));
      }
    }

    return DsRow(
      glyph: Glyph.fileText,
      title: title,
      subtitle: shorten(value),
      subtitleMaxLines: 1,
      trailing: [
        DsAction(
          glyph: Glyph.copy,
          tooltip: context.l10n.commonCopy,
          onPressed: copy,
        ),
      ],
      onTap: copy,
    );
  }
}
