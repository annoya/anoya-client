import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/amnezia/amnezia_account.dart';
import '../../core/device_identity.dart';
import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/profile_store.dart';
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
    final expired = account?.expired == true;
    final l10n = context.l10n;
    return DsPage(
      title: p.name,
      children: [
        DsCard(
          children: [
            ProfileHeaderRow(profile: p, isActive: isActive),
            RefreshRow(profile: p),
          ],
        ),
        if (expired)
          ConfigAlert(
            title: l10n.accountExpiredTitle,
            body: l10n.configSubscriptionExpiredDetail,
          ),
        if (account != null) ?_subscription(l10n, account),
        if (!expired) RoutingRow(profile: p),
        DsStack(
          gap: 0,
          children: [
            const _ThisInstallation(),
            ConfigActions(profile: p, isActive: isActive),
          ],
        ),
      ],
    );
  }

  Widget? _subscription(AppLocalizations l10n, AmneziaAccount account) {
    final rows = <Widget>[
      if (account.endsAt != null)
        DsRow(
          glyph: Glyph.calendar,
          title: account.expired ? l10n.configRanUntil : l10n.configRunsUntil,
          subtitle: _endLabel(l10n, account),
        ),
      if (account.hasDeviceCount && !account.expired)
        DsRow(
          glyph: Glyph.smartphone,
          title: l10n.configDevices,
          subtitle: l10n.configDevicesUsed(
            account.activeDevices,
            account.maxDevices,
          ),
        ),
    ];
    if (rows.isEmpty) return null;
    return DsGroup(caption: l10n.configSectionSubscription, children: rows);
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
          spaced: true,
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
