import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Routing')),
      body: PageBody(
        child: ListView(children: [
          ..._routing(ref, p),
          NamesSection(profile: p),
        ]),
      ),
    );
  }

  /// The policy controls for whichever of the three kinds of configuration this
  /// is. They differ in what they *are*, not in details (ADR-005): a policy the
  /// organization sets and enforces, one a panel offered and the user may
  /// refuse, and the device's own.
  List<Widget> _routing(WidgetRef ref, Profile p) {
    if (p.routing != null) {
      return [
        const SectionHeader('ORGANIZATION ROUTING'),
        ManagedRoutingCard(routing: p.routing!),
        const SectionNote('Your organization sets this policy and applies it. '
            'You can see what it is; changing it is done on their side.'),
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
        const SectionHeader('SUBSCRIPTION ROUTING'),
        ProviderRoutingCard(profile: p),
        if (failed.isNotEmpty) RuleListFailureCard(profile: p, failed: failed),
        // Two owners, two headers: without them the page reads as one setting
        // shown twice.
        const SectionHeader('DEVICE ROUTING'),
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
              overriddenBy: p.providerRoutingEnabled ? 'the subscription’s routes' : null,
            ),
          ),
        ),
        const SectionNote('Turn the switch off to use your own rule set '
            'instead. Your subscription cannot enforce this either way.'),
      ];
    }
    return [
      const SectionHeader('DEVICE ROUTING'),
      LocalRoutingCard(profile: p),
      const SectionNote('Rule sets are shared by every configuration; the '
          'switch is per configuration, so a work subscription and a personal '
          'one can use the same set differently.'),
    ];
  }
}
