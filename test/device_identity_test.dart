import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/device_identity.dart';

/// What this installation tells a subscription panel about itself. The id has
/// to satisfy the convention panels enforce (10–64 chars, Latin letters,
/// digits, `=` and `-`) and stay put across runs — a new id on every launch
/// would burn a device slot each time the app starts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-device');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => call.method == 'device_info'
          ? {'os': 'iOS', 'version': '18.0', 'model': 'iPhone16,1'}
          : throw PlatformException(code: 'no platform in tests'),
    );
    DeviceIdentityStore.forget();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('vpn/control'), null);
    tmp.deleteSync(recursive: true);
    DeviceIdentityStore.forget();
  });

  test('the id satisfies what panels accept', () async {
    final id = await DeviceIdentityStore.load();
    expect(id.hwid.length, inInclusiveRange(10, 64));
    expect(id.hwid, matches(RegExp(r'^[A-Za-z0-9=-]+$')),
        reason: 'the convention allows only these characters');
  });

  test('the id survives a restart, so a launch does not cost a device slot', () async {
    final first = (await DeviceIdentityStore.load()).hwid;
    DeviceIdentityStore.forget(); // as if the app restarted
    expect((await DeviceIdentityStore.load()).hwid, first);
  });

  test('a damaged stored id is replaced rather than sent as-is', () async {
    File('${tmp.path}/device.json').writeAsStringSync(jsonEncode({'hwid': 'oops!'}));
    final id = await DeviceIdentityStore.load();
    expect(id.hwid, isNot('oops!'));
    expect(id.hwid, matches(RegExp(r'^[A-Za-z0-9=-]+$')));
  });

  test('headers carry the id always and the device detail when known', () async {
    final id = await DeviceIdentityStore.load();
    expect(id.headers['x-hwid'], id.hwid);
    expect(id.headers['x-device-os'], 'iOS');
    expect(id.headers['x-ver-os'], '18.0');
    expect(id.headers['x-device-model'], 'iPhone16,1');
    expect(id.label, 'iPhone16,1 · iOS 18.0');
  });

  test('an unknown device still yields a usable identity', () async {
    // The optional fields are absent rather than guessed: only x-hwid is
    // required, and inventing a model would misname the entry in the panel.
    debugSetDeviceIdentity(
        const DeviceIdentity(hwid: 'abcdef0123', os: '', osVersion: '', model: ''));
    final id = await DeviceIdentityStore.load();
    expect(id.headers.keys, ['x-hwid']);
    expect(id.label, 'This device');
  });
}
