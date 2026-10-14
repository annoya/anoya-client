import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/norm_config.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
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
    final head = [
      ProfileHeaderRow(profile: p, isActive: isActive),
      if (account != null) ...[
        DsRow(
          glyph: Glyph.user,
          title: l10n.configAccount,
          subtitle: _accountSummary(l10n, account),
        ),
        if (account.dataLimit > 0) _TrafficRow(account: account),
      ],
    ];
    final origin = [
      if (p.serverUrl != null) SourceRow(value: p.serverUrl!),
      RefreshRow(profile: p),
    ];
    return DsPage(
      title: p.name,
      children: [
        if (account == null)
          DsCard(children: [...head, ...origin])
        else ...[
          DsCard(children: head),
          DsCard(children: origin),
        ],
        RoutingRow(profile: p),
        ConfigActions(profile: p, isActive: isActive),
      ],
    );
  }

  String _accountSummary(AppLocalizations l10n, Account a) {
    final status = a.status.replaceAll('_', ' ');
    if (a.status == 'on_hold') return l10n.configStatusOnHold(status);
    if (a.expiresAt != null) {
      return l10n.configStatusExpires(
        status,
        a.expiresAt!.toLocal().toString().split('.').first,
      );
    }
    return l10n.configStatus(status);
  }
}

class _TrafficRow extends StatelessWidget {
  const _TrafficRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DsRow(
        glyph: Glyph.zap,
        title: context.l10n.configTraffic,
        subtitle: context.l10n.configTrafficUsedOf(
          formatBytes(account.usedBytes),
          formatBytes(account.dataLimit),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DsProgress(value: account.usedBytes / account.dataLimit),
      ),
    ],
  );
}
