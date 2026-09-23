import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:anoya/core/dns_plan.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/parsers/subscription.dart';

void main() {
  Location loc() => Location(
    id: 'a',
    label: 'A',
    proxy: const {
      'type': 'vless',
      'server': 'h.example',
      'port': 443,
      'uuid': 'u',
      'network': 'tcp',
      'tls': true,
    },
  );

  YamlMap dnsBlock(List<String> dns) =>
      (loadYaml(mihomoTunConfigYaml(loc(), dns: dns)) as YamlMap)['dns']
          as YamlMap;

  group('sing-box', () {
    test('a detour to a server means the query rides the tunnel', () {
      const body = '''
{
  "dns": {"servers": [
    {"tag": "remote", "address": "tls://dns.quad9.net", "detour": "vpn"},
    {"tag": "near",   "address": "udp://77.88.8.8",     "detour": "direct-out"},
    {"tag": "plain",  "address": "udp://1.1.1.1"}
  ]},
  "outbounds": [
    {"type": "vless", "tag": "vpn", "server": "h.example", "server_port": 443, "uuid": "u"},
    {"type": "direct", "tag": "direct-out"}
  ]
}''';
      expect(parseSubscriptionBody(body).dns, [
        'tls://dns.quad9.net#PROXY',
        'udp://77.88.8.8',
        'udp://1.1.1.1',
      ]);
    });

    test('the 1.12 schema, where the address is split across fields', () {
      const body = '''
{
  "dns": {"servers": [
    {"type": "https", "tag": "r", "server": "dns.quad9.net", "server_port": 443,
     "path": "/dns-query", "detour": "vpn"},
    {"type": "local", "tag": "l"},
    {"type": "fakeip", "tag": "f", "inet4_range": "198.18.0.0/15"}
  ]},
  "outbounds": [
    {"type": "vless", "tag": "vpn", "server": "h.example", "server_port": 443, "uuid": "u"}
  ]
}''';
      expect(parseSubscriptionBody(body).dns, [
        'https://dns.quad9.net:443/dns-query#PROXY',
      ]);
    });
  });

  group('xray', () {
    test(
      '+local is issued here, anything else goes out through the tunnel',
      () {
        const body = '''
[{"remarks": "A",
  "dns": {"servers": [
    "https://dns.quad9.net/dns-query",
    "https+local://dns.google/dns-query",
    {"address": "8.8.8.8", "domains": ["geosite:google"]},
    "localhost"
  ]},
  "outbounds": [{"protocol": "vless", "settings": {"vnext": [
    {"address": "h.example", "port": 443, "users": [{"id": "u"}]}]}}]}]''';
        expect(parseSubscriptionBody(body).dns, [
          'https://dns.quad9.net/dns-query#PROXY',
          'https://dns.google/dns-query',
          '8.8.8.8#PROXY',
        ]);
      },
    );
  });

  test('clash entries already speak the target syntax', () {
    const body = '''
dns:
  nameserver:
    - https://dns.quad9.net/dns-query#PROXY
    - tls://77.88.8.8
proxies:
  - {name: a, type: vless, server: h.example, port: 443, uuid: u}
''';
    expect(parseSubscriptionBody(body).dns, [
      'https://dns.quad9.net/dns-query#PROXY',
      'tls://77.88.8.8',
    ]);
  });

  test('a link list has nowhere to put a resolver', () {
    expect(
      parseSubscriptionBody('vless://u@h.example:443?security=none#A').dns,
      isEmpty,
    );
  });

  test('HTTP/3 is a transport, not a protocol the engine has a scheme for', () {
    const body = '''
{"dns": {"servers": [{"tag": "r", "address": "h3://dns.google/dns-query"}]},
 "outbounds": [{"type": "vless", "tag": "v", "server": "h.example", "server_port": 443, "uuid": "u"}]}''';
    expect(parseSubscriptionBody(body).dns, ['https://dns.google/dns-query']);
  });

  group('what the renderer will still refuse', () {
    test('a scheme the engine rejects never reaches the config', () {
      final dns = dnsBlock(['h3://dns.google/dns-query', 'tls://9.9.9.9']);
      expect(dns['nameserver'], ['tls://9.9.9.9']);
    });

    test(
      'a resolver the tunnel cannot carry is replaced, not left to fail',
      () {
        final noUdp = Location(
          id: 'b',
          label: 'B',
          proxy: const {
            'type': 'ss',
            'server': 'h.example',
            'port': 443,
            'password': 'p',
            'cipher': 'aes-128-gcm',
          },
        );
        final dns =
            (loadYaml(mihomoTunConfigYaml(noUdp, dns: ['1.1.1.1#PROXY']))
                    as YamlMap)['dns']
                as YamlMap;
        expect(dns['nameserver'], ['https://1.1.1.1/dns-query#PROXY']);
        expect(dns['proxy-server-nameserver'], ['1.1.1.1']);
      },
    );

    test('an encrypted resolver is pinned even when the tunnel has no UDP', () {
      final noUdp = Location(
        id: 'b',
        label: 'B',
        proxy: const {
          'type': 'ss',
          'server': 'h.example',
          'port': 443,
          'password': 'p',
          'cipher': 'aes-128-gcm',
        },
      );
      final dns =
          (loadYaml(
                    mihomoTunConfigYaml(
                      noUdp,
                      dns: ['tls://dns.quad9.net#PROXY'],
                    ),
                  )
                  as YamlMap)['dns']
              as YamlMap;
      expect(dns['nameserver'], ['tls://dns.quad9.net#PROXY']);
    });

    test('resolvers are deduplicated and bounded', () {
      final many = [for (var i = 0; i < 40; i++) 'udp://10.0.0.$i'];
      expect(
        (dnsBlock([...many, ...many])['nameserver'] as YamlList),
        hasLength(kMaxNameservers),
        reason:
            'the engine queries them all at once; a long list is cost, '
            'not redundancy',
      );
    });
  });
}
