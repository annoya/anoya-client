import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/amnezia/amnezia_account.dart';
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
  late Completer<String?> key;

  void seed(Profile p) => File(
    '${tmp.path}/profiles.json',
  ).writeAsStringSync(jsonEncode([p.toJson()]));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-connect');
    key = Completer<String?>();
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'read') return key.future;
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(secure, null);
    tmp.deleteSync(recursive: true);
  });

  Future<ProviderContainer> boot(_FakeCore core) async {
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

  final amnezia = Profile(
    id: 'p-amnezia',
    type: ProfileType.amnezia,
    name: 'Amnezia Premium',
    locations: [
      Location(
        id: amneziaLocationId('de', 'awg'),
        label: 'Germany',
        proxy: const {},
      ),
    ],
    amnezia: const AmneziaState(
      serviceType: 'amnezia-premium',
      serviceProtocol: 'awg',
      userCountryCode: 'ru',
    ),
  );

  test('a server still being issued already reads as connecting', () async {
    seed(amnezia);
    final core = _FakeCore();
    final c = await boot(core);

    unawaited(c.read(profilesControllerProvider.notifier).connect());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(c.read(profilesControllerProvider).preparing, isTrue);
    expect(
      c.read(sessionProvider).status,
      VpnStatus.connecting,
      reason: 'a silent button here is what looked like a lost tap',
    );
    expect(c.read(sessionProvider).busy, isTrue);
  });

  test('a second tap while issuing cancels instead of being lost', () async {
    seed(amnezia);
    final core = _FakeCore();
    final c = await boot(core);
    final ctrl = c.read(profilesControllerProvider.notifier);

    final first = ctrl.connect();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await ctrl.disconnect();

    expect(c.read(sessionProvider).status, VpnStatus.disconnected);

    key.complete(null);
    await first;

    expect(
      core.connects,
      0,
      reason: 'a cancelled start never reaches the tunnel',
    );
    expect(
      c.read(profilesControllerProvider).error,
      isNull,
      reason: 'what the cancelled attempt ran into is not news',
    );
    expect(core.disconnects, 0, reason: 'there was no tunnel to stop');
  });

  test('the hand-off to the tunnel does not blink back to idle', () async {
    seed(
      Profile(
        id: 'p-link',
        type: ProfileType.link,
        name: 'link',
        locations: [
          Location(
            id: 'l1',
            label: 'Germany',
            proxy: const {'type': 'vless', 'server': '1.1.1.1', 'port': 443},
          ),
        ],
      ),
    );
    final core = _FakeCore(answerLate: true);
    final c = await boot(core);
    final seen = <VpnStatus>[];
    c.listen(sessionProvider.select((s) => s.status), (_, s) => seen.add(s));

    await c.read(profilesControllerProvider.notifier).connect();

    expect(core.connects, 1);
    expect(c.read(profilesControllerProvider).preparing, isFalse);
    expect(
      seen,
      isNot(contains(VpnStatus.disconnected)),
      reason: 'the system reports the tunnel a moment after start returns',
    );
    expect(c.read(sessionProvider).status, VpnStatus.connecting);
  });
}

class _FakeCore extends VpnCore {
  _FakeCore({this.answerLate = false});

  final bool answerLate;
  final _status = StreamController<VpnStatus>.broadcast();
  VpnStatus _current = VpnStatus.disconnected;
  int connects = 0;
  int disconnects = 0;

  void emit(VpnStatus s) {
    _current = s;
    _status.add(s);
  }

  @override
  VpnStatus get status => _current;

  @override
  Stream<VpnStatus> statusStream() => _status.stream;

  @override
  Future<String> lastDisconnectError() async => '';

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {
    connects++;
    if (answerLate) {
      Timer(const Duration(milliseconds: 30), () => emit(VpnStatus.connecting));
    }
  }

  @override
  Future<void> disconnect() async => disconnects++;

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
