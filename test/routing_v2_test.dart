import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/parsers/subscription.dart';
import 'package:anoya/core/routing_prefs.dart';
import 'package:anoya/core/rule_set.dart';

Location _loc() => Location(
  id: 'l1',
  label: 'Test',
  proxy: {
    'type': 'vless',
    'server': '1.2.3.4',
    'port': 443,
    'uuid': 'u',
    'network': 'tcp',
    'udp': true,
    'tls': true,
    'servername': 's.example.com',
    'client-fingerprint': 'chrome',
    'reality-opts': {'public-key': 'PK', 'short-id': 'sid'},
  },
);

void main() {
  test('geoip rule renders GEOIP with country upcased and no-resolve', () {
    final yaml = mihomoTunConfigYaml(
      _loc(),
      routing: const Routing(
        mode: 'full',
        rules: [
          RoutingRule(
            type: 'geoip',
            value: 'ru',
            action: 'direct',
            noResolve: true,
          ),
        ],
      ),
    );
    expect(yaml, contains('  - GEOIP,RU,DIRECT,no-resolve'));
    expect(yaml, contains('geodata-mode: false'));
    expect(yaml, contains('geo-auto-update: false'));
  });

  test('geosite rule renders GEOSITE; no geodata keys without geo rules', () {
    final withGeo = mihomoTunConfigYaml(
      _loc(),
      routing: const Routing(
        mode: 'full',
        rules: [
          RoutingRule(type: 'geosite', value: 'netflix', action: 'direct'),
        ],
      ),
    );
    expect(withGeo, contains('  - GEOSITE,netflix,DIRECT'));

    final without = mihomoTunConfigYaml(
      _loc(),
      routing: const Routing(
        mode: 'full',
        rules: [
          RoutingRule(type: 'domain-suffix', value: 'a.com', action: 'proxy'),
        ],
      ),
    );
    expect(without, isNot(contains('geodata-mode')));
  });

  test('invalid geo values are skipped, never interpolated', () {
    final yaml = mihomoTunConfigYaml(
      _loc(),
      routing: const Routing(
        mode: 'full',
        rules: [
          RoutingRule(type: 'geoip', value: 'rus', action: 'direct'),
          RoutingRule(type: 'geosite', value: 'Net flix', action: 'direct'),
        ],
      ),
    );
    expect(yaml, isNot(contains('GEOIP')));
    expect(yaml, isNot(contains('GEOSITE')));
  });

  test('LAN direct rules render as IP-CIDR direct with no-resolve', () {
    final yaml = mihomoTunConfigYaml(
      _loc(),
      routing: Routing(mode: 'full', rules: kLanDirectRules),
    );
    expect(yaml, contains('  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve'));
    expect(yaml, contains('  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve'));
    expect(
      yaml.indexOf('IP-CIDR,10.0.0.0/8'),
      lessThan(yaml.indexOf('MATCH,PROXY')),
    );
  });

  test('RuleSet json round-trip and toRouting', () {
    const set = RuleSet(
      id: 'work',
      name: 'Work',
      mode: RoutingMode.split,
      rules: [
        RoutingRule(
          type: 'geoip',
          value: 'ru',
          action: 'direct',
          noResolve: true,
        ),
        RoutingRule(
          type: 'domain-suffix',
          value: 'corp.example.com',
          action: 'proxy',
        ),
      ],
    );
    final restored = RuleSet.fromJson(set.toJson());
    expect(restored.name, 'Work');
    expect(restored.mode, RoutingMode.split);
    expect(restored.rules.length, 2);
    expect(restored.rules.first.noResolve, true);
    expect(restored.toRouting().mode, 'split');
    expect(set.rules.any((r) => r.needsGeoData), true);
  });

  group('detectInput', () {
    test('share link → link with label', () {
      final d = detectInput('vless://uuid@1.2.3.4:443?type=tcp#Tokyo');
      expect(d!.kind, InputKind.link);
      expect(d.label, contains('Tokyo'));
    });

    test('https URL → subscriptionUrl', () {
      final d = detectInput('https://sub.example.com/s/abc');
      expect(d!.kind, InputKind.subscriptionUrl);
      expect(d.label, contains('sub.example.com'));
    });

    test('raw multi-server text → subscriptionText with count', () {
      const text =
          'vless://u1@1.2.3.4:443?type=tcp#A\nvless://u2@5.6.7.8:443?type=tcp#B';
      final d = detectInput(text);
      expect(d!.kind, InputKind.subscriptionText);
    });

    test('garbage → null', () {
      expect(detectInput('hello world'), isNull);
      expect(detectInput(''), isNull);
    });
  });

  group('whyUnusable', () {
    test('a scheme we have no protocol for', () {
      expect(
        whyUnusable('tuic://a:b@h.example:443'),
        'tuic:// isn’t supported',
      );
    });

    test(
      'a link of ours that will not parse, even with a stray word after it',
      () {
        expect(
          whyUnusable('vless://asdasd123 1212312'),
          'vless:// link can’t be read',
        );
        expect(
          whyUnusable('vless://asdasd123 1212312'),
          isNot(contains('asdasd')),
        );
      },
    );

    test('a transport the engine cannot run is named as the transport', () {
      expect(
        whyUnusable('vless://u@h.example:443?type=kcp'),
        'vless over kcp isn’t supported',
      );
    });

    test('a plugin already names its protocol', () {
      expect(
        whyUnusable('ss://YWVzLTI1Ni1nY206cHc@h.example:8388?plugin=kcptun'),
        'ss+kcptun isn’t supported',
      );
    });

    test('vpn:// that is not a subscription key', () {
      expect(whyUnusable('vpn://nonsense'), 'Not a subscription key');
    });

    test('everything else, and nothing for an empty field', () {
      expect(whyUnusable('hello world'), 'Not a link or subscription');
      expect(whyUnusable('https://'), 'Not a link or subscription');
      expect(whyUnusable('   '), isNull);
    });
  });
}
