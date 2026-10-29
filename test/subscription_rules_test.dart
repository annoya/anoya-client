import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:anoya/core/clash_plan.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/parsers/subscription.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/state/profiles_controller.dart';

const _body = r'''
proxies:
  - {name: 🇩🇪 DE, type: vless, server: de.example, port: 443, uuid: u, udp: true}
  - {name: 🇳🇱 NL, type: vless, server: nl.example, port: 443, uuid: u, udp: true, dialer-proxy: WL}
  - {name: 🇷🇺 RU, type: vless, server: ru.example, port: 443, uuid: u, udp: true}
  - {name: 🏳 LTE, type: vless, server: lte.example, port: 443, uuid: u, udp: true, dialer-proxy: WL, reality-opts: {public-key: k, short-id: 0000000000000000}}
  - {name: Old, type: tuic, server: t.example, port: 443}
  - {name: Без VPN, type: direct}
proxy-groups:
  - {name: 🚀 Proxy, type: select, proxies: [Auto, 🇩🇪 DE, 🇳🇱 NL]}
  - {name: Auto, type: url-test, include-all: true, exclude-filter: '🇷🇺|\x{1F3F3}', url: 'https://cp.cloudflare.com/generate_204', interval: 300, dialer-proxy: WL}
  - {name: WL, type: url-test, include-all: true, filter: '\x{1F3F3}'}
  - {name: ▶️ YouTube, type: select, proxies: [Auto, Без VPN]}
  - {name: RU, type: select, proxies: [Без VPN]}
  - {name: Unused, type: url-test, proxies: [🇩🇪 DE]}
  - {name: Loop, type: select, proxies: [Loop2]}
  - {name: Loop2, type: select, proxies: [Loop, 🇳🇱 NL]}
  - {name: Dead, type: select, proxies: [Old]}
rule-providers:
  youtube: {type: http, behavior: domain, format: mrs, url: 'https://lists.example/yt.mrs'}
rules:
  - DOMAIN-SUFFIX,ru,RU
  - RULE-SET,youtube,▶️ YouTube
  - AND,((NETWORK,UDP),(DST-PORT,443)),REJECT
  - SRC-IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,1.1.1.1/32,🇳🇱 NL,no-resolve
  - IP-CIDR,8.8.8.8/32,DIRECT,src
  - DOMAIN,dead.example,Dead
  - DOMAIN,loop.example,Loop
  - RULE-SET,undefined,DIRECT
  - MATCH,🚀 Proxy
  - DOMAIN,after.example,DIRECT
''';

