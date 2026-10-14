import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ds.dart';
import '../../core/subscription_info.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';

class ProviderSection extends StatelessWidget {
  const ProviderSection({super.key, required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final details = [
      if (info.announce.isNotEmpty)
        DsRow(
          title: info.announce,
          titleWidget: Text(
            info.announce,
            style: DsType.h3.copyWith(color: context.ds.text1),
          ),
        ),
      if (info.hasPlan) _plan(context, l10n),
    ];
    return DsGroup(
      caption: l10n.configSectionDetails,
      child: DsStack(
        children: [
          if (details.isNotEmpty) DsCard(children: details),
          if (info.supportUrl.isNotEmpty)
            DsCard(
              children: [
                DsRow(
                  glyph: Glyph.building2,
                  title: l10n.configGetSupport,
                  trailing: const [DsAction(glyph: Glyph.externalLink)],
                  onTap: () => _openSupport(context),
                ),
              ],
            ),
          if (details.isEmpty && info.supportUrl.isEmpty)
            DsNote(l10n.configNoPlanDetails),
        ],
      ),
    );
  }

  Widget _plan(BuildContext context, AppLocalizations l10n) {
    if (info.unlimited) {
      return DsRow(
        title: l10n.configUsedNoLimit(formatBytes(info.usedBytes)),
        subtitle: _planLine(l10n),
      );
    }
    final ds = context.ds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.configTrafficOf(
              formatBytes(info.usedBytes),
              formatBytes(info.totalBytes),
            ),
            style: DsType.h3.copyWith(color: ds.text1),
          ),
          const SizedBox(height: 8),
          DsProgress(
            value: info.expired ? 1 : info.usedBytes / info.totalBytes,
            warning: info.expired,
          ),
          const SizedBox(height: 8),
          Text(
            _planLine(l10n),
            style: DsType.small.copyWith(
              color: info.expired ? ds.badgeDestructive : ds.text3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    final l10n = context.l10n;
    final uri = Uri.tryParse(info.supportUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showToast(context, l10n.configCouldNotOpenLink);
    }
  }

  String _planLine(AppLocalizations l10n) {
    final at = info.expiresAt;
    final when = at == null
        ? l10n.configNoExpiryDate
        : info.expired
        ? l10n.configExpiredOn(l10n.configDateShort(at))
        : l10n.configActiveUntil(l10n.configDateShort(at));
    return l10n.configPlanLine(when);
  }
}
