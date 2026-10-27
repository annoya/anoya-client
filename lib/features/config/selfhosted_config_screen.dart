import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/norm_config.dart';
import '../../core/profile.dart';
import '../../l10n/l10n.dart';
import 'config_parts.dart';

class SelfhostedConfigScreen extends ConsumerWidget {
  const SelfhostedConfigScreen({
    super.key,
    required this.profile,
    required this.isActive,
  });

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final account = p.account;
    final l10n = context.l10n;
    return DsPage(
      title: p.name,
      children: [
        DsCard(
          children: [
            ProfileHeaderRow(profile: p, isActive: isActive),
            if (p.serverUrl != null) SourceRow(value: p.serverUrl!),
            RefreshRow(profile: p),
          ],
        ),
        if (account != null)
          PlanGroup(caption: l10n.configAccount, rows: _rows(l10n, account)),
        RoutingRow(profile: p),
        ConfigActions(profile: p, isActive: isActive),
      ],
    );
  }

  List<Widget> _rows(AppLocalizations l10n, Account a) {
    final status = a.status.replaceAll('_', ' ');
    final statedEnd = a.status == 'expired' && a.expiresAt != null;
    return [
      if (a.status != 'active' && !statedEnd)
        DsRow(
          glyph: Glyph.user,
          title: a.status == 'on_hold'
              ? l10n.configStatusOnHold(status)
              : l10n.configStatus(status),
        ),
      if (a.expiresAt != null) TermRow(endsAt: a.expiresAt),
      if (a.dataLimit > 0 || a.usedBytes > 0)
        TrafficRow(used: a.usedBytes, total: a.dataLimit),
    ];
  }
}
