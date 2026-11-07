import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/parsers/subscription.dart';
import 'package:anoya/core/profile_import.dart';
import 'package:anoya/core/app_error.dart';

const _priv = 'cGVlci1wcml2YXRlLWtleS0zMi1ieXRlcy1sb25nISE=';
const _pub = 'c2VydmVyLXB1YmxpYy1rZXktMzItYnl0ZXMtbG9uZyE=';
const _psk = 'cHNrMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=';

String conf({
  String extraInterface = '',
  String allowed = '0.0.0.0/0, ::/0',
  String endpoint = 'wg.example:51820',
}) =>
    '''
[Interface]
PrivateKey = $_priv
Address = 10.8.0.2/24, fd42:42:42::2/64
DNS = 1.1.1.1, 2606:4700:4700::1111, corp.lan
$extraInterface
# wg-easy writes this line
[Peer]
PublicKey = $_pub
PresharedKey = $_psk
AllowedIPs = $allowed
PersistentKeepalive = 25
Endpoint = $endpoint
''';

void main() {
  group('a WireGuard .conf', () {
    test('becomes one wireguard server with the interface and peer', () {
      final parsed = parseSubscriptionBody(conf());
      expect(parsed.format, SubscriptionFormat.wireguard);
      expect(parsed.locations, hasLength(1));
      final loc = parsed.locations.single;
      expect(loc.label, 'wg.example:51820');
      expect(loc.description, 'WireGuard');
      expect(loc.proxy, {
        'type': 'wireguard',
        'server': 'wg.example',
        'port': 51820,
        'private-key': _priv,
        'public-key': _pub,
        'pre-shared-key': _psk,
        'ip': '10.8.0.2',
        'ipv6': 'fd42:42:42::2',
        'persistent-keepalive': 25,
        'udp': true,
      });
    });

    test('its resolvers ride the tunnel and search domains are dropped', () {
      expect(parseSubscriptionBody(conf()).dns, [
        '1.1.1.1#$kTunnelOutbound',
        '2606:4700:4700::1111#$kTunnelOutbound',
      ]);
    });

    test('a full-tunnel AllowedIPs leaves routing to the device', () {
      expect(parseSubscriptionBody(conf()).routing, isNull);
    });

    test('a narrower AllowedIPs is the config routing: split', () {
      final routing = parseSubscriptionBody(
        conf(allowed: '10.0.0.0/8, 192.168.1.1'),
      ).routing!;
      expect(routing.mode, 'split');
      expect(routing.rules.single.type, 'ip-cidr');
      expect(routing.rules.single.action, 'proxy');
      expect(routing.rules.single.values, ['10.0.0.0/8', '192.168.1.1/32']);
    });

    test('an IPv6 endpoint keeps its port', () {
      final loc = parseSubscriptionBody(
        conf(endpoint: '[2001:db8::7]:443'),
      ).locations.single;
      expect(loc.proxy['server'], '2001:db8::7');
      expect(loc.proxy['port'], 443);
    });

    test('without a key, endpoint or address nothing is half-read', () {
      for (final broken in [
        conf().replaceFirst('PrivateKey = $_priv', 'PrivateKey = short'),
        conf().replaceFirst(RegExp(r'Endpoint = .*'), ''),
        conf().replaceFirst(RegExp(r'Address = .*'), ''),
      ]) {
        final parsed = parseSubscriptionBody(broken);
        expect(parsed.locations, isEmpty);
        expect(parsed.format, SubscriptionFormat.wireguard);
        expect(detectInput(broken), isNull);
        expect(whyUnusable(broken), contains('WireGuard'));
      }
    });

    test('a broken one is refused with its own reason', () async {
      await expectLater(
        importText(conf(endpoint: 'nope')),
        throwsA(
          isA<SubscriptionFormatException>().having(
            (e) => e.error.title,
            'title',
            contains('WireGuard'),
          ),
        ),
      );
    });

    test('the add screen and a wg-easy QR recognise it as a server', () {
      final d = detectInput(conf());
      expect(d!.kind, InputKind.link);
      expect(d.label, contains('WireGuard'));
      expect(d.label, contains('wg.example'));
    });

    test('importing it adds a single-server configuration', () async {
      final p = await importText(conf(allowed: '10.0.0.0/8'), name: 'wg0.conf');
      expect(p.name, 'wg0.conf');
      expect(p.locations.single.proxyType, 'wireguard');
      expect(p.dns, hasLength(2));
      expect(p.providerRouting?.mode, 'split');
    });
  });

  group('an AmneziaWG .conf', () {
    const awg = '''
Jc = 4
Jmin = 10
Jmax = 50
S1 = 58
S2 = 234
H1 = 758037244-1346176164
H2 = 1833967475-4294967295
H3 = 1346176165-1833967474
H4 = 5-758037243
I1 = <b 0xc30000000108><r 16>
''';

    test('carries its obfuscation into amnezia-wg-option', () {
      final loc = parseSubscriptionBody(
        conf(extraInterface: awg),
      ).locations.single;
      expect(loc.description, 'AmneziaWG');
      expect(loc.proxy['amnezia-wg-option'], {
        'jc': 4,
        'jmin': 10,
        'jmax': 50,
        's1': 58,
        's2': 234,
        'h1': '758037244-1346176164',
        'h2': '1833967475-4294967295',
        'h3': '1346176165-1833967474',
        'h4': '5-758037243',
        'i1': '<b 0xc30000000108><r 16>',
        'version': 3,
      });
    });

    test('runs at the Amnezia MTU unless the config names one', () {
      expect(
        parseSubscriptionBody(
          conf(extraInterface: awg),
        ).locations.single.proxy['mtu'],
        1376,
      );
      expect(
        parseSubscriptionBody(
          conf(extraInterface: '${awg}MTU = 1280'),
        ).locations.single.proxy['mtu'],
        1280,
      );
      expect(
        parseSubscriptionBody(conf()).locations.single.proxy['mtu'],
        isNull,
      );
    });

    test('renders as a wireguard outbound the engine can run', () {
      final loc = parseSubscriptionBody(
        conf(extraInterface: awg),
      ).locations.single;
      final doc = loadYaml(mihomoTunConfigYaml(loc)) as YamlMap;
      final proxy = (doc['proxies'] as YamlList).first as YamlMap;
      expect(proxy['type'], 'wireguard');
      expect(proxy['private-key'], _priv);
      expect((proxy['amnezia-wg-option'] as YamlMap)['i1'], startsWith('<b'));
    });
  });
}
