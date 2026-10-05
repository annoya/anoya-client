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
import 'package:anoya/state/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-import-connected');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(secure, (call) async => null);
    File('${tmp.path}/profiles.json').writeAsStringSync(
      jsonEncode([
        Profile(
          id: 'running',
          type: ProfileType.link,
          name: 'Running',
          locations: [
            Location(
              id: 'r1',
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
      ]),
    );
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(secure, null);
    tmp.deleteSync(recursive: true);
  });

  Future<ProviderContainer> boot(_Core core) async {
    final c = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(core),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
      ],
    );
    addTearDown(c.dispose);
    c.read(sessionProvider);
    while (c.read(profilesControllerProvider).loading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c;
  }

  const link = 'vless://u@new.example:443?security=tls#Amsterdam';

  test(
    'while connected, an import is added but the tunnel keeps its own',
    () async {
      final core = _Core(VpnStatus.connected);
      final c = await boot(core);

      await c.read(profilesControllerProvider.notifier).addFromText(link);

      final st = c.read(profilesControllerProvider);
      expect(st.profiles, hasLength(2));
      expect(
        st.activeId,
        'running',
        reason: 'the screen must name the configuration the tunnel runs',
      );
      expect(st.selectedLocationId, 'r1');
      expect(
        core.synced,
        0,
        reason: 'nothing about the running tunnel changed',
      );
    },
  );

  test('while connecting it is the same', () async {
    final c = await boot(_Core(VpnStatus.connecting));

    await c.read(profilesControllerProvider.notifier).addFromText(link);

    expect(c.read(profilesControllerProvider).activeId, 'running');
  });

  test(
    'with the VPN off, the new configuration is picked, as before',
    () async {
      final c = await boot(_Core(VpnStatus.disconnected));

      await c.read(profilesControllerProvider.notifier).addFromText(link);

      final st = c.read(profilesControllerProvider);
      expect(st.activeId, isNot('running'));
      expect(st.active!.name, isNotEmpty);
    },
  );
}

class _Core extends VpnCore {
  _Core(this._current);

  final VpnStatus _current;
  int synced = 0;

  @override
  VpnStatus get status => _current;

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
