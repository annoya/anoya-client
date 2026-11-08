import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:anoya/core/corp_domains.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/routing_prefs.dart';

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
  const corp = [
    CorpDomains(domains: ['corp.local', 'ad.corp'], server: '10.0.0.53'),
    CorpDomains(domains: ['intra.example.com'], server: 'tls://10.0.0.54'),
  ];

  String render({List<CorpDomains> corpDomains = const []}) {
    final routing = withCorpDomains(
      withLanDirect(const Routing(mode: 'full', rules: [])),
      corpDomains,
    );
    return mihomoTunConfigYaml(
      loc,
      routing: routing,
      corpDomains: corpDomains,
      device: 'Anoya',
    );
  }

  test('people type the zone: masks, case and repeats are normalised', () {
    final parsed = parseCorpDomains(
      ' *.Corp.Local, +.ad.corp\nad.corp; x.lan. ',
    );
    expect(parsed.invalid, isNull);
    expect(parsed.domains, ['corp.local', 'ad.corp', 'x.lan']);
  });

  test('a value that is not a domain is named back, nothing is kept', () {
    final parsed = parseCorpDomains('corp.local, http://wiki');
    expect(parsed.invalid, 'http://wiki');
    expect(parsed.domains, isEmpty);
  });

  test(
    'each domain is asked at its server and answered with a real address',
    () {
      final dns =
          (loadYaml(render(corpDomains: corp)) as YamlMap)['dns'] as YamlMap;
      expect(Map.of(dns['nameserver-policy'] as YamlMap), {
        '+.corp.local': '10.0.0.53',
        '+.ad.corp': '10.0.0.53',
        '+.intra.example.com': 'tls://10.0.0.54',
      });
      expect(List.of(dns['fake-ip-filter'] as YamlList), [
        '+.corp.local',
        '+.ad.corp',
        '+.intra.example.com',
      ]);
    },
  );

  test('corporate names go outside the VPN before any other rule', () {
    final doc = loadYaml(render(corpDomains: corp)) as YamlMap;
    final rules = List<String>.of((doc['rules'] as YamlList).cast());
    expect(rules.first, 'RULE-SET,_inline_0,DIRECT');
    final payload =
        ((doc['rule-providers'] as YamlMap)['_inline_0'] as YamlMap)['payload'];
    expect(List.of(payload as YamlList), [
      '+.corp.local',
      '+.ad.corp',
      '+.intra.example.com',
    ]);
  });

  test('without corporate domains the config is exactly what it was', () {
    final yaml = render();
    expect(yaml, isNot(contains('nameserver-policy')));
    expect(yaml, isNot(contains('fake-ip-filter')));
    expect(
      yaml,
      mihomoTunConfigYaml(
        loc,
        routing: withLanDirect(const Routing(mode: 'full', rules: [])),
        device: 'Anoya',
      ),
    );
  });

  test('adding corporate domains leaves the tun section alone', () {
    final before = (loadYaml(render()) as YamlMap)['tun'];
    final after = (loadYaml(render(corpDomains: corp)) as YamlMap)['tun'];
    expect(after, before);
  });

  test('the list survives a save and a load', () {
    final prefs = RoutingPrefs.fromJson(
      const RoutingPrefs(corpDomains: corp).toJson(),
    );
    expect(
      prefs.corpDomains.map((c) => c.toJson()),
      corp.map((c) => c.toJson()),
    );
    expect(const RoutingPrefs().toJson(), isNot(contains('corp_domains')));
  });
}
