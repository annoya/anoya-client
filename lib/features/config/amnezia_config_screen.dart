import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/amnezia/amnezia_account.dart';
import '../../core/device_identity.dart';
import '../../core/profile.dart';
import '../../core/profile_store.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
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
  const AmneziaConfigScreen({
    super.key,
    required this.profile,
    required this.isActive,
  });

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
        child: ListView(
          children: [
            const SizedBox(height: 8),
            ProfileHeaderCard(profile: p, isActive: isActive),
            if (account?.expired == true) const _ExpiredCard(),
            RefreshCard(profile: p),
            if (account != null) ..._subscription(context.l10n, account),
            RoutingRow(profile: p),
            const _ThisInstallation(),
            ConfigActions(profile: p, isActive: isActive),
          ],
        ),
      ),
    );
  }

  List<Widget> _subscription(AppLocalizations l10n, AmneziaAccount account) {
    final rows = <Widget>[
      if (account.endsAt != null)
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: Text(
            account.expired ? l10n.configRanUntil : l10n.configRunsUntil,
          ),
          subtitle: Text(_endLabel(l10n, account)),
        ),
      if (account.hasDeviceCount)
        ListTile(
          leading: const Icon(Icons.devices_outlined),
          title: Text(l10n.configDevices),
          subtitle: Text(
            l10n.configDevicesUsed(account.activeDevices, account.maxDevices),
          ),
        ),
    ];
    // The description Amnezia sends is the sales copy from its store page. On
    // the settings screen of a subscription already bought it answers no
    // question the user came here with — how long it runs, how many slots are
    // left — so nothing is shown when those are all we would have.
    if (rows.isEmpty) return const [];
    return [
      SectionHeader(l10n.configSectionSubscription),
      Card(
        margin: kCardMargin,
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              row,
            ],
          ],
        ),
      ),
    ];
  }

  String _endLabel(AppLocalizations l10n, AmneziaAccount account) {
    final date = l10n.configDateLong(account.endsAt!.toLocal());
    if (account.expired) return date;
    final left = account.endsAt!.difference(DateTime.now().toUtc()).inDays;
    // The date alone answers "when"; the count answers "should I do something
    // about it", which is the question someone opens this screen with.
    return left <= 0 ? date : l10n.configDaysLeft(date, left);
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
    final l10n = context.l10n;
    return FutureBuilder<(DeviceIdentity, String)>(
      future: _identity,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || data.$2.isEmpty) return const SizedBox.shrink();
        return DeviceSection(
          label: data.$1.label,
          labelSubtitle: l10n.configDeviceIdentifiedSubtitle,
          idTitle: l10n.configDeviceId,
          idValue: data.$2,
          hint: l10n.configDeviceHintAmnezia,
        );
      },
    );
  }
}

/// The subscription ran out, in Amnezia's own words (code 1112) so that the
/// same failure reads the same in both clients.
class _ExpiredCard extends StatelessWidget {
  const _ExpiredCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Card(
      margin: kCardMargin,
      color: cs.errorContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: cs.error),
        title: Text(l10n.accountExpiredTitle),
        subtitle: Text(l10n.configSubscriptionExpiredDetail),
        isThreeLine: true,
      ),
    );
  }
}
