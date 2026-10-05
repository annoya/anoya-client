import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/profile_store.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  Profile profile(String id, String name) => Profile(
    id: id,
    type: ProfileType.subscription,
    name: name,
    locations: [
      Location(
        id: '$id-a',
        label: 'Germany',
        proxy: {'type': 'vless', 'server': '1.1.1.1'},
      ),
      Location(
        id: '$id-b',
        label: 'Japan',
        proxy: {'type': 'vless', 'server': '2.2.2.2'},
      ),
    ],
    groups: const [
      ProxyGroup(name: 'auto', type: 'url-test', members: ['p2-a', 'p2-b']),
    ],
  );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-selection');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => null,
    );
    File('${tmp.path}/profiles.json').writeAsStringSync(
      jsonEncode([
        profile('p1', 'nexus').toJson(),
        profile('p2', 'work').toJson(),
      ]),
    );
  });
  tearDown(() async {
    // Un-awaited writes from disposed containers race the directory delete.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      null,
    );
    tmp.deleteSync(recursive: true);
  });

  Future<ProfilesController> launch() async {
    final container = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(_QuietCore()),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
      ],
    );
    addTearDown(container.dispose);
    final ctrl = container.read(profilesControllerProvider.notifier);
    for (
      var i = 0;
      i < 800 && container.read(profilesControllerProvider).loading;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return ctrl;
  }

  Future<void> written(String profileId, String selectionId) async {
    var quiet = 0;
    for (var i = 0; i < 800 && quiet < 10; i++) {
      final pending = tmp.listSync().any((f) => f.path.endsWith('.tmp'));
      quiet = pending ? 0 : quiet + 1;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final saved = await ProfileStore.loadSelection();
    expect(
      (saved.profileId, saved.selectionId),
      (profileId, selectionId),
      reason: 'the selection never reached disk',
    );
  }

  test('the configuration and the server come back', () async {
    final first = await launch();
    await first.setActive('p2');
    await first.selectLocation('p2-b');
    await written('p2', 'p2-b');

    final next = await launch();
    expect(next.state.active?.id, 'p2');
    expect(next.state.selectionId, 'p2-b');
  });

  test(
    'a chosen group comes back as a group, not as one of its members',
    () async {
      final first = await launch();
      await first.setActive('p2');
      const group = ProxyGroup(name: 'auto', type: 'url-test', members: []);
      await first.selectLocation(group.id);
      await written('p2', group.id);

      final next = await launch();
      expect(next.state.selectedGroup?.name, 'auto');
    },
  );

  group('what an id no longer names', () {
    test('a configuration that is gone falls back to the first', () async {
      await ProfileStore.saveSelection('p-removed', 'p1-b');
      final ctrl = await launch();
      expect(ctrl.state.active?.id, 'p1');
      expect(
        ctrl.state.selectionId,
        'p1-a',
        reason: 'the saved server belonged to the configuration that is gone',
      );
    });

    test(
      'a server the refresh dropped falls back to the first of that config',
      () async {
        await ProfileStore.saveSelection('p2', 'p2-vanished');
        final ctrl = await launch();
        expect(ctrl.state.active?.id, 'p2');
        expect(ctrl.state.selectionId, 'p2-a');
      },
    );

    test('nothing saved at all is the old behaviour, unchanged', () async {
      final ctrl = await launch();
      expect(ctrl.state.active?.id, 'p1');
      expect(ctrl.state.selectionId, 'p1-a');
    });
  });
}

class _QuietCore extends VpnCore {
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
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}
