import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/ui.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: PageBody(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            ProfileHeaderCard(profile: p, isActive: isActive),
            if (p.deviceLimitReached) const DeviceLimitCard(),
            if (p.unsupportedServers.isNotEmpty)
              UnsupportedServersCard(profile: p),
            if (p.subscriptionUrl != null)
              SourceCard(
                value: p.subscriptionUrl!,
                openUrl: p.providerInfo?.webPageUrl.isNotEmpty == true
                    ? p.providerInfo!.webPageUrl
                    : p.subscriptionUrl,
                viaFallback: p.usedFallback,
              ),
            RefreshCard(profile: p),
            RoutingRow(profile: p),
            if (p.providerInfo != null) ProviderSection(info: p.providerInfo!),
            if (p.deviceLimitActive) const ThisDeviceSection(),
            ConfigActions(profile: p, isActive: isActive),
          ],
        ),
      ),
    );
  }
}
