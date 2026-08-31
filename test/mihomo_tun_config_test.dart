import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:vpn_client/core/mihomo_tun_config.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/parsers/share_link.dart';
import 'package:vpn_client/core/parsers/subscription.dart';

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
    // Not wireguard, which the renderer emits now that Amnezia's AWG
    // configurations arrive with their own key material — the same trap the
    // hysteria2 note below records.
    final loc = Location.fromJson({'id': 'w', 'label': 'x', 'proxy': {'type': 'ssh'}});
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
    // tuic, not hysteria2: hysteria2 is supported now, and a test whose
    // "unsupported" example quietly became supported stops testing anything.
    final loc = Location.fromJson({'id': 'x', 'label': 'y', 'proxy': {'type': 'tuic'}});
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

  test('renders a parsed hysteria2 proxy', () {
    // QUIC-based: no transport section, and alpn is a list rather than a string.
    final loc = parseProxyUri(
        'hysteria2://pw@h.example:30443/?sni=h.example&alpn=h3&insecure=1#HY')!;
    final doc = loadYaml(mihomoTunConfigYaml(loc)) as YamlMap;
    final proxy = (doc['proxies'] as YamlList).single as YamlMap;
    expect(proxy['type'], 'hysteria2');
    expect(proxy['password'], 'pw');
    expect(proxy['port'], 30443);
    expect(proxy['sni'], 'h.example');
    expect(proxy['alpn'], ['h3']);
    expect(proxy['skip-cert-verify'], true);
    expect(proxy.containsKey('network'), isFalse,
        reason: 'a transport would be meaningless for QUIC');
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

  test('dns comes from the config; the app default rides the tunnel', () {
    final fallback = loadYaml(mihomoTunConfigYaml(vlessLoc())) as YamlMap;
    // Pinned, unlike a resolver the configuration chose: unpinned it would go
    // out on the physical interface, telling the local network which resolver
    // this device uses and the resolver which addresses are asking. Through the
    // tunnel it says neither, and a network blocking it stops mattering.
    expect((fallback['dns'] as YamlMap)['nameserver'],
        ['https://1.1.1.1/dns-query#PROXY']);
    // Reaching the proxy is the one job that cannot ride the tunnel, so it gets
    // its own unpinned list — and three operators rather than one, because it
    // resolves a single hostname the local network already watched us dial.
    expect((fallback['dns'] as YamlMap)['proxy-server-nameserver'], hasLength(3));
    expect((fallback['dns'] as YamlMap)['default-nameserver'], isNull,
        reason: 'every default is addressed by IP, so nothing needs bootstrapping');

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

  test('resolving the proxy never needs the proxy', () {
    // A panel pins its resolver to the tunnel so DNS does not leak to the local
    // network. Honouring that pin without saying how proxy hostnames resolve
    // deadlocks the engine: the query waits on the tunnel, the tunnel waits on
    // the query, and every dial dies with "couldn't find ip" — a VPN that
    // connects and carries nothing.
    final dns = (loadYaml(mihomoTunConfigYaml(vlessLoc(),
        dns: ['https://dns.quad9.net/dns-query#PROXY'])) as YamlMap)['dns'] as YamlMap;
    expect(dns['nameserver'], ['https://dns.quad9.net/dns-query#PROXY'],
        reason: "the provider's pin is kept: DNS still rides the tunnel");
    final bootstrap = (dns['proxy-server-nameserver'] as YamlList).map((e) => '$e');
    expect(bootstrap, isNotEmpty);
    expect(bootstrap.every((ns) => !ns.contains('#')), isTrue,
        reason: 'a pinned resolver here would rebuild the same loop');
  });

  test('a pin we cannot honour is dropped, its resolver kept', () {
    // mihomo reads an unknown pin as an interface name and binds the socket to
    // it, so a provider group name we replaced with ours would send every query
    // out of a device that does not exist.
    final dns = (loadYaml(mihomoTunConfigYaml(vlessLoc(), dns: [
      'https://dns.quad9.net/dns-query#\u{1F680} Auto',
      'tls://dns.google#RULES',
    ])) as YamlMap)['dns'] as YamlMap;
    expect(dns['nameserver'], [
      'https://dns.quad9.net/dns-query',
      'tls://dns.google#RULES',
    ]);
  });

  test('a group member can be pinned to, because we render it', () {
    const g = ProxyGroup(name: 'auto', type: 'url-test', members: ['a']);
    final dns = (loadYaml(mihomoTunConfigYaml(vlessLoc(),
        group: g,
        members: [vlessLoc()],
        dns: ['tls://dns.google#p0'])) as YamlMap)['dns'] as YamlMap;
    expect(dns['nameserver'], ['tls://dns.google#p0']);
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
    expect((doc['dns'] as YamlMap)['nameserver'], ['https://1.1.1.1/dns-query#PROXY']);
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

  group('rule lists', () {
    const list = RuleList(
      name: 'reject',
      url: 'https://lists.example/reject.yaml',
      behavior: 'domain',
    );
    const routing = Routing(mode: 'split', rules: [
      RoutingRule(type: 'rule-list', value: 'reject', action: 'block'),
      RoutingRule(type: 'domain-suffix', value: 'ip.me', action: 'proxy'),
    ], lists: [list]);

    test('a downloaded list is handed over as a local file', () {
      // Never `type: http`: mihomo fetches providers inside config apply, 20 s
      // per file under a wait group, which is a stalled connect — and a failure
      // there is only logged, leaving a rule that matches nothing.
      final doc = loadYaml(mihomoTunConfigYaml(vlessLoc(),
          routing: routing,
          listPaths: {'reject': '/tmp/group/rulelists/abc.yaml'})) as YamlMap;
      final provider = (doc['rule-providers'] as YamlMap)['reject'] as YamlMap;
      expect(provider['type'], 'file');
      expect(provider['path'], '/tmp/group/rulelists/abc.yaml');
      expect(provider['behavior'], 'domain');
      expect(provider['format'], 'yaml');
      expect((doc['rules'] as YamlList).map((e) => '$e'),
          contains('RULE-SET,reject,REJECT'));
    });

    test('without the file the rule is left out, not left dangling', () {
      final doc = loadYaml(mihomoTunConfigYaml(vlessLoc(), routing: routing)) as YamlMap;
      expect(doc['rule-providers'], isNull);
      final rules = (doc['rules'] as YamlList).map((e) => '$e').toList();
      expect(rules.any((r) => r.startsWith('RULE-SET')), isFalse,
          reason: 'a rule pointing at nothing silently matches nothing');
      expect(rules, contains('DOMAIN-SUFFIX,ip.me,PROXY'),
          reason: 'one missing list must not cost the other rules');
    });

    test('a regex rule reaches the engine as DOMAIN-REGEX', () {
      const r = Routing(mode: 'full', rules: [
        RoutingRule(type: 'domain-regex', value: r'^.*[.]ads[.]example$', action: 'block'),
      ]);
      final doc = loadYaml(mihomoTunConfigYaml(vlessLoc(), routing: r)) as YamlMap;
      expect((doc['rules'] as YamlList).map((e) => '$e'),
          contains(r'DOMAIN-REGEX,^.*[.]ads[.]example$,REJECT'));
    });

    test('a list name that is not YAML-safe never reaches the config', () {
      const bad = Routing(mode: 'full', rules: [
        RoutingRule(type: 'rule-list', value: 'a: b', action: 'block'),
      ], lists: [RuleList(name: 'a: b', url: 'https://x.example/l', behavior: 'domain')]);
      final yaml = mihomoTunConfigYaml(vlessLoc(),
          routing: bad, listPaths: {'a: b': '/tmp/x.yaml'});
      expect(yaml, isNot(contains('a: b')));
      loadYaml(yaml); // must still parse
    });
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
