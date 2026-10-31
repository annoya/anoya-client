import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';
import 'package:anoya/state/routing_status.dart';
import 'support/memory_secrets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-tunnel-sync');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    memorySecrets['profiles'] = jsonEncode([
      Profile(
        id: 'p',
        type: ProfileType.link,
        name: 'P',
        locations: [
          Location(
            id: 'l',
            label: 'Frankfurt',
            proxy: const {
              'type': 'vless',
              'server': 'r.example',
              'port': 443,
              'uuid': 'u',
            },
          ),
        ],
      ).toJson(),
    ]);
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    tmp.deleteSync(recursive: true);
  });

  Future<(ProviderContainer, _Core)> boot() async {
    final core = _Core();
    final c = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(core),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
      ],
    );
    addTearDown(c.dispose);
    while (c.read(profilesControllerProvider).loading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    core.synced = 0;
    return (c, core);
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test(
    'a routing setting reaches the tunnel without the screen asking',
    () async {
      final (c, core) = await boot();
      await c
          .read(routingPrefsProvider.notifier)
          .update((p) => p.copyWith(lanDirect: !p.lanDirect));
      await settle();
      expect(core.synced, 1);
    },
  );

  test('a changed rule set reaches the tunnel', () async {
    final (c, core) = await boot();
    c.read(ruleSetRevisionProvider.notifier).bump();
    await settle();
    expect(core.synced, 1);
  });

  test('turning engine logs off reaches the tunnel', () async {
    final (c, core) = await boot();
    await c.read(appPrefsProvider.notifier).setCollectLogs(false);
    await settle();
    expect(core.synced, 1);
  });
}

class _Core extends VpnCore {
  int synced = 0;

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
  Future<void> syncConfig(NormConfig config, String locationId) async =>
      synced++;
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();

  @override
  Future<void> onConnected() async {}
}
