import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:anoya/core/clash_plan.dart';
import 'package:anoya/core/corp_domains.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/parsers/subscription.dart';
import 'package:anoya/core/routing_prefs.dart';

const _local = '77.88.8.8';

void main() {
  final loc = Location.fromJson({
    'id': 'worker_1',
    'label': 'L1',
    'proxy': {
      'type': 'vless',
      'server': '203.0.113.10',
      'port': 443,
      'uuid': '2182dac0-d9a4-43a0-b905-963db9bc3abe',
      'tls': true,
    },
  });
  const routing = Routing(
    mode: 'full',
    rules: [
      RoutingRule(
        type: 'domain-suffix',
        values: ['ozon.ru', 'wb.ru'],
        action: 'direct',
      ),
      RoutingRule(
        type: 'domain-exact',
        values: ['gosuslugi.ru'],
        action: 'direct',
      ),
      RoutingRule(
        type: 'domain-suffix',
        values: ['youtube.com'],
        action: 'proxy',
      ),
      RoutingRule(
        type: 'ip-cidr',
        values: ['5.0.0.0/8', '6.0.0.0/8'],
        action: 'direct',
      ),
    ],
  );

  String render({
    Routing routing = routing,
    List<CorpDomains> corpDomains = const [],
    String? localDns,
  }) => localDns == null
      ? mihomoTunConfigYaml(
          loc,
          routing: routing,
          corpDomains: corpDomains,
          device: 'Anoya',
        )
      : mihomoTunConfigYaml(
          loc,
          routing: routing,
          corpDomains: corpDomains,
          localDns: localDns,
          device: 'Anoya',
        );

  YamlMap dnsOf(String yaml) => (loadYaml(yaml) as YamlMap)['dns'] as YamlMap;

  test('direct domains are asked at the local DNS and get real addresses', () {
    final dns = dnsOf(render(localDns: _local));
    expect(List.of(dns['direct-nameserver'] as YamlList), [_local]);
    expect(dns['direct-nameserver-follow-policy'], isTrue);
    expect(Map.of(dns['nameserver-policy'] as YamlMap), {
      'rule-set:_inline_0': _local,
      'gosuslugi.ru': _local,
    });
    expect(List.of(dns['fake-ip-filter'] as YamlList), [
      'rule-set:_inline_0',
      'gosuslugi.ru',
    ]);
  });

  test('corporate domains keep their own server ahead of the local DNS', () {
    const corp = [
      CorpDomains(domains: ['corp.local', 'ad.corp'], server: '10.0.0.53'),
    ];
    final dns = dnsOf(
      render(
        routing: withCorpDomains(routing, corp),
        corpDomains: corp,
        localDns: _local,
      ),
    );
    final policy = (dns['nameserver-policy'] as YamlMap).entries.toList();
    expect(policy.take(2).map((e) => '${e.key} ${e.value}'), [
      '+.corp.local 10.0.0.53',
      '+.ad.corp 10.0.0.53',
    ]);
  });

  group('subscription rules', () {
    final parsed = parseSubscriptionBody(r'''
proxies:
  - {name: DE, type: vless, server: de.example, port: 443, uuid: u}
  - {name: Без VPN, type: direct}
proxy-groups:
  - {name: RU, type: select, proxies: [Без VPN]}
  - {name: YouTube, type: select, proxies: [DE, Без VPN]}
rule-providers:
  youtube: {type: http, behavior: domain, format: mrs, url: 'https://lists.example/yt.mrs'}
  nets: {type: http, behavior: ipcidr, format: text, url: 'https://lists.example/n.txt'}
rules:
  - DOMAIN-SUFFIX,ru,RU
  - RULE-SET,youtube,YouTube
  - RULE-SET,nets,DIRECT
  - MATCH,DE
  - DOMAIN,after.example,DIRECT
''');

    YamlMap? policyOf({Map<String, String> choices = const {}}) =>
        dnsOf(
              mihomoTunConfigYaml(
                parsed.locations.first,
                clashPlan: parsed.plan,
                planChoices: choices,
                planLocations: parsed.locations,
                listPaths: const {
                  'youtube': '/shared/yt.mrs',
                  'nets': '/shared/n.txt',
                },
                localDns: _local,
              ),
            )['nameserver-policy']
            as YamlMap?;

    test('a rule whose group goes direct counts, an address list never', () {
      expect(policyOf()!.keys, ['+.ru']);
      expect(policyOf(choices: {'YouTube': ClashPlan.direct})!.keys, [
        '+.ru',
        'rule-set:l0',
      ]);
    });
  });

  test('without a local DNS the config is exactly what it was', () {
    final yaml = render(localDns: '');
    expect(yaml, render());
    expect(yaml, isNot(contains('direct-nameserver')));
    expect(yaml, isNot(contains('nameserver-policy')));
  });

  test('turning the local DNS on leaves the tun section alone', () {
    final before = (loadYaml(render()) as YamlMap)['tun'];
    final after = (loadYaml(render(localDns: _local)) as YamlMap)['tun'];
    expect(after, before);
  });

  test('the setting survives a save and a load', () {
    final prefs = RoutingPrefs.fromJson(
      const RoutingPrefs(localDns: _local).toJson(),
    );
    expect(prefs.localDns, _local);
    expect(const RoutingPrefs().toJson(), isNot(contains('local_dns')));
  });
}
