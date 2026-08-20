import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/log.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';
import '../../core/rule_list_store.dart';
import 'config_parts.dart';

/// Settings of a subscription.
///
/// A subscription is a feed of servers and nothing more (ADR-005): the panel on
/// the other end controls access by changing what the URL returns, so there is
/// no account to show and no status it could tell us. What it does have is an
/// origin — hence the source and the refresh — and routing that is the device's
/// own unless the panel sent rules, in which case both are offered and the user
/// picks.
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
    // Only a list the user asked for can be "missing": before the switch is on
    // there is nothing to have failed.
    final failedLists = p.providerRuleListsEnabled
        ? (ref.watch(providerRuleListsProvider(p.id)).value ?? const [])
            .where((s) => !s.available)
            .toList()
        : const <RuleListStatus>[];
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: PageBody(
        child: ListView(children: [
          const SizedBox(height: 8),
          ProfileHeaderCard(profile: p, isActive: widget.isActive),
          if (p.deviceLimitReached) const DeviceLimitCard(),
          if (p.unsupportedServers.isNotEmpty) UnsupportedServersCard(profile: p),
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
          if (p.providerRouting != null) ...[
            ProviderRoutingCard(profile: p),
            if (failedLists.isNotEmpty)
              RuleListFailureCard(profile: p, failed: failedLists),
            // The local card stays reachable: turning the provider's routes off
            // is only a real choice if the alternative is visible and pickable.
            Opacity(
              opacity: p.providerRoutingEnabled ? 0.38 : 1,
              child: LocalRoutingCard(
                profile: p,
                overriddenBy: p.providerRoutingEnabled ? 'the provider’s routes' : null,
              ),
            ),
            const SectionNote('Turn the switch off to use your own rule set '
                'instead. Your provider cannot enforce this either way.'),
          ] else
            LocalRoutingCard(profile: p),
          ConfigActions(profile: p, isActive: widget.isActive),
        ]),
      ),
    );
  }
}
