import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/rule_set.dart';
import 'package:anoya/core/rule_set_transfer.dart';

void main() {
  const work = RuleSet(
    id: 'work',
    name: 'Work',
    mode: RoutingMode.split,
    editor: RuleEditor.advanced,
    rules: [
      RoutingRule(
        type: 'domain-suffix',
        value: 'corp.example',
        action: 'proxy',
      ),
      RoutingRule(
        type: 'ip-cidr',
        value: '10.20.0.0/16',
        action: 'proxy',
        noResolve: true,
      ),
      RoutingRule(type: 'process-name', value: 'Slack', action: 'direct'),
      RoutingRule(type: 'domain-regex', value: r'^ads\.', action: 'block'),
    ],
  );

  List<Map<String, dynamic>> shape(List<RoutingRule> rules) => [
    for (final r in rules) r.toJson(),
  ];

  group('our own format', () {
    test('a file comes back whole', () {
      final back = parseRuleSetImport(encodeRuleSetFile(work))!;

      expect(back.source, RuleSetSource.anoya);
      expect(back.name, 'Work');
      expect(back.mode, RoutingMode.split);
      expect(
        shape(back.rules),
        shape(work.rules),
        reason: 'processes, regex and no-resolve survive — nothing is lossy',
      );
      expect(back.skipped, isEmpty);
    });

    test('the link for clipboard and QR comes back whole', () {
      final link = encodeRuleSetLink(work);
      expect(link, startsWith('anoya://ruleset/add/'));

      final back = parseRuleSetImport(link)!;

      expect(back.name, 'Work');
      expect(shape(back.rules), shape(work.rules));
    });

    test('a file from a newer app is refused, not half-read', () {
      final doc = jsonDecode(encodeRuleSetFile(work)) as Map<String, dynamic>;
      doc['anoya_ruleset'] = kRuleSetFormatVersion + 1;

      expect(parseRuleSetImport(jsonEncode(doc)), isNull);
    });

    test('the file is named after the set', () {
      expect(ruleSetFileName('Work · VPN'), 'work-vpn.anoya-rules.json');
      expect(ruleSetFileName('工作'), 'rule-set.anoya-rules.json');
    });
  });

  group('Clash / mihomo', () {
    const yaml = '''
port: 7890
proxies: []
rules:
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN,ads.example.com,REJECT
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - GEOIP,ru,DIRECT
  - GEOSITE,Category-Ads-All,REJECT-DROP
  - RULE-SET,https://example.com/list.yaml,Proxy
  - USER-AGENT,curl*,DIRECT
  - MATCH,DIRECT
''';

    test('rules move type for type, policies become actions', () {
      final r = parseRuleSetImport(yaml, fallbackName: 'clash')!;

      expect(r.source, RuleSetSource.clash);
      expect(r.name, 'clash');
      expect(shape(r.rules), [
        {'type': 'domain-suffix', 'value': 'google.com', 'action': 'proxy'},
        {'type': 'domain-exact', 'value': 'ads.example.com', 'action': 'block'},
        {
          'type': 'ip-cidr',
          'value': '192.168.0.0/16',
          'action': 'direct',
          'no_resolve': true,
        },
        {'type': 'geoip', 'value': 'RU', 'action': 'direct'},
        {'type': 'geosite', 'value': 'category-ads-all', 'action': 'block'},
      ]);
    });

    test('MATCH,DIRECT means only the rules go through the VPN', () {
      expect(parseRuleSetImport(yaml)!.mode, RoutingMode.split);
      expect(
        parseRuleSetImport('DOMAIN-SUFFIX,a.com,DIRECT\nMATCH,Proxy')!.mode,
        RoutingMode.full,
      );
    });

    test('what cannot move is counted and named', () {
      final skipped = parseRuleSetImport(yaml)!.skipped;

      final lists = skipped.firstWhere((s) => s.reason == SkipReason.ruleLists);
      expect(lists.count, 1);
      final other = skipped.firstWhere(
        (s) => s.reason == SkipReason.unsupported,
      );
      expect(other.count, 1);
      expect(other.kinds, ['USER-AGENT']);
    });
  });

  group('Shadowrocket / Surge', () {
    test('only the [Rule] section is read; FINAL picks the direction', () {
      const conf = '''
[General]
bypass-system = true
dns-server = system

[Rule]
# streaming
DOMAIN-SUFFIX,netflix.com,PROXY
DOMAIN-KEYWORD,youtube,PROXY
IP-CIDR6,2001:db8::/32,DIRECT
FINAL,PROXY

[Host]
localhost = 127.0.0.1
''';
      final r = parseRuleSetImport(conf, fallbackName: 'rocket')!;

      expect(r.source, RuleSetSource.surge);
      expect(r.mode, RoutingMode.full);
      expect(r.rules.map((x) => x.type), [
        'domain-suffix',
        'domain-keyword',
        'ip-cidr',
      ]);
      expect(r.skipped, isEmpty);
    });
  });

  group('Happ routing profile', () {
    final profile = {
      'Name': 'Russia direct',
      'GlobalProxy': true,
      'RemoteDNSType': 'DoH',
      'RemoteDNSDomain': 'https://cloudflare-dns.com/dns-query',
      'Geoipurl': 'https://example.com/geoip.dat',
      'Geositeurl': 'https://example.com/geosite.dat',
      'DirectSites': ['geosite:ru', 'domain:yandex.ru', 'vk.com'],
      'DirectIp': ['geoip:ru', '77.88.8.8', '10.0.0.0/8'],
      'ProxySites': ['full:www.youtube.com', 'keyword:openai'],
      'ProxyIp': <String>[],
      'BlockSites': ['geosite:category-ads-all', 'ext:custom.dat:ads'],
      'BlockIp': <String>[],
      'DomainStrategy': 'IPIfNonMatch',
    };
    final link =
        'happ://routing/onadd/${base64.encode(utf8.encode(jsonEncode(profile)))}';

    test('the lists become rules, block before proxy before direct', () {
      final r = parseRuleSetImport(link)!;

      expect(r.source, RuleSetSource.happ);
      expect(r.name, 'Russia direct');
      expect(r.mode, RoutingMode.full);
      expect(shape(r.rules), [
        {'type': 'geosite', 'value': 'category-ads-all', 'action': 'block'},
        {'type': 'domain-exact', 'value': 'www.youtube.com', 'action': 'proxy'},
        {'type': 'domain-keyword', 'value': 'openai', 'action': 'proxy'},
        {'type': 'geosite', 'value': 'ru', 'action': 'direct'},
        {'type': 'domain-suffix', 'value': 'yandex.ru', 'action': 'direct'},
        {'type': 'domain-suffix', 'value': 'vk.com', 'action': 'direct'},
        {'type': 'geoip', 'value': 'RU', 'action': 'direct'},
        {'type': 'ip-cidr', 'value': '77.88.8.8/32', 'action': 'direct'},
        {'type': 'ip-cidr', 'value': '10.0.0.0/8', 'action': 'direct'},
      ], reason: 'a proxy exception inside a direct country must still win');
    });

    test('DNS and geo links are reported, not silently dropped', () {
      final reasons = parseRuleSetImport(link)!.skipped.map((s) => s.reason);

      expect(reasons, containsAll([SkipReason.dns, SkipReason.geoUrls]));
      final other = parseRuleSetImport(
        link,
      )!.skipped.firstWhere((s) => s.reason == SkipReason.unsupported);
      expect(other.count, 1, reason: 'the ext: file reference');
    });

    test('GlobalProxy false means only the proxy lists use the VPN', () {
      final r = parseRuleSetImport(
        jsonEncode({
          'Name': 'Only YouTube',
          'GlobalProxy': false,
          'ProxySites': ['geosite:youtube'],
        }),
      )!;

      expect(r.mode, RoutingMode.split);
      expect(r.skipped, isEmpty);
    });
  });

  test('a taken name gets the next free number, ignoring case', () {
    expect(uniqueRuleSetName('Work', ['Default']), 'Work');
    expect(uniqueRuleSetName('Default', ['Default']), 'Default 2');
    expect(uniqueRuleSetName('default', ['Default', 'default 2']), 'default 3');
  });

  test('text that is none of these is refused', () {
    expect(parseRuleSetImport('hello world'), isNull);
    expect(parseRuleSetImport('HELLO,world'), isNull);
    expect(parseRuleSetImport('{"some": "json"}'), isNull);
    expect(parseRuleSetImport('vless://uuid@1.2.3.4:443#x'), isNull);
  });
}
