import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/profile_store.dart';
import 'package:anoya/core/secret_store.dart';

import 'support/memory_secrets.dart';

void main() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-secure-profiles');
    messenger.setMockMethodCallHandler(pathProvider, (_) async => tmp.path);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(pathProvider, null);
    tmp.deleteSync(recursive: true);
  });

  Profile server() => Profile(
    id: 'p1',
    type: ProfileType.link,
    name: 'Office',
    locations: [
      Location(
        id: 'l1',
        label: 'Frankfurt',
        proxy: const {
          'type': 'vless',
          'server': 'vpn.example.com',
          'port': 443,
          'uuid': 'secret-uuid',
        },
      ),
    ],
  );

  test(
    'a configuration lives in the keychain and never touches the disk',
    () async {
      await ProfileStore.save([server()]);

      expect(memorySecrets['profiles'], contains('secret-uuid'));
      expect(
        tmp
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.readAsStringSync().contains('secret-uuid')),
        isEmpty,
      );
      expect(
        (await ProfileStore.load()).single.locations.single.label,
        'Frankfurt',
      );
    },
  );

  test('a keychain that could not be read is never saved over', () async {
    memorySecrets['profiles'] = jsonEncode([server().toJson()]);
    var writes = 0;
    messenger.setMockMethodCallHandler(secureStorageChannel, (call) async {
      if (call.method == 'read') {
        throw PlatformException(code: '-25308', message: 'locked');
      }
      if (call.method == 'write') writes++;
      return memorySecretsHandler(call);
    });

    expect(await ProfileStore.load(), isEmpty);
    await expectLater(ProfileStore.save([]), throwsStateError);
    expect(writes, 0);
    expect(memorySecrets['profiles'], contains('secret-uuid'));
  });

  test(
    'a write over an item the keychain will not update replaces it',
    () async {
      var refused = false;
      messenger.setMockMethodCallHandler(secureStorageChannel, (call) async {
        if (call.method == 'write' && !refused) {
          refused = true;
          throw PlatformException(code: '-25299', message: 'duplicate item');
        }
        return memorySecretsHandler(call);
      });

      await SecretStore().write('token_p1', 'fresh');
      expect(memorySecrets['token_p1'], 'fresh');
    },
  );
}
