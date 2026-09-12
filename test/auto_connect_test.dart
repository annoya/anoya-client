import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/platform_support.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/vpn_core.dart';
import 'package:vpn_client/features/settings_screen.dart';
import 'package:vpn_client/state/auto_connect_controller.dart';
import 'package:vpn_client/state/providers.dart';

/// Bringing the tunnel up with the machine — the one thing that happens with
/// no app running, and therefore the one thing the user has to have agreed to.
///
/// The bug this pins: the Windows service started the tunnel at every boot
/// merely because a config was on disk, and the app writes that config on any
/// sync of the selection. A person who had never pressed Connect got a VPN
/// after rebooting, with no setting anywhere that could have said otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-auto-connect');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    debugDefaultTargetPlatformOverride = null;
    tmp.deleteSync(recursive: true);
  });

  Future<void> settle() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('the setting', () {
    test('is off until somebody turns it on', () async {
      final core = _FakeCore();
      final c = ProviderContainer(
        overrides: [vpnCoreProvider.overrideWithValue(core)],
      );
      addTearDown(c.dispose);

      expect(c.read(autoConnectProvider), isFalse);
      await settle();
      expect(
        core.autoConnect,
        isFalse,
        reason:
            'a fresh install tells the service nothing new, but tells it truthfully',
      );
    });

    test('reaches the service, and survives a restart of the app', () async {
      final core = _FakeCore();
      final first = ProviderContainer(
        overrides: [vpnCoreProvider.overrideWithValue(core)],
      );
      await first.read(autoConnectProvider.notifier).set(true);
      expect(core.autoConnect, isTrue);
      first.dispose();

      // A new run of the app: the answer comes back off disk and is repeated
      // to the service, whose own copy a reinstall may have taken with it.
      core.autoConnect = false;
      final second = ProviderContainer(
        overrides: [vpnCoreProvider.overrideWithValue(core)],
      );
      addTearDown(second.dispose);
      second.read(autoConnectProvider);
      await settle();

      expect(second.read(autoConnectProvider), isTrue);
      expect(core.autoConnect, isTrue);
    });

    test('turning it off is pushed too, not just forgotten locally', () async {
      final core = _FakeCore();
      final c = ProviderContainer(
        overrides: [vpnCoreProvider.overrideWithValue(core)],
      );
      addTearDown(c.dispose);

      await c.read(autoConnectProvider.notifier).set(true);
      await c.read(autoConnectProvider.notifier).set(false);

      expect(core.autoConnect, isFalse);
      expect(c.read(autoConnectProvider), isFalse);
    });
  });

  group('where the switch appears', () {
    testWidgets('on Windows, in the connection section', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(supportsBootAutoConnect, isTrue);

      await _pumpSettings(tester);

      expect(find.text('Auto-connect'), findsOneWidget);
      expect(find.text('Connect when Windows starts'), findsOneWidget);
      // Apple's screen and Android's explainer answer to facilities Windows
      // does not have; offering either here would name something imaginary.
      expect(find.text('On demand'), findsNothing);
      expect(find.text('Always-on VPN'), findsNothing);
      // Reset inside the body: testWidgets checks for a leaked debug variable
      // before the tearDown that would otherwise clear it.
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('nowhere else', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await _pumpSettings(tester);

      expect(find.text('Auto-connect'), findsNothing);
      expect(find.text('On demand'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

Future<void> _pumpSettings(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [vpnCoreProvider.overrideWithValue(_FakeCore())],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}

class _FakeCore extends VpnCore {
  bool autoConnect = false;

  @override
  Future<void> setAutoConnect(bool enabled) async => autoConnect = enabled;

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
  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async => false;
}
