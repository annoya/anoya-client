import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/provider_rule_lists.dart';
import 'config_parts.dart';

/// Where a configuration's traffic goes, and who names the addresses.
///
/// Its own page because the configuration screen answers a different question —
/// what this subscription is and whether it is still alive — and these two
/// sections were the largest thing on it while being the part almost nobody
/// opens. One row leads here now.
///
/// Routing and DNS are not the same subject and keep their own headers. They
/// share a page because they are opened for the same reason: something went
/// somewhere the user did not expect, and the answer is in one of the two.
class RoutingConfigScreen extends ConsumerWidget {
  const RoutingConfigScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(profilesControllerProvider);
    Profile? profile;
    for (final p in st.profiles) {
      if (p.id == profileId) profile = p;
    }
    if (profile == null) {
      // Removed while open.
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final p = profile;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.configRouting)),
      body: PageBody(
        child: ListView(
          children: [
            ..._routing(l10n, ref, p),
            NamesSection(profile: p),
          ],
        ),
      ),
    );
  }

  /// The policy controls for whichever of the three kinds of configuration this
  /// is. They differ in what they *are*, not in details (ADR-005): a policy the
  /// organization sets and enforces, one a panel offered and the user may
  /// refuse, and the device's own.
  List<Widget> _routing(AppLocalizations l10n, WidgetRef ref, Profile p) {
    if (p.routing != null) {
      return [
        SectionHeader(l10n.configSectionOrganizationRouting),
        ManagedRoutingCard(routing: p.routing!),
        SectionNote(l10n.configOrganizationRoutingNote),
      ];
    }
    if (p.providerRouting != null) {
      // Only a list the user asked for can be "missing": before the switch is
      // on there is nothing to have failed.
      final failed = p.providerRuleListsEnabled
          ? (ref.watch(providerRuleListsProvider(p.id)).value ?? const [])
                .where((s) => !s.available)
                .toList()
          : const <RuleListStatus>[];
      return [
        SectionHeader(l10n.configSectionSubscriptionRouting),
        ProviderRoutingCard(profile: p),
        if (failed.isNotEmpty) RuleListFailureCard(profile: p, failed: failed),
        // Two owners, two headers: without them the page reads as one setting
        // shown twice.
        SectionHeader(l10n.configSectionDeviceRouting),
        // Visible but genuinely out of reach while the provider's routes are
        // on. Dimming alone left the switch tappable and the rule set
        // openable, and neither changed anything — a control that moves and
        // does nothing teaches the user not to trust the screen. The one real
        // switch is the provider's above, and the note says so.
        IgnorePointer(
          ignoring: p.providerRoutingEnabled,
          child: Opacity(
            opacity: p.providerRoutingEnabled ? 0.38 : 1,
            child: LocalRoutingCard(
              profile: p,
              overriddenBy: p.providerRoutingEnabled
                  ? l10n.configSubscriptionRoutes
                  : null,
            ),
          ),
        ),
        SectionNote(l10n.configSubscriptionRoutingNote),
      ];
    }
    return [
      SectionHeader(l10n.configSectionDeviceRouting),
      LocalRoutingCard(profile: p),
      SectionNote(l10n.configDeviceRoutingNote),
    ];
  }
}
