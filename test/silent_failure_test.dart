import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/vpn_core.dart';
import 'package:vpn_client/state/on_demand_controller.dart';
import 'package:vpn_client/state/profiles_controller.dart';
import 'package:vpn_client/state/providers.dart';

/// A tunnel that stops without being asked to.
///
/// An extension that refuses a config reports it to the system, not to the call
/// that started it, so the app used to see the status fall back to disconnected
/// and nothing else — which reads as a connect that hung and then gave up. That
/// was the whole of what a user saw when a rule set produced a config the
/// engine would not run.
void main() {
  ProviderContainer boot(_FakeCore core) {
    final c = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(core),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
      ],
    );
    addTearDown(c.dispose);
    c.read(profilesControllerProvider);
    return c;
  }

  test('a tunnel that stops on its own says why', () async {
    final core = _FakeCore(
      reason: 'mihomo start failed: rule GEOSITE not found',
    );
    final c = boot(core);

    core.emit(VpnStatus.connecting);
    core.emit(VpnStatus.disconnected);
    await Future<void>.delayed(Duration.zero);

    final error = c.read(profilesControllerProvider).error;
    expect(error, isNotNull, reason: 'silence here is what looked like a hang');
    expect(error!.detail, contains('GEOSITE'));
  });

  test('a stop the user asked for is not an error', () async {
    final core = _FakeCore(reason: 'whatever the system kept');
    final c = boot(core);

    core.emit(VpnStatus.connected);
    await c.read(profilesControllerProvider.notifier).disconnect();
    core.emit(VpnStatus.disconnected);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(profilesControllerProvider).error, isNull);
  });

  test('a platform that kept no reason stays quiet', () async {
    // An extension the system killed for memory leaves nothing behind, and a
    // dialog saying "the tunnel stopped" with no reason helps nobody.
    final core = _FakeCore(reason: '');
    final c = boot(core);

    core.emit(VpnStatus.connecting);
    core.emit(VpnStatus.disconnected);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(profilesControllerProvider).error, isNull);
  });

  test('a disconnected state that never went up explains nothing', () async {
    final core = _FakeCore(reason: 'stale reason from an old session');
    final c = boot(core);

    core.emit(VpnStatus.disconnected);
    await Future<void>.delayed(Duration.zero);

    expect(
      c.read(profilesControllerProvider).error,
      isNull,
      reason: 'the reason belongs to a session this one never started',
    );
  });
}

class _FakeCore extends VpnCore {
  _FakeCore({required this.reason});

  final String reason;
  final _status = StreamController<VpnStatus>.broadcast();
  VpnStatus _current = VpnStatus.disconnected;

  void emit(VpnStatus s) {
    _current = s;
    _status.add(s);
  }

  @override
  VpnStatus get status => _current;

  @override
  Stream<VpnStatus> statusStream() => _status.stream;

  @override
  Future<String> lastDisconnectError() async => reason;

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reload(NormConfig config, String locationId) async {}

  @override
  Future<void> syncConfig(NormConfig config, String locationId) async {}

  @override
  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async => false;
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}
