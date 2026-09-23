import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/provider_rule_lists.dart';
import 'config_parts.dart';

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

  List<Widget> _routing(AppLocalizations l10n, WidgetRef ref, Profile p) {
    if (p.routing != null) {
      return [
        SectionHeader(l10n.configSectionOrganizationRouting),
        ManagedRoutingCard(routing: p.routing!),
        SectionNote(l10n.configOrganizationRoutingNote),
      ];
    }
    if (p.providerRouting != null) {
      final failed = p.providerRuleListsEnabled
          ? (ref.watch(providerRuleListsProvider(p.id)).value ?? const [])
                .where((s) => !s.available)
                .toList()
          : const <RuleListStatus>[];
      return [
        SectionHeader(l10n.configSectionSubscriptionRouting),
        ProviderRoutingCard(profile: p),
        if (failed.isNotEmpty) RuleListFailureCard(profile: p, failed: failed),
        SectionHeader(l10n.configSectionDeviceRouting),
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
