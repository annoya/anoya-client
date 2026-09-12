import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing_policy.dart';
import '../core/rule_set.dart';
import 'profiles_controller.dart';

/// The routing policy in force for the active configuration, as the home
/// screen's status chip shows it.
enum RoutingStatus {
  /// No rule set applies — everything goes into the tunnel.
  off,

  /// A set applies with everything tunnelled by default; its rules are the
  /// exceptions.
  full,

  /// A set applies and only matching traffic is tunnelled.
  split;

  String get label => switch (this) {
    RoutingStatus.off => 'off',
    RoutingStatus.full => 'full',
    RoutingStatus.split => 'split',
  };

  static RoutingStatus ofMode(String mode) =>
      mode == 'split' ? RoutingStatus.split : RoutingStatus.full;
}

/// Bumped whenever a rule set changes on disk. The sets live in a file rather
/// than in a provider, so whatever displays their effective mode has nothing
/// else to listen to and would otherwise keep showing the mode from before the
/// edit.
class RuleSetRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final ruleSetRevisionProvider = NotifierProvider<RuleSetRevision, int>(
  RuleSetRevision.new,
);

/// Every rule set on the device, re-read after each edit.
final ruleSetsProvider = FutureProvider<List<RuleSet>>((ref) async {
  ref.watch(ruleSetRevisionProvider);
  return RuleSetStore.load();
});

/// Resolves what the active configuration actually does with traffic: the
/// server-managed policy when there is one, otherwise its rule set — and only
/// while routing is switched on for that configuration.
final routingStatusProvider = FutureProvider<RoutingStatus>((ref) async {
  // select: re-running this (and its RuleSetStore disk read) on every
  // switching/loading/error flip of the profiles state is pure waste.
  final profile = ref.watch(profilesControllerProvider.select((s) => s.active));
  ref.watch(ruleSetRevisionProvider);
  if (profile == null) return RoutingStatus.off;
  // Which of the three policies is in force answers this: a policy someone
  // else set is never "off" (its author owns it), and a local one is off until
  // the user turns it on.
  final policy = routingPolicyFor(profile, loadRuleSet: RuleSetStore.byId);
  if (policy is LocalRoutingPolicy && !policy.enabled) return RoutingStatus.off;
  return RoutingStatus.ofMode((await policy.resolve()).mode);
});
