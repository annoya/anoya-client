import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vpn_client/core/device_identity.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/subscription_fetch.dart';
import 'package:vpn_client/core/subscription_info.dart';

/// The three headers a panel uses to stay reachable: where to ask when its main
/// address is blocked, how long to wait for it, and how often to bother.
///
/// All three are the provider's statements about their own service, so the app
/// honours them — within bounds it sets itself, because each one is also a way
/// for a panel to make the app do work on its behalf.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-resilience');
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

  group('the backup address', () {
    test(
      'is used when the main one does not answer, and is reported',
      () async {
        final asked = <String>[];
        final client = MockClient((req) async {
          asked.add(req.url.host);
          if (req.url.host == 'main.example') {
            throw const SocketException('blocked');
          }
          return http.Response('vless://u@h.example:443?security=none#DE', 200);
        });
        final res = await fetchSubscription(
          'https://main.example/tok3n',
          probeRenderings: false,
          client: client,
          probeRouting: false,
          fallbackUrl: 'https://backup.example/tok3n',
        );
        expect(asked, ['main.example', 'backup.example']);
        expect(res.body, contains('vless://'));
        expect(
          res.usedFallback,
          isTrue,
          reason:
              'a provider whose main address is dead should not look untouched',
        );
      },
    );

    test('is not tried when the main address answers', () async {
      final asked = <String>[];
      final client = MockClient((req) async {
        asked.add(req.url.host);
        return http.Response('vless://u@h.example:443?security=none#DE', 200);
      });
      final res = await fetchSubscription(
        'https://main.example/tok3n',
        probeRenderings: false,
        client: client,
        probeRouting: false,
        fallbackUrl: 'https://backup.example/t',
      );
      expect(asked, ['main.example']);
      expect(res.usedFallback, isFalse);
    });

    test('a failure on both is the failure of the main one', () async {
      // What the user can act on is the address they added; the backup is the
      // provider's business.
      final client = MockClient((req) async => http.Response('nope', 500));
      try {
        await fetchSubscription(
          'https://main.example/s3cr3t',
          probeRenderings: false,
          client: client,
          fallbackUrl: 'https://backup.example/s3cr3t',
        );
        fail('both failing must throw');
      } catch (e) {
        expect('$e', contains('main.example'));
        expect('$e', isNot(contains('s3cr3t')));
      }
    });

    test('only an https backup is honoured', () async {
      // The address decides which servers the app trusts.
      final asked = <String>[];
      final client = MockClient((req) async {
        asked.add(req.url.host);
        throw const SocketException('blocked');
      });
      await expectLater(
        fetchSubscription(
          'https://main.example/t',
          probeRenderings: false,
          client: client,
          fallbackUrl: 'http://backup.example/t',
        ),
        throwsA(anything),
      );
      expect(asked, ['main.example']);
    });

    test('the header is read as one, and rejected when it is not https', () {
      expect(
        SubscriptionInfo.fromHeaders({
          'fallback-url': 'https://backup.example/t',
        }).fallbackUrl,
        'https://backup.example/t',
      );
      expect(
        SubscriptionInfo.fromHeaders({
          'fallback-url': 'http://backup.example/t',
        }).fallbackUrl,
        isEmpty,
      );
    });
  });

  group('the request timeout', () {
    test('the panel\'s number is honoured inside the window we allow', () async {
      // A panel asking for a minute would hold a manual refresh — and the user
      // watching it — open for that long.
      final client = MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return http.Response('vless://u@h.example:443?security=none#DE', 200);
      });
      final res = await fetchSubscription(
        'https://main.example/t',
        probeRenderings: false,
        client: client,
        probeRouting: false,
        timeout: const Duration(seconds: 5),
      );
      expect(res.body, contains('vless://'));
    });

    test('a header out of range is clamped, not obeyed', () {
      expect(
        SubscriptionInfo.fromHeaders({
          'subscription-request-timeout': '9',
        }).requestTimeout,
        9,
      );
      // The clamp itself lives in the fetch; what the parser must not do is
      // invent a value the panel never sent.
      expect(SubscriptionInfo.fromHeaders({}).requestTimeout, isNull);
    });
  });

  group('the update cadence', () {
    Profile sub({int? hours, DateTime? refreshedAt, int? chosen}) => Profile(
      id: 'p1',
      type: ProfileType.subscription,
      name: 'S',
      locations: const [],
      subscriptionUrl: 'https://main.example/t',
      providerInfo: SubscriptionInfo.fromHeaders(
        hours == null ? {} : {'profile-update-interval': '$hours'},
      ),
      refreshedAt: refreshedAt,
      refreshHours: chosen,
    );

    test('the header is hours, which is the convention\'s unit', () {
      // It was read as days before: a panel asking for 12 hours was shown as
      // "every 12 days" and polled 144 times inside each of those hours.
      expect(refreshGapFor(sub(hours: 12)), const Duration(hours: 12));
      expect(refreshGapFor(sub(hours: 1)), const Duration(hours: 1));
    });

    test('a source that asks for nothing is read hourly, not at the floor', () {
      // The floor is what a source may ask *down to*, never what silence
      // means. Read as a schedule it fetched the whole list every five
      // minutes — 288 times a day, off someone else's server.
      expect(refreshGapFor(sub()), const Duration(hours: 1));
      // A zero in the header is that same silence, spelled out. It used to
      // clamp to the floor, which made the least meaningful answer a panel can
      // give the most expensive one to receive.
      expect(refreshGapFor(sub(hours: 0)), const Duration(hours: 1));
    });

    test('a key subscription is polled in hours, and actually polled', () {
      // Its gateway has no interval field to answer in, so it takes the
      // default like any other silent source. The screen says "auto every
      // 1 h"; both halves of that have to be true.
      final key = Profile(
        id: 'a1',
        type: ProfileType.amnezia,
        name: 'Subscription',
        locations: const [],
        refreshedAt: DateTime.now(),
      );
      expect(refreshGapFor(key), const Duration(hours: 1));
      // The poll skipped this domain entirely, so the line above the gear was
      // a promise nothing kept.
      expect(key.isRefreshable, isTrue);
      // The gear still wins: it is the user's battery.
      expect(
        refreshGapFor(key.copyWith(refreshHours: (value: 3))),
        const Duration(hours: 3),
      );
    });

    test('a source is left alone until its own interval is up', () {
      final now = DateTime.now();
      final p = sub(
        hours: 12,
        refreshedAt: now.subtract(const Duration(hours: 2)),
      );
      expect(isDueForRefresh(p, now: now), isFalse);
      expect(
        isDueForRefresh(
          sub(hours: 12, refreshedAt: now.subtract(const Duration(hours: 13))),
          now: now,
        ),
        isTrue,
      );
    });

    test('one never refreshed is always due', () {
      expect(isDueForRefresh(sub(hours: 12)), isTrue);
    });

    group('when the user has set a period', () {
      test('theirs wins over the panel’s request', () {
        // The panel asks; the traffic and the battery are not its own to spend.
        expect(
          refreshGapFor(sub(hours: 12, chosen: 1)),
          const Duration(hours: 1),
        );
      });

      test('clearing it hands the choice back to the panel', () {
        expect(refreshGapFor(sub(hours: 12)), const Duration(hours: 12));
      });

      test('it survives storage, and "unset" is not zero', () {
        final restored = Profile.fromJson(sub(hours: 12, chosen: 6).toJson());
        expect(restored.refreshHours, 6);
        expect(Profile.fromJson(sub(hours: 12).toJson()).refreshHours, isNull);
      });
    });
  });

  group('asking for a rendering that carries groups', () {
    const clash = '''
proxies:
  - {name: A, type: vless, server: a.example, port: 443, uuid: u}
proxy-groups:
  - {name: Fastest, type: url-test, proxies: [A]}
''';

    test('a body with no groups makes the app ask by name', () async {
      final asked = <String>[];
      final client = MockClient((req) async {
        asked.add(req.url.path);
        if (req.url.path.endsWith('/mihomo')) return http.Response(clash, 200);
        return http.Response('vless://u@h.example:443?security=none#DE', 200);
      });
      final res = await fetchSubscription(
        'https://sub.example/tok3n',
        client: client,
        probeRouting: false,
      );
      expect(asked, ['/tok3n', '/tok3n/mihomo']);
      expect(res.rendering, 'mihomo');
      expect(res.body, contains('proxy-groups'));
      expect(res.renderingProbed, isTrue);
    });

    test('a body that already has groups is not second-guessed', () async {
      final asked = <String>[];
      final client = MockClient((req) async {
        asked.add(req.url.path);
        return http.Response(clash, 200);
      });
      final res = await fetchSubscription(
        'https://sub.example/tok3n',
        client: client,
        probeRouting: false,
      );
      expect(asked, ['/tok3n']);
      expect(
        res.rendering,
        isEmpty,
        reason: 'the panel already sent what we need',
      );
    });

    test(
      'a panel with no such rendering costs three requests and keeps its body',
      () async {
        final asked = <String>[];
        final client = MockClient((req) async {
          asked.add(req.url.path);
          if (req.url.pathSegments.length > 1) {
            return http.Response('Not Found', 404);
          }
          return http.Response('vless://u@h.example:443?security=none#DE', 200);
        });
        final res = await fetchSubscription(
          'https://sub.example/tok3n',
          client: client,
          probeRouting: false,
        );
        expect(asked, [
          '/tok3n',
          '/tok3n/mihomo',
          '/tok3n/clash-meta',
          '/tok3n/clash',
        ]);
        expect(
          res.body,
          contains('vless://'),
          reason: 'the plain body is kept',
        );
        expect(res.rendering, isEmpty);
      },
    );

    group('what the next refresh asks for', () {
      // Only the positive outcome is worth remembering. "Nothing answered" used
      // to be remembered just as firmly, and one 404 during a bad minute pinned
      // a subscription to its plain body for good — for a panel like Remnawave
      // that body is a base64 link list, so the policy fell through to the Xray
      // probe and arrived as a fraction of itself, with no way back from the
      // interface.
      test('a rendering that answered is gone to directly', () {
        expect(shouldProbeRenderings('mihomo'), isFalse);
      });

      test('nothing having answered is not a final answer', () {
        expect(shouldProbeRenderings(''), isTrue);
      });
    });

    test(
      'a known rendering is asked for directly, and falls back when it dies',
      () async {
        final asked = <String>[];
        final client = MockClient((req) async {
          asked.add(req.url.path);
          if (req.url.path.endsWith('/mihomo')) {
            return http.Response('gone', 500);
          }
          return http.Response('vless://u@h.example:443?security=none#DE', 200);
        });
        final res = await fetchSubscription(
          'https://sub.example/tok3n',
          client: client,
          probeRouting: false,
          rendering: 'mihomo',
          probeRenderings: false,
        );
        expect(asked, ['/tok3n/mihomo', '/tok3n']);
        expect(
          res.body,
          contains('vless://'),
          reason: 'the address the user added is the answer of record',
        );
      },
    );
  });
}
