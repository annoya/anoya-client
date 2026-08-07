import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/mihomo_tun_config.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/vpn_core.dart';
import 'package:vpn_client/features/home_screen.dart';
import 'package:vpn_client/state/on_demand_controller.dart';
import 'package:vpn_client/state/profiles_controller.dart';
import 'package:vpn_client/state/providers.dart';

/// The hot-switch contract: a connected tunnel does NOT lock the pickers
/// (switching is a live reload under the standing session), locks belong to
/// the initial connect only, and the brief switch itself is announced in the
/// status line while taps are ignored.
void main() {
  Profile profile(String id, String name) => Profile(
        id: id,
        type: ProfileType.subscription,
        name: name,
        locations: [
          Location(id: '$id-a', label: 'Germany', proxy: {'type': 'vless', 'server': '1.1.1.1'}),
          Location(id: '$id-b', label: 'Japan', proxy: {'type': 'vless', 'server': '2.2.2.2'}),
        ],
      );

  Future<void> pump(
    WidgetTester tester, {
    required VpnStatus status,
    bool switching = false,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vpnCoreProvider.overrideWithValue(_FixedCore(status)),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
        profilesControllerProvider.overrideWith(
            () => _FixedProfiles([profile('p1', 'nexus'), profile('p2', 'work')], switching)),
      ],
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const HomeScreen()),
    ));
    await tester.pump();
  }

  ListTile tile(WidgetTester tester, String title) =>
      tester.widget<ListTile>(find.widgetWithText(ListTile, title));

  testWidgets('a connected tunnel keeps both pickers active — no locks',
      (tester) async {
    await pump(tester, status: VpnStatus.connected);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(tile(tester, 'nexus').onTap, isNotNull);
    expect(tile(tester, 'Germany').onTap, isNotNull);
  });

  testWidgets('the initial connect is the only state with locks', (tester) async {
    await pump(tester, status: VpnStatus.connecting);

    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    expect(tile(tester, 'nexus').onTap, isNull);
    expect(tile(tester, 'Germany').onTap, isNull);
  });

  testWidgets('a switch in flight announces itself and ignores taps', (tester) async {
    await pump(tester, status: VpnStatus.connected, switching: true);

    expect(find.text('Switching server…'), findsOneWidget);
    // No locks: the state is too brief for them — the rows just ignore taps.
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(tile(tester, 'nexus').onTap, isNull);
    expect(tile(tester, 'Germany').onTap, isNull);
  });

  test('a core without hot reload says so instead of pretending', () {
    final config = NormConfig(
        version: 1, account: Account.fromJson(const {}), locations: const []);
    expect(_MinimalCore().reload(config, 'x'), throwsUnsupportedError);
  });

  // A leak has exactly one cause in this architecture: the NE session going
  // down (the OS routes then fall back to the physical interface). So the
  // leak-freedom of switching is testable as invariants: nothing on the switch
  // path may stop or restart the session, in any outcome.
  group('leak invariants', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vpn-switch-test');
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path,
      );
      // The stores behind _normConfig probe the extension channel (shared dir
      // for geo status); in tests there is no platform side, same as a tunnel
      // that is not running.
      messenger.setMockMethodCallHandler(
        const MethodChannel('vpn/control'),
        (call) async => throw PlatformException(code: 'no platform in tests'),
      );
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('vpn/control'), null);
      tmp.deleteSync(recursive: true);
    });

    (_RecordingCore, ProfilesController) harness(VpnStatus status) {
      final core = _RecordingCore(status);
      final container = ProviderContainer(overrides: [
        vpnCoreProvider.overrideWithValue(core),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
        profilesControllerProvider.overrideWith(
            () => _FixedProfiles([profile('p1', 'nexus'), profile('p2', 'work')], false)),
      ]);
      addTearDown(container.dispose);
      return (core, container.read(profilesControllerProvider.notifier));
    }

    test('switching a location or profile on a live tunnel is reload-only', () async {
      final (core, ctrl) = harness(VpnStatus.connected);

      await ctrl.selectLocation('p1-b');
      await ctrl.setActive('p2');

      expect(core.calls, ['reload', 'reload'],
          reason: 'no stop/start anywhere on the switch path — the session '
              'must stay up, or the OS routes fall back and traffic leaks');
    });

    test('a failed switch leaves the running tunnel alone', () async {
      final (core, ctrl) = harness(VpnStatus.connected);
      core.failReload = true;

      await ctrl.selectLocation('p1-b');

      expect(core.calls, ['reload'],
          reason: 'no disconnect as error handling: dropping the session is '
              'the one thing that can actually leak');
      final st = ctrl.state;
      expect(st.switching, false);
      expect(st.error, isNotNull, reason: 'the failure is told, not swallowed');
    });

    test('switching while disconnected never starts a tunnel', () async {
      final (core, ctrl) = harness(VpnStatus.disconnected);

      await ctrl.selectLocation('p1-b');

      expect(core.calls, ['sync'],
          reason: 'only the persisted config is updated for the next start');
    });

    test('the engine never forwards ICMP itself', () {
      // mihomo's ICMP path is a DIRECT outbound: it dials the target from the
      // physical interface, so a ping placed into the tun leaves outside it and
      // exposes the real address. The stack must answer echo requests instead.
      final location = Location(id: 'a', label: 'DE', proxy: {
        'type': 'vless', 'server': '1.1.1.1', 'port': 443, 'uuid': 'u',
      });
      expect(mihomoTunConfigYaml(location), contains('disable-icmp-forwarding: true'));
    });

    test('the tun section is identical across locations and routings', () {
      // mihomo only skips re-creating the TUN listener (and thus keeps the fd
      // and the NE session) while the tun/dns sections do not change between
      // configs. If a per-location option ever sneaks in there, hot switching
      // silently turns into a session drop — this pins it.
      String section(String yaml, String key) {
        final lines = yaml.split('\n');
        final start = lines.indexOf('$key:');
        expect(start, isNot(-1));
        final buf = <String>[lines[start]];
        for (var i = start + 1; i < lines.length && lines[i].startsWith(' '); i++) {
          buf.add(lines[i]);
        }
        return buf.join('\n');
      }

      final vless = Location(id: 'a', label: 'DE', proxy: {
        'type': 'vless', 'server': '1.1.1.1', 'port': 443, 'uuid': 'u',
      });
      final trojan = Location(id: 'b', label: 'JP', proxy: {
        'type': 'trojan', 'server': '2.2.2.2', 'port': 443, 'password': 'p',
      });
      const split = Routing(mode: 'split', rules: [
        RoutingRule(type: 'domain-suffix', value: 'corp.example.com', action: 'proxy'),
        RoutingRule(type: 'geoip', value: 'ru', action: 'direct'),
      ]);

      final a = mihomoTunConfigYaml(vless);
      final b = mihomoTunConfigYaml(trojan, routing: split);
      final c = mihomoTunConfigYaml(vless, collectLogs: false);
      for (final other in [b, c]) {
        expect(section(other, 'tun'), section(a, 'tun'));
        expect(section(other, 'dns'), section(a, 'dns'));
      }
    });
  });
}

