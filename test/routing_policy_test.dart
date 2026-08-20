import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/routing_policy.dart';
import 'package:vpn_client/core/rule_set.dart';

/// Three sources of routing, three different sets of powers.
///
/// The point of separating them is that the differences are not cosmetic: who
/// may switch a policy off, and what a policy is allowed to reach for, differ
/// per source. A single code path with flags is how those differences get
/// quietly mixed up.
void main() {
  const localSet = RuleSet(
    id: 'work',
    name: 'Work',
    mode: 'split',
    rules: [RoutingRule(type: 'domain-suffix', value: 'corp.example', action: 'proxy')],
  );
  Future<RuleSet> load(String? id) async => localSet;

  Profile profile({
    Routing? managed,
    Routing? provider,
    bool providerOn = true,
    bool listsOn = false,
    bool localOn = false,
  }) =>
      Profile(
        id: 'p1',
        type: managed != null ? ProfileType.selfhosted : ProfileType.subscription,
        name: 'Config',
        locations: const [],
        routing: managed,
        providerRouting: provider,
        providerRoutingEnabled: providerOn,
        providerRuleListsEnabled: listsOn,
        routingEnabled: localOn,
        ruleSetId: 'work',
      );

  const providerRouting = Routing(
    mode: 'split',
    rules: [
      RoutingRule(type: 'rule-list', value: 'reject', action: 'block'),
      RoutingRule(type: 'domain-suffix', value: 'ip.me', action: 'proxy'),
    ],
    lists: [
      RuleList(name: 'reject', url: 'https://lists.example/r.yaml', behavior: 'domain')
    ],
  );

  test('a self-hosted policy outranks everything and cannot be switched off', () async {
    const managed = Routing(mode: 'full', rules: []);
    final policy = routingPolicyFor(
        profile(managed: managed, provider: providerRouting, localOn: true),
        loadRuleSet: load);
    expect(policy, isA<ManagedRoutingPolicy>());
    expect(policy.switchable, isFalse,
        reason: 'the server would only re-apply it; a switch would be a lie');
    expect((await policy.resolve()).rules, isEmpty);
  });

  test('a provider policy applies while the user leaves it on', () async {
    final policy = routingPolicyFor(profile(provider: providerRouting), loadRuleSet: load);
    expect(policy, isA<ProviderRoutingPolicy>());
    expect(policy.switchable, isTrue);
  });

  test('refusing a provider policy hands the device its own set back', () async {
    final policy = routingPolicyFor(
        profile(provider: providerRouting, providerOn: false, localOn: true),
        loadRuleSet: load);
    expect(policy, isA<LocalRoutingPolicy>());
    expect((await policy.resolve()).rules.single.value, 'corp.example');
  });

  test('local routing switched off means no rules at all', () async {
    final policy = routingPolicyFor(profile(localOn: false), loadRuleSet: load);
    final routing = await policy.resolve();
    expect(routing.rules, isEmpty);
    expect(routing.mode, 'full', reason: 'off means everything through the tunnel');
  });

  group('a provider policy and its lists', () {
    test('list rules are removed until the user accepts the lists', () async {
      final policy = routingPolicyFor(profile(provider: providerRouting), loadRuleSet: load)
          as ProviderRoutingPolicy;
      final routing = await policy.resolve();
      expect(routing.rules.map((r) => r.value), ['ip.me']);
      expect(routing.lists, isEmpty,
          reason: 'a definition with no rule using it would only invite a download');
      expect(policy.rulesNeedingLists, 1,
          reason: 'the count is what makes the switch worth offering');
    });

    test('accepted, the whole policy is carried, definitions included', () async {
      final policy = routingPolicyFor(profile(provider: providerRouting, listsOn: true),
          loadRuleSet: load) as ProviderRoutingPolicy;
      final routing = await policy.resolve();
      expect(routing.rules.length, 2);
      expect(routing.lists.single.name, 'reject');
      expect(policy.listsEnabled, isTrue);
    });

    test('an untranslatable rule is remembered as a count, not lost', () {
      final p = Profile(
        id: 'p1',
        type: ProfileType.subscription,
        name: 'Config',
        locations: const [],
        providerRouting: providerRouting,
        providerRoutingSkipped: 3,
      );
      final policy = routingPolicyFor(p, loadRuleSet: load) as ProviderRoutingPolicy;
      expect(policy.untranslated, 3);
    });
  });
}
