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

  Log.i('routing: ${await _describe(policy, routing)}');

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

Future<String> _describe(RoutingPolicy policy, Routing routing) async {
  final source = switch (policy) {
    ManagedRoutingPolicy() => 'organization policy',
    ProviderRoutingPolicy() => 'subscription routing',
    LocalRoutingPolicy(:final enabled) when !enabled => 'off',
    LocalRoutingPolicy(:final profile) =>
      'rule set "${(await RuleSetStore.byId(profile.ruleSetId)).name}"',
  };
  if (source == 'off') return 'off for this configuration';
  final kinds = <String, int>{};
  for (final r in routing.rules) {
    final key = '${r.type}→${r.action}';
    kinds[key] = (kinds[key] ?? 0) + r.values.length;
  }
  final rules = kinds.isEmpty
      ? 'no rules'
      : kinds.entries.map((e) => '${e.key} ×${e.value}').join(', ');
  return '$source, ${routing.mode}: $rules';
}
