import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/device_identity.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';

class ThisDeviceSection extends StatelessWidget {
  const ThisDeviceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<DeviceIdentity>(
      future: DeviceIdentityStore.load(),
      builder: (context, snap) {
        final id = snap.data;
        if (id == null) return const SizedBox.shrink();
        return DeviceSection(
          label: id.label,
          labelSubtitle: l10n.configDeviceIdentifiedSubtitle,
          idTitle: l10n.configDeviceId,
          idValue: id.hwid,
          hint: l10n.configDeviceHintPanel,
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
  });

  final String label;
  final String labelSubtitle;
  final String idTitle;
  final String idValue;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(context.l10n.configSectionThisDevice),
        Card(
          margin: kCardMargin,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.smartphone_outlined),
                title: Text(label),
                subtitle: Text(labelSubtitle),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              IdentifierRow(title: idTitle, value: idValue),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
          child: Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class IdentifierRow extends StatelessWidget {
  const IdentifierRow({super.key, required this.title, required this.value});

  final String title;
  final String value;

  static String shorten(String v) =>
      v.length <= 24 ? v : '${v.substring(0, 12)}…${v.substring(v.length - 8)}';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: Text(title),
      subtitle: Text(shorten(value)),
      trailing: IconButton(
        icon: const Icon(Icons.copy_outlined, size: 18),
        tooltip: context.l10n.commonCopy,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            showToast(context, context.l10n.configCopiedTitle(title));
          }
        },
      ),
    );
  }
}
