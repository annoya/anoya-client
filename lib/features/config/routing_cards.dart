import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/norm_config.dart';
import '../../core/profile.dart';
import '../../core/rule_set.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/routing_status.dart';
import '../dns_screen.dart';
import 'routing_config_screen.dart';
import '../managed_policy_screen.dart';
import '../../state/provider_rule_lists.dart';
import 'provider_routing_card.dart';

class LocalRoutingCard extends ConsumerWidget {
  const LocalRoutingCard({super.key, required this.profile, this.overriddenBy});

  final Profile profile;

  final String? overriddenBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(ruleSetsProvider).value ?? const <RuleSet>[];
    final ruleSet = sets
        .where((s) => s.id == (profile.ruleSetId ?? RuleSet.defaultId))
        .firstOrNull;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    final l10n = context.l10n;

    return Card(
      margin: kCardMargin,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.alt_route),
            title: Text(l10n.configRouting),
            subtitle: Text(
              overriddenBy != null
                  ? l10n.configReplacedBy(overriddenBy!)
                  : localRoutingSummary(profile, ruleSet),
            ),
            value: profile.routingEnabled,
            onChanged: (v) => ctrl.setRoutingEnabled(profile.id, v),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Opacity(
            opacity: profile.routingEnabled ? 1 : 0.38,
            child: ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: Text(l10n.configRuleSet),
              subtitle: Text(ruleSet?.name ?? l10n.configRuleSetDefault),
              trailing: const Icon(Icons.expand_more),
              // Tappable while dimmed: picking a set is how routing gets turned on.
              onTap: () => _pick(context, ref, sets),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<RuleSet> sets,
  ) async {
    final l10n = context.l10n;
    final picked = await pickOption<String>(
      context,
      title: l10n.configRuleSet,
      selected: profile.ruleSetId ?? RuleSet.defaultId,
      options: sets
          .map(
            (s) => Option(
              s.id,
              s.name,
              subtitle: l10n.ruleSetSummary(
                s.mode.label,
                s.rules.isEmpty
                    ? l10n.ruleSetNoRules
                    : l10n.configRulesCount(s.rules.length),
              ),
              leading: const Icon(Icons.layers_outlined),
            ),
          )
          .toList(),
    );
    if (picked != null) {
      await ref
          .read(profilesControllerProvider.notifier)
          .setRuleSet(profile.id, picked);
    }
  }
}

void openManagedRouting(BuildContext context, Routing routing) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ManagedPolicyScreen(routing)));
}

String localRoutingSummary(Profile p, RuleSet? set) {
  final l10n = L10n.current;
  if (!p.routingEnabled) return l10n.configRoutingOffSummary;
  final mode = (set?.mode ?? RoutingMode.full).label;
  final rules = set?.rules.length ?? 0;
  return l10n.ruleSetSummary(
    mode,
    rules == 0 ? l10n.ruleSetNoRules : l10n.configRulesCount(rules),
  );
}

class ManagedRoutingCard extends StatelessWidget {
  const ManagedRoutingCard({super.key, required this.routing});

  final Routing routing;

  @override
  Widget build(BuildContext context) => Card(
    margin: kCardMargin,
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.35),
    child: ListTile(
      leading: const Icon(Icons.business_outlined),
      title: Text(context.l10n.configManagedByOrganization),
      subtitle: Text(
        context.l10n.configManagedSummary(
          routing.mode == 'split'
              ? context.l10n.ruleSetModeSplit
              : context.l10n.ruleSetModeFull,
          routing.rules.length,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openManagedRouting(context, routing),
    ),
  );
}

class RoutingRow extends ConsumerWidget {
  const RoutingRow({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final plan = dnsPlanForProfile(ref, profile);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.settingsSectionRouting),
        Card(
          margin: kCardMargin,
          child: ListTile(
            leading: const Icon(Icons.alt_route),
            title: Text(l10n.configRouting),
            subtitle: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${_routing(l10n, ref)} · '),
                  if (plan.dropped.isEmpty)
                    TextSpan(
                      text: plan.usingFallback
                          ? l10n.configDnsByApp
                          : l10n.configDnsOrigin(dnsOriginLabel(profile, plan)),
                    )
                  else
                    TextSpan(
                      text: l10n.configDnsRefused(plan.dropped.length),
                      style: TextStyle(color: cs.error),
                    ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RoutingConfigScreen(profileId: profile.id),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _routing(AppLocalizations l10n, WidgetRef ref) {
    if (profile.routing != null) {
      final mode = profile.routing!.mode == 'split'
          ? l10n.ruleSetModeSplit
          : l10n.ruleSetModeFull;
      return l10n.configSetByOrganization(mode);
    }
    if (profile.providerRouting != null && profile.providerRoutingEnabled) {
      return providerRoutingSummary(
        profile,
        ref.watch(providerRuleListsProvider(profile.id)).value,
      );
    }
    final sets = ref.watch(ruleSetsProvider).value ?? const <RuleSet>[];
    final set = sets
        .where((s) => s.id == (profile.ruleSetId ?? RuleSet.defaultId))
        .firstOrNull;
    return localRoutingSummary(profile, set);
  }
}
