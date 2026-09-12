import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vpn_client/core/app_error.dart';
import 'package:vpn_client/core/device_identity.dart';
import 'package:vpn_client/core/subscription_fetch.dart';

/// What a panel says about this device, and what the user is told about it.
///
/// A device limit turns a working subscription into one that silently stops
/// refreshing. Without reading these headers the app can only say "couldn't
/// refresh", which sends the user to check their URL — the one thing that is
/// not wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-subfetch');
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

  http.Client answering(
    String body, {
    int status = 200,
    Map<String, String> headers = const {},
  }) => MockClient((_) async => http.Response(body, status, headers: headers));

  test('every subscription request identifies this device', () async {
    late Map<String, String> sent;
    final client = MockClient((req) async {
      sent = req.headers;
      return http.Response('vless://x', 200);
    });
    await fetchSubscription(
      'https://panel.example/sub/abc',
      probeRenderings: false,
      client: client,
    );
    expect(sent['x-hwid'], 'aaaabbbbccccdddd');
    expect(sent['x-device-os'], 'iOS');
    expect(sent['x-ver-os'], '18.0');
    expect(sent['x-device-model'], 'iPhone16,1');
  });

  test(
    'a refusal is reported, and what the panel sent instead is kept',
    () async {
      // The panel answers a refused device with entries whose names carry its
      // message. Throwing here would discard exactly what the user needs to read,
      // so the refusal is a flag and the body travels on.
      final client = answering(
        'vless://x@0.0.0.0:1#Device%20limit%20reached',
        headers: {'x-hwid-max-devices-reached': 'true'},
      );
      final res = await fetchSubscription(
        'https://panel.example/sub/abc',
        probeRenderings: false,
        client: client,
      );
      expect(res.deviceLimitReached, isTrue);
      expect(
        res.body,
        contains('0.0.0.0'),
        reason: 'the placeholder is the message',
      );
      expect(
        res.deviceLimitActive,
        isTrue,
        reason: 'a panel that refuses a device is one that counts devices',
      );
    },
  );

  test('the older header name for the same condition is honoured', () async {
    final res = await fetchSubscription(
      'https://panel.example/sub/abc',
      probeRenderings: false,
      client: answering('vless://x', headers: {'x-hwid-limit': 'true'}),
    );
    expect(res.deviceLimitReached, isTrue);
  });

  test('the refusal reads the same wherever it is shown', () {
    expect(kDeviceLimitReached.title, 'Device limit reached');
    expect(kDeviceLimitReached.detail, contains('Free a slot'));
  });

  test(
    'a panel that counts devices is remembered, so the app can say so',
    () async {
      final client = answering('vless://x', headers: {'x-hwid-active': 'true'});
      final res = await fetchSubscription(
        'https://panel.example/sub/abc',
        probeRenderings: false,
        client: client,
      );
      expect(res.deviceLimitActive, isTrue);
      expect(res.body, 'vless://x');
    },
  );

  test('a panel that says nothing about devices claims no limit', () async {
    final res = await fetchSubscription(
      'https://panel.example/sub/abc',
      probeRenderings: false,
      client: answering('vless://x'),
    );
    expect(res.deviceLimitActive, isFalse);
  });

  test('the subscription secret never travels in an error', () async {
    final client = answering('nope', status: 500);
    try {
      await fetchSubscription(
        'https://panel.example/sub/s3cr3t-token',
        probeRenderings: false,
        client: client,
      );
      fail('a 500 must throw');
    } catch (e) {
      expect('$e', isNot(contains('s3cr3t-token')));
      expect('$e', contains('panel.example'));
    }
  });
}
