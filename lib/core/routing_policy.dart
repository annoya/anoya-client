import 'norm_config.dart';
import 'profile.dart';
import 'rule_set.dart';

sealed class RoutingPolicy {
  const RoutingPolicy(this.profile);

  final Profile profile;

  Future<Routing> resolve();
}

final class ManagedRoutingPolicy extends RoutingPolicy {
  const ManagedRoutingPolicy(super.profile);

  Routing get routing => profile.routing!;

  @override
  Future<Routing> resolve() async => routing;
}

final class ProviderRoutingPolicy extends RoutingPolicy {
  const ProviderRoutingPolicy(super.profile);

  Routing get routing => profile.providerRouting!;

  bool get listsEnabled => profile.providerRuleListsEnabled;

  @override
  Future<Routing> resolve() async {
    if (listsEnabled) return routing;
    return Routing(
      mode: routing.mode,
      rules: routing.rules.where((r) => !r.needsRuleList).toList(),
      lists: const [],
    );
  }
}

final class LocalRoutingPolicy extends RoutingPolicy {
  const LocalRoutingPolicy(super.profile, this.load);

  final Future<RuleSet> Function(String? id) load;

  bool get enabled => profile.routingEnabled;

  @override
  Future<Routing> resolve() async {
    if (!enabled) return const Routing(mode: 'full', rules: []);
    return (await load(profile.ruleSetId)).toRouting();
  }
}

RoutingPolicy routingPolicyFor(
  Profile p, {
  required Future<RuleSet> Function(String? id) loadRuleSet,
}) {
  if (p.routing != null) return ManagedRoutingPolicy(p);
  if (p.providerRouting != null && p.providerRoutingEnabled) {
    return ProviderRoutingPolicy(p);
  }
  return LocalRoutingPolicy(p, loadRuleSet);
}
