import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:anoya/core/app_prefs.dart';
import 'package:anoya/core/log.dart';
import 'package:anoya/core/log_archive.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    Log.enabled = true;
    tmp = Directory.systemTemp.createTempSync('vpn-logs-test');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => throw PlatformException(code: 'tunnel not running'),
    );
  });
  tearDown(() {
    Log.enabled = true;
    Log.clear();
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      null,
    );
    tmp.deleteSync(recursive: true);
  });

  group('what a shared log gives away', () {
    test('a failed fetch names the host, never the subscription token', () {
      Log.clear();
      final e = http.ClientException(
        'Connection refused',
        Uri.parse('https://panel.example:8443/sub/SECRETTOKEN?flag=1'),
      );
      Log.e('profile poll failed', '$e');
      Log.i('GET https://panel.example/api/client/config (auth)');
      final dump = Log.dump();
      expect(dump, isNot(contains('SECRETTOKEN')));
      expect(dump, contains('https://panel.example:8443/…'));
      expect(dump, contains('GET https://panel.example/…'));
    });

    test('a share link keeps its host and loses its credential', () {
      expect(
        Log.redact('bad link vless://d1f8b2c4-aaaa@de.example:443?pbk=K#DE'),
        'bad link vless://de.example:443/…',
      );
      expect(Log.redact('key vpn://AAAAbase64payload'), 'key vpn://…');
      expect(
        Log.redact('at https://[2001:db8::1]/x'),
        'at https://[2001:db8::1]/…',
      );
      expect(
        Log.redact('see https://host.example'),
        'see https://host.example',
      );
    });

    test('a parse error keeps its reason and drops the quoted body', () {
      Log.clear();
      Object? error;
      try {
        loadYaml('proxies:\n  - uuid: SECRETUUID\n    port: [');
      } catch (e) {
        error = e;
      }
      Log.e('clash yaml parse failed', '$error');
      try {
        jsonDecode('{"password": "SECRETPASS", oops}');
      } catch (e) {
        error = e;
      }
      Log.e('xray json parse failed', '$error');
      final dump = Log.dump();
      expect(dump, contains('clash yaml parse failed: '));
      expect(dump, contains('xray json parse failed: FormatException'));
      expect(dump, isNot(contains('SECRETUUID')));
      expect(dump, isNot(contains('SECRETPASS')));
    });
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
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          printed.add(message ?? '');
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
      expect(mihomoTunConfigYaml(location), contains('log-level: debug'));
      expect(
        mihomoTunConfigYaml(location, collectLogs: false),
        contains('log-level: silent'),
      );
    });

    test('the preference survives a round trip and defaults to on', () {
      expect(const AppPrefs().collectLogs, true);
      final off = const AppPrefs().copyWith(collectLogs: false);
      expect(AppPrefs.fromJson(off.toJson()).collectLogs, false);
      expect(AppPrefs.fromJson({'theme_mode': 'dark'}).collectLogs, true);
    });
  });

  group('archive', () {
    test('is written even after the system emptied the caches', () async {
      final gone = '${tmp.path}/Caches/org.annoya.test';
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => gone,
      );

      final file = await buildLogArchive(now: DateTime(2026, 10, 3, 12, 31, 6));

      expect(file.existsSync(), isTrue, reason: 'macOS purges Caches at will');
      expect(file.parent.path, gone);
    });

    test(
      'holds every log, and says why the extension ones are missing',
      () async {
        Log.clear();
        Log.i('hello from the app');

        final file = await buildLogArchive(now: DateTime(2026, 8, 6, 14, 5, 9));
        addTearDown(() => file.delete());

        expect(file.path, endsWith('vpn-logs-20260806-140509.zip'));
        final entries = ZipDecoder().decodeBytes(await file.readAsBytes());
        expect(entries.files.map((f) => f.name).toSet(), {
          'app.log',
          'tunnel.log',
          'mihomo.log',
        });

        String read(String name) => utf8.decode(
          entries.files.firstWhere((f) => f.name == name).content as List<int>,
        );
        expect(read('app.log'), contains('hello from the app'));
        expect(
          read('tunnel.log'),
          contains('only while the tunnel is running'),
        );
      },
    );
  });
}
