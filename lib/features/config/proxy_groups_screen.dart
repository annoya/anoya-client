import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clash_plan.dart';
import '../../core/country_flag.dart';
import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/plan_group_member.dart';
import '../../state/profiles_controller.dart';
import '../../state/provider_rule_lists.dart';
import '../home_widgets.dart';
import 'provider_routing_card.dart';

class ProxyGroupsScreen extends ConsumerStatefulWidget {
  const ProxyGroupsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProxyGroupsScreen> createState() => _ProxyGroupsScreenState();
}

class _ProxyGroupsScreenState extends ConsumerState<ProxyGroupsScreen> {
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _pollWhile(bool downloading) {
    if (!downloading) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(
      kListStatusPoll,
      (_) => ref.invalidate(providerRuleListsProvider(widget.profileId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profilesControllerProvider);
    final p = st.profiles.where((p) => p.id == widget.profileId).firstOrNull;
    final plan = p?.plan;
    if (p == null || plan == null) return const DsPage();
    final l10n = context.l10n;
    final lists = ref.watch(providerRuleListsProvider(p.id)).value;
    final missing = {
      for (final s in lists ?? const <RuleListStatus>[])
        if (!s.available) s.list.name,
    };
    final failed = [
      for (final s in lists ?? const <RuleListStatus>[])
        if (!s.available && s.error != null) s,
    ];
    _pollWhile(missing.isNotEmpty && failed.isEmpty);
    final catchAll = plan.groupOf(plan.catchAll);
    final listed = plan.ruleGroups.where((g) => g != catchAll).toList();

    Widget row(PlanGroup g) => _GroupRow(
      profile: p,
      group: g,
      waiting: plan.rules
          .where((r) => r.target == ClashPlan.groupRef(g.name))
          .every((r) => r.lists.isNotEmpty && r.lists.any(missing.contains)),
    );

    final notes = [
      if (plan.catchAll == ClashPlan.direct) l10n.proxyGroupsRestDirect,
      if (plan.skipped > 0) l10n.proxyGroupsNotApplied(plan.skipped),
    ];
    final choosable = listed.where((g) => g.isChoosable).toList();
    final fixed = listed.where((g) => !g.isChoosable).toList();
    return DsPage(
      title: l10n.proxyGroupsTitle,
      children: [
        if (failed.isNotEmpty)
          RuleListFailureCard(profile: p, failed: failed)
        else if (missing.isNotEmpty)
          DsNotification(
            glyph: Glyph.download,
            title: l10n.proxyGroupsDownloading(
              lists!.length - missing.length,
              lists.length,
            ),
            body: l10n.proxyGroupsDownloadingBody,
          ),
        if (catchAll != null)
          DsGroup(
            caption: l10n.proxyGroupsEverythingElse,
            children: [row(catchAll)],
          )
        else if (p.locations.where((l) => l.id == plan.catchAll).firstOrNull
            case final server?)
          DsGroup(
            caption: l10n.proxyGroupsEverythingElse,
            children: [
              DsRow(
                leading: flagOrIcon(server),
                title: stripLeadingFlag(server.label),
                subtitle: server.subtitle,
              ),
            ],
          ),
        if (choosable.isNotEmpty)
          DsGroup(
            caption: l10n.proxyGroupsChooseExit,
            children: choosable.map(row).toList(),
          ),
        if (fixed.isNotEmpty)
          DsGroup(
            caption: l10n.proxyGroupsSetBySubscription,
            children: fixed.map(row).toList(),
          ),
        if (notes.isNotEmpty) DsNote(notes.join(' ')),
      ],
    );
  }
}

const kListStatusPoll = Duration(seconds: 2);

class _GroupRow extends ConsumerWidget {
  const _GroupRow({
    required this.profile,
    required this.group,
    required this.waiting,
  });

  final Profile profile;
  final PlanGroup group;
  final bool waiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = profile.plan!;
    final name = splitGroupName(group.name);
    final index = plan.groups.indexOf(group);
    final live = ref.watch(planGroupMemberProvider(index)).value ?? '';
    final String exit;
    if (group.members.length == 1 && group.members.first == ClashPlan.direct) {
      exit = l10n.proxyGroupsDirectOutside;
    } else if (group.isSelect) {
      final chosen = effectiveMember(group, profile.groupChoices);
      final title = describePlanRef(chosen, profile).title;
      final nested = plan.groupOf(chosen);
      final now = nested == null || nested.isSelect
          ? ''
          : ref
                    .watch(planGroupMemberProvider(plan.groups.indexOf(nested)))
                    .value ??
                '';
      final shown = now.isEmpty ? title : '$title · $now';
      exit = profile.groupChoices.containsKey(group.name)
          ? l10n.proxyGroupsYourChoice(shown)
          : shown;
    } else {
      final what = group.engineGroup.describe(group.members.length);
      exit = live.isEmpty ? what : '$what · $live';
    }
    final tile = DsRow(
      leading: name.leading,
      title: name.title,
      subtitle: waiting ? l10n.proxyGroupsWaiting(exit) : exit,
      subtitleMaxLines: 1,
      trailing: [if (group.isChoosable) const DsChevron(down: true)],
      onTap: group.isChoosable ? () => _pick(context, ref) : null,
    );
    return waiting ? Opacity(opacity: kDisabledOpacity, child: tile) : tile;
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = effectiveMember(group, profile.groupChoices);
    final picked = await pickOption<String>(
      context,
      title: splitGroupName(group.name).title,
      selected: current,
      pinnedHeader: l10n.proxyGroupsFromSubscription,
      pinned: [
        for (final (i, m) in group.members.indexed)
          () {
            final d = describePlanRef(m, profile);
            return Option(
              m,
              d.title,
              subtitle: i == 0
                  ? l10n.proxyGroupsDefault(d.detail ?? d.title)
                  : d.detail,
              leading: d.leading,
            );
          }(),
      ],
      options: const [],
    );
    if (picked == null) return;
    await ref
        .read(profilesControllerProvider.notifier)
        .setGroupChoice(
          profile.id,
          group.name,
          picked == group.members.first ? null : picked,
        );
  }
}

({Widget leading, String title}) splitGroupName(String name) {
  final chars = name.characters;
  final first = chars.isEmpty ? '' : chars.first;
  final rest = chars.skip(1).toString();
  final symbol =
      first.isNotEmpty &&
      !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(first) &&
      rest.startsWith(' ');
  if (!symbol) return (leading: const GlyphIcon(Glyph.split), title: name);
  return (
    leading: SizedBox.square(
      dimension: kRowIcon,
      child: Center(child: Text(first, style: const TextStyle(fontSize: 20))),
    ),
    title: rest.trim(),
  );
}

({String title, String? detail, Widget leading}) describePlanRef(
  String ref,
  Profile p,
) {
  final l10n = L10n.current;
  if (ref == ClashPlan.direct) {
    return (
      title: l10n.proxyGroupsDirect,
      detail: l10n.proxyGroupsOutsideVpn,
      leading: const GlyphIcon(Glyph.globe),
    );
  }
  if (ref == ClashPlan.block) {
    return (
      title: l10n.proxyGroupsBlocked,
      detail: null,
      leading: const GlyphIcon(Glyph.xCircle),
    );
  }
  final group = p.plan?.groupOf(ref);
  if (group != null) {
    final name = splitGroupName(group.name);
    return (
      title: name.title,
      detail: group.isSelect
          ? describePlanRef(effectiveMember(group, p.groupChoices), p).title
          : group.engineGroup.describe(group.members.length),
      leading: group.isSelect ? name.leading : GlyphIcon(groupIcon(group.type)),
    );
  }
  final loc = p.locations.where((l) => l.id == ref).firstOrNull;
  if (loc != null) {
    return (
      title: stripLeadingFlag(loc.label),
      detail: loc.subtitle,
      leading: flagOrIcon(loc),
    );
  }
  return (title: ref, detail: null, leading: const GlyphIcon(Glyph.split));
}

class ProxyGroupsCard extends ConsumerWidget {
  const ProxyGroupsCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = profile.plan!;
    final groups = plan.ruleGroups;
    final String subtitle;
    if (plan.catchAll == ClashPlan.direct) {
      final tunnelled = groups.where((g) {
        final exit = resolvePlanRef(
          ClashPlan.groupRef(g.name),
          plan,
          profile.groupChoices,
        );
        return exit != ClashPlan.direct && exit != ClashPlan.block;
      }).length;
      subtitle = l10n.homeProxyGroupsDirect(tunnelled);
    } else {
      final exit = resolvePlanRef(plan.catchAll, plan, profile.groupChoices);
      final group = plan.groupOf(exit);
      final live = group == null
          ? ''
          : ref
                    .watch(planGroupMemberProvider(plan.groups.indexOf(group)))
                    .value ??
                '';
      final server = live.isNotEmpty
          ? live
          : describePlanRef(exit, profile).title;
      subtitle = l10n.homeProxyGroupsRest(server, groups.length);
    }
    return DsCard(
      children: [
        DsRow(
          glyph: Glyph.network,
          title: l10n.proxyGroupsTitle,
          subtitle: subtitle,
          subtitleMaxLines: 1,
          trailing: const [DsChevron()],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProxyGroupsScreen(profileId: profile.id),
            ),
          ),
        ),
      ],
    );
  }
}
