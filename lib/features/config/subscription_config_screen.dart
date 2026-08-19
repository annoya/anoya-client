import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/log.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';
import 'config_parts.dart';

/// Settings of a subscription.
///
/// A subscription is a feed of servers and nothing more (ADR-005): the panel on
/// the other end controls access by changing what the URL returns, so there is
/// no account to show and no status it could tell us. What it does have is an
/// origin — hence the source and the refresh — and routing that stays the
/// device's own.
class SubscriptionConfigScreen extends ConsumerStatefulWidget {
  const SubscriptionConfigScreen({super.key, required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  ConsumerState<SubscriptionConfigScreen> createState() => _SubscriptionConfigScreenState();
}

class _SubscriptionConfigScreenState extends ConsumerState<SubscriptionConfigScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final updated =
          await ref.read(profilesControllerProvider.notifier).refreshProfile(widget.profile.id);
      // The fetch itself succeeded — the panel simply answered with a refusal
      // and placeholders. Nothing threw, so without this the refresh would look
      // like it worked while the server list quietly turned into a message.
      if (updated.deviceLimitReached && mounted) {
        showToast(context, kDeviceLimitReached.line);
      }
    } catch (e) {
      Log.e('manual refresh failed', '$e');
      // The cached servers still work, so this is news, not a decision.
      if (mounted) {
        showToast(context,
            'Couldn’t refresh — ${describeError(e).detail ?? 'showing the servers we already have.'}');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: PageBody(
        child: ListView(children: [
          const SizedBox(height: 8),
          ProfileHeaderCard(profile: p, isActive: widget.isActive),
          if (p.deviceLimitReached) const DeviceLimitCard(),
          if (p.subscriptionUrl != null)
            SourceCard(
              value: p.subscriptionUrl!,
              // The panel names the page meant for people; its own URL is the
              // fallback, since that is what a browser would be given anyway.
              openUrl: p.providerInfo?.webPageUrl.isNotEmpty == true
                  ? p.providerInfo!.webPageUrl
                  : p.subscriptionUrl,
            ),
          RefreshCard(profile: p, refreshing: _refreshing, onRefresh: _refresh),
          if (p.providerInfo != null) ProviderSection(info: p.providerInfo!),
          if (p.deviceLimitActive) const ThisDeviceSection(),
          const SectionHeader('ROUTING'),
          LocalRoutingCard(profile: p),
          ConfigActions(profile: p, isActive: widget.isActive),
        ]),
      ),
    );
  }
}
