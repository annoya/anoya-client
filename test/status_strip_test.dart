import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/app_prefs.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/routing_prefs.dart';
import 'package:anoya/core/rule_set.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/config/config_screen.dart';
import 'package:anoya/features/home_screen.dart';
import 'package:anoya/features/logs_screen.dart';
import 'package:anoya/features/on_demand_screen.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';
import 'package:anoya/state/routing_status.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  Profile profile({
    bool routingEnabled = false,
    Routing? managed,
    String? ruleSetId,
  }) => Profile(
    id: 'p1',
    type: ProfileType.subscription,
    name: 'nexus',
    routingEnabled: routingEnabled,
    routing: managed,
    ruleSetId: ruleSetId,
    locations: [
      Location(
        id: 'a',
        label: 'Germany',
        proxy: {'type': 'vless', 'server': '1.1.1.1'},
      ),
    ],
  );

  // Pinned to iOS: the Auto chip is Apple-only, and widget tests default to
  // android.
  group('strip', () {
    Future<void> pump(
      WidgetTester tester, {
      required OnDemandPrefs onDemand,
      required RoutingStatus routing,
      required bool collectLogs,
      bool withProfile = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vpnCoreProvider.overrideWithValue(_FixedCore()),
            onDemandProvider.overrideWith(() => _FixedOnDemand(onDemand)),
            appPrefsProvider.overrideWith(() => _FixedPrefs(collectLogs)),
            routingStatusProvider.overrideWith((_) async => routing),
            profilesControllerProvider.overrideWith(
              () => _FixedProfiles(withProfile ? [profile()] : []),
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

    testWidgets(
      'every chip names its state, not just its subject',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await pump(
          tester,
          onDemand: const OnDemandPrefs(
            enabled: true,
            systemArmed: true,
            rules: [OnDemandRule(id: 'r1')],
          ),
          routing: RoutingStatus.split,
          collectLogs: true,
        );

        expect(find.text('Auto · on'), findsOneWidget);
        expect(find.text('Routing · split'), findsOneWidget);
        expect(find.text('Logs · on'), findsOneWidget);
      },
    );

    testWidgets(
      'nothing enabled still shows three chips',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await pump(
          tester,
          onDemand: const OnDemandPrefs(),
          routing: RoutingStatus.off,
          collectLogs: false,
        );

        expect(find.text('Auto · off'), findsOneWidget);
        expect(find.text('Routing · off'), findsOneWidget);
        expect(find.text('Logs · off'), findsOneWidget);
      },
    );

    testWidgets(
      'armed but not working is its own word',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await pump(
          tester,
          onDemand: const OnDemandPrefs(
            enabled: true,
            paused: true,
            rules: [OnDemandRule(id: 'r1')],
          ),
          routing: RoutingStatus.off,
          collectLogs: false,
        );

        expect(find.text('Auto · paused'), findsOneWidget);
        expect(find.text('Auto · off'), findsNothing);
      },
    );

    testWidgets(
      'chips open the screen that owns the setting',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await pump(
          tester,
          onDemand: const OnDemandPrefs(),
          routing: RoutingStatus.off,
          collectLogs: false,
        );

        await tester.tap(find.text('Logs · off'));
        await tester.pumpAndSettle();
        expect(find.byType(LogsScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(LogsScreen))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Auto · off'));
        await tester.pumpAndSettle();
        expect(find.byType(OnDemandScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(OnDemandScreen))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Routing · off'));
        await tester.pumpAndSettle();
        expect(find.byType(ConfigScreen), findsOneWidget);
      },
    );
  });

  group('routing switch', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vpn-routing-test');
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

    (_RecordingCore, ProfilesController) harness(Profile p, VpnStatus status) {
      final core = _RecordingCore(status);
      final container = ProviderContainer(
        overrides: [
          vpnCoreProvider.overrideWithValue(core),
          onDemandProvider.overrideWith(
            () => _FixedOnDemand(const OnDemandPrefs()),
          ),
          profilesControllerProvider.overrideWith(() => _FixedProfiles([p])),
        ],
      );
      addTearDown(container.dispose);
      return (core, container.read(profilesControllerProvider.notifier));
    }

    const workRules = [
      RoutingRule(
        type: 'domain-suffix',
        value: 'corp.example.com',
        action: 'proxy',
      ),
    ];

    // RoutingRule has no value equality, and rules that came back through the
    // store are fresh instances — compare what they serialise to.
    List<Map<String, dynamic>> shape(List<RoutingRule> rules) => [
      for (final r in rules) r.toJson(),
    ];

    Future<void> writeWorkSet() => RuleSetStore.save([
      const RuleSet(id: RuleSet.defaultId, name: 'Default'),
      const RuleSet(
        id: 'work',
        name: 'Work',
        mode: RoutingMode.split,
        rules: workRules,
      ),
    ]);

    test('switched off, no rule set reaches the engine', () async {
      await writeWorkSet();
      final (_, ctrl) = harness(
        profile(ruleSetId: 'work'),
        VpnStatus.disconnected,
      );

      final config = await ctrl.effectiveConfig(ctrl.state.profiles.single);

      expect(config.routing!.mode, 'full');
      expect(shape(config.routing!.rules), shape(kLanDirectRules));
    });

    test('switched on, the chosen set is what runs', () async {
      await writeWorkSet();
      final (_, ctrl) = harness(
        profile(ruleSetId: 'work', routingEnabled: true),
        VpnStatus.disconnected,
      );

      final config = await ctrl.effectiveConfig(ctrl.state.profiles.single);

      expect(config.routing!.mode, 'split');
      expect(
        shape(config.routing!.rules),
        shape([...kLanDirectRules, ...workRules]),
      );
    });

    test('a server-managed policy ignores the local switch', () async {
      const managed = Routing(mode: 'split', rules: workRules);
      final (_, ctrl) = harness(
        profile(managed: managed),
        VpnStatus.disconnected,
      );

      final config = await ctrl.effectiveConfig(ctrl.state.profiles.single);

      expect(config.routing!.mode, 'split');
      expect(
        shape(config.routing!.rules),
        shape([...kLanDirectRules, ...workRules]),
      );
    });

    test('picking a rule set turns routing on', () async {
      await writeWorkSet();
      final (_, ctrl) = harness(profile(), VpnStatus.disconnected);

      await ctrl.setRuleSet('p1', 'work');

      expect(
        ctrl.state.profiles.single.routingEnabled,
        true,
        reason: 'choosing a set and seeing nothing happen would read as a bug',
      );
      expect(ctrl.state.profiles.single.ruleSetId, 'work');
    });

    test('toggling routing on a live tunnel is a hot reload', () async {
      await writeWorkSet();
      final (core, ctrl) = harness(
        profile(ruleSetId: 'work'),
        VpnStatus.connected,
      );

      await ctrl.setRoutingEnabled('p1', true);
      await ctrl.setRoutingEnabled('p1', false);

      expect(
        core.calls,
        ['reload', 'reload'],
        reason:
            'routing is applied under the standing session, like a server '
            'switch — a stop/start would drop the tunnel and leak',
      );
    });

    test('with the tunnel down only the persisted config is updated', () async {
      await writeWorkSet();
      final (core, ctrl) = harness(
        profile(ruleSetId: 'work'),
        VpnStatus.disconnected,
      );

      await ctrl.setRoutingEnabled('p1', true);

      expect(core.calls, ['sync']);
    });
  });
}

class _FixedProfiles extends ProfilesController {
  _FixedProfiles(this.profiles);
  final List<Profile> profiles;

  @override
  ProfilesState build() => ProfilesState(
    profiles: profiles,
    activeId: profiles.isEmpty ? null : profiles.first.id,
  );
}

class _FixedOnDemand extends OnDemandController {
  _FixedOnDemand(this.prefs);
  final OnDemandPrefs prefs;

  @override
  OnDemandPrefs build() => prefs;
}

class _FixedPrefs extends AppPrefsController {
  _FixedPrefs(this.collectLogs);
  final bool collectLogs;

  @override
  AppPrefs build() => AppPrefs(collectLogs: collectLogs);
}

class _FixedCore extends VpnCore {
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

class _RecordingCore extends _FixedCore {
  _RecordingCore(this._status);
  final VpnStatus _status;

  final calls = <String>[];

  @override
  VpnStatus get status => _status;

  @override
  Future<void> connect(String locationId) async => calls.add('connect');

  @override
  Future<void> disconnect() async => calls.add('disconnect');

  @override
  Future<void> reload(NormConfig config, String locationId) async =>
      calls.add('reload');

  @override
  Future<void> syncConfig(NormConfig config, String locationId) async =>
      calls.add('sync');
}
