import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:vpn_client/core/mihomo_tun_config.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/proxy_uri.dart';

void main() {
  test('mihomoTunConfigYaml renders a tun inbound + vless proxy', () {
    final loc = Location.fromJson({
      'id': 'worker_1',
      'label': 'L1',
      'proxy': {
        'type': 'vless',
        'server': '203.0.113.10',
        'port': 443,
        'uuid': '2182dac0-d9a4-43a0-b905-963db9bc3abe',
        'tls': true,
        'flow': 'xtls-rprx-vision',
        'reality': {
          'public_key': 'PUBKEY',
          'short_id': '882bd333',
          'server_name': 'www.apple.com',
        },
      },
    });

    final doc = loadYaml(mihomoTunConfigYaml(loc)) as YamlMap;
    final tun = doc['tun'] as YamlMap;
    expect(tun['enable'], true);
    expect(tun['stack'], 'gvisor');

    final proxy = (doc['proxies'] as YamlList).first as YamlMap;
    expect(proxy['type'], 'vless');
    expect(proxy['server'], '203.0.113.10');
    expect(proxy['servername'], 'www.apple.com');
    expect((proxy['reality-opts'] as YamlMap)['short-id'], '882bd333');
  });

  test('mihomoTunConfigYaml rejects unknown proxy types', () {
    final loc = Location.fromJson({'id': 'w', 'label': 'x', 'proxy': {'type': 'wireguard'}});
    expect(() => mihomoTunConfigYaml(loc), throwsStateError);
  });

  Location vlessLoc() => Location.fromJson({
        'id': 'worker_1',
        'label': 'L1',
        'proxy': {
          'type': 'vless',
          'server': '203.0.113.10',
          'port': 443,
          'uuid': 'u',
          'reality': {'public_key': 'PK', 'short_id': 's', 'server_name': 'www.apple.com'},
        },
      });

  test('stack defaults to gvisor and is overridable (iOS uses system)', () {
    expect(mihomoTunConfigYaml(vlessLoc()), contains('stack: gvisor'));
    final ios = mihomoTunConfigYaml(vlessLoc(), stack: 'system');
    expect(ios, contains('stack: system'));
    expect(ios, isNot(contains('stack: gvisor')));
  });

  test('no routing → full tunnel, process matching off', () {
    final yaml = mihomoTunConfigYaml(vlessLoc());
    expect(yaml, contains('find-process-mode: "off"'));
    final rules = (loadYaml(yaml) as YamlMap)['rules'] as YamlList;
    expect(rules, ['MATCH,PROXY']);
  });

  test('split routing renders ordered rules and MATCH,DIRECT', () {
    const routing = Routing(mode: 'split', rules: [
      RoutingRule(type: 'domain-suffix', value: 'corp.example.com', action: 'proxy'),
      RoutingRule(type: 'ip-cidr', value: '10.0.0.0/8', action: 'proxy'),
      RoutingRule(type: 'domain-keyword', value: 'tracker', action: 'block'),
    ]);
    final rules =
        (loadYaml(mihomoTunConfigYaml(vlessLoc(), routing: routing)) as YamlMap)['rules'] as YamlList;
    expect(rules, [
      'DOMAIN-SUFFIX,corp.example.com,PROXY',
      'IP-CIDR,10.0.0.0/8,PROXY,no-resolve',
      'DOMAIN-KEYWORD,tracker,REJECT',
      'MATCH,DIRECT',
    ]);
  });

  test('full routing keeps MATCH,PROXY and renders direct exceptions', () {
    const routing = Routing(mode: 'full', rules: [
      RoutingRule(type: 'domain-suffix', value: 'bank.local', action: 'direct'),
    ]);
    final rules =
        (loadYaml(mihomoTunConfigYaml(vlessLoc(), routing: routing)) as YamlMap)['rules'] as YamlList;
    expect(rules, ['DOMAIN-SUFFIX,bank.local,DIRECT', 'MATCH,PROXY']);
  });

  test('renders a parsed vmess (ws+tls) proxy', () {
    final loc = parseProxyUri(
      'vmess://${base64.encode(utf8.encode(jsonEncode({
            'ps': 'VM', 'add': '9.9.9.9', 'port': '8443', 'id': 'vmess-uuid',
            'aid': '0', 'scy': 'auto', 'net': 'ws', 'host': 'h.example.com',
            'path': '/p', 'tls': 'tls', 'sni': 's.example.com',
          }))).replaceAll('\n', '')}')!;
    final doc = loadYaml(mihomoTunConfigYaml(loc)) as YamlMap;
    final proxy = (doc['proxies'] as YamlList).first as YamlMap;
    expect(proxy['name'], 'proxy');
    expect(proxy['type'], 'vmess');
    expect(proxy['server'], '9.9.9.9');
    expect(proxy['port'], 8443);
    expect(proxy['uuid'], 'vmess-uuid');
    expect(proxy['tls'], true);
    expect((proxy['ws-opts'] as YamlMap)['path'], '/p');
    expect(((proxy['ws-opts'] as YamlMap)['headers'] as YamlMap)['Host'], 'h.example.com');
  });

  test('renders a parsed trojan proxy + group references it', () {
    final loc = parseProxyUri('trojan://p@t.example.com:443?sni=t.example.com#T')!;
    final doc = loadYaml(mihomoTunConfigYaml(loc)) as YamlMap;
    final proxy = (doc['proxies'] as YamlList).first as YamlMap;
    expect(proxy['type'], 'trojan');
    expect(proxy['password'], 'p');
    expect(proxy['sni'], 't.example.com');
    expect((doc['proxy-groups'] as YamlList).first['proxies'], ['proxy']);
  });

  test('rejects unknown proxy types (renderer)', () {
    final loc = Location.fromJson({'id': 'x', 'label': 'y', 'proxy': {'type': 'hysteria2'}});
    expect(() => mihomoTunConfigYaml(loc), throwsStateError);
  });

  test('process rules enable strict process matching', () {
    const routing = Routing(mode: 'full', rules: [
      RoutingRule(type: 'process-name', value: 'Slack', action: 'direct'),
    ]);
    final yaml = mihomoTunConfigYaml(vlessLoc(), routing: routing);
    expect(yaml, contains('find-process-mode: strict'));
    expect(yaml, contains('PROCESS-NAME,Slack,DIRECT'));
  });

  test('invalid or malicious rules are skipped, never interpolated', () {
    const routing = Routing(mode: 'split', rules: [
      RoutingRule(type: 'domain-suffix', value: 'ok.example.com', action: 'proxy'),
      RoutingRule(type: 'domain-suffix', value: 'evil,MATCH', action: 'proxy'),
      RoutingRule(type: 'domain-suffix', value: 'x\nrules:', action: 'proxy'),
      RoutingRule(type: 'ip-cidr', value: '10.0.0.1', action: 'proxy'), // bare IP
      RoutingRule(type: 'geo-ip', value: 'ru', action: 'proxy'), // unknown type
      RoutingRule(type: 'domain-suffix', value: 'y.com', action: 'allow'), // unknown action
    ]);
    final yaml = mihomoTunConfigYaml(vlessLoc(), routing: routing);
    final rules = (loadYaml(yaml) as YamlMap)['rules'] as YamlList;
    expect(rules, ['DOMAIN-SUFFIX,ok.example.com,PROXY', 'MATCH,DIRECT']);
    expect(yaml, isNot(contains('evil')));
  });
}
