import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/json_file_store.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/profile_store.dart';

/// The persistence contract every store now rides on: damage costs the user
/// as little as possible. A corrupted file yields the fallback instead of a
/// crash, one damaged entry never discards its siblings, and a save leaves no
/// half-written file behind for the next load to trip over.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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
        const MethodChannel('plugins.flutter.io/path_provider'), null);
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
        '{"id":"c","type":"link","name":"Also good","locations":[]}]');
    final profiles = await ProfileStore.load();
    expect(profiles.map((p) => p.id), ['a', 'c']);
  });

  test('save is temp+rename: the target is whole json or absent, never partial', () async {
    final store = JsonFileStore('atomic.json');
    await store.save({'v': 1});
    await store.save({'v': 2});
    expect(File('${tmp.path}/atomic.json.tmp').existsSync(), isFalse,
        reason: 'the temp file must not outlive the rename');
    expect(await store.load((j) => (j as Map)['v'], 0), 2);
  });

  test('round trip through the shared store', () async {
    final p = Profile(
        id: 'x', type: ProfileType.link, name: 'One', locations: const []);
    await ProfileStore.save([p]);
    final back = await ProfileStore.load();
    expect(back.single.id, 'x');
    expect(back.single.type, ProfileType.link);
  });
}
