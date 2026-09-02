import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';
import '../policy_origin.dart';
import '../routing_screen.dart';
import '../../state/provider_rule_lists.dart';

/// The routing section for a subscription whose panel sent rules of its own.
///
/// Applied by default — a provider that sent rules meant them — but with a
/// switch, which is the whole difference from a self-hosted policy: an
/// organization's server both sets and enforces its policy, while a panel can
/// only stop returning servers (ADR-005). It cannot decide where this device's
/// traffic goes, so the decision is stated in words rather than implied.
class ProviderRoutingCard extends ConsumerStatefulWidget {
  const ProviderRoutingCard({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<ProviderRoutingCard> createState() => _ProviderRoutingCardState();
}

class _ProviderRoutingCardState extends ConsumerState<ProviderRoutingCard> {
  /// A dozen files from someone else's hosts is seconds, and more on a phone.
  /// The switch cannot move until they are here — a rule whose list is missing
  /// matches nothing, so an early "on" would be a lie — so the row carries the
  /// state instead of leaving the tap unanswered.
  bool _downloading = false;

  Future<void> _setLists(bool enabled) async {
    if (enabled) setState(() => _downloading = true);
    try {
      await ref
          .read(profilesControllerProvider.notifier)
          .setProviderRuleListsEnabled(widget.profile.id, enabled);
      ref.invalidate(providerRuleListsProvider(widget.profile.id));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final cs = Theme.of(context).colorScheme;
    final routing = profile.providerRouting!;
    final on = profile.providerRoutingEnabled;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    final lists = ref.watch(providerRuleListsProvider(profile.id)).value;
    final needLists = routing.rules.where((r) => r.needsRuleList).length;
    return Card(
      margin: kCardMargin,
      color: cs.primaryContainer.withValues(alpha: 0.35),
      child: Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.alt_route),
          // Named like the device's own controls below it. Whose policy this
          // is comes from the section header, once, instead of from every row —
          // the width a repeated "from your provider" costs is width the
          // subtitle needs for facts.
          title: const Text('Routing'),
          subtitle: Text(providerRoutingSummary(profile, lists)),
          value: on,
          onChanged: (v) => ctrl.setProviderRoutingEnabled(profile.id, v),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        // Readable with the switch off: deciding whether to accept someone
        // else's rules requires seeing them first.
        ListTile(
          leading: const Icon(Icons.layers_outlined),
          title: const Text('Rule set'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RoutingScreen.managed(
              routing,
              origin: PolicyOrigin.provider(
                profile.name,
                skipped: profile.providerRoutingSkipped,
              ),
              // Null while the lists are refused, so the rules that need them
              // can say "off" rather than "not downloaded" — the user's own
              // decision reads differently from a failure.
              listsAvailable: profile.providerRuleListsEnabled
                  ? (lists ?? const [])
                      .where((s) => s.available)
                      .map((s) => s.list.name)
                      .toSet()
                  : null,
            ),
          )),
        ),
        // Only when there is something to decide: a policy with no external
        // lists would get a switch that governs nothing.
        if (needLists > 0) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            // The spinner takes the icon's place rather than the switch's, so
            // the row does not change width and it stays clear which operation
            // is running — the same shape as the refresh card.
            secondary: _downloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.description_outlined),
            title: const Text('Rule lists'),
            subtitle: Text(_downloading
                ? 'Downloading ${needLists == 1 ? 'one list' : '$needLists lists'}…'
                : _listSummary(profile, needLists, lists)),
            value: profile.providerRuleListsEnabled,
            // A second tap would not hurry the first, and two writers on the
            // same files is how half a list ends up on disk.
            onChanged: _downloading ? null : _setLists,
          ),
        ],
      ]),
    );
  }
}

/// The line under the switch. Says what is in force, and — when something is
/// missing — says that too, because a summary that reads as complete is the
/// one place this could mislead.
String providerRoutingSummary(Profile profile, List<RuleListStatus>? lists) {
  final routing = profile.providerRouting!;
  final mode = routing.mode == 'split' ? 'Split' : 'Full tunnel';
  final applied = routing.rules
      .where((r) => !r.needsRuleList || _isAvailable(profile, r.value, lists))
      .length;
  final rules = applied == 0 ? 'no exceptions' : '$applied rule${applied > 1 ? 's' : ''}';
  final parts = ['$mode · $rules'];
  final skipped = profile.providerRoutingSkipped;
  if (skipped > 0) parts.add('$skipped not supported');
  final missing = routing.rules.length - applied;
  if (missing > 0) {
    parts.add(profile.providerRuleListsEnabled
        ? '$missing list${missing > 1 ? 's' : ''} unavailable'
        : '$missing need${missing > 1 ? '' : 's'} their lists');
  }
  return parts.join(' · ');
}

bool _isAvailable(Profile p, String name, List<RuleListStatus>? lists) {
  if (!p.providerRuleListsEnabled) return false;
  // Unknown status is not the same as absent: while the read is in flight,
  // assume what the user asked for rather than flashing a failure.
  if (lists == null) return true;
  return lists.any((s) => s.list.name == name && s.available);
}

String _listSummary(Profile p, int needed, List<RuleListStatus>? lists) {
  if (!p.providerRuleListsEnabled) {
    return 'Off · $needed rule${needed > 1 ? 's' : ''} need${needed > 1 ? '' : 's'} them';
  }
  if (lists == null) return 'Checking…';
  final have = lists.where((s) => s.available).toList();
  if (have.isEmpty) return 'None downloaded yet';
  final kb = have.fold<int>(0, (a, s) => a + s.bytes) ~/ 1024;
  final count = have.length == lists.length
      ? '${have.length} list${have.length > 1 ? 's' : ''}'
      : '${have.length} of ${lists.length} downloaded';
  return '$count · $kb KB';
}

/// Shown when the provider named a list we could not fetch.
///
/// The engine would say nothing here: a rule whose list is missing matches
/// nothing, traffic falls through to the next rule, and the policy quietly
/// changes. So this is the same choice as for geo rules — the rule is not
/// applied and the fact is stated, with the one action that can fix it.

class RuleListFailureCard extends ConsumerStatefulWidget {
  const RuleListFailureCard({super.key, required this.profile, required this.failed});

  final Profile profile;
  final List<RuleListStatus> failed;

  @override
  ConsumerState<RuleListFailureCard> createState() => _RuleListFailureCardState();
}

class _RuleListFailureCardState extends ConsumerState<RuleListFailureCard> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(profilesControllerProvider.notifier)
          .syncRuleLists(widget.profile.id);
      ref.invalidate(providerRuleListsProvider(widget.profile.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warn = context.vpnColors.connecting;
    final n = widget.failed.length;
    final names = widget.failed.map((s) => '«${s.list.name}»').join(', ');
    final hosts = widget.failed
        .map((s) => Uri.parse(s.list.url).host)
        .toSet()
        .join(', ');
    return Card(
      margin: kCardMargin,
      color: warn.withValues(alpha: 0.12),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.warning_amber_outlined, color: warn),
          title: Text(n == 1
              ? 'One list could not be downloaded'
              : '$n lists could not be downloaded'),
          subtitle: Text('$names from $hosts — '
              'the rule${n > 1 ? 's' : ''} using ${n > 1 ? 'them' : 'it'} '
              '${n > 1 ? 'are' : 'is'} not applied.'),
          isThreeLine: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
            child: FilledButton.tonal(
              onPressed: _busy ? null : _retry,
              child: _busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Try again'),
            ),
          ),
        ),
      ]),
    );
  }
}
