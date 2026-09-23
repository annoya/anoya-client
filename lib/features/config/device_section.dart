import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/device_identity.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';

/// Shown only for a configuration whose panel said it counts devices.
///
/// The panel reports *that* it counts and *that* it is full — never how many of
/// how many — so this says what we know and stops. What it must say is that
/// this installation occupies a slot: that is a consequence of using the app,
/// and learning it by hitting the limit somewhere else would be a surprise.
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

/// How this installation looks to whoever is counting devices: the machine in
/// words, then the id itself.
///
/// Both halves earn their place, and the order is the order of the
/// conversation they exist for. Support asks "which device is yours" — the
/// answer starts with "my iPhone" and ends with the id that pins it down. The
/// provider differs (a panel counts by hwid, Amnezia by an installation uuid)
/// but the question does not, so neither should the layout.
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

/// An identifier the user may need to quote, shown short and copied whole.
///
/// It exists for one conversation: a provider says a slot is taken and the
/// user has to say which device is theirs. Truncated because nobody reads a
/// uuid off a screen, and copied in full because nobody has to — the point is
/// to paste it somewhere, not to memorise it.
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
