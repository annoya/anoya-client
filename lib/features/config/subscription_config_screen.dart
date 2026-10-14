import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import 'config_parts.dart';

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
        RoutingRow(profile: p),
        if (p.providerInfo != null) ProviderSection(info: p.providerInfo!),
        DsStack(
          gap: 0,
          children: [
            if (p.deviceLimitActive) const ThisDeviceSection(),
            ConfigActions(profile: p, isActive: isActive),
          ],
        ),
      ],
    );
  }
}
