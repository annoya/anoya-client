import 'clash_plan.dart';
import 'corp_domains.dart';
import 'geo_store.dart';
import 'geosite_index.dart';
import 'log.dart';
import 'norm_config.dart';
import 'platform_support.dart';
import 'profile.dart';
import 'routing_policy.dart';
import 'routing_prefs.dart';
import 'rule_set.dart';

Future<NormConfig> buildNormConfig(Profile p) async {
  if (p.usesSubscriptionRules) return _subscriptionRulesConfig(p);
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

  if (routing.rules.any((r) => r.type == 'geosite')) {
    final known = await _geositeCategories();
    if (known != null) {
      final rules = <RoutingRule>[];
      var left = 0;
      for (final r in routing.rules) {
        if (r.type != 'geosite') {
          rules.add(r);
          continue;
        }
        final values = r.values.where((v) => _inGeosite(known, v)).toList();
        left += r.values.length - values.length;
        if (values.isNotEmpty) rules.add(r.copyWith(values: values));
      }
      if (left > 0) {
        Log.e(
          'routing',
          '$left geosite categor${left == 1 ? 'y' : 'ies'} skipped: not in '
              'the downloaded database',
        );
        routing = Routing(
          mode: routing.mode,
          rules: rules,
          lists: routing.lists,
        );
      }
    }
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
  if (prefs.lanDirect) routing = withLanDirect(routing);
  routing = withCorpDomains(routing, prefs.corpDomains);

  return NormConfig(
    version: 1,
    account: p.account ?? Account(displayName: p.name, status: 'active'),
    locations: p.locations,
    groups: p.groups,
    routing: routing,
    dns: p.dns,
    defaultDns: prefs.defaultDns,
    dnsProtection: prefs.dnsProtection,
    corpDomains: prefs.corpDomains,
    localDns: prefs.localDns,
    name: p.name,
  );
}

Future<Set<String>?> _geositeCategories() async {
  final index = await GeositeIndex.load();
  return index.isEmpty ? null : {for (final c in index) c.name};
}

bool _inGeosite(Set<String> known, String value) =>
    known.contains(value.split('@').first.toLowerCase());

Future<NormConfig> _subscriptionRulesConfig(Profile p) async {
  final plan = p.plan!;
  final geoReady = (await GeoStore.status()).downloaded;
  final known = geoReady ? await _geositeCategories() : null;
  final rules = [
    for (final r in plan.rules)
      if ((geoReady || !r.needsGeoData) &&
          (supportsProcessRules || !r.needsProcess) &&
          (known == null || r.geosites.every((c) => _inGeosite(known, c))))
        r,
  ];
  final left = plan.rules.length - rules.length;
  if (left > 0) {
    Log.e(
      'routing',
      '$left subscription rule(s) skipped: geo databases, a geosite category '
          'or process matching unavailable here',
    );
  }
  Log.i(
    'routing: subscription rules, ${rules.length} rule(s), '
    '${plan.groups.length} group(s), catch-all ${plan.catchAll}',
  );
  final prefs = await RoutingPrefsStore.load();
  return NormConfig(
    version: 1,
    account: p.account ?? Account(displayName: p.name, status: 'active'),
    locations: p.locations,
    groups: p.groups,
    plan: ClashPlan(
      groups: plan.groups,
      rules: rules,
      lists: plan.lists,
      inline: plan.inline,
      dialers: plan.dialers,
      skipped: plan.skipped,
    ),
    planChoices: p.groupChoices,
    routing: withCorpDomains(
      Routing(
        mode: 'full',
        rules: prefs.lanDirect ? kLanDirectRules : const [],
      ),
      prefs.corpDomains,
    ),
    dns: p.dns,
    defaultDns: prefs.defaultDns,
    dnsProtection: prefs.dnsProtection,
    corpDomains: prefs.corpDomains,
    localDns: prefs.localDns,
    name: p.name,
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
