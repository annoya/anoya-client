import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:anoya/core/device_identity.dart';
import 'package:anoya/core/parsers/provider_routing.dart';
import 'package:anoya/core/subscription_fetch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('xray routing', () {
    const live = '''
{
  "outbounds": [{"tag": "proxy", "protocol": "vless"}],
  "routing": {
    "rules": [
      {"type": "field", "inboundTag": ["dns-in"], "outboundTag": "dns-out"},
      {"type": "field", "domain": ["domain:doubleclick.net", "domain:googleadservices.com",
        "domain:googlesyndication.com"], "outboundTag": "block"},
      {"type": "field", "domain": ["domain:ip.me"], "outboundTag": "proxy"},
      {"type": "field", "outboundTag": "direct"}
    ]
  }
}''';

    test('translates the rules a panel actually sends', () {
      final r = parseXrayRouting(live)!;
      expect(r.skipped, 0);
      expect(r.routing.rules.length, 4);
      expect(r.routing.rules.map((e) => '${e.action} ${e.type} ${e.value}'), [
        'block domain-suffix doubleclick.net',
        'block domain-suffix googleadservices.com',
        'block domain-suffix googlesyndication.com',
        'proxy domain-suffix ip.me',
      ]);
    });

    test('a catch-all direct is a split tunnel', () {
      expect(parseXrayRouting(live)!.routing.mode, 'split');
    });

    test('no catch-all is read as full tunnel', () {
      final body = live.replaceAll(
        '{"type": "field", "outboundTag": "direct"}',
        '',
      );
      expect(
        parseXrayRouting(body.replaceAll(',\n      \n', '\n'))!.routing.mode,
        'full',
        reason: 'the safer reading keeps traffic inside the tunnel',
      );
    });

    test('rules about inbounds and ports are not counted as lost', () {
      expect(parseXrayRouting(live)!.skipped, 0);
    });

    test('a regular expression is translated, an external file is not', () {
      const body = '''
{"routing": {"rules": [
  {"type": "field", "domain": ["regexp:.*[.]ad[.].*"], "outboundTag": "block"},
  {"type": "field", "ip": ["ext:cn.dat:cn"], "outboundTag": "direct"},
  {"type": "field", "domain": ["domain:example.com"], "outboundTag": "block"}
]}}''';
      final r = parseXrayRouting(body)!;
      expect(r.skipped, 1);
      expect(r.routing.rules.map((e) => '${e.type} ${e.value}'), [
        'domain-regex .*[.]ad[.].*',
        'domain-suffix example.com',
      ]);
    });

    test('a pattern the rule syntax cannot carry is refused', () {
      const body = r'''
{"routing": {"rules": [
  {"type": "field", "domain": ["regexp:^a{1,3}[.]example$"], "outboundTag": "block"}
]}}''';
      expect(parseXrayRouting(body), isNull);
    });

    test('a bare IP becomes a /32, a bare domain a keyword', () {
      const body = '''
{"routing": {"rules": [
  {"type": "field", "ip": ["1.2.3.4"], "outboundTag": "direct"},
  {"type": "field", "domain": ["ads"], "outboundTag": "block"},
  {"type": "field", "ip": ["geoip:cn"], "outboundTag": "direct"}
]}}''';
      final r = parseXrayRouting(body)!;
      expect(r.routing.rules.map((e) => '${e.type} ${e.value}'), [
        'ip-cidr 1.2.3.4/32',
        'domain-keyword ads',
        'geoip cn',
      ]);
    });

    test(
      'a body with no routing yields nothing rather than an empty policy',
      () {
        expect(parseXrayRouting('{"outbounds": []}'), isNull);
        expect(parseXrayRouting('not json'), isNull);
        expect(parseXrayRouting('{"routing": {"rules": []}}'), isNull);
      },
    );
  });

  group('happ routing header', () {
    test('reads the six lists and the direction', () {
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'GlobalProxy': false,
            'ProxySites': ['ip.me'],
            'BlockSites': ['ads.example'],
            'DirectIp': ['10.0.0.0/8'],
          }),
        ),
      );
      final r = parseHappRouting('happ://routing/add/$payload')!;
      expect(r.routing.mode, 'split');
      expect(r.routing.rules.map((e) => '${e.action} ${e.type} ${e.value}'), [
        'proxy domain-keyword ip.me',
        'direct ip-cidr 10.0.0.0/8',
        'block domain-keyword ads.example',
      ]);
    });

    test('a direction with no exceptions is not shown as a policy', () {
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'GlobalProxy': true})),
      );
      expect(
        parseHappRouting('happ://routing/add/$payload'),
        isNull,
        reason: 'everything through the VPN is what we do anyway',
      );
    });
  });

  group('clash rules', () {
    test('transcribes what our engine already speaks', () {
      final r = parseClashRules([
        'DOMAIN-SUFFIX,ads.example,REJECT',
        'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
        'GEOSITE,category-ads,REJECT',
        'RULE-SET,something,PROXY',
        'MATCH,DIRECT',
      ])!;
      expect(r.routing.mode, 'split');
      expect(r.skipped, 1, reason: 'RULE-SET has no equivalent here');
      expect(r.routing.rules.length, 3);
      expect(r.routing.rules[1].noResolve, isTrue);
    });

    test(
      "a provider's process rules survive to the platform that can run them",
      () {
        final r = parseClashRules(const [
          'PROCESS-NAME,EscapeFromTarkov.exe,DIRECT',
          'DOMAIN-SUFFIX,ip.me,PROXY',
          'MATCH,DIRECT',
        ])!;
        expect(r.routing.rules.map((x) => x.type), [
          'process-name',
          'domain-suffix',
        ]);
        expect(r.routing.rules.first.value, 'EscapeFromTarkov.exe');
        expect(
          r.skipped,
          0,
          reason: 'nothing was skipped, so nothing is counted',
        );
      },
    );

    test('a rules list that is only MATCH says nothing', () {
      expect(parseClashRules(['MATCH,→ Provider']), isNull);
    });
  });

  group('clash rule lists', () {
    const body = '''
rule-providers:
  reject:
    type: http
    behavior: domain
    format: yaml
    url: "https://lists.example/reject.yaml"
    interval: 86400
  local-file:
    type: file
    behavior: domain
    path: ./local.yaml
  ads-extra:
    type: http
    behavior: classical
    url: "http://lists.example/insecure.yaml"
proxies: []
rules:
  - RULE-SET,reject,REJECT
  - RULE-SET,local-file,DIRECT
  - RULE-SET,ads-extra,REJECT
  - RULE-SET,never-defined,REJECT
  - DOMAIN-SUFFIX,ip.me,PROXY
  - MATCH,DIRECT
''';

    test('a remote list becomes a rule plus its definition', () {
      final r = parseClashRouting(body)!;
      expect(r.routing.rules.map((e) => '${e.type} ${e.value}'), [
        'rule-list reject',
        'domain-suffix ip.me',
      ]);
      expect(r.routing.lists.single.name, 'reject');
      expect(r.routing.lists.single.behavior, 'domain');
    });

    test('lists we cannot fetch are dropped and counted', () {
      expect(parseClashRouting(body)!.skipped, 3);
    });

    test('a policy that is only unusable list rules is no policy', () {
      const onlyLists = '''
rules:
  - RULE-SET,undefined,REJECT
  - MATCH,DIRECT
''';
      expect(parseClashRouting(onlyLists), isNull);
    });
  });

  group('fetching it', () {
    late Directory tmp;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vpn-provrouting');
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path,
      );
      DeviceIdentityStore.debugCache(
        const DeviceIdentity(
          hwid: 'aaaabbbbccccdddd',
          os: 'iOS',
          osVersion: '18.0',
          model: 'iPhone16,1',
        ),
      );
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      tmp.deleteSync(recursive: true);
      DeviceIdentityStore.debugCache(null);
    });

    test('the panel is asked for its json rendering by name', () async {
      final asked = <String>[];
      final client = MockClient((req) async {
        asked.add(req.url.path);
        if (req.url.path.endsWith('/json')) {
          return http.Response(
            '{"routing":{"rules":[{"domain":["domain:ip.me"],"outboundTag":"proxy"}]}}',
            200,
          );
        }
        return http.Response('vless://x', 200);
      });
      final res = await fetchSubscription(
        'https://sub.example/tok3n',
        probeRenderings: false,
        client: client,
      );
      expect(asked, [
        '/tok3n',
        '/tok3n/json',
      ], reason: 'asking for a format by name beats impersonating another app');
      expect(res.routing!.routing.rules.single.value, 'ip.me');
      expect(res.routingProbed, isTrue);
    });

    test(
      'a url that already names a rendering is not asked to render again',
      () async {
        final asked = <String>[];
        final client = MockClient((req) async {
          asked.add(req.url.path);
          return http.Response('{"routing":{"rules":[]}}', 200);
        });
        await fetchSubscription(
          'https://sub.example/tok3n/mihomo',
          probeRenderings: false,
          client: client,
        );
        expect(asked, ['/tok3n/mihomo']);
      },
    );

    test('the header is read without a second request', () async {
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'GlobalProxy': true,
            'BlockSites': ['ads.example'],
          }),
        ),
      );
      final asked = <String>[];
      final client = MockClient((req) async {
        asked.add(req.url.path);
        return http.Response(
          'vless://x',
          200,
          headers: {'routing': 'happ://routing/add/$payload'},
        );
      });
      final res = await fetchSubscription(
        'https://sub.example/tok3n',
        probeRenderings: false,
        client: client,
      );
      expect(asked, ['/tok3n']);
      expect(res.routing!.routing.rules.single.value, 'ads.example');
    });

    test('a probe that fails leaves the subscription working', () async {
      final client = MockClient(
        (req) async => req.url.path.endsWith('/json')
            ? http.Response('nope', 500)
            : http.Response('vless://x', 200),
      );
      final res = await fetchSubscription(
        'https://sub.example/tok3n',
        probeRenderings: false,
        client: client,
      );
      expect(res.body, 'vless://x');
      expect(res.routing, isNull);
      expect(
        res.routingProbed,
        isTrue,
        reason: 'do not repeat it every five minutes',
      );
    });

    test(
      'probing can be turned off for a source already known to have none',
      () async {
        final asked = <String>[];
        final client = MockClient((req) async {
          asked.add(req.url.path);
          return http.Response('vless://x', 200);
        });
        final res = await fetchSubscription(
          'https://sub.example/tok3n',
          probeRenderings: false,
          client: client,
          probeRouting: false,
        );
        expect(asked, ['/tok3n']);
        expect(res.routingProbed, isFalse);
      },
    );
  });
}
