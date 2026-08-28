import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:vpn_client/core/mihomo_tun_config.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/parsers/subscription.dart';
import 'package:vpn_client/core/subscription_fetch.dart';

/// Groups a subscription offers, whose member the **engine** picks.
///
/// The risk here is not a crash: a group that renders wrong produces a tunnel
/// that works through the wrong server, or one that silently carries traffic
/// through a member the user was never offered. So these tests are about what
/// reaches the engine and what the engine is allowed to do with it.
void main() {
  const body = '''
proxies:
  - {name: "🇩🇪 Germany", type: vless, server: de.example, port: 443, uuid: u1}
  - {name: "🇳🇱 Netherlands", type: vless, server: nl.example, port: 443, uuid: u2}
  - {name: "🇯🇵 Tokyo", type: tuic, server: jp.example, port: 443, uuid: u3}
proxy-groups:
  - name: ⚡️ Fastest
    type: url-test
    url: https://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 150
    include-all: true
  - name: 🛟 Failover
    type: fallback
    url: https://cp.cloudflare.com/generate_204
    interval: 60
    proxies: ["🇩🇪 Germany", "🇳🇱 Netherlands"]
  - name: ⚖️ Balance
    type: load-balance
    strategy: consistent-hashing
    url: https://cp.cloudflare.com/generate_204
    interval: 300
    include-all: true
  - name: 🎲 Odd
    type: load-balance
    strategy: by-the-phase-of-the-moon
    include-all: true
  - name: 🖐 Manual
    type: select
    proxies: ["🇩🇪 Germany", "🇳🇱 Netherlands"]
  - name: 💀 Dead
    type: url-test
    proxies: ["🇯🇵 Tokyo"]
rules:
  - MATCH,⚡️ Fastest
''';

  group('reading them', () {
    test('only the types where the engine chooses are carried', () {
      final p = parseSubscriptionBody(body);
      expect(p.groups.map((g) => g.name),
          ['⚡️ Fastest', '🛟 Failover', '⚖️ Balance', '🎲 Odd'],
          reason: 'select is a human choosing, which the server picker already is');
    });

    test('include-all means every server we can actually run', () {
      final p = parseSubscriptionBody(body);
      final fastest = p.groups.first;
      // tuic is in the document and not in the group: a member we cannot run is
      // not a member, and offering it would be offering a dead choice.
      expect(fastest.members.length, 2);
      expect(p.unsupported, {'tuic': 1});
    });

    group('membership by pattern', () {
      // A provider that writes `exclude-filter: 🇷🇺` is saying "not through a
      // Russian exit". Read without the pattern, the group is built from every
      // server in the document and sends the user exactly where they were being
      // steered away from — so this is not cosmetic, and a group we cannot
      // build correctly is dropped rather than widened.
      const filtered = '''
proxies:
  - {name: "🇩🇪 Germany", type: vless, server: de.example, port: 443, uuid: u1}
  - {name: "🇷🇺 Moscow", type: vless, server: ru.example, port: 443, uuid: u2}
  - {name: "🏳️ Direct-ish", type: vless, server: wl.example, port: 443, uuid: u3}
proxy-groups:
  - name: Abroad
    type: url-test
    include-all: true
    exclude-filter: 🇷🇺|🏳️
  - name: White lists
    type: url-test
    include-all: true
    filter: 🏳️
  - name: Listed
    type: url-test
    proxies: ["🇩🇪 Germany", "🇷🇺 Moscow"]
    exclude-filter: 🇷🇺
''';

      List<String> labels(String name) {
        final p = parseSubscriptionBody(filtered);
        final g = p.groups.firstWhere((g) => g.name == name);
        return [
          for (final id in g.members) p.locations.firstWhere((l) => l.id == id).label
        ];
      }

      test('exclude-filter removes what the provider excluded', () {
        expect(labels('Abroad'), ['🇩🇪 Germany']);
      });

      test('filter selects from include-all rather than from nothing', () {
        expect(labels('White lists'), ['🏳️ Direct-ish']);
      });

      test('exclude-filter applies to an explicit list too', () {
        // The engine skips `filter` for a hand-written list but not
        // `exclude-filter` — it runs over the membership however it was built.
        expect(labels('Listed'), ['🇩🇪 Germany']);
      });

      test('a pattern we cannot run drops the group, never widens it', () {
        const broken = '''
proxies:
  - {name: "A", type: vless, server: a.example, port: 443, uuid: u1}
proxy-groups:
  - name: Broken
    type: url-test
    include-all: true
    exclude-filter: "[unclosed"
''';
        expect(parseSubscriptionBody(broken).groups, isEmpty);
      });

      test('exclude-type is the same statement about the protocol', () {
        const byType = '''
proxies:
  - {name: "A", type: vless, server: a.example, port: 443, uuid: u1}
  - {name: "B", type: hysteria2, server: b.example, port: 443, password: p}
proxy-groups:
  - name: No QUIC
    type: url-test
    include-all: true
    exclude-type: hysteria2
''';
        final p = parseSubscriptionBody(byType);
        expect(p.groups.single.members.length, 1);
      });
    });

    test('a group left with nothing runnable is not offered at all', () {
      expect(parseSubscriptionBody(body).groups.map((g) => g.name),
          isNot(contains('💀 Dead')));
    });

    test('members keep the provider\'s order, because fallback is that order', () {
      final failover = parseSubscriptionBody(body).groups[1];
      final byId = {for (final l in parseSubscriptionBody(body).locations) l.id: l.label};
      expect(failover.members.map((m) => byId[m]), ['🇩🇪 Germany', '🇳🇱 Netherlands']);
    });

    test('a load-balance strategy is carried, and an unknown one is not', () {
      // mihomo rejects an unknown strategy while *applying* the config, which
      // would take the running tunnel down over one mistyped field.
      final groups = parseSubscriptionBody(body).groups;
      expect(groups[2].strategy, 'consistent-hashing');
      expect(groups[3].strategy, isEmpty, reason: 'the engine default beats a config it refuses');
    });

    test('a group survives a round trip through storage', () {
      final g = parseSubscriptionBody(body).groups.first;
      final back = ProxyGroup.fromJson(g.toJson());
      expect(back.name, g.name);
      expect(back.type, g.type);
      expect(back.members, g.members);
      expect(back.tolerance, 150);
    });
  });

  group('rendering them', () {
    final members = [
      Location(id: 'a', label: '🇩🇪 Germany', proxy: {
        'type': 'vless', 'server': 'de.example', 'port': 443, 'uuid': 'u1',
      }),
      Location(id: 'b', label: '🇳🇱 Netherlands', proxy: {
        'type': 'vless', 'server': 'nl.example', 'port': 443, 'uuid': 'u2',
      }),
    ];
    const group = ProxyGroup(
      name: '⚡️ Fastest',
      type: 'url-test',
      members: ['a', 'b'],
      testUrl: 'https://cp.cloudflare.com/generate_204',
      intervalSeconds: 600,
      tolerance: 150,
    );

    YamlMap render(ProxyGroup g) => loadYaml(
          mihomoTunConfigYaml(members.first, group: g, members: members),
        ) as YamlMap;

    test('every member is a proxy and the group decides between them', () {
      final doc = render(group);
      expect((doc['proxies'] as YamlList).map((p) => p['name']), ['p0', 'p1']);
      final groups = doc['proxy-groups'] as YamlList;
      expect(groups.first['name'], kGroupName);
      expect(groups.first['type'], 'url-test');
      expect(groups.first['proxies'], ['p0', 'p1']);
      expect(groups.first['tolerance'], 150);
    });

    test('the rules still point at PROXY, whatever PROXY now contains', () {
      // Rules and the `tun` section are what a hot switch compares; a group must
      // not reach into either, or switching to one would drop the session.
      final doc = render(group);
      final proxy = (doc['proxy-groups'] as YamlList).last;
      expect(proxy['name'], 'PROXY');
      expect(proxy['proxies'], [kGroupName]);
      expect((doc['rules'] as YamlList).last, 'MATCH,PROXY');
    });

    test('members are named by position, never by the provider\'s text', () {
      // A label can hold anything — emoji, colons, newlines — and these are
      // YAML keys and rule targets.
      final doc = render(group);
      expect(mihomoTunConfigYaml(members.first, group: group, members: members),
          isNot(contains('Fastest')));
      expect((doc['proxies'] as YamlList).map((p) => p['server']),
          ['de.example', 'nl.example'], reason: 'position is the only mapping');
    });

    test('an interval below the floor is raised to it', () {
      // The check runs from the user's device, through the tunnel, once per
      // member per round. A provider asking for ten seconds does not get it.
      final doc = render(const ProxyGroup(
        name: 'g', type: 'url-test', members: ['a', 'b'], intervalSeconds: 10,
      ));
      expect((doc['proxy-groups'] as YamlList).first['interval'],
          kMinGroupInterval.inSeconds);
    });

    test('a longer interval than ours is the provider\'s to choose', () {
      expect(render(group)['proxy-groups'].first['interval'], 600);
    });

    test('a test URL that is not https is replaced, not trusted', () {
      final doc = render(const ProxyGroup(
        name: 'g', type: 'url-test', members: ['a', 'b'],
        testUrl: 'http://tracker.example/probe',
      ));
      expect((doc['proxy-groups'] as YamlList).first['url'], kDefaultGroupTestUrl);
    });

    test('the strategy reaches the engine only for the group that has one', () {
      final balanced = render(const ProxyGroup(
        name: 'g', type: 'load-balance', members: ['a', 'b'],
        strategy: 'round-robin', intervalSeconds: 300,
      ));
      expect((balanced['proxy-groups'] as YamlList).first['strategy'], 'round-robin');
      expect((render(group)['proxy-groups'] as YamlList).first['strategy'], isNull,
          reason: 'url-test has no strategy, and mihomo refuses fields it does not expect');
    });

    test('a chain has nothing to measure, so it gets no probe', () {
      final doc = render(const ProxyGroup(
        name: 'g', type: 'relay', members: ['a', 'b'],
        testUrl: 'https://cp.cloudflare.com/generate_204', intervalSeconds: 300,
      ));
      final g = (doc['proxy-groups'] as YamlList).first;
      expect(g['type'], 'relay');
      expect(g['url'], isNull);
      expect(g['interval'], isNull);
    });
  });

  group('selecting one', () {
    test('a group id is distinguishable from a server id', () {
      // They share one selection — the user answers a single question — so the
      // id has to say which kind of answer it is.
      const g = ProxyGroup(name: '⚡️ Fastest', type: 'url-test', members: ['a']);
      expect(ProxyGroup.isGroupId(g.id), isTrue);
      expect(ProxyGroup.isGroupId('link_abc123'), isFalse);
      expect(ProxyGroup.isGroupId('sub_0_abcdef'), isFalse);
    });

    test('what a group does is said in words, not in its type name', () {
      const url = ProxyGroup(name: 'a', type: 'url-test', members: ['a']);
      const fb = ProxyGroup(name: 'b', type: 'fallback', members: ['a']);
      expect(url.describe(12), 'Lowest latency of 12');
      expect(fb.describe(12), contains('in their order'));
    });
  });

  group('asking for a rendering by name', () {
    test('the panel names differ, and each is tried in turn', () {
      // Remnawave calls it mihomo, Marzban clash-meta — Marzban has no
      // "mihomo" at all.
      final base = Uri.parse('https://sub.example/tok3n');
      expect(renderingUrl(base, 'mihomo').toString(), 'https://sub.example/tok3n/mihomo');
      expect(renderingUrl(base, 'clash-meta').toString(),
          'https://sub.example/tok3n/clash-meta');
    });

    test('3x-ui serves it from another path, not a suffix', () {
      // /sub/<id> next to /clash/<id> and /json/<id>: appending would ask the
      // subscription endpoint for a server named "clash".
      final u = Uri.parse('https://panel.example/sub/abc123');
      expect(renderingUrl(u, 'clash').toString(), 'https://panel.example/clash/abc123');
      expect(renderingUrl(u, 'mihomo'), isNull);
    });

    test('a URL that already names a rendering is left alone', () {
      final u = Uri.parse('https://sub.example/tok3n/mihomo');
      expect(renderingUrl(u, 'mihomo'), isNull);
      expect(renderingUrl(Uri.parse('https://sub.example/t/clash-meta'), 'mihomo'), isNull);
    });
  });
}
