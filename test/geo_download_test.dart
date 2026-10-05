import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/geo_store.dart';
import 'package:anoya/core/routing_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;
  late ServerSocket server;

  setUp(() async {
    HttpOverrides.global = null;
    GeoStore.stallTimeout = const Duration(seconds: 1);
    tmp = Directory.systemTemp.createTempSync('vpn-geo');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => call.method == 'shared_dir' ? tmp.path : null,
    );
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((sock) {
      sock.listen((_) {});
      sock.write('HTTP/1.1 200 OK\r\nContent-Length: 1048576\r\n\r\n');
      sock.add(List.filled(1024, 1));
    });
    final url = 'http://127.0.0.1:${server.port}/geo';
    await RoutingPrefsStore.save(
      const RoutingPrefs().copyWith(geoipUrl: url, geositeUrl: url),
    );
  });

  tearDown(() async {
    await server.close();
    for (final c in [
      const MethodChannel('plugins.flutter.io/path_provider'),
      const MethodChannel('vpn/control'),
    ]) {
      messenger.setMockMethodCallHandler(c, null);
    }
    tmp.deleteSync(recursive: true);
  });

  test('a stalled download names the stall, not a closed file', () async {
    Object? error;
    try {
      await GeoStore.download();
    } catch (e) {
      error = e;
    }

    expect(
      error,
      isA<TimeoutException>(),
      reason: '"File closed" sent the report looking at the disk',
    );
    expect(File('${tmp.path}/${GeoStore.geoipFile}.tmp').existsSync(), isFalse);
    expect(File('${tmp.path}/${GeoStore.geoipFile}').existsSync(), isFalse);
  });
}
