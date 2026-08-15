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

  test('IPv6 is carried end to end, not just claimed', () {
    // The tunnel owns the v6 default route (ADR-002), so the engine has to
    // handle v6: with it off, the fake-IP pool refuses AAAA and every v6
    // destination fails instead of being proxied.
    final doc = loadYaml(mihomoTunConfigYaml(vlessLoc())) as YamlMap;
    expect(doc['ipv6'], true);
    final dns = doc['dns'] as YamlMap;
    expect(dns['fake-ip-range6'], kFakeIpRange6);
    expect((doc['tun'] as YamlMap)['inet6-address'], [kTunInet6Address]);
  });

  test('the engine is forbidden from fetching geo databases itself', () {
    // Not a preference: a missing database makes mihomo download it *while
    // parsing*, 90s per file inside the engine lock — during startTunnel that
    // overruns the system's deadline. Empty URLs make it fail immediately.
    final doc = loadYaml(mihomoTunConfigYaml(vlessLoc())) as YamlMap;
    final urls = doc['geox-url'] as YamlMap;
    expect(urls.values, everyElement(''),
        reason: 'every geo source must be empty, whatever rules the config has');
  });

  test('the single outbound is always named "proxy"', () {
    // Both the PROXY group and the engine wrapper's egress probe (Go side,
    // native/mihomocore/engine.go) look the outbound up by this exact name.
    // A rename here would silently disable the probe rather than fail.
    final doc = loadYaml(mihomoTunConfigYaml(vlessLoc())) as YamlMap;
    expect((doc['proxies'] as YamlList).single['name'], 'proxy');
    expect((doc['proxy-groups'] as YamlList).single['proxies'], ['proxy']);
  });

  test('a hostile subscription cannot add config keys of its own', () {
    // Keys are structural: unlike values, a key carrying a newline escapes its
    // block and lands at column 0. The payload here would open mihomo's
    // unauthenticated control API to the network.
    const body = '''
proxies:
  - name: pwn
    type: ss
    server: 1.2.3.4
    port: 443
    cipher: aes-128-gcm
    password: x
    "udp: true\\nexternal-controller: 0.0.0.0:9090": "z"
    ws-opts:
      headers:
        "Host: a\\nallow-lan": "true"
''';
    final locations = parseSubscription(body);
    expect(locations, hasLength(1), reason: 'the proxy itself is still usable');
    final doc = loadYaml(mihomoTunConfigYaml(locations.single)) as YamlMap;
    expect(doc.keys, isNot(contains('external-controller')));
    expect(doc.keys, isNot(contains('allow-lan')));
    expect(doc['proxies'], hasLength(1));
  });

  test('dns comes from the config; Cloudflare DoH is the fallback', () {
    final fallback = loadYaml(mihomoTunConfigYaml(vlessLoc())) as YamlMap;
    expect((fallback['dns'] as YamlMap)['nameserver'], ['https://1.1.1.1/dns-query']);
    expect((fallback['dns'] as YamlMap)['default-nameserver'], isNull);

    final own = loadYaml(mihomoTunConfigYaml(vlessLoc(),
        dns: ['10.0.0.53', 'tls://1.1.1.1:853'])) as YamlMap;
    expect((own['dns'] as YamlMap)['nameserver'], ['10.0.0.53', 'tls://1.1.1.1:853']);
    // Every resolver is IP-addressed: no bootstrap needed.
    expect((own['dns'] as YamlMap)['default-nameserver'], isNull);
  });

  test('hostname resolvers get a plain-IP bootstrap', () {
    final doc = loadYaml(mihomoTunConfigYaml(vlessLoc(),
        dns: ['https://dns.google/dns-query', '1.1.1.1'])) as YamlMap;
    expect((doc['dns'] as YamlMap)['default-nameserver'], ['1.1.1.1']);
  });

  test('unusable dns entries are dropped, never interpolated', () {
    final yaml = mihomoTunConfigYaml(vlessLoc(), dns: [
      'evil"\n  - injected', // quote + escape
      'bad entry with spaces',
      'x\nrules: []', // newline
      '', // empty
    ]);
    final doc = loadYaml(yaml) as YamlMap;
    // Everything was dropped, so the fallback applies and nothing leaked in.
    expect((doc['dns'] as YamlMap)['nameserver'], ['https://1.1.1.1/dns-query']);
    expect(yaml, isNot(contains('injected')));
  });

  test('fake-ip settings are app constants, whatever dns the config brings', () {
    // The OS caches the fake addresses the engine handed out; a range that
    // moved with the config would strand every cached answer on a hot switch.
    for (final dns in [<String>[], ['10.0.0.53'], ['https://dns.google/dns-query']]) {
      final doc = loadYaml(mihomoTunConfigYaml(vlessLoc(), dns: dns)) as YamlMap;
      expect((doc['dns'] as YamlMap)['fake-ip-range'], '198.18.0.1/16');
      expect((doc['dns'] as YamlMap)['enhanced-mode'], 'fake-ip');
    }
  });

  test('subscriptionDns mines dns.nameserver out of a Clash YAML body', () {
    const clash = '''
dns:
  enable: true
  nameserver:
    - https://doh.example.net/dns-query
    - 9.9.9.9
proxies:
  - {name: a, type: vless, server: 1.2.3.4, port: 443, uuid: u}
''';
    expect(subscriptionDns(clash),
        ['https://doh.example.net/dns-query', '9.9.9.9']);
    // Link lists carry no DNS.
    expect(subscriptionDns('vless://u@h:443?security=none#x'), isEmpty);
  });
}
