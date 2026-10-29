import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/cloud_sync.dart';
import 'package:anoya/core/device_transfer.dart';
import 'package:anoya/core/json_file_store.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/profile_store.dart';
import 'package:anoya/core/routing_prefs.dart';
import 'package:anoya/core/rule_set.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';
import 'package:anoya/state/transfer_inbox.dart';

void main() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-transfer');
    messenger.setMockMethodCallHandler(pathProvider, (_) async => tmp.path);
  });
  tearDown(() async {
    // Windows refuses to delete a file a store write still holds open.
    for (var i = 0; i < 200 && JsonFileStore.pending > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    messenger.setMockMethodCallHandler(pathProvider, null);
    tmp.deleteSync(recursive: true);
  });

  Profile link(String id, {String name = 'Office', String? ruleSetId}) =>
      Profile(
        id: id,
        type: ProfileType.link,
        name: name,
        ruleSetId: ruleSetId,
        locations: [
          Location(
            id: '$id-1',
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

  TransferCode code(List<int> key, {List<String>? addresses, int port = 1}) =>
      TransferCode(
        name: 'Chromecast · Android 14',
        kind: TransferDeviceKind.tv,
        addresses: addresses ?? const ['192.168.1.20', '10.0.0.5'],
        port: port,
        publicKey: key,
      );

  group('the code', () {
    test('a receive code survives the trip through a QR link', () async {
      final keys = await TransferKeys.generate();
      final back = TransferCode.parse(code(keys.publicKey).toLink())!;
      expect(back.name, 'Chromecast · Android 14');
      expect(back.kind, TransferDeviceKind.tv);
      expect(back.addresses, ['192.168.1.20', '10.0.0.5']);
      expect(back.port, 1);
      expect(back.publicKey, keys.publicKey);
    });

    test('only a code from the Receive screen is read as one', () async {
      final link = code((await TransferKeys.generate()).publicKey).toLink();
      for (final bad in [
        'vless://uuid@host:443',
        link.replaceFirst('anoya://receive', 'anoya://ruleset'),
        link.replaceFirst('v=1', 'v=2'),
        link.replaceFirst(RegExp(r'k=[^&]+'), 'k=c2hvcnQ'),
        link.replaceFirst(RegExp(r'a=[^&]+'), 'a=fe80%3A%3A1'),
        link.replaceFirst(RegExp(r'p=[^&]+'), 'p=0'),
      ]) {
        expect(TransferCode.parse(bad), isNull, reason: bad);
      }
    });

    test('the code offers LAN addresses, never the tunnel’s own', () {
      final offered = transferAddresses([
        InternetAddress('192.168.1.20'),
        InternetAddress('10.0.0.5'),
        InternetAddress('172.20.3.4'),
        InternetAddress('172.19.0.1'),
        InternetAddress('198.18.0.1'),
        InternetAddress('127.0.0.1'),
        InternetAddress('8.8.8.8'),
        InternetAddress('169.254.1.1'),
        InternetAddress('fe80::1'),
      ]);
      expect(offered, ['192.168.1.20', '10.0.0.5', '172.20.3.4']);
    });
  });

  group('sealing', () {
    const package = TransferPackage(
      from: 'Pixel 8 · Android 15',
      routing: {'lan_direct': false},
    );

    test('a package opens only under the key it was sealed to', () async {
      final right = await TransferKeys.generate();
      final other = await TransferKeys.generate();
      final sealed = await sealTransfer(right.publicKey, package);
      expect((await right.open(sealed))?.from, 'Pixel 8 · Android 15');
      expect(await other.open(sealed), isNull);
    });

    test('a tampered package is refused', () async {
      final keys = await TransferKeys.generate();
      final sealed = await sealTransfer(keys.publicKey, package);
      sealed[sealed.length - 20] ^= 1;
      expect(await keys.open(sealed), isNull);
    });
  });

  group('over the network', () {
    const package = TransferPackage(from: 'Pixel 8 · Android 15');

    setUp(() => HttpOverrides.global = null);

    Future<TransferReceiver> receiver() => TransferReceiver.start(
      name: 'Chromecast · Android 14',
      kind: TransferDeviceKind.tv,
      addresses: const ['127.0.0.1'],
    );

    test('the package reaches the receiver once', () async {
      final r = await receiver();
      final sealed = await sealTransfer(r.code.publicKey, package);
      await sendTransfer(r.code, sealed);
      expect((await r.received).from, 'Pixel 8 · Android 15');
      await expectLater(
        sendTransfer(r.code, sealed),
        throwsA(isA<TransferException>()),
        reason: 'the port closes once a package has been taken',
      );
    });

    test('a package for an older code is refused and the code stays', () async {
      final r = await receiver();
      final stale = await TransferKeys.generate();
      await expectLater(
        sendTransfer(r.code, await sealTransfer(stale.publicKey, package)),
        throwsA(
          isA<TransferException>().having(
            (e) => e.failure,
            'failure',
            TransferFailure.refused,
          ),
        ),
      );
      await sendTransfer(r.code, await sealTransfer(r.code.publicKey, package));
      expect((await r.received).from, 'Pixel 8 · Android 15');
    });

    test('nobody listening is unreachable, not refused', () async {
      final keys = await TransferKeys.generate();
      final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = free.port;
      await free.close();
      await expectLater(
        sendTransfer(
          code(keys.publicKey, addresses: const ['127.0.0.1'], port: port),
          await sealTransfer(keys.publicKey, package),
        ),
        throwsA(
          isA<TransferException>().having(
            (e) => e.failure,
            'failure',
            TransferFailure.unreachable,
          ),
        ),
      );
    });
  });

  group('what is sent', () {
    test(
      'a configuration takes the rule set it routes by, even unticked',
      () async {
        await RuleSetStore.save([
          const RuleSet(id: 'work', name: 'Work'),
          const RuleSet(id: 'home', name: 'Home'),
        ]);
        await ProfileStore.save([link('p1', ruleSetId: 'work'), link('p2')]);
        final package = await buildTransferPackage(
          from: 'Pixel',
          profileIds: {'p1'},
          allRuleSets: false,
          settings: false,
        );
        expect(package.profiles.map((p) => p['id']), ['p1']);
        expect(package.ruleSets.map((s) => s['id']), ['work']);
        expect(package.hasSettings, isFalse);
      },
    );

    test('settings travel without this device’s geo download time', () async {
      await RoutingPrefsStore.save(
        RoutingPrefs(lanDirect: false, geoUpdatedAt: DateTime(2026)),
      );
      final package = await buildTransferPackage(
        from: 'Pixel',
        profileIds: const {},
        allRuleSets: true,
        settings: true,
      );
      expect(package.routing?['lan_direct'], isFalse);
      expect(package.routing, isNot(contains('geo_updated_at')));
      expect(package.check, isNotNull);
    });
  });

  group('on the receiving side', () {
    Future<ProviderContainer> open() async {
      final c = ProviderContainer(
        overrides: [
          vpnCoreProvider.overrideWithValue(_Core()),
          onDemandProvider.overrideWith(_QuietOnDemand.new),
        ],
      );
      while (c.read(profilesControllerProvider).loading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return c;
    }

    Future<TransferPackage> arriving(Profile p) async => TransferPackage(
      from: 'Pixel',
      profiles: [await profileRecipe(p)],
      ruleSets: [const RuleSet(id: 'work', name: 'Work').toJson()],
      routing: const RoutingPrefs(lanDirect: false).toJson(),
    );

    test(
      'what arrives is added, the first configuration made active',
      () async {
        final c = await open();
        addTearDown(c.dispose);
        await c.read(transferInboxProvider).add(await arriving(link('p1')));
        final st = c.read(profilesControllerProvider);
        expect(st.profiles.map((p) => p.id), ['p1']);
        expect(st.active?.id, 'p1');
        expect((await RuleSetStore.load()).map((s) => s.id), contains('work'));
        expect(c.read(routingPrefsProvider).lanDirect, isFalse);
      },
    );

    test('a configuration that came before is updated, not doubled', () async {
      final c = await open();
      addTearDown(c.dispose);
      final inbox = c.read(transferInboxProvider);
      await inbox.add(await arriving(link('p1')));
      expect(inbox.isKnown('p1'), isTrue);
      await inbox.add(await arriving(link('p1', name: 'Renamed')));
      expect(c.read(profilesControllerProvider).profiles.map((p) => p.name), [
        'Renamed',
      ]);
    });
  });
}

class _Core extends VpnCore {
  @override
  VpnStatus get status => VpnStatus.disconnected;

  @override
  Stream<VpnStatus> statusStream() => const Stream.empty();

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reload(NormConfig config, String locationId) async {}
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();

  @override
  Future<void> onConnected() async {}
}
