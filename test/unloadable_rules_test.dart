import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/effective_config.dart';
import 'package:anoya/core/geo_store.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/parsers/subscription.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/rule_set.dart';

import 'routing_simple_test.dart' show geoSiteList;

const _body = r'''
proxies:
  - {name: NL, type: vless, server: nl.example, port: 443, uuid: u}
proxy-groups:
  - {name: Proxy, type: select, proxies: [NL]}
rules:
  - GEOSITE,youtube,Proxy
  - GEOSITE,elsewhere,Proxy
  - AND,((GEOSITE,elsewhere),(NETWORK,UDP)),REJECT
  - IP-ASN,13335,Proxy
  - MATCH,Proxy
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channels = [
    MethodChannel('plugins.flutter.io/path_provider'),
    MethodChannel('vpn/control'),
  ];
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-unloadable-rules');
    for (final c in channels) {
      messenger.setMockMethodCallHandler(c, (call) async => tmp.path);
    }
    File('${tmp.path}/${GeoStore.geoipFile}').writeAsBytesSync([1, 2, 3]);
    File(
      '${tmp.path}/${GeoStore.geositeFile}',
    ).writeAsBytesSync(geoSiteList({'YOUTUBE': 2}));
  });

  tearDown(() {
    for (final c in channels) {
      messenger.setMockMethodCallHandler(c, null);
    }
    tmp.deleteSync(recursive: true);
  });

  test(
    'a geosite category the database lacks is left out of a rule set',
    () async {
      await RuleSetStore.save([
        const RuleSet(id: RuleSet.defaultId, name: 'Default'),
        const RuleSet(
          id: 'work',
          name: 'Work',
          mode: RoutingMode.split,
          rules: [
            RoutingRule(
              type: 'geosite',
              values: ['youtube', 'elsewhere'],
              action: 'proxy',
            ),
            RoutingRule(
              type: 'geosite',
              values: ['elsewhere'],
              action: 'block',
            ),
          ],
        ),
      ]);

      final config = await buildNormConfig(
        Profile(
          id: 'p',
          type: ProfileType.subscription,
          name: 'Nexus',
          locations: const [],
          routingEnabled: true,
          ruleSetId: 'work',
        ),
      );

      final geosite = config.routing!.rules.where((r) => r.type == 'geosite');
      expect(geosite.map((r) => r.values), [
        ['youtube'],
      ]);
    },
  );

  test('subscription rules the engine cannot load never reach it', () async {
    final parsed = parseSubscriptionBody(_body);
    expect(parsed.plan!.skipped, 1, reason: 'no ASN database is shipped');

    final config = await buildNormConfig(
      Profile(
        id: 'p',
        type: ProfileType.subscription,
        name: 'Nexus',
        locations: parsed.locations,
        plan: parsed.plan,
        subscriptionRules: true,
      ),
    );

    expect(config.plan!.rules.map((r) => '${r.type},${r.payload}'), [
      'GEOSITE,youtube',
      'MATCH,',
    ]);
  });
}
