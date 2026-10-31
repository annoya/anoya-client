import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/control_transport.dart';
import 'package:anoya/core/network_extension_core.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';

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

  test(
    'a start the engine refused says why after passing through error',
    () async {
      final core = _FakeCore(reason: 'parse config: proxy 0: unsupported type');
      final c = boot(core);

      core.emit(VpnStatus.connecting);
      core.emit(VpnStatus.error);
      core.emit(VpnStatus.disconnected);
      await Future<void>.delayed(Duration.zero);

      final error = c.read(profilesControllerProvider).error;
      expect(
        error?.detail,
        contains('unsupported type'),
        reason:
            'Android and the desktop service report a refused start this way',
      );
    },
  );

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
    final core = _FakeCore(reason: '');
    final c = boot(core);

    core.emit(VpnStatus.connecting);
    core.emit(VpnStatus.disconnected);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(profilesControllerProvider).error, isNull);
  });

  test('a desktop tunnel service that went away says so', () async {
    final transport = _GoneService();
    addTearDown(() => NetworkExtensionCore(transport: ChannelTransport()));
    final c = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(
          NetworkExtensionCore(transport: transport),
        ),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
      ],
    );
    addTearDown(c.dispose);
    c.read(profilesControllerProvider);
    await pumpEventQueue();

    transport.status.add('connected');
    transport.status.add('disconnected');
    await pumpEventQueue();

    expect(
      c.read(profilesControllerProvider).error?.detail,
      contains('not running'),
      reason: 'the service is the one that would have kept the reason',
    );
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

class _GoneService implements ControlTransport {
  final status = StreamController<String?>.broadcast();

  @override
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (method != 'disconnect_error') return null;
    throw PlatformException(
      code: 'service_unavailable',
      message: 'the tunnel service is not running',
    );
  }

  @override
  Stream<String?> get statusEvents => status.stream;

  @override
  Stream<String> get noticeEvents => const Stream.empty();
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
