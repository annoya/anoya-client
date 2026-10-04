import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/mihomo_tun_config.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/home_screen.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
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
  );

  Future<void> pump(
    WidgetTester tester, {
    required VpnStatus status,
    bool switching = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnCoreProvider.overrideWithValue(_FixedCore(status)),
          onDemandProvider.overrideWith(_QuietOnDemand.new),
          profilesControllerProvider.overrideWith(
            () => _FixedProfiles([
              profile('p1', 'nexus'),
              profile('p2', 'work'),
            ], switching),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  ListTile tile(WidgetTester tester, String title) =>
      tester.widget<ListTile>(find.widgetWithText(ListTile, title));

  testWidgets('a connected tunnel keeps both pickers active — no locks', (
    tester,
  ) async {
    await pump(tester, status: VpnStatus.connected);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(tile(tester, 'nexus').onTap, isNotNull);
    expect(tile(tester, 'Germany').onTap, isNotNull);
  });

  testWidgets('the initial connect is the only state with locks', (
    tester,
  ) async {
    await pump(tester, status: VpnStatus.connecting);

    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    expect(tile(tester, 'nexus').onTap, isNull);
    expect(tile(tester, 'Germany').onTap, isNull);
  });

  testWidgets('a switch in flight announces itself and ignores taps', (
    tester,
  ) async {
    await pump(tester, status: VpnStatus.connected, switching: true);

    expect(find.text('Switching server…'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(tile(tester, 'nexus').onTap, isNull);
    expect(tile(tester, 'Germany').onTap, isNull);
  });

  test('a core without hot reload says so instead of pretending', () {
    final config = NormConfig(
      version: 1,
      account: Account.fromJson(const {}),
      locations: const [],
    );
    expect(_MinimalCore().reload(config, 'x'), throwsUnsupportedError);
  });

  group('leak invariants', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vpn-switch-test');
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('vpn/control'),
        (call) async => throw PlatformException(code: 'no platform in tests'),
      );
    });
    tearDown(() {
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

    (_RecordingCore, ProfilesController) harness(VpnStatus status) {
      final core = _RecordingCore(status);
      final container = ProviderContainer(
        overrides: [
          vpnCoreProvider.overrideWithValue(core),
          onDemandProvider.overrideWith(_QuietOnDemand.new),
          profilesControllerProvider.overrideWith(
            () => _FixedProfiles([
              profile('p1', 'nexus'),
              profile('p2', 'work'),
            ], false),
          ),
        ],
      );
      addTearDown(container.dispose);
      return (core, container.read(profilesControllerProvider.notifier));
    }

    test(
      'switching a location or profile on a live tunnel is reload-only',
      () async {
        final (core, ctrl) = harness(VpnStatus.connected);

        await ctrl.selectLocation('p1-b');
        await ctrl.setActive('p2');

        expect(
          core.calls,
          ['reload', 'reload'],
          reason:
              'no stop/start anywhere on the switch path — the session '
              'must stay up, or the OS routes fall back and traffic leaks',
        );
      },
    );

    test('a poll reapply on a live tunnel is reload-only too', () async {
      final (core, ctrl) = harness(VpnStatus.connected);

      final before = profile('p1', 'nexus');
      final after = Profile(
        id: 'p1',
        type: ProfileType.subscription,
        name: 'nexus',
        locations: [
          Location(
            id: 'p1-a',
            label: 'Germany',
            proxy: {'type': 'vless', 'server': '9.9.9.9'},
          ),
          Location(
            id: 'p1-b',
            label: 'Japan',
            proxy: {'type': 'vless', 'server': '2.2.2.2'},
          ),
        ],
      );
      await ctrl.maybeReapply(before, after);

      expect(
        core.calls,
        ['reload'],
        reason:
            'a background reapply must never stop/start or re-persist '
            'the session — that is the reconnect leak ADR-002 closes',
      );
    });

    test(
      'an account the server turned off is disconnected and told why',
      () async {
        final (core, ctrl) = harness(VpnStatus.connected);
        final before = profile('p1', 'nexus');
        final after = Profile(
          id: 'p1',
          type: ProfileType.selfhosted,
          name: 'nexus',
          locations: before.locations,
          account: Account(displayName: 'Alice', status: 'deactivated'),
        );
        await ctrl.maybeReapply(before, after);

        expect(core.calls, ['disconnect']);
        expect(
          ctrl.state.error?.title,
          L10n.current.accountDeactivatedTitle,
          reason:
              'a tunnel that vanishes on a poll with no word reads as a crash',
        );
      },
    );

    test(
      'a server the poll no longer lists is not a reason to drop the tunnel',
      () async {
        final (core, ctrl) = harness(VpnStatus.connected);
        final before = profile('p1', 'nexus');
        final after = Profile(
          id: 'p1',
          type: ProfileType.subscription,
          name: 'nexus',
          locations: [before.locations.last],
        );
        await ctrl.maybeReapply(before, after);

        expect(
          core.calls,
          isEmpty,
          reason:
              'management drops a worker it has not heard from in 45 s while the '
              'worker keeps serving; disconnecting sends traffic around the tunnel',
        );
      },
    );

    test('a failed switch leaves the running tunnel alone', () async {
      final (core, ctrl) = harness(VpnStatus.connected);
      core.failReload = true;

      await ctrl.selectLocation('p1-b');

      expect(
        core.calls,
        ['reload'],
        reason:
            'no disconnect as error handling: dropping the session is '
            'the one thing that can actually leak',
      );
      final st = ctrl.state;
      expect(st.switching, false);
      expect(st.error, isNotNull, reason: 'the failure is told, not swallowed');
      expect(st.selectionId, 'p1-a', reason: 'the picker stays on the old one');
    });

    test('switching while disconnected never starts a tunnel', () async {
      final (core, ctrl) = harness(VpnStatus.disconnected);

      await ctrl.selectLocation('p1-b');

      expect(core.calls, [
        'sync',
      ], reason: 'only the persisted config is updated for the next start');
    });

    test('the engine never forwards ICMP itself', () {
      final location = Location(
        id: 'a',
        label: 'DE',
        proxy: {'type': 'vless', 'server': '1.1.1.1', 'port': 443, 'uuid': 'u'},
      );
      expect(
        mihomoTunConfigYaml(location),
        contains('disable-icmp-forwarding: true'),
      );
    });

    test('the tun section is identical across locations and routings', () {
      String section(String yaml, String key) {
        final lines = yaml.split('\n');
        final start = lines.indexOf('$key:');
        expect(start, isNot(-1));
        final buf = <String>[lines[start]];
        for (
          var i = start + 1;
          i < lines.length && lines[i].startsWith(' ');
          i++
        ) {
          buf.add(lines[i]);
        }
        return buf.join('\n');
      }

      final vless = Location(
        id: 'a',
        label: 'DE',
        proxy: {'type': 'vless', 'server': '1.1.1.1', 'port': 443, 'uuid': 'u'},
      );
      final trojan = Location(
        id: 'b',
        label: 'JP',
        proxy: {
          'type': 'trojan',
          'server': '2.2.2.2',
          'port': 443,
          'password': 'p',
        },
      );
      const split = Routing(
        mode: 'split',
        rules: [
          RoutingRule(
            type: 'domain-suffix',
            values: ['corp.example.com'],
            action: 'proxy',
          ),
          RoutingRule(type: 'geoip', values: ['ru'], action: 'direct'),
        ],
      );

      final a = mihomoTunConfigYaml(vless);
      final b = mihomoTunConfigYaml(trojan, routing: split);
      final c = mihomoTunConfigYaml(vless, collectLogs: false);
      final d = mihomoTunConfigYaml(
        vless,
        dns: ['https://dns.google/dns-query'],
      );
      for (final other in [b, c, d]) {
        expect(section(other, 'tun'), section(a, 'tun'));
      }
      for (final other in [b, c]) {
        expect(section(other, 'dns'), section(a, 'dns'));
      }
      expect(section(d, 'dns'), isNot(section(a, 'dns')));
      expect(section(d, 'dns'), contains('fake-ip-range: 198.18.0.1/16'));
    });
  });
}

class _FixedProfiles extends ProfilesController {
  _FixedProfiles(this.profiles, this.switching);
  final List<Profile> profiles;
  final bool switching;

  @override
  ProfilesState build() => ProfilesState(
    profiles: profiles,
    activeId: profiles.first.id,
    switching: switching,
  );
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
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}
}

class _MinimalCore extends _FixedCore {
  _MinimalCore() : super(VpnStatus.connected);
}

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
  Future<void> syncConfig(NormConfig config, String locationId) async =>
      calls.add('sync');

  @override
  Future<void> removeSystemProfile() async => calls.add('remove');
}
