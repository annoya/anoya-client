import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:vpn_client/core/amnezia/secondary_config.dart';
import 'package:vpn_client/core/amnezia/vpn_key.dart';
import 'package:vpn_client/core/mihomo_tun_config.dart';

/// Reading what Amnezia hands out.
///
/// Their format is Qt's, twice over: a `vpn://` key is base64 over a
/// zlib stream behind a four-byte prefix, and the protocol config that comes
/// back from the gateway is that same envelope again, with the real settings
/// as a JSON string nested inside the JSON. The shapes below are the ones a
/// live premium subscription actually returned; the key material is not
/// (nobody's working credentials belong in a test).
void main() {
  /// Builds a key the way Amnezia's encoder does, so the decoder is tested
  /// against the format rather than against one recorded string.
  String vpnKey(Map<String, dynamic> doc, {bool premiumSignature = true}) {
    final body = ZLibCodec().encode(utf8.encode(jsonEncode(doc)));
    final prefix = premiumSignature
        // Their premium encoder overwrites the length with a constant, which
        // is exactly why the reader must not believe it.
        ? [0, 0, 0, 0xff]
        : [0, 0, 0, jsonEncode(doc).length & 0xff];
    final bytes = Uint8List.fromList([...prefix, ...body]);
    return 'vpn://${base64Url.encode(bytes)}';
  }

  Map<String, dynamic> primary({
    String serviceType = 'amnezia-premium',
    String protocol = 'awg',
    int version = 2,
  }) => {
    'name': 'Amnezia Premium',
    'description': 'Amnezia Premium',
    'config_version': version,
    'api_config': {
      'service_type': serviceType,
      'service_protocol': protocol,
      'user_country_code': 'ru',
    },
    'auth_data': {'api_key': 'a-subscription-key'},
  };

  group('the vpn:// key', () {
    test('carries the service, the protocol and the credential', () {
      final key = parseAmneziaVpnKey(vpnKey(primary()));
      expect(key, isNotNull);
      expect(key!.serviceType, 'amnezia-premium');
      expect(key.serviceProtocol, 'awg');
      expect(key.userCountryCode, 'ru');
      expect(key.apiKey, 'a-subscription-key');
    });

    test('survives the mangling a key gets between apps', () {
      // Padding stripped, whitespace inserted by a chat client, no scheme.
      final full = vpnKey(primary());
      final naked = full.substring(6).replaceAll('=', '');
      final wrapped = '${naked.substring(0, 20)}\n${naked.substring(20)}';
      expect(
        parseAmneziaVpnKey('vpn://$wrapped')?.apiKey,
        'a-subscription-key',
      );
    });

    test('a length prefix that lies is still readable', () {
      // The premium encoder's constant prefix is the common case, so a reader
      // that trusted the number would fail on every premium key there is.
      expect(
        parseAmneziaVpnKey(vpnKey(primary(), premiumSignature: false))?.apiKey,
        'a-subscription-key',
      );
      expect(
        parseAmneziaVpnKey(vpnKey(primary()))?.apiKey,
        'a-subscription-key',
      );
    });

    test('the formats this app does not serve are refused, not half-read', () {
      // v1 is the retired gateway format Amnezia's own client rejects; a
      // document with no api_config is a self-hosted server bundle, which is
      // a different domain of this app (ADR-005) and not this one.
      expect(parseAmneziaVpnKey(vpnKey(primary(version: 1))), isNull);
      expect(
        parseAmneziaVpnKey(vpnKey({'name': 'x', 'containers': []})),
        isNull,
      );
      expect(parseAmneziaVpnKey('vless://u@h.example:443#A'), isNull);
      expect(parseAmneziaVpnKey('not a key'), isNull);
    });
  });

  /// The shape a live `/v1/config` answered with for an AWG location, with
  /// the key material replaced. H1–H4 really do arrive as ranges.
  Map<String, dynamic> awgAnswer({
    String privateKey = r'$WIREGUARD_CLIENT_PRIVATE_KEY',
  }) {
    final lastConfig = {
      'H1': '758037244-1346176164',
      'H2': '1833967475-4294967295',
      'H3': '1346176165-1833967474',
      'H4': '5-758037243',
      'Jc': '4',
      'Jmax': '80',
      'Jmin': '10',
      'S1': '58',
      'S2': '234',
      'S3': '292',
      'S4': '5',
      'I1': '<b 0xc30000000108>',
      'Itime': '0',
      'client_ip': '100.98.117.86/32',
      'client_priv_key': privateKey,
      'client_pub_key': 'Y2xpZW50cHVibGljMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
      'config':
          '[Interface]\nAddress = 100.98.117.86/32\nPrivateKey = $privateKey\n',
      'hostName': '135.136.45.186',
      'port': 7328,
      'psk_key': 'cHNrMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
      'server_pub_key': 'c2VydmVycHVibGljMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
      'allowed_ips': ['0.0.0.0/0', '::/0'],
      'persistent_keep_alive': 25,
    };
    final doc = {
      'name': 'Amnezia Premium',
      'config_version': 2,
      'hostName': '135.136.45.186',
      'defaultContainer': 'amnezia-awg',
      'dns1': '100.64.0.1',
      'dns2': '8.8.4.4',
      'containers': [
        {
          'container': 'amnezia-awg',
          'awg': {
            'port': '7328',
            'transport_proto': 'udp',
            'last_config': jsonEncode(lastConfig),
          },
        },
      ],
      'api_config': {
        'service_type': 'amnezia-premium',
        'public_key': {'expires_at': '2026-09-30T12:00:00Z'},
      },
    };
    return {'config': vpnKey(doc)};
  }

  group('an AWG location', () {
    test('becomes a wireguard outbound the engine can run', () {
      final parsed = parseAmneziaSecondaryConfig(
        awgAnswer(),
        label: 'Germany',
        privateKey: 'bXlwcml2YXRla2V5MDAwMDAwMDAwMDAwMDAwMDAwMA=',
      );
      expect(parsed, isNotNull);
      final proxy = parsed!.location.proxy;
      expect(proxy['type'], 'wireguard');
      expect(proxy['server'], '135.136.45.186');
      expect(proxy['port'], 7328);
      expect(
        proxy['private-key'],
        'bXlwcml2YXRla2V5MDAwMDAwMDAwMDAwMDAwMDAwMA=',
      );
      expect(
        proxy['public-key'],
        'c2VydmVycHVibGljMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
      );
      // The mask belongs to the .conf, not to the engine's address field.
      expect(proxy['ip'], '100.98.117.86');
      expect(
        proxy['udp'],
        isTrue,
        reason:
            'WireGuard carries datagrams, and a resolver may be pinned '
            'through it only if we say so',
      );
    });

    test('keeps the obfuscation exactly as issued', () {
      final parsed = parseAmneziaSecondaryConfig(
        awgAnswer(),
        label: 'Germany',
        privateKey: 'k',
      );
      final awg =
          parsed!.location.proxy['amnezia-wg-option'] as Map<String, dynamic>;
      expect(awg['jc'], 4);
      expect(awg['jmin'], 10);
      expect(awg['jmax'], 80);
      expect(awg['s3'], 292);
      expect(awg['s4'], 5);
      // Ranges, not numbers — the AWG 2+ form. Parsing these into ints would
      // silently change which packets the server accepts.
      expect(awg['h1'], '758037244-1346176164');
      expect(awg['h4'], '5-758037243');
      expect(awg['i1'], '<b 0xc30000000108>');
      // Both of the engine's AmneziaWG ports accept this configuration and put
      // it on the wire differently, so the choice cannot be left to whichever
      // one happens to be the default: the current protocol is named outright.
      expect(awg['version'], 3);
      expect(
        awg.containsKey('itime'),
        isFalse,
        reason: 'deprecated, and forwarding it would pin the legacy port',
      );
    });

    test('a v3.1 server is marked as one', () {
      final answer = awgAnswer();
      // Re-issue the same config with the parameters AWG 3.1 adds.
      final decoded = decodeAmneziaEnvelope(answer['config'] as String)!;
      final container = (decoded['containers'] as List).first as Map;
      final awg = (container['awg'] as Map).cast<String, dynamic>();
      final lc =
          jsonDecode(awg['last_config'] as String) as Map<String, dynamic>;
      lc['HeaderProtectionKey'] = 'aGVhZGVyLXByb3RlY3Rpb24ta2V5';
      lc['DisableCookies'] = 'true';
      awg['last_config'] = jsonEncode(lc);
      container['awg'] = awg;

      final parsed = parseAmneziaSecondaryConfig(
        {'config': vpnKey(decoded)},
        label: 'Germany',
        privateKey: 'k',
      );
      final opts =
          parsed!.location.proxy['amnezia-wg-option'] as Map<String, dynamic>;
      expect(opts['version'], 3);
      expect(opts['header-protection-key'], 'aGVhZGVyLXByb3RlY3Rpb24ta2V5');
      expect(opts['disable-cookies'], 'true');
    });

    test('a config we hold no private key for is refused, not run', () {
      // The placeholder surviving means the substitution never happened. Run
      // as-is it would fail a handshake with nothing to explain why.
      expect(
        parseAmneziaSecondaryConfig(
          awgAnswer(),
          label: 'Germany',
          privateKey: '',
        ),
        isNull,
      );
    });

    test('the resolvers it came with are carried, not invented', () {
      final parsed = parseAmneziaSecondaryConfig(
        awgAnswer(),
        label: 'Germany',
        privateKey: 'k',
      );
      expect(parsed!.dns, ['100.64.0.1', '8.8.4.4']);
      expect(parsed.expiresAt, DateTime.utc(2026, 9, 30, 12));
    });

    test('reaches the engine as YAML mihomo accepts', () {
      final parsed = parseAmneziaSecondaryConfig(
        awgAnswer(),
        label: 'Germany',
        privateKey: 'bXlwcml2YXRla2V5MDAwMDAwMDAwMDAwMDAwMDAwMA=',
      );
      final doc =
          loadYaml(mihomoTunConfigYaml(parsed!.location, dns: parsed.dns))
              as YamlMap;
      final proxy = (doc['proxies'] as YamlList).first as YamlMap;
      expect(proxy['type'], 'wireguard');
      expect((proxy['amnezia-wg-option'] as YamlMap)['jc'], 4);
      expect(
        (proxy['amnezia-wg-option'] as YamlMap)['h1'],
        '758037244-1346176164',
      );
    });
  });

  test(
    'a VLESS location goes through the Xray reader this app already has',
    () {
      // Amnezia ships an ordinary Xray document; an Amnezia VLESS server and a
      // panel's VLESS server differ in provenance, not in what they are.
      final xrayConfig = {
        'log': {'loglevel': 'error'},
        'inbounds': [
          {'listen': '127.0.0.1', 'port': 10808, 'protocol': 'socks'},
        ],
        'outbounds': [
          {
            'protocol': 'vless',
            'tag': 'proxy',
            'settings': {
              'vnext': [
                {
                  'address': '135.136.45.186',
                  'port': 443,
                  'users': [
                    {
                      'id': '0304f78c-2c15-4441-9bac-3897297dddcf',
                      'encryption': 'none',
                      'flow': 'xtls-rprx-vision',
                    },
                  ],
                },
              ],
            },
            'streamSettings': {
              'network': 'tcp',
              'security': 'reality',
              'realitySettings': {
                'fingerprint': 'firefox',
                'publicKey': 'U6-myBaEyMsYQ2pBu-VoJiX1AcS2v7VmdEdhqo-KtG4',
                'shortId': '',
                'serverName': '',
              },
            },
          },
          {'tag': 'dns-out', 'protocol': 'dns'},
        ],
      };
      final doc = {
        'name': 'Amnezia Premium',
        'config_version': 2,
        'hostName': '135.136.45.186',
        'defaultContainer': 'amnezia-xray',
        'dns1': '100.64.0.1',
        'containers': [
          {
            'container': 'amnezia-xray',
            'xray': {'port': '443', 'last_config': jsonEncode(xrayConfig)},
          },
        ],
      };
      final parsed = parseAmneziaSecondaryConfig(
        {'config': vpnKey(doc)},
        label: 'Germany',
        privateKey: '',
      );
      expect(parsed, isNotNull);
      expect(parsed!.location.proxy['type'], 'vless');
      expect(parsed.location.proxy['server'], '135.136.45.186');
      expect(parsed.dns, ['100.64.0.1']);
    },
  );

  test('nothing the user reads names a company behind the subscription', () {
    // The key format and the gateway are not Amnezia's alone: other providers
    // sell the same `vpn://` key, carrying their own name and a service type
    // of their own, through the same gateway. "Renew it with Amnezia" on one
    // of those subscriptions is not a rough edge — it is a false statement
    // about who holds the user's money. The name we do show comes from the
    // key itself, so it is right for whoever issued it.
    final offenders = <String>[];
    for (final path in [
      'lib/core/amnezia/amnezia_errors.dart',
      'lib/core/amnezia/amnezia_source.dart',
      'lib/core/amnezia/vpn_key.dart',
      'lib/features/config/amnezia_config_screen.dart',
    ]) {
      for (final line in File(path).readAsLinesSync()) {
        // Quoted text only, and not the protocol's own name: AmneziaWG is what
        // the thing is called, whoever is selling it.
        // …and neither does it invent one. SPEC-CLIENT §5: everything a
        // subscription supplies is attributed to the subscription, because
        // there is no account behind it to attribute it to.
        final quoted = RegExp(
          r"'[^']*(Amnezia|provider)[^']*'",
        ).allMatches(line);
        for (final m in quoted) {
          final text = m.group(0)!;
          if (text.contains('AmneziaWG')) continue;
          offenders.add('$path: $text');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
