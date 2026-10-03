import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/provider_rule_lists.dart';
import '../../state/routing_status.dart';
import '../rule_sets_screen.dart';
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
        const RuleSetsCard(),
        SectionNote(l10n.configSubscriptionRoutingNote),
      ];
    }
    return [
      SectionHeader(l10n.configSectionDeviceRouting),
      LocalRoutingCard(profile: p),
      const RuleSetsCard(),
      SectionNote(l10n.configDeviceRoutingNote),
    ];
  }
}

class RuleSetsCard extends ConsumerWidget {
  const RuleSetsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final count = ref.watch(ruleSetsProvider).value?.length;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.edit_outlined),
        title: Text(l10n.ruleSetsTitle),
        subtitle: count == null ? null : Text(l10n.settingsRuleSetCount(count)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RuleSetsScreen())),
      ),
    );
  }
}
