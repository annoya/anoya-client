import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing_policy.dart';
import '../core/rule_set.dart';
import 'profiles_controller.dart';

enum RoutingStatus {
  off,

  full,

  split;

  String get label => switch (this) {
    RoutingStatus.off => 'off',
    RoutingStatus.full => 'full',
    RoutingStatus.split => 'split',
  };

  static RoutingStatus ofMode(String mode) =>
      mode == 'split' ? RoutingStatus.split : RoutingStatus.full;
}

class RuleSetRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final ruleSetRevisionProvider = NotifierProvider<RuleSetRevision, int>(
  RuleSetRevision.new,
);

final ruleSetsProvider = FutureProvider<List<RuleSet>>((ref) async {
  ref.watch(ruleSetRevisionProvider);
  return RuleSetStore.load();
});

final routingStatusProvider = FutureProvider<RoutingStatus>((ref) async {
  // select: skips the disk read on every switching/loading/error flip.
  final profile = ref.watch(profilesControllerProvider.select((s) => s.active));
  ref.watch(ruleSetRevisionProvider);
  if (profile == null) return RoutingStatus.off;
  final policy = routingPolicyFor(profile, loadRuleSet: RuleSetStore.byId);
  if (policy is LocalRoutingPolicy && !policy.enabled) return RoutingStatus.off;
  return RoutingStatus.ofMode((await policy.resolve()).mode);
});