void main() {
  final parsed = parseSubscriptionBody(_body);
  final plan = parsed.plan!;
  final ids = {for (final l in parsed.locations) l.label: l.id};

  group('reading the subscription\'s rules', () {
    test(
      'only groups the rules reach are kept, in the subscription\'s order',
      () {
        expect(plan.groups.map((g) => g.name), [
          '🚀 Proxy',
          'Auto',
          'WL',
          '▶️ YouTube',
          'RU',
          'Loop',
          'Loop2',
        ]);
      },
    );

    test('members are the subscription\'s, filters applied', () {
      expect(plan.group('🚀 Proxy')!.members, [
        ClashPlan.groupRef('Auto'),
        ids['🇩🇪 DE'],
        ids['🇳🇱 NL'],
      ]);
      expect(plan.group('Auto')!.members, [ids['🇩🇪 DE'], ids['🇳🇱 NL']]);
      expect(plan.group('WL')!.members, [ids['🏳 LTE']]);
      expect(plan.group('RU')!.members, [ClashPlan.direct]);
    });

    test('a server\'s chain is kept, one that would loop is not', () {
      expect(plan.dialers, {ids['🇳🇱 NL']: ClashPlan.groupRef('WL')});
    });

    test('a short id written with zeros keeps its digits', () {
      final lte = parsed.locations.firstWhere((l) => l.label == '🏳 LTE');
      expect(
        (lte.proxy['reality-opts'] as Map)['short-id'],
        '0000000000000000',
      );
    });

    test('a loop between groups is cut, never handed to the engine', () {
      expect(plan.group('Loop')!.members, [ClashPlan.groupRef('Loop2')]);
      expect(plan.group('Loop2')!.members, [ids['🇳🇱 NL']]);
    });

    test('every rule keeps its own target, the catch-all last', () {
      expect(plan.rules.map((r) => '${r.type} ${r.target}'), [
        'DOMAIN-SUFFIX ${ClashPlan.groupRef('RU')}',
        'RULE-SET ${ClashPlan.groupRef('▶️ YouTube')}',
        'AND ${ClashPlan.block}',
        'IP-CIDR ${ids['🇳🇱 NL']}',
        'DOMAIN ${ClashPlan.groupRef('Loop')}',
        'MATCH ${ClashPlan.groupRef('🚀 Proxy')}',
      ]);
      expect(plan.catchAll, ClashPlan.groupRef('🚀 Proxy'));
    });

    test('a rule we cannot apply as written is left out and counted', () {
      expect(
        plan.skipped,
        4,
        reason:
            'a source match, an option that changes the meaning, a group '
            'with nothing runnable and a list that is not defined',
      );
    });

    test('only the lists the rules use are kept', () {
      expect(plan.lists.map((l) => l.name), ['youtube']);
    });

    test('rules with nothing but a catch-all to a server still have modes', () {
      final p = parseSubscriptionBody('''
proxies:
  - {name: A, type: vless, server: a.example, port: 443, uuid: u}
rules:
  - MATCH,A
''').plan!;
      expect(p.groups, isEmpty);
      expect(p.catchAll, isNot(ClashPlan.direct));
    });

    test('a body without rules has no modes', () {
      expect(
        parseSubscriptionBody('''
proxies:
  - {name: A, type: vless, server: a.example, port: 443, uuid: u}
proxy-groups:
  - {name: G, type: url-test, proxies: [A]}
''').plan,
        isNull,
      );
    });

    test('it survives storage', () {
      final restored = ClashPlan.fromJson(plan.toJson());
      expect(restored.toJson(), plan.toJson());
    });
  });

  group('handing them to the engine', () {
    String render({
      Map<String, String> choices = const {},
      Map<String, String> lists = const {'youtube': '/shared/yt.mrs'},
    }) => mihomoTunConfigYaml(
      parsed.locations.first,
      clashPlan: plan,
      planChoices: choices,
      planLocations: parsed.locations,
      listPaths: lists,
    );

    YamlMap doc(String yaml) => loadYaml(yaml) as YamlMap;

    test('groups and rules reach the engine under positional names', () {
      final d = doc(render());
      final groups = {
        for (final g in d['proxy-groups'] as YamlList)
          g['name']: (g['proxies'] as YamlList).toList(),
      };
      expect(groups['g0'], ['g1', 'p0', 'p1']);
      expect(groups['g3'], ['g1', 'DIRECT']);
      expect(groups['g5'], ['g6']);
      expect(groups['g6'], ['p1']);
      expect((d['rules'] as YamlList).toList(), [
        'DOMAIN-SUFFIX,ru,g4',
        'RULE-SET,l0,g3',
        'AND,((NETWORK,UDP),(DST-PORT,443)),REJECT',
        'IP-CIDR,1.1.1.1/32,p1,no-resolve',
        'DOMAIN,loop.example,g5',
        'MATCH,g0',
      ]);
    });

    test('only the servers the groups and rules use are rendered', () {
      final names = (doc(render())['proxies'] as YamlList)
          .map((p) => p['name'])
          .toSet();
      expect(names, {'p0', 'p1', 'p3'});
    });

    test('a chain points at the rendered group, on the server only', () {
      final d = doc(render());
      final nl = (d['proxies'] as YamlList).firstWhere(
        (p) => p['name'] == 'p1',
      );
      expect(nl['dialer-proxy'], 'g2');
      final auto = (d['proxy-groups'] as YamlList).firstWhere(
        (g) => g['name'] == 'g1',
      );
      expect(
        auto['dialer-proxy'],
        isNull,
        reason: 'the engine refuses a chain on a group',
      );
    });

    test('a choice in a select goes first, which is what the engine picks', () {
      final d = doc(render(choices: {'🚀 Proxy': ids['🇳🇱 NL']!}));
      final proxy = (d['proxy-groups'] as YamlList).firstWhere(
        (g) => g['name'] == 'g0',
      );
      expect((proxy['proxies'] as YamlList).toList(), ['p1', 'g1', 'p0']);
    });

    test('a choice that is no longer offered falls back to the default', () {
      final d = doc(render(choices: {'🚀 Proxy': 'gone'}));
      final proxy = (d['proxy-groups'] as YamlList).firstWhere(
        (g) => g['name'] == 'g0',
      );
      expect((proxy['proxies'] as YamlList).first, 'g1');
    });

    test('a rule whose list is not on disk yet is left out, not broken', () {
      final rules = (doc(render(lists: const {}))['rules'] as YamlList)
          .toList();
      expect(rules.any((r) => '$r'.startsWith('RULE-SET')), isFalse);
      expect(doc(render(lists: const {}))['rule-providers'], isNull);
      expect(rules.last, 'MATCH,g0');
    });

    test('a downloaded list is read from its file', () {
      final provider = (doc(render())['rule-providers'] as YamlMap)['l0'];
      expect(provider['type'], 'file');
      expect(provider['path'], '/shared/yt.mrs');
      expect(provider['format'], 'mrs');
    });

    test('our own fallback group follows the catch-all', () {
      final d = doc(render(choices: {'🚀 Proxy': ids['🇳🇱 NL']!}));
      final ours = (d['proxy-groups'] as YamlList).firstWhere(
        (g) => g['name'] == kTunnelOutbound,
      );
      expect((ours['proxies'] as YamlList).toList(), ['p1']);
    });
  });

  group('which mode a subscription is in', () {
    Profile stored({
      bool? rules,
      bool lists = false,
      bool routing = true,
      ClashPlan? with_,
    }) => Profile(
      id: 'p',
      type: ProfileType.subscription,
      name: 'Nexus',
      locations: parsed.locations,
      plan: with_ ?? plan,
      subscriptionRules: rules,
      providerRuleListsEnabled: lists,
      providerRoutingEnabled: routing,
    );

    Profile refreshed(Profile p) => p.withBundle(
      locations: p.locations,
      account: null,
      routing: null,
      dns: const [],
      refreshedAt: DateTime(2026),
      plan: p.plan,
    );

    test('a profile from before keeps its rules only if it had the lists', () {
      expect(refreshed(stored(lists: true)).usesSubscriptionRules, isTrue);
      expect(refreshed(stored()).usesSubscriptionRules, isFalse);
      expect(
        refreshed(stored(lists: true, routing: false)).usesSubscriptionRules,
        isFalse,
      );
    });

    test('rules that need no lists need no consent', () {
      final noLists = ClashPlan(groups: plan.groups, rules: plan.rules);
      expect(refreshed(stored(with_: noLists)).usesSubscriptionRules, isTrue);
    });

    test('a decision once made is kept through refreshes', () {
      expect(
        refreshed(stored(rules: false, lists: true)).subscriptionRules,
        isFalse,
      );
      expect(refreshed(stored(rules: true)).subscriptionRules, isTrue);
    });

    test('the mode, the plan and the choices survive a restart', () {
      final p = stored(
        rules: true,
      ).copyWith(groupChoices: {'🚀 Proxy': ids['🇳🇱 NL']!});
      final restored = Profile.fromJson(p.toJson());
      expect(restored.usesSubscriptionRules, isTrue);
      expect(restored.groupChoices, p.groupChoices);
      expect(restored.plan!.toJson(), plan.toJson());
    });

    group('when it is added', () {
      Profile added({ClashPlan? with_}) => Profile(
        id: 'p',
        type: ProfileType.subscription,
        name: 'Nexus',
        locations: parsed.locations,
        plan: with_ ?? plan,
      );

      test('rules that need lists are used only after a yes', () async {
        var asked = 0;
        final yes = await withModeChosen(added(), (_) async {
          asked++;
          return true;
        });
        expect(asked, 1);
        expect(yes.usesSubscriptionRules, isTrue);
        expect(yes.providerRuleListsEnabled, isTrue);
      });

      test('a no makes it a server list, and nothing is kept', () async {
        final no = await withModeChosen(added(), (_) async => false);
        expect(no.usesSubscriptionRules, isFalse);
        expect(no.subscriptionRules, isFalse);
        expect(no.providerRuleListsEnabled, isFalse);
      });

      test('nobody to ask counts as no', () async {
        expect(
          (await withModeChosen(added(), null)).usesSubscriptionRules,
          isFalse,
        );
      });

      test('rules without lists are used without asking', () async {
        var asked = false;
        final p = await withModeChosen(
          added(
            with_: ClashPlan(groups: plan.groups, rules: plan.rules),
          ),
          (_) async => asked = true,
        );
        expect(asked, isFalse);
        expect(p.usesSubscriptionRules, isTrue);
      });
    });

    test('lists need consent until it was given once', () {
      expect(stored().needsListConsent, isTrue);
      expect(stored(lists: true).needsListConsent, isFalse);
    });
  });

  test('where a group finally goes follows the choices through selects', () {
    expect(
      resolvePlanRef(ClashPlan.groupRef('🚀 Proxy'), plan, const {}),
      ClashPlan.groupRef('Auto'),
    );
    expect(
      resolvePlanRef(ClashPlan.groupRef('RU'), plan, const {}),
      ClashPlan.direct,
    );
  });

  test('a location label is not mistaken for a server', () {
    expect(parsed.locations.map((l) => l.label), isNot(contains('Old')));
    expect(
      parsed.locations.whereType<Location>().length,
      4,
      reason: 'tuic is not runnable and the direct entry is not a server',
    );
  });
}
