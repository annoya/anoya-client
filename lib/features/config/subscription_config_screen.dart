import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import 'config_parts.dart';
import 'subscription_mode.dart';

class SubscriptionConfigScreen extends ConsumerWidget {
  const SubscriptionConfigScreen({
    super.key,
    required this.profile,
    required this.isActive,
  });

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    return DsPage(
      title: p.name,
      children: [
        DsStack(
          gap: kNoteGap,
          children: [
            DsCard(
              children: [
                ProfileHeaderRow(profile: p, isActive: isActive),
                if (p.subscriptionUrl != null)
                  SourceRow(
                    value: p.subscriptionUrl!,
                    openUrl: p.providerInfo?.webPageUrl.isNotEmpty == true
                        ? p.providerInfo!.webPageUrl
                        : p.subscriptionUrl,
                  ),
                RefreshRow(profile: p),
              ],
            ),
            if (p.usedFallback) const FallbackSourceNote(),
          ],
        ),
        if (p.deviceLimitReached) const DeviceLimitAlert(),
        if (p.unsupportedServers.isNotEmpty)
          UnsupportedServersAlert(profile: p),
        if (p.hasModes) SubscriptionModeGroup(profile: p),
        if (SubscriptionPlanGroup.shows(p)) SubscriptionPlanGroup(profile: p),
        RoutingRow(profile: p),
        DsStack(
          gap: 0,
          children: [
            ThisDeviceSection(
              counted: p.deviceLimitActive || p.deviceLimitReached,
            ),
            ConfigActions(profile: p, isActive: isActive),
          ],
        ),
      ],
    );
  }
}
