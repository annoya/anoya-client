import 'geo_store.dart';
import 'log.dart';
import 'norm_config.dart';
import 'platform_support.dart';
import 'profile.dart';
import 'routing_policy.dart';
import 'routing_prefs.dart';
import 'rule_set.dart';

/// Builds a NormConfig for the core from a profile: its locations + the
/// effective routing. Precedence: server-managed policy (self-hosted), else
/// the profile's global rule set. Device-level extras are applied on top:
/// LAN-direct rules are prepended, and geo rules are dropped (with a log)
/// while the databases aren't downloaded — a rule that can't match must not
/// stall the engine into fetching 20+ MB mid-connect.
Future<NormConfig> buildNormConfig(Profile p) async {
  // Whose rules apply is the policy's decision, not this method's: one of
  // three classes answers it (ADR-005), and what is left here is the
  // device-level trimming that applies to any of them.
  final policy = routingPolicyFor(p, loadRuleSet: RuleSetStore.byId);
  Routing routing = await policy.resolve();

  if (routing.rules.any((r) => r.needsGeoData) &&
      !(await GeoStore.status()).downloaded) {
    Log.e('routing', 'geo rules skipped: databases not downloaded');
    routing = Routing(
      mode: routing.mode,
      rules: routing.rules.where((r) => !r.needsGeoData).toList(),
      lists: routing.lists,
    );
  }

  // A set authored on a desktop can travel to a phone (same account, same
  // sets). Its process rules cannot match there, and leaving them in would
  // turn find-process-mode on for nothing.
  if (!supportsProcessRules && routing.rules.any((r) => r.type == 'process-name')) {
    Log.e('routing', 'process rules skipped: this platform cannot resolve processes');
    routing = Routing(
      mode: routing.mode,
      rules: routing.rules.where((r) => r.type != 'process-name').toList(),
      lists: routing.lists,
    );
  }

  final prefs = await RoutingPrefsStore.load();
  if (prefs.lanDirect) {
    routing = Routing(
        mode: routing.mode,
        rules: [...kLanDirectRules, ...routing.rules],
        lists: routing.lists);
  }

  return NormConfig(
    version: 1,
    account: p.account ?? Account(displayName: p.name, status: 'active'),
    locations: p.locations,
    groups: p.groups,
    routing: routing,
    dns: p.dns,
    // Only reaches the engine when the configuration named nothing; the
    // renderer decides that, so the value travels rather than being folded in
    // here — folded in, the DNS screen would report the app's own resolver as
    // the subscription's choice.
    defaultDns: prefs.defaultDns,
  );
}
