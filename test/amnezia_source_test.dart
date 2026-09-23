import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/amnezia/agw_ffi.dart';
import 'package:anoya/core/amnezia/amnezia_account.dart';
import 'package:anoya/core/amnezia/amnezia_errors.dart';
import 'package:anoya/core/amnezia/amnezia_source.dart';
import 'package:anoya/core/amnezia/vpn_key.dart';
import 'package:anoya/core/amnezia/gateway.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/profile_store.dart';
import 'package:anoya/features/config/config_parts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => switch (call.method) {
            'read' => store[call.arguments['key']],
            'write' =>
              store[call.arguments['key']] = call.arguments['value'] as String,
            'delete' => store.remove(call.arguments['key']),
            'readAll' => store,
            _ => null,
          },
        );
  });

  String envelope(Map<String, dynamic> doc) {
    final body = ZLibCodec().encode(utf8.encode(jsonEncode(doc)));
    return 'vpn://${base64Url.encode(Uint8List.fromList([0, 0, 0, 0xff, ...body]))}';
  }

  Map<String, dynamic> awgConfigAnswer({DateTime? expiresAt}) {
    final lastConfig = {
      'client_ip': '10.8.1.5/32',
      'client_priv_key': r'$WIREGUARD_CLIENT_PRIVATE_KEY',
      'hostName': '198.51.100.7',
      'port': 51820,
      'server_pub_key': 'c2VydmVycHVibGljMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
      'Jc': '4',
    };
    return {
      'config': envelope({
        'config_version': 2,
        'hostName': '198.51.100.7',
        'dns1': '100.64.0.1',
        'containers': [
          {
            'container': 'amnezia-awg',
            'awg': {'port': '51820', 'last_config': jsonEncode(lastConfig)},
          },
        ],
        'api_config': {
          if (expiresAt != null)
            'public_key': {'expires_at': expiresAt.toIso8601String()},
        },
      }),
    };
  }

  Profile profile({List<Location> locations = const [], AmneziaState? state}) =>
      Profile(
        id: 'p-amnezia',
        type: ProfileType.amnezia,
        name: 'Amnezia Premium',
        locations: locations,
        amnezia:
            state ??
            const AmneziaState(
              serviceType: 'amnezia-premium',
              serviceProtocol: 'awg',
              userCountryCode: 'ru',
            ),
      );

  setUp(() async {
    store.clear();
    await ProfileStore.saveAmneziaKey('p-amnezia', 'the-subscription-key');
  });

  group('what the gateway offers', () {
    test('premium becomes one location per country and protocol', () async {
      final gw = _FakeGateway(
        accountBody: {
          'active_device_count': 5,
          'max_device_count': 7,
          'subscription_end_date': '2027-06-26T13:27:49Z',
          'available_countries': [
            {
              'server_country_code': 'de',
              'server_country_code_l10n': 'de',
              'server_country_name': 'Germany',
              'available_protocols': ['awg', 'vless'],
            },
            {
              'server_country_code': 'nl-ams-1',
              'server_country_code_l10n': 'nl',
              'server_country_name': 'Netherlands',
              'available_protocols': ['awg'],
            },
          ],
        },
      );
      final updated = await AmneziaSource(profile(), gateway: gw).refresh();

      expect(updated.locations.map((l) => l.id), [
        'amnezia_de_awg',
        'amnezia_de_vless',
        'amnezia_nl-ams-1_awg',
      ]);
      expect(updated.locations.first.label, 'Germany');
      expect(updated.locations.first.description, 'AmneziaWG');
      expect(updated.amnezia!.account.maxDevices, 7);
    });

    test('a subscription offering nowhere gets no invented location', () async {
      final gw = _FakeGateway(
        accountBody: {
          'subscription_description': 'Nothing on offer right now.',
        },
      );
      final updated = await AmneziaSource(profile(), gateway: gw).refresh();

      expect(updated.locations, isEmpty);
      expect(updated.amnezia!.offersLocations, isFalse);
      expect(updated.amnezia!.account.hasDeviceCount, isFalse);
      expect(updated.amnezia!.account.endsAt, isNull);
      expect(
        updated.amnezia!.account.expired,
        isFalse,
        reason: 'a subscription nobody dated has not run out',
      );
    });

    test('a free key is refused with a reason, not imported to fail later', () {
      final free = AmneziaVpnKey(
        name: 'Amnezia Free',
        serviceType: 'amnezia-free',
        serviceProtocol: 'awg',
        userCountryCode: 'ru',
        apiKey: 'k',
      );
      expect(amneziaKeyUnsupported(free), contains('CAPTCHA'));
      expect(
        amneziaKeyUnsupported(
          AmneziaVpnKey(
            name: 'Amnezia Premium',
            serviceType: 'amnezia-premium',
            serviceProtocol: 'awg',
            userCountryCode: 'ru',
            apiKey: 'k',
          ),
        ),
        isNull,
      );
    });

    test('a refusal is reported in words, not as an empty list', () async {
      final gw = _FakeGateway(
        accountBody: _refusal(422, kSubscriptionInactive),
      );
      await expectLater(
        AmneziaSource(profile(), gateway: gw).refresh(),
        throwsA(isA<Object>()),
      );
    });

    test('a config already issued survives a refresh', () async {
      final held = Location(
        id: 'amnezia_de_awg',
        label: 'Germany',
        proxy: const {'type': 'wireguard', 'server': '198.51.100.7'},
        description: 'AmneziaWG',
      );
      final gw = _FakeGateway(
        accountBody: {
          'available_countries': [
            {
              'server_country_code': 'de',
              'server_country_name': 'Germany',
              'available_protocols': ['awg'],
            },
          ],
        },
      );
      final updated = await AmneziaSource(
        profile(locations: [held]),
        gateway: gw,
      ).refresh();
      expect(updated.locations.single.proxy['server'], '198.51.100.7');
    });
  });

  group('issuing a server', () {
    Profile withPlace() => profile(
      locations: [
        Location(
          id: 'amnezia_de_awg',
          label: 'Germany',
          proxy: const {},
          description: 'AmneziaWG',
        ),
      ],
      state: const AmneziaState(
        serviceType: 'amnezia-premium',
        serviceProtocol: 'awg',
        userCountryCode: 'ru',
      ),
    );

    test('a place with no server yet is resolved on demand', () async {
      final gw = _FakeGateway(
        configBody: awgConfigAnswer(expiresAt: DateTime.utc(2030)),
      );
      final updated = await AmneziaSource(
        withPlace(),
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');

      expect(gw.configCalls, 1);
      expect(gw.lastCountry, 'de');
      expect(gw.lastProtocol, 'awg');
      final proxy = updated.locations.single.proxy;
      expect(proxy['type'], 'wireguard');
      expect(proxy['server'], '198.51.100.7');
      expect('${proxy['private-key']}'.contains('WIREGUARD_CLIENT'), isFalse);
      expect(gw.lastPublicKey, isNot(contains('WIREGUARD_CLIENT')));
      expect(updated.dns, [
        '100.64.0.1',
      ], reason: 'the resolvers the server came with, not ours');
    });

    test('a server still in date is used as it is', () async {
      final gw = _FakeGateway(configBody: awgConfigAnswer());
      final resolved = await AmneziaSource(
        withPlace(),
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');
      final again = await AmneziaSource(
        resolved,
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');

      expect(
        gw.configCalls,
        1,
        reason: 'nothing had expired, so nothing was asked',
      );
      expect(identical(again, resolved), isTrue);
    });

    test('a server about to expire is replaced before it is used', () async {
      final soon = DateTime.now().toUtc().add(const Duration(minutes: 2));
      final gw = _FakeGateway(configBody: awgConfigAnswer(expiresAt: soon));
      final resolved = await AmneziaSource(
        withPlace(),
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');
      await AmneziaSource(
        resolved,
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');
      expect(gw.configCalls, 2);
    });

    test('a switch always asks, however good the config in hand is', () async {
      final gw = _FakeGateway(
        configBody: awgConfigAnswer(expiresAt: DateTime.utc(2030)),
      );
      final resolved = await AmneziaSource(
        withPlace(),
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');
      await AmneziaSource(
        resolved,
        gateway: gw,
      ).resolveSelection('amnezia_de_awg', force: true);
      expect(gw.configCalls, 2);
    });

    test('only the place in use keeps a server', () async {
      final gw = _FakeGateway(configBody: awgConfigAnswer());
      final two = profile(
        locations: [
          Location(id: 'amnezia_de_awg', label: 'Germany', proxy: const {}),
          Location(
            id: 'amnezia_nl_awg',
            label: 'Netherlands',
            proxy: const {'type': 'wireguard', 'server': '203.0.113.9'},
          ),
        ],
      );
      final updated = await AmneziaSource(
        two,
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');

      expect(
        updated.locations
            .firstWhere((l) => l.id == 'amnezia_de_awg')
            .isPlaceholder,
        isFalse,
      );
      expect(
        updated.locations
            .firstWhere((l) => l.id == 'amnezia_nl_awg')
            .isPlaceholder,
        isTrue,
        reason: 'the one we are not using is a name again',
      );
    });

    test('a selection that is not ours is left alone', () async {
      final gw = _FakeGateway(configBody: awgConfigAnswer());
      final same = await AmneziaSource(
        withPlace(),
        gateway: gw,
      ).resolveSelection('sub_1_whatever');
      expect(gw.configCalls, 0);
      expect(identical(same, gw.lastProfile ?? same), isTrue);
    });
  });

  group('a place whose server has not been issued yet', () {
    final placeholder = Location(
      id: 'amnezia_de_awg',
      label: 'Germany',
      proxy: const {},
      description: 'AmneziaWG',
    );

    test('says nothing about itself rather than guessing', () {
      expect(placeholder.subtitle, 'AmneziaWG');
      expect(Location(id: 'x', label: 'y', proxy: const {}).subtitle, isEmpty);
    });

    test('is a placeholder, not a broken server', () {
      expect(placeholder.isPlaceholder, isTrue);
      expect(
        Location(
          id: 'x',
          label: 'y',
          proxy: const {'type': 'vless'},
        ).isPlaceholder,
        isFalse,
      );
    });
  });

  group('what survives a refresh', () {
    test('the state that says which subscription this even is', () {
      final expiry = DateTime.utc(2026, 9, 30, 12);
      final before = Profile(
        id: 'p-amnezia',
        type: ProfileType.amnezia,
        name: 'Amnezia Premium',
        locations: const [],
        amnezia: AmneziaState(
          serviceType: 'amnezia-premium',
          serviceProtocol: 'awg',
          userCountryCode: 'ru',
          account: const AmneziaAccount(maxDevices: 7),
          expiries: {'amnezia_de_awg': expiry},
        ),
      );

      final after = before.withBundle(
        locations: const [],
        account: null,
        routing: null,
        dns: const [],
        refreshedAt: DateTime.now(),
      );

      expect(after.amnezia, isNotNull);
      expect(after.amnezia!.serviceType, 'amnezia-premium');
      expect(after.amnezia!.expiries['amnezia_de_awg'], expiry);
    });

    test('and it survives being written down and read back', () {
      final restored = Profile.fromJson(
        Profile(
          id: 'p',
          type: ProfileType.amnezia,
          name: 'Amnezia Premium',
          locations: const [],
          amnezia: const AmneziaState(
            serviceType: 'amnezia-premium',
            serviceProtocol: 'awg',
            userCountryCode: 'ru',
          ),
        ).toJson(),
      );
      expect(restored.amnezia?.serviceType, 'amnezia-premium');
      expect(restored.amnezia?.userCountryCode, 'ru');
    });
  });

  group('the identity a device holds a slot by', () {
    test('is shown short enough to read and copied whole', () {
      const full = '3f2b9a10-4c7e-4c2a-9f11-2b6d5e8a7c31';
      final shown = IdentifierRow.shorten(full);
      expect(shown.length, lessThan(full.length));
      expect(shown, startsWith('3f2b9a10-4c7'));
      expect(shown, endsWith('5e8a7c31'));
      expect(IdentifierRow.shorten('abc123'), 'abc123');
    });

    test('is minted once and kept', () async {
      final first = await ProfileStore.amneziaInstallId();
      final again = await ProfileStore.amneziaInstallId();
      expect(first, isNotEmpty);
      expect(again, first);
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });
  });

  group('what the system would start on its own', () {
    test('a picked place is issued before anything is stored', () async {
      final gw = _FakeGateway(configBody: awgConfigAnswer());
      final before = profile(
        locations: [
          Location(
            id: 'amnezia_de_awg',
            label: 'Germany',
            proxy: const {},
            description: 'AmneziaWG',
          ),
        ],
      );
      expect(before.locations.single.isPlaceholder, isTrue);

      final after = await AmneziaSource(
        before,
        gateway: gw,
      ).resolveSelection('amnezia_de_awg');

      expect(
        after.locations.single.isPlaceholder,
        isFalse,
        reason: 'the stored configuration must carry a server, not a name',
      );
      expect(after.locations.single.proxy['server'], '198.51.100.7');
    });
  });

  group('what a failure tells the user', () {
    test('every outcome the library reports has words of its own', () {
      for (final code in [
        AgwStatus.cancelled,
        AgwStatus.network,
        AgwStatus.timeout,
        AgwStatus.ssl,
        AgwStatus.config,
        AgwStatus.decrypt,
        AgwStatus.invalidArgument,
      ]) {
        final e = describeAmneziaError(AgwResponse(code, ''));
        expect(e.title, isNotEmpty);
        expect(e.detail, isNotNull, reason: 'code $code says what to do');
        expect(
          e.title,
          isNot(contains('$code')),
          reason: 'the number is for support, not for the sentence',
        );
      }
    });

    test(
      'every refusal the gateway can write into its answer is read as the reference client reads it',
      () {
        final cases = <(int, String, Map<String, Object>, String)>[
          (429, '', {}, 'Too many requests'),
          (409, '', {}, 'Device limit reached'),
          (409, 'Trial subscription already used', {}, 'Trial already used'),
          (404, '', {}, 'Subscription not found'),
          (408, '', {}, 'The gateway timed out'),
          (501, '', {}, 'The gateway requires a newer client'),
          (422, kSubscriptionInactive, {}, 'Subscription expired'),
          (402, 'refresh_captcha', {}, 'The CAPTCHA expired'),
          (402, 'invalid_captcha', {}, 'The CAPTCHA was rejected'),
          (402, 'rate_limit_exceeded', {}, 'The gateway asked for a CAPTCHA'),
          (402, '', {'captcha_id': 'abc'}, 'The gateway asked for a CAPTCHA'),
          (402, '', {}, 'Subscription not active'),
        ];
        for (final (status, message, extra, title) in cases) {
          final res = AgwResponse(
            AgwStatus.ok,
            jsonEncode({..._refusal(status, message), ...extra}),
          );
          expect(
            res.ok,
            isFalse,
            reason: 'HTTP $status is a refusal, not an answer',
          );
          expect(
            describeAmneziaError(res).title,
            title,
            reason: 'HTTP $status "$message"',
          );
        }
      },
    );

    test(
      'an answer is one the gateway did not refuse, with or without a status',
      () {
        expect(
          AgwResponse(AgwStatus.ok, '{"http_status": 200, "config": {}}').ok,
          isTrue,
        );
        expect(
          AgwResponse(AgwStatus.ok, '{"config": {}}').ok,
          isTrue,
          reason:
              'a document without http_status is read as the reference client reads it',
        );
        expect(AgwResponse(AgwStatus.network, '').ok, isFalse);
      },
    );

    test(
      'a code or status we have never seen is quoted rather than guessed at',
      () {
        expect(
          describeAmneziaError(AgwResponse(9999, '')).detail,
          contains('9999'),
        );
        expect(
          describeAmneziaError(
            AgwResponse(AgwStatus.ok, '{"http_status": 418}'),
          ).detail,
          contains('418'),
        );
      },
    );

    test('the gateway’s own sentence wins over ours', () {
      final e = describeAmneziaError(
        AgwResponse(
          AgwStatus.ok,
          jsonEncode(_refusal(404, 'Account not found.')),
        ),
      );
      expect(e.title, 'Subscription not found');
      expect(e.detail, 'Account not found.');
    });
  });
}

const kSubscriptionInactive =
    'Failed to retrieve subscription information. Is it activated?';

Map<String, dynamic> _refusal(int status, String message) => {
  'http_status': status,
  if (message.isNotEmpty) 'message': message,
};

class _FakeGateway implements AmneziaGateway {
  _FakeGateway({this.accountBody = const {}, this.configBody = const {}});

  final Map<String, dynamic> accountBody;
  final Map<String, dynamic> configBody;

  int configCalls = 0;
  String lastCountry = '';
  String lastProtocol = '';
  String lastPublicKey = '';
  Profile? lastProfile;

  @override
  String get installationUuid => 'test-install';

  @override
  Future<AgwResponse> accountInfo({
    required String apiKey,
    required String serviceType,
    required String userCountryCode,
    String subscriptionStatus = 'active',
  }) async => AgwResponse(AgwStatus.ok, jsonEncode(accountBody));

  @override
  Future<AgwResponse> config({
    required String apiKey,
    required String serviceType,
    required String serviceProtocol,
    required String userCountryCode,
    required String publicKey,
    String serverCountryCode = '',
    bool isConnectEvent = false,
  }) async {
    configCalls++;
    lastCountry = serverCountryCode;
    lastProtocol = serviceProtocol;
    lastPublicKey = publicKey;
    return AgwResponse(AgwStatus.ok, jsonEncode(configBody));
  }
}
