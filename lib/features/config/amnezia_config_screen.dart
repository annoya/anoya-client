import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/amnezia/amnezia_account.dart';
import '../../core/device_identity.dart';
import '../../core/profile.dart';
import '../../core/profile_store.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import 'config_parts.dart';

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
            // No SourceCard: the source is the subscription key, a credential.
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
    return left <= 0 ? date : l10n.configDaysLeft(date, left);
  }
}

class _ThisInstallation extends StatefulWidget {
  const _ThisInstallation();

  @override
  State<_ThisInstallation> createState() => _ThisInstallationState();
}

class _ThisInstallationState extends State<_ThisInstallation> {
  // Read once: a future made in build would blank the section on each rebuild.
  late final Future<(DeviceIdentity, String)> _identity = _load();

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
