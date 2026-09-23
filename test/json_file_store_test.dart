import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/json_file_store.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-store');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    tmp.deleteSync(recursive: true);
  });

  test('a truncated file yields the fallback, not a crash', () async {
    File('${tmp.path}/broken.json').writeAsStringSync('{"half": ');
    final store = JsonFileStore('broken.json');
    expect(await store.load((j) => j as Map, {'ok': true}), {'ok': true});
  });

  test('one damaged entry never discards the rest of the list', () async {
    File('${tmp.path}/profiles.json').writeAsStringSync(
      '[{"id":"a","type":"link","name":"Good","locations":[]},'
      '{"id":"b","type":"unknown-type","name":"Bad"},'
      '{"id":"c","type":"link","name":"Also good","locations":[]}]',
    );
    final profiles = await ProfileStore.load();
    expect(profiles.map((p) => p.id), ['a', 'c']);
  });

  test(
    'save is temp+rename: the target is whole json or absent, never partial',
    () async {
      final store = JsonFileStore('atomic.json');
      await store.save({'v': 1});
      await store.save({'v': 2});
      expect(
        tmp.listSync().where((e) => e.path.endsWith('.tmp')),
        isEmpty,
        reason: 'the scratch file must not outlive the rename',
      );
      expect(await store.load((j) => (j as Map)['v'], 0), 2);
    },
  );

  test('concurrent saves never corrupt the file or throw', () async {
    final store = JsonFileStore('race.json');
    final big = {'v': List.filled(20000, 'xxxxxxxxxxxxxxxxxxxx')};
    final small = {'v': 'small'};
    for (var i = 0; i < 10; i++) {
      await Future.wait([store.save(big), store.save(small)]);
      final back = await store.load<Map?>((j) => j as Map, null);
      expect(back, isNotNull, reason: 'round $i left an unparseable file');
    }
    expect(
      tmp.listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
      reason: 'no scratch file may outlive its write',
    );
  });

  test('a save that fails does not poison the next one', () async {
    final store = JsonFileStore('chain.json');
    await expectLater(
      store.save(Object()),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
    await store.save({'v': 1});
    expect(await store.load((j) => (j as Map)['v'], 0), 1);
  });

  test(
    'what the panel said about device counting survives a restart',
    () async {
      final p = Profile(
        id: 's',
        type: ProfileType.subscription,
        name: 'Sub',
        locations: const [],
        subscriptionUrl: 'https://panel.example/sub/abc',
        deviceLimitActive: true,
      );
      await ProfileStore.save([p]);
      expect((await ProfileStore.load()).single.deviceLimitActive, isTrue);
    },
  );

  test('round trip through the shared store', () async {
    final p = Profile(
      id: 'x',
      type: ProfileType.link,
      name: 'One',
      locations: const [],
    );
    await ProfileStore.save([p]);
    final back = await ProfileStore.load();
    expect(back.single.id, 'x');
    expect(back.single.type, ProfileType.link);
  });
}
