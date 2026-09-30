import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/state/profiles_controller.dart';

void main() {
  String premiumKey() {
    final doc = {
      'name': 'Premium',
      'config_version': 2,
      'api_config': {
        'service_type': 'amnezia-premium',
        'service_protocol': 'awg',
        'user_country_code': 'ru',
      },
      'auth_data': {'api_key': 'a-subscription-key'},
    };
    final body = ZLibCodec().encode(utf8.encode(jsonEncode(doc)));
    return 'vpn://${base64Url.encode(Uint8List.fromList([0, 0, 0, 0xff, ...body]))}';
  }

  test(
    'a key saved to a file is imported as a key, not read as a server list',
    () async {
      final c = ProviderContainer(
        overrides: [profilesControllerProvider.overrideWith(_KeyRecorder.new)],
      );
      addTearDown(c.dispose);
      final ctrl = c.read(profilesControllerProvider.notifier) as _KeyRecorder;

      await ctrl.addFromText('${premiumKey()}\r\n', name: 'premium_key.vpn');

      expect(ctrl.keys, hasLength(1));
    },
  );
}

class _KeyRecorder extends ProfilesController {
  final keys = <String>[];

  @override
  ProfilesState build() => const ProfilesState(profiles: []);

  @override
  Future<void> addAmneziaKey(String text) async => keys.add(text);
}
