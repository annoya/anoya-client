import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/provider_rule_lists.dart';
import 'config_parts.dart';
import 'subscription_rules_card.dart';

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
    if (profile == null) return const DsPage();
    final p = profile;
    final l10n = context.l10n;
    final note = p.routing != null
        ? l10n.configOrganizationRoutingNote
        : p.usesSubscriptionRules
        ? l10n.routingSubscriptionRulesNote
        : p.providerRouting != null
        ? l10n.configSubscriptionRoutingNote
        : null;
    return DsPage(
      title: l10n.configRouting,
      children: [
        ..._routing(context, ref, p),
        DsStack(
          gap: kNoteGap,
          children: [
            NamesSection(profile: p),
            if (note != null) DsNote(note),
          ],
        ),
      ],
    );
  }

  List<Widget> _routing(BuildContext context, WidgetRef ref, Profile p) {
    final l10n = context.l10n;
    if (p.routing != null) {
      return [
        DsGroup(
          caption: l10n.configSectionOrganizationRouting,
          color: context.ds.accentSubtle,
          children: [ManagedRoutingRow(routing: p.routing!)],
        ),
      ];
    }
    if (p.usesSubscriptionRules) {
      final failed = (ref.watch(providerRuleListsProvider(p.id)).value ?? [])
          .where((s) => !s.available && s.error != null)
          .toList();
      return [
        DsGroup(
          caption: l10n.configSectionSubscriptionRouting,
          child: SubscriptionRulesCard(profile: p),
        ),
        if (failed.isNotEmpty) RuleListFailureCard(profile: p, failed: failed),
        DsGroup(
          caption: l10n.configSectionDeviceRouting,
          child: IgnorePointer(
            child: LocalRoutingCard(
              profile: p,
              lockedNote: l10n.routingWorksWithOwnRules,
            ),
          ),
        ),
      ];
    }
    if (p.providerRouting != null) {
      final failed = p.providerRuleListsEnabled
          ? (ref.watch(providerRuleListsProvider(p.id)).value ?? const [])
                .where((s) => !s.available)
                .toList()
          : const <RuleListStatus>[];
      return [
        DsGroup(
          caption: l10n.configSectionSubscriptionRouting,
          child: ProviderRoutingCard(profile: p),
        ),
        if (failed.isNotEmpty) RuleListFailureCard(profile: p, failed: failed),
        DsGroup(
          caption: l10n.configSectionDeviceRouting,
          child: IgnorePointer(
            ignoring: p.providerRoutingEnabled,
            child: LocalRoutingCard(
              profile: p,
              overriddenBy: p.providerRoutingEnabled
                  ? l10n.configSubscriptionRoutes
                  : null,
            ),
          ),
        ),
      ];
    }
    return [
      DsGroup(
        caption: l10n.configSectionDeviceRouting,
        note: l10n.configDeviceRoutingNote,
        child: LocalRoutingCard(profile: p),
      ),
    ];
  }
}
