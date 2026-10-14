import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/norm_config.dart';
import '../../core/profile.dart';
import '../../core/ds.dart';
import '../../core/rule_set.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/routing_status.dart';
import '../dns_screen.dart';
import 'routing_config_screen.dart';
import '../managed_policy_screen.dart';
import '../rule_sets_screen.dart';
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
    final on = profile.routingEnabled;

    if (overriddenBy != null) {
      return DsCard(
        children: [
          DsRow(
            glyph: Glyph.layers,
            title: l10n.configRuleSet,
            subtitle: l10n.configReplacedBy(overriddenBy!),
            trailing: const [DsChevron(down: true)],
            enabled: false,
          ),
        ],
      );
    }
    return DsCard(
      children: [
        DsRow(
          glyph: Glyph.split,
          title: l10n.configRouting,
          subtitle: localRoutingSummary(profile, ruleSet),
          onTap: () => ctrl.setRoutingEnabled(profile.id, !on),
          trailing: [
            DsToggle(
              value: on,
              onChanged: (v) => ctrl.setRoutingEnabled(profile.id, v),
            ),
          ],
        ),
        Opacity(
          opacity: on ? 1 : kDisabledOpacity,
          child: DsRow(
            glyph: Glyph.layers,
            title: l10n.configRuleSet,
            subtitle: ruleSet?.name ?? l10n.configRuleSetDefault,
            trailing: const [DsChevron(down: true)],
            onTap: () => _pick(context, ref, sets),
          ),
        ),
        const RuleSetsRow(),
      ],
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
              leading: const GlyphIcon(Glyph.layers),
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

class ManagedRoutingRow extends StatelessWidget {
  const ManagedRoutingRow({super.key, required this.routing});

  final Routing routing;

  @override
  Widget build(BuildContext context) => DsRow(
    glyph: Glyph.building2,
    title: context.l10n.configManagedByOrganization,
    subtitle: context.l10n.configManagedSummary(
      routing.mode == 'split'
          ? context.l10n.ruleSetModeSplit
          : context.l10n.ruleSetModeFull,
      routing.rules.length,
    ),
    trailing: const [DsChevron()],
    onTap: () => openManagedRouting(context, routing),
  );
}

class RuleSetsRow extends ConsumerWidget {
  const RuleSetsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final count = ref.watch(ruleSetsProvider).value?.length;
    return DsRow(
      glyph: Glyph.layers,
      title: l10n.ruleSetsTitle,
      subtitle: count == null ? null : l10n.settingsRuleSetCount(count),
      trailing: const [DsChevron()],
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const RuleSetsScreen())),
    );
  }
}

class RoutingRow extends ConsumerWidget {
  const RoutingRow({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = dnsPlanForProfile(ref, profile);
    final l10n = context.l10n;
    final dns = plan.dropped.isNotEmpty
        ? l10n.configDnsRefused(plan.dropped.length)
        : plan.usingFallback
        ? l10n.configDnsByApp
        : l10n.configDnsOrigin(dnsOriginLabel(profile, plan));
    return DsGroup(
      caption: l10n.settingsSectionRouting,
      children: [
        DsRow(
          glyph: Glyph.split,
          title: l10n.configRouting,
          subtitle: '${_routing(l10n, ref)} · $dns',
          trailing: const [DsChevron()],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoutingConfigScreen(profileId: profile.id),
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
