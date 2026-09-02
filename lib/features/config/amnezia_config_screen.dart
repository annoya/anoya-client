import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/amnezia/amnezia_account.dart';
import '../../core/device_identity.dart';
import '../../core/profile.dart';
import '../../core/profile_store.dart';
import '../../core/ui.dart';
import 'config_parts.dart';

/// An Amnezia Premium/Free subscription.
///
/// The screen shows what the gateway said and nothing else. That is a rule
/// rather than a preference here, because the two products answer with
/// genuinely different amounts: a premium subscription has an end date, a
/// device count and a list of places, and a free one has none of the three. A
/// dash where a number would go, or "0 of 0" devices, would assert a value
/// exists and is empty — which is a different claim from "they never said".
///
/// There is deliberately no Source row. The source is the subscription key,
/// and the key is the credential: anyone who reads it holds the subscription.
class AmneziaConfigScreen extends ConsumerWidget {
  const AmneziaConfigScreen({super.key, required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final state = p.amnezia;
    final account = state?.account;
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: PageBody(
        child: ListView(children: [
          const SizedBox(height: 8),
          ProfileHeaderCard(profile: p, isActive: isActive),
          if (account?.expired == true) const _ExpiredCard(),
          RefreshCard(profile: p),
          if (account != null) ..._subscription(account),
          RoutingRow(profile: p),
          const _ThisInstallation(),
          ConfigActions(profile: p, isActive: isActive),
        ]),
      ),
    );
  }

  List<Widget> _subscription(AmneziaAccount account) {
    final rows = <Widget>[
      if (account.endsAt != null)
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: Text(account.expired ? 'Ran until' : 'Runs until'),
          subtitle: Text(_endLabel(account)),
        ),
      if (account.hasDeviceCount)
        ListTile(
          leading: const Icon(Icons.devices_outlined),
          title: const Text('Devices'),
          subtitle: Text('${account.activeDevices} of ${account.maxDevices} used'),
        ),
    ];
    // The description Amnezia sends is the sales copy from its store page. On
    // the settings screen of a subscription already bought it answers no
    // question the user came here with — how long it runs, how many slots are
    // left — so nothing is shown when those are all we would have.
    if (rows.isEmpty) return const [];
    return [
      const SectionHeader('SUBSCRIPTION'),
      Card(
        margin: kCardMargin,
        child: Column(children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            row,
          ],
        ]),
      ),
    ];
  }

  String _endLabel(AmneziaAccount account) {
    final end = account.endsAt!.toLocal();
    final date = '${end.day} ${_months[end.month - 1]} ${end.year}';
    if (account.expired) return date;
    final left = account.endsAt!.difference(DateTime.now().toUtc()).inDays;
    // The date alone answers "when"; the count answers "should I do something
    // about it", which is the question someone opens this screen with.
    return left <= 0 ? date : '$date · $left days left';
  }
}

/// The id Amnezia counts devices by.
///
/// Shown for the same reason a panel's hwid is: the count above says how many
/// slots are used, not which one is this phone, and that is the question
/// support asks. It identifies the *installation*, not the request — a slot is
/// spent on it, so it is made once and kept.
class _ThisInstallation extends StatefulWidget {
  const _ThisInstallation();

  @override
  State<_ThisInstallation> createState() => _ThisInstallationState();
}

class _ThisInstallationState extends State<_ThisInstallation> {
  /// Read once. The screen rebuilds on every refresh tick above it, and a
  /// future made in build() would send the section back to empty each time —
  /// neither store answers instantly, and the keychain least of all.
  late final Future<(DeviceIdentity, String)> _identity = _load();

  /// The two halves come from different stores — the machine from the device
  /// file, the id from the keychain — and neither is worth a frame of its own.
  Future<(DeviceIdentity, String)> _load() async =>
      (await DeviceIdentityStore.load(), await ProfileStore.amneziaInstallId());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(DeviceIdentity, String)>(
      future: _identity,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || data.$2.isEmpty) return const SizedBox.shrink();
        return DeviceSection(
          label: data.$1.label,
          labelSubtitle: 'Identified to your subscription, which counts devices',
          idTitle: 'Device id',
          idValue: data.$2,
          hint: 'Your subscription counts devices by this id. It is made once '
              'and kept, so reconnecting costs no slot — but a reinstall takes '
              'a new one.',
        );
      },
    );
  }
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// The subscription ran out, in Amnezia's own words (code 1112) so that the
/// same failure reads the same in both clients.
class _ExpiredCard extends StatelessWidget {
  const _ExpiredCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: kCardMargin,
      color: cs.errorContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: cs.error),
        title: const Text('Subscription expired'),
        subtitle: const Text(
            'Renew the subscription, then refresh this configuration.'),
        isThreeLine: true,
      ),
    );
  }
}
