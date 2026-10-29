import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/ds.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/parsers/subscription.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/rule_list_store.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/config/config_screen.dart';
import 'package:anoya/features/config/proxy_groups_screen.dart';
import 'package:anoya/features/config/routing_config_screen.dart';
import 'package:anoya/features/home_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/provider_rule_lists.dart';
import 'package:anoya/state/providers.dart';

import 'support/ds_finders.dart';

const _body = r'''
proxies:
  - {name: 🇩🇪 DE, type: vless, server: de.example, port: 443, uuid: u}
  - {name: 🇳🇱 NL, type: vless, server: nl.example, port: 443, uuid: u}
  - {name: Без VPN, type: direct}
proxy-groups:
  - {name: 🚀 Proxy, type: select, proxies: [Auto, 🇩🇪 DE, 🇳🇱 NL]}
  - {name: Auto, type: url-test, proxies: [🇩🇪 DE, 🇳🇱 NL]}
  - {name: ▶️ YouTube, type: select, proxies: [Auto, Без VPN]}
  - {name: RU сайты, type: select, proxies: [Без VPN]}
rule-providers:
  youtube: {type: http, behavior: domain, url: 'https://lists.example/yt.yaml'}
rules:
  - DOMAIN-SUFFIX,ru,RU сайты
  - RULE-SET,youtube,▶️ YouTube
  - SRC-IP-CIDR,10.0.0.0/8,DIRECT
  - MATCH,🚀 Proxy
''';

void main() {
  final parsed = parseSubscriptionBody(_body);

  Profile profile({bool? rules = true, bool lists = true}) => Profile(
    id: 'p1',
    type: ProfileType.subscription,
    name: 'Nexus',
    locations: parsed.locations,
    groups: parsed.groups,
    plan: parsed.plan,
    subscriptionRules: rules,
    providerRuleListsEnabled: lists,
    subscriptionUrl: 'https://panel.example/s/a',
    refreshedAt: DateTime.now(),
  );

  late _Profiles controller;

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Profile? p,
    List<RuleListStatus> lists = const [],
  }) async {
    controller = _Profiles(p ?? profile());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnCoreProvider.overrideWithValue(_Core()),
          onDemandProvider.overrideWith(_QuietOnDemand.new),
          profilesControllerProvider.overrideWith(() => controller),
          providerRuleListsProvider.overrideWith((ref, id) async => lists),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump();
  }

  group('Home', () {
    testWidgets('with the subscription\'s rules there is no server to pick', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(findRow('Proxy groups'), findsOneWidget);
      expect(findRow('Germany'), findsNothing);
      expect(find.text('Subscription · its rules'), findsOneWidget);
      expect(find.text('The rest via Auto · 3 groups'), findsOneWidget);
    });

    testWidgets('with own rules Home is the server list it always was', (
      tester,
    ) async {
      await pump(tester, const HomeScreen(), p: profile(rules: false));
      expect(findRow('Proxy groups'), findsNothing);
      expect(findRow('DE'), findsOneWidget);
    });
  });

  group('Proxy groups', () {
    testWidgets('the catch-all comes first, then choices, then the rest', (
      tester,
    ) async {
      await pump(
        tester,
        const ProxyGroupsScreen(profileId: 'p1'),
        lists: [
          RuleListStatus(
            list: parsed.plan!.lists.single,
            bytes: 10,
            updatedAt: DateTime(2026),
          ),
        ],
      );
      expect(find.text('Everything else'), findsOneWidget);
      expect(find.text('Choose the exit'), findsOneWidget);
      expect(find.text('Set by the subscription'), findsOneWidget);
      expect(findRow('Proxy'), findsOneWidget);
      expect(findRow('YouTube'), findsOneWidget);
      expect(find.text('Direct, outside the VPN'), findsOneWidget);
      expect(
        find.textContaining('1 rule of the subscription could not be applied'),
        findsOneWidget,
      );
    });

    testWidgets('a group whose list has not arrived says it is waiting', (
      tester,
    ) async {
      await pump(
        tester,
        const ProxyGroupsScreen(profileId: 'p1'),
        lists: [RuleListStatus(list: parsed.plan!.lists.single)],
      );
      expect(find.text('Downloading rule lists · 0 of 1'), findsOneWidget);
      expect(find.text('Auto · waiting for its list'), findsOneWidget);
    });

    testWidgets('the exit sheet offers only what the subscription lists', (
      tester,
    ) async {
      await pump(tester, const ProxyGroupsScreen(profileId: 'p1'));
      await tester.tap(findRow('YouTube'));
      await tester.pumpAndSettle();
      expect(find.text('From the subscription'), findsOneWidget);
      expect(find.text('Default · Lowest latency of 2'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
      expect(find.textContaining('Choose a server'), findsNothing);
      await tester.tap(find.text('Direct'));
      await tester.pumpAndSettle();
      expect(controller.choices, {'▶️ YouTube': 'DIRECT'});
    });
  });

  group('mode', () {
    testWidgets('the configuration says which mode it is in', (tester) async {
      await pump(tester, const ConfigScreen(profileId: 'p1'));
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Subscription rules'), findsOneWidget);
      expect(find.text('Own rules'), findsOneWidget);
    });

    testWidgets('switching to its rules asks before keeping any list', (
      tester,
    ) async {
      await pump(
        tester,
        const ConfigScreen(profileId: 'p1'),
        p: profile(rules: false, lists: false),
      );
      await tester.tap(find.text('Subscription rules'));
      await tester.pumpAndSettle();
      expect(find.text('Use the subscription’s rules?'), findsOneWidget);
      expect(find.textContaining('lists.example'), findsOneWidget);
      await tester.tap(find.text('Own rules').last);
      await tester.pumpAndSettle();
      expect(controller.modes, [false]);
    });

    testWidgets('routing under its rules is readable, not switchable', (
      tester,
    ) async {
      await pump(tester, const RoutingConfigScreen(profileId: 'p1'));
      expect(find.text('Works with Own rules'), findsOneWidget);
      expect(find.byType(DsToggle), findsNothing);
    });
  });
}

class _Profiles extends ProfilesController {
  _Profiles(this.profile);

  Profile profile;
  final choices = <String, String>{};
  final modes = <bool>[];

  @override
  ProfilesState build() =>
      ProfilesState(profiles: [profile], activeId: profile.id);

  @override
  Future<void> setGroupChoice(
    String profileId,
    String group,
    String? choice,
  ) async {
    if (choice != null) choices[group] = choice;
  }

  @override
  Future<bool> setSubscriptionRules(
    String profileId,
    bool enabled, {
    ListConsent? consent,
  }) async {
    final yes =
        !enabled || await (consent?.call(profile) ?? Future.value(false));
    modes.add(yes && enabled);
    return yes;
  }
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}

class _Core extends VpnCore {
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
