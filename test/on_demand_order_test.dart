import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-on-demand-order');
    messenger.setMockMethodCallHandler(pathProvider, (call) async => tmp.path);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(pathProvider, null);
    tmp.deleteSync(recursive: true);
  });

  test(
    'switching on-demand off right after on leaves the system off',
    () async {
      final core = _SlowCore();
      final c = ProviderContainer(
        overrides: [vpnCoreProvider.overrideWithValue(core)],
      );
      addTearDown(c.dispose);
      final ctrl = c.read(onDemandProvider.notifier);

      await Future.wait([ctrl.setEnabled(true), ctrl.setEnabled(false)]);

      expect(core.sent.last, isFalse, reason: 'the last choice is what sticks');
      expect(core.mostAtOnce, 1, reason: 'the system is asked one at a time');
      expect(c.read(onDemandProvider).enabled, isFalse);
    },
  );
}

class _SlowCore extends VpnCore {
  final sent = <bool>[];
  int _inFlight = 0;
  int mostAtOnce = 0;

  @override
  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async {
    _inFlight++;
    if (_inFlight > mostAtOnce) mostAtOnce = _inFlight;
    await Future<void>.delayed(Duration(milliseconds: prefs.armed ? 200 : 10));
    sent.add(prefs.armed);
    _inFlight--;
    return prefs.armed;
  }

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