class _FixedProfiles extends ProfilesController {
  _FixedProfiles(this.profiles, this.switching);
  final List<Profile> profiles;
  final bool switching;

  @override
  ProfilesState build() =>
      ProfilesState(profiles: profiles, activeId: profiles.first.id, switching: switching);
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}

class _FixedCore extends VpnCore {
  _FixedCore(this._status);
  final VpnStatus _status;

  @override
  VpnStatus get status => _status;

  @override
  Stream<VpnStatus> statusStream() => const Stream.empty();

  @override
  Stream<VpnStats> statsStream() => const Stream.empty();

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<String?> engineVersion() async => null;
}

class _MinimalCore extends _FixedCore {
  _MinimalCore() : super(VpnStatus.connected);
}

/// Records every call that could touch the tunnel session.
class _RecordingCore extends _FixedCore {
  _RecordingCore(super.status);

  final calls = <String>[];
  bool failReload = false;

  @override
  Future<void> load(NormConfig config) async => calls.add('load');

  @override
  Future<void> connect(String locationId) async => calls.add('connect');

  @override
  Future<void> disconnect() async => calls.add('disconnect');

  @override
  Future<void> reload(NormConfig config, String locationId) async {
    calls.add('reload');
    if (failReload) throw StateError('engine rejected the config');
  }

  @override
  Future<void> syncConfig(NormConfig config, String locationId) async => calls.add('sync');

  @override
  Future<void> removeSystemProfile() async => calls.add('remove');
}
