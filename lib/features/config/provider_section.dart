import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/subscription_info.dart';
import '../../core/ui.dart';

/// Everything the subscription's panel reported, in its own voice.
///
/// The header is neutral because the rows already carry the attribution: the
/// provider's message stands without an icon of ours, and the plan's numbers
/// say "what the subscription reports, not verified here". Naming the section
/// after the source said it a third time, and in testing it read as the name of
/// some separate thing rather than as "details of this subscription". What must
/// not happen is the opposite — calling it ACCOUNT, which would claim an
/// authority a subscription does not have (ADR-005).
class ProviderSection extends StatelessWidget {
  const ProviderSection({super.key, required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('DETAILS'),
      if (info.announce.isNotEmpty)
        Card(
          margin: kCardMargin,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            // Their text, rendered as text: no links made clickable out of it,
            // and no warning icon lent to it. A provider's message is not a
            // state of the app.
            child: Text(info.announce, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      if (info.hasPlan) _PlanCard(info: info),
      if (info.supportUrl.isNotEmpty)
        Card(
          margin: kCardMargin,
          child: ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Get support'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.tryParse(info.supportUrl);
              if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) showToast(context, 'Couldn’t open that link.');
              }
            },
          ),
        ),
      if (!info.hasPlan && info.announce.isEmpty && info.supportUrl.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
          child: Text('Your subscription reported no plan details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
        ),
    ]);
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final warn = Theme.of(context).colorScheme.error;
    return Card(
      margin: kCardMargin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            info.unlimited
                // A share of zero is not a number: a bar here would read as
                // "all used up" for a plan that has no ceiling at all.
                ? 'Used ${formatBytes(info.usedBytes)} · no limit'
                : 'Traffic: ${formatBytes(info.usedBytes)} of ${formatBytes(info.totalBytes)}',
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
            _planLine(info),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: info.expired ? warn : muted),
          ),
        ]),
      ),
    );
  }

  String _planLine(SubscriptionInfo info) {
    final at = info.expiresAt;
    final when = at == null
        ? 'No expiry date given'
        : '${info.expired ? 'Expired' : 'Active until'} ${_date(at)}';
    return '$when · what the subscription reports, not verified here';
  }

  String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
