import 'norm_config.dart';
import 'profile.dart';
import 'rule_set.dart';

/// Whose rules a configuration routes by.
///
/// Three sources, three different sets of powers, and every difference between
/// them used to be an `if` somewhere — in the config screens, in the status
/// provider, in the renderer's caller. One subclass each instead, mirroring
/// [ConfigSource]: a new kind of policy is a new subclass and one `switch` arm.
///
/// The differences are not cosmetic:
///
///  - **[ManagedRoutingPolicy]** — a self-hosted server sets it and enforces
///    it. No switch: the server would only re-apply it, and offering one would
///    promise control the configuration does not have.
///  - **[ProviderRoutingPolicy]** — a subscription's panel sent it. Applied by
///    default, because a provider that sends rules means them, but switchable:
///    a panel controls what it returns, not where this device's traffic goes
///    (ADR-005). It is also the only policy that can name files someone else
///    hosts, which is a second, separate decision for the user.
///  - **[LocalRoutingPolicy]** — the device's own rule sets. Opt-in, editable,
///    and what the user falls back to when they refuse a provider's routes.
sealed class RoutingPolicy {
  const RoutingPolicy(this.profile);

  final Profile profile;

  /// The rules this policy puts in force, with anything it cannot run already
  /// removed. Async because a local set lives on disk.
  Future<Routing> resolve();
}

/// A self-hosted server's policy: applied as delivered, not negotiable here.
final class ManagedRoutingPolicy extends RoutingPolicy {
  const ManagedRoutingPolicy(super.profile);

  Routing get routing => profile.routing!;

  @override
  Future<Routing> resolve() async => routing;
}

/// A subscription panel's policy, translated into our model on arrival.
final class ProviderRoutingPolicy extends RoutingPolicy {
  const ProviderRoutingPolicy(super.profile);

  Routing get routing => profile.providerRouting!;

  /// Whether the user agreed to hold this provider's list files on the device.
  bool get listsEnabled => profile.providerRuleListsEnabled;

  @override
  Future<Routing> resolve() async {
    if (listsEnabled) return routing;
    // Not merely unfetched — refused. The rules that need them are removed
    // here rather than left for the renderer to drop, so that what the screen
    // counts and what the engine runs come from the same decision.
    return Routing(
      mode: routing.mode,
      rules: routing.rules.where((r) => !r.needsRuleList).toList(),
      lists: const [],
    );
  }
}

/// The device's own rule sets: opt-in per configuration, editable, global to
/// the device.
final class LocalRoutingPolicy extends RoutingPolicy {
  const LocalRoutingPolicy(super.profile, this.load);

  /// Reader for the set named by the profile. Injected so the policy stays
  /// free of the store, which is what makes it testable without a filesystem.
  final Future<RuleSet> Function(String? id) load;

  bool get enabled => profile.routingEnabled;

  @override
  Future<Routing> resolve() async {
    // Off means off: with routing disabled no set is read at all, so
    // everything goes into the tunnel.
    if (!enabled) return const Routing(mode: 'full', rules: []);
    return (await load(profile.ruleSetId)).toRouting();
  }
}

/// Which policy governs a profile right now.
///
/// Order is authority, not preference: a managed policy outranks everything, a
/// provider's routes apply while the user leaves them on, and the device's own
/// sets are what remains.
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
