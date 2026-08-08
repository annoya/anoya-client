import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final ruleSetRevisionProvider =
    NotifierProvider<RuleSetRevision, int>(RuleSetRevision.new);

/// Every rule set on the device, re-read after each edit.
final ruleSetsProvider = FutureProvider<List<RuleSet>>((ref) async {
  ref.watch(ruleSetRevisionProvider);
  return RuleSetStore.load();
});

/// Resolves what the active configuration actually does with traffic: the
/// server-managed policy when there is one, otherwise its rule set — and only
/// while routing is switched on for that configuration.
final routingStatusProvider = FutureProvider<RoutingStatus>((ref) async {
  final profile = ref.watch(profilesControllerProvider).active;
  ref.watch(ruleSetRevisionProvider);
  if (profile == null) return RoutingStatus.off;
  // A managed policy is never "off": the server owns it, and the local switch
  // does not exist for such configurations.
  final managed = profile.routing;
  if (managed != null) return RoutingStatus.ofMode(managed.mode);
  if (!profile.routingEnabled) return RoutingStatus.off;
  return RoutingStatus.ofMode((await RuleSetStore.byId(profile.ruleSetId)).mode);
});
