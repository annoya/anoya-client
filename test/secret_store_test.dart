import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Directory tmp;
  late Directory dir;
  late Map<String, String> keyring;
  late bool keyringUp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-secrets');
    dir = Directory('${tmp.path}/org.anoya');
    keyring = {};
    keyringUp = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (!keyringUp) {
        throw PlatformException(code: 'Libsecret error', message: 'no service');
      }
      final key = call.arguments['key'] as String?;
      return switch (call.method) {
        'read' => keyring[key],
        'write' => keyring[key!] = call.arguments['value'] as String,
        'delete' => keyring.remove(key),
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tmp.deleteSync(recursive: true);
  });

  SecretStore store({bool fileFallback = true}) =>
      SecretStore(fileFallback: fileFallback, directory: () async => dir);

  File file() => File('${dir.path}/${SecretStore.fileName}');

  test(
    'with no keyring a secret goes to a file only this user reads',
    () async {
      final s = store();

      await s.write('token_p1', 't-123');

      expect(await s.read('token_p1'), 't-123');
      expect(s.usingFile.value, isTrue, reason: 'the app says so once');
      expect(jsonDecode(file().readAsStringSync()), {'token_p1': 't-123'});
      expect(file().statSync().mode & 0x1FF, 0x180, reason: 'rw------- (0600)');
      expect(dir.statSync().mode & 0x1FF, 0x1C0, reason: 'rwx------ (0700)');
    },
  );

  test(
    'a keyring that shows up later takes over and the file copy goes',
    () async {
      final s = store();
      await s.write('token_p1', 'old');

      keyringUp = true;
      await s.write('token_p1', 'new');

      expect(keyring['token_p1'], 'new');
      expect(await s.read('token_p1'), 'new');
      expect(file().existsSync(), isFalse, reason: 'no secret left on disk');
    },
  );

  test('a value written without a keyring is still found with one', () async {
    final s = store();
    await s.write('amnezia_install_uuid', 'u-1');

    keyringUp = true;

    expect(await s.read('amnezia_install_uuid'), 'u-1');
  });

  test('delete reaches the file even when the keyring refuses', () async {
    final s = store();
    await s.write('a', '1');
    await s.write('b', '2');

    await s.delete('a');

    expect(await s.read('a'), isNull);
    expect(await s.read('b'), '2');
  });

  test('concurrent writes do not lose each other', () async {
    final s = store();

    await Future.wait([for (var i = 0; i < 10; i++) s.write('k$i', 'v$i')]);

    for (var i = 0; i < 10; i++) {
      expect(await s.read('k$i'), 'v$i');
    }
  });

  test('outside Linux a keyring failure is not hidden', () async {
    final s = store(fileFallback: false);

    await expectLater(
      s.write('token_p1', 't'),
      throwsA(isA<PlatformException>()),
    );
    expect(file().existsSync(), isFalse);
  });
}
