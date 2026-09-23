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

/// The routing section for a configuration whose rules are the device's own:
/// an opt-in switch plus the rule set in force.
class LocalRoutingCard extends ConsumerWidget {
  const LocalRoutingCard({super.key, required this.profile, this.overriddenBy});

  final Profile profile;

  /// Names the policy standing in for this one, when something else is in
  /// force. Dimming alone would say "unavailable"; the row has to say why, and
  /// stay usable, because switching back is how the user takes it over again.
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
            // The subtitle is the policy in force, not a description of the
            // switch: the set itself is named in the row below, and repeating it
            // here would say nothing new.
            subtitle: Text(
              overriddenBy != null
                  ? l10n.configReplacedBy(overriddenBy!)
                  : localRoutingSummary(profile, ruleSet),
            ),
            value: profile.routingEnabled,
            onChanged: (v) => ctrl.setRoutingEnabled(profile.id, v),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Kept visible while off — hiding it would make the switch look like it
          // controls nothing, and the chosen set is remembered for when routing
          // comes back on.
          Opacity(
            opacity: profile.routingEnabled ? 1 : 0.38,
            child: ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: Text(l10n.configRuleSet),
              subtitle: Text(ruleSet?.name ?? l10n.configRuleSetDefault),
              trailing: const Icon(Icons.expand_more),
              // Reachable with routing off: picking a set is how it gets turned on.
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

/// Opens the read-only view of a policy the configuration did not choose.
void openManagedRouting(BuildContext context, Routing routing) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ManagedPolicyScreen(routing)));
}

/// The policy a device's own rule set puts in force, in one line.
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

/// A policy the organization owns: shown, never switched.
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

/// The one row that stands in for everything about where traffic goes and who
/// names the addresses.
///
/// Both used to sit on the configuration screen and were the largest thing on
/// it, while being the part almost nobody opens. The subtitle carries the two
/// facts a passer-by would have read off those sections — the policy in force
/// and whose resolvers — so moving them costs no one an answer they used to
/// get for free.
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
                  // The refusals were just taken out of a log file nobody reads.
                  // Leaving them two taps away would put them back — in words, and in
                  // the one place a passer-by looks.
                  if (plan.dropped.isEmpty)
                    // "DNS app default" reads as a typo; the app is the one origin
                    // that needs a preposition of its own.
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

  /// Whichever of the three policies is actually in force.
  String _routing(AppLocalizations l10n, WidgetRef ref) {
    // Named rather than summarised: a row that leads to something the user
    // cannot change should say so before it is tapped.
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
