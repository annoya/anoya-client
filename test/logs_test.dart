import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/app_prefs.dart';
import 'package:vpn_client/core/log.dart';
import 'package:vpn_client/core/log_archive.dart';
import 'package:vpn_client/core/mihomo_tun_config.dart';
import 'package:vpn_client/core/norm_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    Log.enabled = true;
    tmp = Directory.systemTemp.createTempSync('vpn-logs-test');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    // No tunnel in tests: the extension channel is simply not there, which is
    // exactly what the app sees while the VPN is down.
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => throw PlatformException(code: 'tunnel not running'),
    );
  });
  tearDown(() {
    Log.enabled = true;
    Log.clear();
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('vpn/control'), null);
    tmp.deleteSync(recursive: true);
  });

  group('collection switch', () {
    test('off stops recording but keeps what was already collected', () {
      Log.clear();
      Log.i('before');
      expect(Log.dump(), contains('before'));

      Log.enabled = false;
      Log.i('during');
      expect(Log.dump(), contains('before'), reason: 'history is not hidden');
      expect(Log.dump(), isNot(contains('during')));

      Log.enabled = true;
      Log.i('after');
      expect(Log.dump(), contains('after'));
    });

    test('off silences the buffer, never the console', () {
      // debugPrint is where the console output goes in a debug build; the
      // switch is about the files the user sees, not about developing the app.
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = original);

      Log.enabled = false;
      Log.i('to the console only');
      expect(Log.dump(), isNot(contains('to the console only')));
      expect(printed.join('\n'), contains('to the console only'));
    });

    test('the engine is silenced through the rendered config', () {
      final location = Location(
        id: 'l1',
        label: 'DE',
        proxy: {'type': 'vless', 'server': '1.2.3.4', 'port': 443, 'uuid': 'u'},
      );
      // debug, not info: collecting logs is for finding out why something
      // failed, and the engine reports a handshake that never completed only
      // on its verbose channel.
      expect(mihomoTunConfigYaml(location), contains('log-level: debug'));
      expect(mihomoTunConfigYaml(location, collectLogs: false), contains('log-level: silent'));
    });

    test('the preference survives a round trip and defaults to on', () {
      expect(const AppPrefs().collectLogs, true);
      final off = const AppPrefs().copyWith(collectLogs: false);
      expect(AppPrefs.fromJson(off.toJson()).collectLogs, false);
      // A file written before this setting existed must not silence logging.
      expect(AppPrefs.fromJson({'theme_mode': 'dark'}).collectLogs, true);
    });
  });

  group('archive', () {
    test('holds every log, and says why the extension ones are missing', () async {
      Log.clear();
      Log.i('hello from the app');

      final file = await buildLogArchive(now: DateTime(2026, 8, 6, 14, 5, 9));
      addTearDown(() => file.delete());

      expect(file.path, endsWith('vpn-logs-20260806-140509.zip'));
      final entries = ZipDecoder().decodeBytes(await file.readAsBytes());
      expect(entries.files.map((f) => f.name).toSet(), {'app.log', 'tunnel.log', 'mihomo.log'});

      String read(String name) =>
          utf8.decode(entries.files.firstWhere((f) => f.name == name).content as List<int>);
      expect(read('app.log'), contains('hello from the app'));
      // No tunnel running in tests: the entry explains itself instead of being
      // an empty file the user would have to guess about.
      expect(read('tunnel.log'), contains('only while the VPN is connected'));
    });
  });
}
