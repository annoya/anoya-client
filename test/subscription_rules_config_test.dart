import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/effective_config.dart';
import 'package:anoya/core/parsers/subscription.dart';
import 'package:anoya/core/profile.dart';

const _body = r'''
proxies:
  - {name: NL, type: vless, server: nl.example, port: 443, uuid: u, dialer-proxy: WL}
  - {name: LTE, type: vless, server: lte.example, port: 443, uuid: u}
proxy-groups:
  - {name: Proxy, type: select, proxies: [NL]}
  - {name: WL, type: select, proxies: [LTE]}
rule-providers:
  ads: {type: inline, behavior: domain, payload: ['ads.example']}
rules:
  - RULE-SET,ads,REJECT
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
    tmp = Directory.systemTemp.createTempSync('vpn-subscription-rules');
    for (final c in channels) {
      messenger.setMockMethodCallHandler(c, (call) async => tmp.path);
    }
  });

  tearDown(() {
    for (final c in channels) {
      messenger.setMockMethodCallHandler(c, null);
    }
    tmp.deleteSync(recursive: true);
  });

  test('chains and inline lists reach the config the engine gets', () async {
    final parsed = parseSubscriptionBody(_body);
    final plan = parsed.plan!;
    expect(plan.dialers, isNotEmpty);
    expect(plan.inline, isNotEmpty);

    final config = await buildNormConfig(
      Profile(
        id: 'p',
        type: ProfileType.subscription,
        name: 'Nexus',
        locations: parsed.locations,
        plan: plan,
        subscriptionRules: true,
      ),
    );

    expect(config.plan!.dialers, plan.dialers);
    expect(config.plan!.inline.map((l) => l.name), ['ads']);
  });
}
