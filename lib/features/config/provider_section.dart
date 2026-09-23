import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/subscription_info.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';

class ProviderSection extends StatelessWidget {
  const ProviderSection({super.key, required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.configSectionDetails),
        if (info.announce.isNotEmpty)
          Card(
            margin: kCardMargin,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Text(
                info.announce,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        if (info.hasPlan) _PlanCard(info: info),
        if (info.supportUrl.isNotEmpty)
          Card(
            margin: kCardMargin,
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(l10n.configGetSupport),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final uri = Uri.tryParse(info.supportUrl);
                if (uri == null ||
                    !await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                  if (context.mounted) {
                    showToast(context, l10n.configCouldNotOpenLink);
                  }
                }
              },
            ),
          ),
        if (!info.hasPlan && info.announce.isEmpty && info.supportUrl.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
            child: Text(
              l10n.configNoPlanDetails,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final warn = Theme.of(context).colorScheme.error;
    final l10n = context.l10n;
    return Card(
      margin: kCardMargin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.unlimited
                  ? l10n.configUsedNoLimit(formatBytes(info.usedBytes))
                  : l10n.configTrafficOf(
                      formatBytes(info.usedBytes),
                      formatBytes(info.totalBytes),
                    ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!info.unlimited) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (info.usedBytes / info.totalBytes).clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _planLine(l10n, info),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: info.expired ? warn : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _planLine(AppLocalizations l10n, SubscriptionInfo info) {
    final at = info.expiresAt;
    final when = at == null
        ? l10n.configNoExpiryDate
        : info.expired
        ? l10n.configExpiredOn(l10n.configDateShort(at))
        : l10n.configActiveUntil(l10n.configDateShort(at));
    return l10n.configPlanLine(when);
  }
}
