import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/amnezia/amnezia_account.dart';
import 'package:anoya/core/cloud_sync.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/settings_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/cloud_sync_controller.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const kvs = MethodChannel('vpn/icloud');
  const kvsChanges = EventChannel('vpn/icloud/changes');

  late Directory deviceA;
  late Directory deviceB;
  late Directory current;
  late Map<String, String> cloud;
  late Map<String, String> iCloudKeychain;
  late Map<Directory, Map<String, String>> keychains;
  late List<String> kvsCalls;
  late bool cloudBroken;

  setUp(() {
    deviceA = Directory.systemTemp.createTempSync('vpn-sync-a');
    deviceB = Directory.systemTemp.createTempSync('vpn-sync-b');
    current = deviceA;
    cloud = {};
    iCloudKeychain = {};
    keychains = {deviceA: {}, deviceB: {}};
    kvsCalls = [];
    cloudBroken = false;
    messenger.setMockMethodCallHandler(
      pathProvider,
      (call) async => current.path,
    );
    messenger.setMockMethodCallHandler(secure, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String?;
      final store = key == 'icloud_sync_key'
          ? iCloudKeychain
          : keychains[current]!;
      switch (call.method) {
        case 'read':
          return store[key];
        case 'write':
          store[key!] = args['value'] as String;
        case 'delete':
          store.remove(key);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(kvs, (call) async {
      kvsCalls.add(call.method);
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : const <String, dynamic>{};
      switch (call.method) {
        case 'available':
          return true;
        case 'snapshot':
          if (cloudBroken) throw PlatformException(code: 'kvs');
          return Map.of(cloud);
        case 'set':
          cloud[args['key'] as String] = args['value'] as String;
        case 'remove':
          cloud.remove(args['key']);
      }
      return null;
    });
    messenger.setMockStreamHandler(
      kvsChanges,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathProvider, null);
    messenger.setMockMethodCallHandler(secure, null);
    messenger.setMockMethodCallHandler(kvs, null);
    messenger.setMockStreamHandler(kvsChanges, null);
    deviceA.deleteSync(recursive: true);
    deviceB.deleteSync(recursive: true);
  });

  Profile link(String id, String server) => Profile(
    id: id,
    type: ProfileType.link,
    name: 'Link $id',
    locations: [
      Location(
        id: '$id-1',
        label: 'Frankfurt',
        proxy: {
          'type': 'vless',
          'server': server,
          'port': 443,
          'uuid': 'secret-uuid-$id',
        },
      ),
    ],
  );

  void seed(Directory dir, List<Profile> profiles, {String? theme}) {
    File(
      '${dir.path}/profiles.json',
    ).writeAsStringSync(jsonEncode([for (final p in profiles) p.toJson()]));
    if (theme != null) {
      File(
        '${dir.path}/app_prefs.json',
      ).writeAsStringSync(jsonEncode({'theme_mode': theme}));
    }
  }

  Future<ProviderContainer> open(Directory dir, [_Core? core]) async {
    current = dir;
    final c = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(core ?? _Core()),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
        cloudSyncProvider.overrideWith(
          () => CloudSyncController(supported: true),
        ),
      ],
    );
    c.read(appPrefsProvider);
    c.read(cloudSyncProvider);
    while (c.read(profilesControllerProvider).loading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c;
  }

  Future<void> close(ProviderContainer c) async {
    await c.read(cloudSyncProvider.notifier).syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.dispose();
  }

  Future<ProviderContainer> enable(Directory dir, [_Core? core]) async {
    final c = await open(dir, core);
    final sync = c.read(cloudSyncProvider.notifier);
    await sync.setEnabled(true);
    await sync.syncNow();
    await sync.syncNow();
    return c;
  }

  group('reconcile', () {
    String h(String v) => syncDigest(v);

    test('new on either side travels to the other', () {
      final plan = reconcile(
        local: {'a': '1'},
        remote: {'b': '2'},
        unreadable: {},
        seen: {},
      );
      expect(plan.push, {'a': '1'});
      expect(plan.apply, {'b': '2'});
    });

    test('a deletion on either side deletes on the other', () {
      final plan = reconcile(
        local: {'b': '2'},
        remote: {'a': '1'},
        unreadable: {},
        seen: {'a': h('1'), 'b': h('2')},
      );
      expect(plan.removeRemote, {'a'});
      expect(plan.deleteLocal, {'b'});
      expect(plan.seen, isEmpty);
    });

    test('the side that changed since the last sync wins', () {
      final plan = reconcile(
        local: {'a': 'mine', 'b': 'old'},
        remote: {'a': 'old', 'b': 'theirs'},
        unreadable: {},
        seen: {'a': h('old'), 'b': h('old')},
      );
      expect(plan.push, {'a': 'mine'});
      expect(plan.apply, {'b': 'theirs'});
    });

    test('on a first merge what is in iCloud wins', () {
      final plan = reconcile(
        local: {'app': 'light'},
        remote: {'app': 'dark'},
        unreadable: {},
        seen: {},
      );
      expect(plan.apply, {'app': 'dark'});
      expect(plan.push, isEmpty);
    });

    test('an item sealed with another key is replaced, never deleted', () {
      final plan = reconcile(
        local: {'a': '1'},
        remote: {},
        unreadable: {'a', 'b'},
        seen: {'a': h('1'), 'b': h('2')},
      );
      expect(plan.push, {'a': '1'});
      expect(plan.deleteLocal, isEmpty);
      expect(plan.removeRemote, isEmpty);
    });
  });

  group('sealing', () {
    test(
      'a value is unreadable without the key and under another item',
      () async {
        final key = await SyncKey.create();
        final sealed = await key.seal('profile.p1', '{"token":"jwt-secret"}');
        expect(
          utf8.decode(base64Decode(sealed), allowMalformed: true),
          isNot(contains('jwt-secret')),
        );
        expect(await key.open('profile.p1', sealed), '{"token":"jwt-secret"}');
        expect(await key.open('profile.p2', sealed), isNull);
        iCloudKeychain.clear();
        final other = await SyncKey.create();
        expect(await other.open('profile.p1', sealed), isNull);
      },
    );
  });

  group('recipe', () {
    test('a subscription travels as its URL, not its servers', () async {
      final p = Profile(
        id: 's1',
        type: ProfileType.subscription,
        name: 'Provider',
        subscriptionUrl: 'https://panel.example/sub/abc',
        locations: [link('x', 'srv.example').locations.first],
        refreshedAt: DateTime(2026),
        routingEnabled: true,
        ruleSetId: 'rs1',
      );
      final recipe = await profileRecipe(p);
      expect(recipe['subscription_url'], 'https://panel.example/sub/abc');
      expect(recipe['routing_enabled'], true);
      expect(recipe['rule_set_id'], 'rs1');
      expect(recipe.containsKey('locations'), isFalse);
      expect(recipe.containsKey('refreshed_at'), isFalse);
    });

    test('a link carries its server, the only copy there is', () async {
      final recipe = await profileRecipe(link('l1', 'srv.example'));
      expect(recipe['locations'], isNotEmpty);
    });

    test(
      'an Amnezia key travels; servers issued to this device do not',
      () async {
        keychains[current]!['amnezia_key_a1'] = 'vpn-key-secret';
        final p = Profile(
          id: 'a1',
          type: ProfileType.amnezia,
          name: 'Premium',
          locations: [link('x', 'issued.example').locations.first],
          amnezia: AmneziaState(
            serviceType: 'amnezia-premium',
            serviceProtocol: 'awg',
            userCountryCode: 'de',
            expiries: {'x': DateTime.utc(2027)},
          ),
        );
        final recipe = await profileRecipe(p);
        expect(recipe['amnezia_key'], 'vpn-key-secret');
        expect(recipe['amnezia'], {
          'service_type': 'amnezia-premium',
          'service_protocol': 'awg',
          'user_country_code': 'de',
        });
        expect(jsonEncode(recipe), isNot(contains('issued.example')));
      },
    );

    test('a self-hosted token travels with its server', () async {
      keychains[current]!['token_h1'] = 'jwt-secret';
      final recipe = await profileRecipe(
        Profile(
          id: 'h1',
          type: ProfileType.selfhosted,
          name: 'Home',
          serverUrl: 'https://vpn.example',
          locations: const [],
        ),
      );
      expect(recipe['token'], 'jwt-secret');
      expect(recipe['server_url'], 'https://vpn.example');
    });

    test('an arriving recipe keeps what this device fetched', () {
      final local = Profile(
        id: 's1',
        type: ProfileType.subscription,
        name: 'Old name',
        subscriptionUrl: 'https://panel.example/sub/abc',
        locations: [link('x', 'srv.example').locations.first],
      );
      final merged = profileFromRecipe({
        'id': 's1',
        'type': 'subscription',
        'name': 'New name',
        'subscription_url': 'https://panel.example/sub/abc',
      }, local);
      expect(merged.name, 'New name');
      expect(merged.locations, hasLength(1));
    });
  });

  group('status', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final at = DateTime.now().subtract(const Duration(minutes: 2));

    test('the row says what sync is doing, not what it is', () {
      String status(CloudSyncState s) => cloudSyncStatus(l10n, s);
      const on = CloudSyncState(supported: true, enabled: true);
      expect(status(const CloudSyncState(supported: true)), 'Off');
      expect(status(on), 'Syncing…');
      expect(status(on.copyWith(lastSyncedAt: at, syncing: true)), 'Syncing…');
      expect(status(on.copyWith(lastSyncedAt: at)), 'Synced 2 min ago');
      expect(
        status(on.copyWith(lastSyncedAt: at, failed: true)),
        'Didn’t sync · last synced 2 min ago',
      );
      expect(status(on.copyWith(failed: true)), 'Didn’t sync');
      expect(
        status(on.copyWith(waitingForKey: true)),
        'Waiting for the key from iCloud Keychain',
      );
      expect(
        status(on.copyWith(available: false)),
        'Sign in to iCloud on this device first',
      );
    });

    test('a sync records when it happened, and a failure keeps it', () async {
      seed(deviceA, [link('pa', 'a.example')]);
      final a = await enable(deviceA);
      final synced = a.read(cloudSyncProvider).lastSyncedAt;
      expect(synced, isNotNull);
      expect(a.read(cloudSyncProvider).syncing, isFalse);

      cloudBroken = true;
      await a.read(cloudSyncProvider.notifier).syncNow();
      expect(a.read(cloudSyncProvider).failed, isTrue);
      expect(a.read(cloudSyncProvider).lastSyncedAt, synced);
      expect(a.read(cloudSyncProvider).syncing, isFalse);
      a.dispose();

      cloudBroken = false;
      final again = await open(deviceA);
      await again.read(cloudSyncProvider.notifier).checkNow();
      expect(again.read(cloudSyncProvider).failed, isFalse);
      expect(
        again.read(cloudSyncProvider).lastSyncedAt!.isAfter(synced!),
        isTrue,
      );
      await close(again);
    });
  });

  test('two devices end up with both sets, sealed in iCloud', () async {
    seed(deviceA, [link('pa', 'a.example')], theme: 'dark');
    seed(deviceB, [link('pb', 'b.example')]);

    await close(await enable(deviceA));
    expect(cloud.keys, containsAll(['key', 'app', 'profile.pa']));

    final b = await enable(deviceB);
    expect(
      b.read(profilesControllerProvider).profiles.map((p) => p.id),
      unorderedEquals(['pa', 'pb']),
    );
    expect(b.read(appPrefsProvider).themeMode, ThemeMode.dark);
    await close(b);

    final a = await open(deviceA);
    await a.read(cloudSyncProvider.notifier).syncNow();
    expect(
      a.read(profilesControllerProvider).profiles.map((p) => p.id),
      unorderedEquals(['pa', 'pb']),
    );
    await close(a);

    final everything = cloud.values.join();
    for (final secret in [
      'a.example',
      'b.example',
      'secret-uuid',
      'theme_mode',
    ]) {
      expect(everything, isNot(contains(secret)));
    }
  });

  test('deleting a configuration deletes it on the other device', () async {
    seed(deviceA, [link('pa', 'a.example'), link('gone', 'g.example')]);
    await close(await enable(deviceA));
    await close(await enable(deviceB));

    final a = await open(deviceA);
    await a.read(profilesControllerProvider.notifier).removeProfile('gone');
    await close(a);
    expect(cloud.containsKey('profile.gone'), isFalse);

    final b = await open(deviceB);
    await b.read(cloudSyncProvider.notifier).syncNow();
    expect(b.read(profilesControllerProvider).profiles.map((p) => p.id), [
      'pa',
    ]);
    await close(b);
  });

  test('what identifies this device never reaches iCloud', () async {
    seed(deviceA, [
      Profile(
        id: 'am',
        type: ProfileType.amnezia,
        name: 'Premium',
        locations: [
          Location(
            id: 'de/awg',
            label: 'Germany',
            proxy: const {
              'type': 'wireguard',
              'server': 'issued.example',
              'private-key': 'issued-private-key',
            },
          ),
        ],
        amnezia: AmneziaState(
          serviceType: 'amnezia-premium',
          serviceProtocol: 'awg',
          userCountryCode: 'de',
          expiries: {'de/awg': DateTime.utc(2027)},
        ),
      ),
    ]);
    File(
      '${deviceA.path}/device.json',
    ).writeAsStringSync(jsonEncode({'hwid': 'hwid-of-device-a'}));
    keychains[deviceA]!.addAll({
      'amnezia_key_am': 'vpn-key-secret',
      'amnezia_install_uuid': 'install-uuid-of-device-a',
      'amnezia_agw_state': 'gateway-state-of-device-a',
    });

    await close(await enable(deviceA));

    final key = (await SyncKey.load())!;
    final plain = [
      for (final e in cloud.entries)
        if (SyncItem.isItem(e.key)) await key.open(e.key, e.value),
    ].join();
    expect(plain, contains('vpn-key-secret'));
    for (final local in [
      'hwid-of-device-a',
      'install-uuid-of-device-a',
      'gateway-state-of-device-a',
      'issued.example',
      'issued-private-key',
      '2027',
    ]) {
      expect(plain, isNot(contains(local)), reason: local);
    }

    final b = await enable(deviceB);
    await close(b);
    expect(keychains[deviceB]!['amnezia_key_am'], 'vpn-key-secret');
    expect(
      keychains[deviceB]!['amnezia_install_uuid'],
      isNot('install-uuid-of-device-a'),
    );
    expect(keychains[deviceB]!.containsKey('amnezia_agw_state'), isFalse);
    expect(File('${deviceB.path}/device.json').existsSync(), isFalse);
  });

  test('turning sync off removes nothing, here or in iCloud', () async {
    seed(deviceA, [link('pa', 'a.example')]);
    final a = await enable(deviceA);
    final before = Map.of(cloud);
    kvsCalls.clear();

    await a.read(cloudSyncProvider.notifier).setEnabled(false);
    await a.read(profilesControllerProvider.notifier).removeProfile('pa');
    await close(a);

    expect(cloud, before);
    expect(kvsCalls, isNot(contains('remove')));
    expect(kvsCalls, isNot(contains('set')));
  });

  test('a change to the running configuration reloads, never stops', () async {
    seed(deviceA, [link('pa', 'a.example')]);
    await close(await enable(deviceA));
    await close(await enable(deviceB));

    final a = await open(deviceA);
    await a
        .read(profilesControllerProvider.notifier)
        .setRoutingEnabled('pa', true);
    await close(a);

    final core = _Core(VpnStatus.connected);
    final b = await open(deviceB, core);
    await b.read(cloudSyncProvider.notifier).syncNow();
    expect(b.read(profilesControllerProvider).active!.routingEnabled, isTrue);
    expect(core.reloads, greaterThan(0));
    expect(core.disconnects, 0);
    await close(b);
  });
}

class _Core extends VpnCore {
  _Core([this._status = VpnStatus.disconnected]);

  final VpnStatus _status;
  int reloads = 0;
  int disconnects = 0;

  @override
  VpnStatus get status => _status;

  @override
  Stream<VpnStatus> statusStream() => const Stream.empty();

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<void> reload(NormConfig config, String locationId) async => reloads++;
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();

  @override
  Future<void> onConnected() async {}
}
