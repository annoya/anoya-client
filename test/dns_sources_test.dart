import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:vpn_client/core/dns_plan.dart';
import 'package:vpn_client/core/mihomo_tun_config.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/parsers/subscription.dart';

/// Where a configuration's resolvers come from, per format.
///
/// Every format says two things about a resolver: where it is, and whether the
/// query is issued locally or sent out through the proxy. The second one is the
/// reason a provider writes a DNS block at all, and it is spelled differently
/// in each format — a `detour` tag in sing-box, a `+local` scheme in Xray, a
/// `#pin` in Clash. These pin the translation into the single form the engine
/// reads.
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
      (loadYaml(mihomoTunConfigYaml(loc(), dns: dns)) as YamlMap)['dns'] as YamlMap;

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
      expect(subscriptionDns(body), [
        'tls://dns.quad9.net#PROXY',
        'udp://77.88.8.8',
        // No detour is sing-box's own default, and its default is direct.
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
      // The two mechanisms are dropped: inside the extension "local" is the
      // tunnel's own DNS setting, so asking it loops straight back to us.
      expect(subscriptionDns(body), ['https://dns.quad9.net:443/dns-query#PROXY']);
    });
  });

  group('xray', () {
    test('+local is issued here, anything else goes out through the tunnel', () {
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
      expect(subscriptionDns(body), [
        'https://dns.quad9.net/dns-query#PROXY',
        'https://dns.google/dns-query',
        // The object form carries the same address plus filters we cannot
        // express; the address is the part that survives.
        '8.8.8.8#PROXY',
      ]);
    });
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
    expect(subscriptionDns(body),
        ['https://dns.quad9.net/dns-query#PROXY', 'tls://77.88.8.8']);
  });

  test('a link list has nowhere to put a resolver', () {
    expect(subscriptionDns('vless://u@h.example:443?security=none#A'), isEmpty);
  });

  test('HTTP/3 is a transport, not a protocol the engine has a scheme for', () {
    // mihomo spells the choice `prefer-h3` and rejects the scheme outright —
    // and rejecting it costs the whole config, not the entry.
    const body = '''
{"dns": {"servers": [{"tag": "r", "address": "h3://dns.google/dns-query"}]},
 "outbounds": [{"type": "vless", "tag": "v", "server": "h.example", "server_port": 443, "uuid": "u"}]}''';
    expect(subscriptionDns(body), ['https://dns.google/dns-query']);
  });

  group('what the renderer will still refuse', () {
    test('a scheme the engine rejects never reaches the config', () {
      // Clash entries are passed through as written, so this is the last stop.
      // The engine answers an unknown scheme by failing the parse: the tunnel
      // would not start at all, for one line in someone else's dns block.
      final dns = dnsBlock(['h3://dns.google/dns-query', 'tls://9.9.9.9']);
      expect(dns['nameserver'], ['tls://9.9.9.9']);
    });

    test('a resolver the tunnel cannot carry is replaced, not left to fail', () {
      // mihomo answers a datagram dial through a UDP-less outbound with an
      // error on every attempt, so keeping the pin would mean no DNS at all.
      // Unpinning it instead would put every domain on the local network in
      // clear text — so the entry goes and the encrypted fallback stands in.
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
      final dns = (loadYaml(mihomoTunConfigYaml(noUdp,
          dns: ['1.1.1.1#PROXY'])) as YamlMap)['dns'] as YamlMap;
      expect(dns['nameserver'], ['https://1.1.1.1/dns-query']);
      // Reaching the proxy itself is a TCP dial, so the resolver is still fine
      // for that job.
      expect(dns['proxy-server-nameserver'], ['1.1.1.1']);
    });

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
      final dns = (loadYaml(mihomoTunConfigYaml(noUdp,
          dns: ['tls://dns.quad9.net#PROXY'])) as YamlMap)['dns'] as YamlMap;
      expect(dns['nameserver'], ['tls://dns.quad9.net#PROXY']);
    });

    test('resolvers are deduplicated and bounded', () {
      final many = [for (var i = 0; i < 40; i++) 'udp://10.0.0.$i'];
      expect((dnsBlock([...many, ...many])['nameserver'] as YamlList),
          hasLength(kMaxNameservers),
          reason: 'the engine queries them all at once; a long list is cost, '
              'not redundancy');
    });
  });
}
