import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';

class PlanGroup extends StatelessWidget {
  const PlanGroup({
    super.key,
    required this.caption,
    required this.rows,
    this.renewUrl = '',
    this.supportUrl = '',
    this.note,
  });

  final String caption;
  final List<Widget> rows;
  final String renewUrl;
  final String supportUrl;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsGroup(
      caption: caption,
      child: DsStack(
        children: [
          if (rows.isNotEmpty) DsCard(children: rows),
          if (renewUrl.isNotEmpty || supportUrl.isNotEmpty)
            DsCard(
              children: [
                if (renewUrl.isNotEmpty)
                  _LinkRow(
                    glyph: Glyph.rotateCcw,
                    title: l10n.configRenew,
                    url: renewUrl,
                  ),
                if (supportUrl.isNotEmpty)
                  _LinkRow(
                    glyph: Glyph.building2,
                    title: l10n.configGetSupport,
                    url: supportUrl,
                  ),
              ],
            ),
          if (note != null) DsNote(note!),
        ],
      ),
    );
  }
}

class SubscriptionPlanGroup extends StatelessWidget {
  const SubscriptionPlanGroup({super.key, required this.profile});

  final Profile profile;

  static bool shows(Profile p) =>
      p.providerInfo != null || p.deviceLimitReached;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = profile.providerInfo;
    final rows = [
      if (info != null && info.announce.isNotEmpty)
        DsRow(
          title: info.announce,
          titleWidget: Text(
            info.announce,
            style: DsType.h3.copyWith(color: context.ds.text1),
          ),
        ),
      if (info != null && info.hasPlan) TermRow(endsAt: info.expiresAt),
      if (info != null && (info.usedBytes > 0 || info.totalBytes > 0))
        TrafficRow(
          used: info.usedBytes,
          total: info.totalBytes,
          warning: info.expired,
        ),
      if (profile.deviceLimitReached)
        DevicesRow(subtitle: l10n.configDevicesFull),
    ];
    final renew = info?.renewUrl ?? '';
    final support = info?.supportUrl ?? '';
    return PlanGroup(
      caption: l10n.configSectionSubscription,
      rows: rows,
      renewUrl: renew,
      supportUrl: support,
      note: rows.isEmpty && renew.isEmpty && support.isEmpty
          ? l10n.configNoPlanDetails
          : null,
    );
  }
}

class TermRow extends StatelessWidget {
  const TermRow({super.key, required this.endsAt});

  final DateTime? endsAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = endsAt?.toLocal();
    if (at == null) {
      return DsRow(glyph: Glyph.calendar, title: l10n.configNoExpiryDate);
    }
    final date = l10n.configDateShort(at);
    final now = DateTime.now();
    if (at.isBefore(now)) {
      return DsRow(
        glyph: Glyph.calendar,
        title: l10n.configExpired,
        titleStyle: DsType.h3.copyWith(color: context.ds.badgeDestructive),
        subtitle: l10n.configEndedOn(date),
      );
    }
    final days = DateTime.utc(
      at.year,
      at.month,
      at.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    return DsRow(
      glyph: Glyph.calendar,
      title: l10n.configTermLeft(days),
      subtitle: l10n.configActiveUntil(date),
    );
  }
}

class TrafficRow extends StatelessWidget {
  const TrafficRow({
    super.key,
    required this.used,
    required this.total,
    this.warning = false,
  });

  final int used;
  final int total;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (total <= 0) {
      return DsRow(
        glyph: Glyph.zap,
        title: l10n.configTraffic,
        subtitle: l10n.configUsedNoLimit(formatBytes(used)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsRow(
          glyph: Glyph.zap,
          title: l10n.configTraffic,
          subtitle: l10n.configTrafficUsedOf(
            formatBytes(used),
            formatBytes(total),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DsProgress(value: warning ? 1 : used / total, warning: warning),
        ),
      ],
    );
  }
}

class DevicesRow extends StatelessWidget {
  const DevicesRow({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) => DsRow(
    glyph: Glyph.smartphone,
    title: context.l10n.configDevices,
    subtitle: subtitle,
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.glyph, required this.title, required this.url});

  final Glyph glyph;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) => DsRow(
    glyph: glyph,
    title: title,
    trailing: const [DsAction(glyph: Glyph.externalLink)],
    onTap: () => _open(context),
  );

  Future<void> _open(BuildContext context) async {
    final l10n = context.l10n;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showToast(context, l10n.configCouldNotOpenLink);
    }
  }
}
