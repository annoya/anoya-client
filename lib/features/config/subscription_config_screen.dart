import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/ui.dart';
import 'config_parts.dart';

/// Settings of a subscription.
///
/// A subscription is a feed of servers and nothing more (ADR-005): the panel on
/// the other end controls access by changing what the URL returns, so there is
/// no account to show and no status it could tell us. What it does have is an
/// origin — hence the source and the refresh — and routing that is the device's
/// own unless the panel sent rules, in which case both are offered and the user
/// picks.
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
                // The panel names the page meant for people; its own URL is the
                // fallback, since that is what a browser would be given anyway.
                openUrl: p.providerInfo?.webPageUrl.isNotEmpty == true
                    ? p.providerInfo!.webPageUrl
                    : p.subscriptionUrl,
                viaFallback: p.usedFallback,
              ),
            RefreshCard(profile: p),
            // Above the provider's own details: this is the configuration's
            // behaviour, and what the panel reports about the account is
            // background to it.
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
