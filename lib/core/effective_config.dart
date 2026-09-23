import 'geo_store.dart';
import 'log.dart';
import 'norm_config.dart';
import 'platform_support.dart';
import 'profile.dart';
import 'routing_policy.dart';
import 'routing_prefs.dart';
import 'rule_set.dart';

Future<NormConfig> buildNormConfig(Profile p) async {
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

  if (!supportsProcessRules &&
      routing.rules.any((r) => r.type == 'process-name')) {
    Log.e(
      'routing',
      'process rules skipped: this platform cannot resolve processes',
    );
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
      lists: routing.lists,
    );
  }

  return NormConfig(
    version: 1,
    account: p.account ?? Account(displayName: p.name, status: 'active'),
    locations: p.locations,
    groups: p.groups,
    routing: routing,
    dns: p.dns,
    defaultDns: prefs.defaultDns,
  );
}
