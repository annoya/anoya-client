import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/rule_list_store.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/ui.dart';
import 'package:vpn_client/features/config/config_parts.dart';
import 'package:vpn_client/features/config/config_screen.dart';
import 'package:vpn_client/state/on_demand_controller.dart';
import 'package:vpn_client/state/profiles_controller.dart';

/// One screen per domain (ADR-005), each showing only what its domain has.
///
/// The width assertions look pedantic until you know why they exist: the three
/// screens were split out of one, and a Column added along the way handed its
/// children their intrinsic width — so the action buttons quietly stopped
/// spanning the content and no test noticed.
void main() {
  Profile profile(ProfileType type, {Account? account, Routing? routing}) => Profile(
        id: 'p1',
        type: type,
        name: 'Config',
        locations: [
          Location(id: 'l1', label: 'Germany', proxy: {'type': 'vless', 'server': '1.2.3.4'}),
        ],
        serverUrl: type == ProfileType.selfhosted ? 'https://vpn.example' : null,
        subscriptionUrl: type == ProfileType.subscription ? 'https://panel.example/s/a' : null,
        account: account,
        routing: routing,
        refreshedAt: DateTime.now(),
      );

  Future<void> pump(WidgetTester tester, Profile p,
      {List<RuleListStatus>? lists}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onDemandProvider.overrideWith(_QuietOnDemand.new),
        profilesControllerProvider.overrideWith(() => _FixedProfiles([p])),
        // The real one reads the App Group container over a platform channel.
        // A widget test has neither, and what is under test here is what the
        // screen does with the answer, not how it is obtained.
        if (lists != null)
          providerRuleListsProvider.overrideWith((ref, id) async => lists),
      ],
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const ConfigScreen(profileId: 'p1'),
      ),
    ));
    await tester.pump();
  }

  /// Every button on the screen spans the content width, so a stack of them
  /// reads as one column of controls rather than a ragged edge. The buttons sit
  /// at the bottom of a lazy list, so they have to be scrolled into existence
  /// before they can be measured.
  Future<void> expectFullWidthButtons(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Remove configuration'), 200);
    await tester.pump();
    final outer = tester.getSize(find.byType(PageBody).first).width;
    final content = outer < kMaxContentWidth ? outer : kMaxContentWidth;
    final buttons = find.byType(OutlinedButton);
    expect(buttons, findsWidgets);
    for (var i = 0; i < tester.widgetList(buttons).length; i++) {
      final w = tester.getSize(buttons.at(i)).width;
      expect(w, closeTo(content - 2 * kGutter, 1),
          reason: 'button $i is ${w}pt wide, content is ${content}pt');
    }
  }

  testWidgets('a link shows a header, routing and the actions — nothing else',
      (tester) async {
    await pump(tester, profile(ProfileType.link));
    expect(find.text('Single server'), findsOneWidget);
    expect(find.text('Source'), findsNothing, reason: 'a link has no origin to re-ask');
    expect(find.text('Last refreshed'), findsNothing);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Remove configuration'), findsOneWidget);
    await expectFullWidthButtons(tester);
  });

  testWidgets('a subscription shows its source and refresh, but no account',
      (tester) async {
    await pump(tester, profile(ProfileType.subscription));
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Last refreshed'), findsOneWidget);
    expect(find.text('Account'), findsNothing,
        reason: 'a panel never tells us an account state (ADR-005)');
    expect(find.text('THIS DEVICE'), findsNothing,
        reason: 'not until the panel says it counts devices');
    await expectFullWidthButtons(tester);
  });

  testWidgets('a self-hosted configuration is the only one with an account',
      (tester) async {
    await pump(
        tester,
        profile(ProfileType.selfhosted,
            account: Account.fromJson(const {'status': 'active', 'data_limit': 100, 'used_bytes': 20})));
    expect(find.text('Account'), findsOneWidget);
    expect(find.textContaining('Traffic:'), findsOneWidget);
    await expectFullWidthButtons(tester);
  });

  testWidgets('a server-set policy replaces the local routing controls',
      (tester) async {
    await pump(
        tester,
        profile(ProfileType.selfhosted,
            routing: const Routing(mode: 'full', rules: [])));
    expect(find.text('Managed by your organization'), findsOneWidget);
    expect(find.text('Rule set'), findsNothing,
        reason: 'offering a rule set would promise control this config lacks');
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('servers the app cannot run are counted in the header and explained',
      (tester) async {
    // The user counted locations in their provider's panel. A smaller number
    // here with no reason reads as the app losing them.
    await pump(
        tester,
        profile(ProfileType.subscription).copyWithUnsupported({'hysteria2': 12}));
    expect(find.text('Subscription · 1 of 13 servers'), findsOneWidget);
    expect(find.text('12 of 13 servers unsupported'), findsOneWidget);
    expect(find.textContaining('hysteria2'), findsOneWidget);
  });

  testWidgets('a configuration with nothing skipped says only how many it has',
      (tester) async {
    await pump(tester, profile(ProfileType.subscription));
    expect(find.text('Subscription · 1 server'), findsOneWidget);
    expect(find.textContaining('unsupported'), findsNothing);
  });

  testWidgets('a refused device is stated on the screen, not only in a toast',
      (tester) async {
    // The toast leaves after three seconds; the condition does not. Without a
    // card here, a location list full of the provider's placeholders would be
    // unexplainable the moment the toast is gone.
    await pump(
        tester,
        profile(ProfileType.subscription).copyWithDeviceLimitReached());
    expect(find.text('Device limit reached'), findsOneWidget);
    expect(find.textContaining('Free a slot'), findsOneWidget);
  });

  testWidgets('a provider\'s routes are applied, attributed and switchable',
      (tester) async {
    // The difference from a self-hosted policy is the switch: a panel can stop
    // returning servers, but it cannot decide where this device's traffic goes
    // (ADR-005), so the choice has to exist and be visible.
    await pump(tester, profile(ProfileType.subscription).copyWithProviderRoutes());
    expect(find.text('Routes from your provider'), findsOneWidget);
    expect(find.text('Split · 2 rules · 1 not supported'), findsOneWidget,
        reason: 'a summary that reads as complete is the one place this misleads');
    expect(find.text('See what they route'), findsOneWidget);
    final sw = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Routes from your provider'));
    expect(sw.value, isTrue, reason: 'a provider that sent rules meant them');
    expect(find.text('Replaced by the provider\u2019s routes'), findsOneWidget,
        reason: 'the local set must say why it is dimmed, not just look disabled');
  });

  testWidgets('a rule that needs the provider\'s lists says so and offers the switch',
      (tester) async {
    // The count is the point: "not supported" that names its own remedy is
    // actionable, while a bare number only discourages.
    await pump(tester, profile(ProfileType.subscription).copyWithProviderLists(),
        lists: const []);
    expect(find.text('Split · 1 rule · 1 needs their lists'), findsOneWidget);
    expect(find.text('Their rule lists'), findsOneWidget);
    expect(find.text('Off · 1 of their rules need them'), findsOneWidget);
    final sw = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Their rule lists'));
    expect(sw.value, isFalse,
        reason: 'holding someone else\'s files is a separate decision');
  });

  testWidgets('a policy with no external lists is offered no switch for them',
      (tester) async {
    await pump(tester, profile(ProfileType.subscription).copyWithProviderRoutes());
    expect(find.text('Their rule lists'), findsNothing,
        reason: 'a switch that governs nothing is worse than no switch');
  });

  testWidgets('a list that never arrived is reported, with the rest still applied',
      (tester) async {
    // The engine says nothing in this state — a rule whose list is missing
    // matches nothing and the policy quietly changes — so the screen must.
    await pump(
      tester,
      profile(ProfileType.subscription).copyWithProviderLists(accepted: true),
      lists: const [
        RuleListStatus(
          list: RuleList(
              name: 'reject', url: 'https://lists.example/r.yaml', behavior: 'domain'),
          error: 'lists.example: timeout',
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('One list could not be downloaded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Split · 1 rule · 1 list unavailable'), findsOneWidget,
        reason: 'the other rule is still applied, and the gap is still named');
  });

  testWidgets('a downloaded list is counted, not just claimed', (tester) async {
    await pump(
      tester,
      profile(ProfileType.subscription).copyWithProviderLists(accepted: true),
      lists: const [
        RuleListStatus(
          list: RuleList(
              name: 'reject', url: 'https://lists.example/r.yaml', behavior: 'domain'),
          bytes: 214 * 1024,
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Split · 2 rules'), findsOneWidget);
    expect(find.text('1 list · 214 KB'), findsOneWidget);
    expect(find.text('One list could not be downloaded'), findsNothing);
  });

  testWidgets('a subscription with no provider routes keeps its own controls',
      (tester) async {
    await pump(tester, profile(ProfileType.subscription));
    expect(find.text('Routes from your provider'), findsNothing);
    expect(find.text('Routing'), findsOneWidget);
  });

  testWidgets('the active configuration offers no "set active" button', (tester) async {
    await pump(tester, profile(ProfileType.link));
    expect(find.text('Set active'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}

extension on Profile {
  /// A source that offered protocols this app cannot run.
  Profile copyWithUnsupported(Map<String, int> kinds) => Profile(
        id: id,
        type: type,
        name: name,
        locations: locations,
        subscriptionUrl: subscriptionUrl,
        unsupportedServers: kinds,
        refreshedAt: refreshedAt,
      );

  /// A panel that sent routing, one rule of which we could not translate.
  Profile copyWithProviderRoutes() => Profile(
        id: id,
        type: type,
        name: name,
        locations: locations,
        subscriptionUrl: subscriptionUrl,
        providerRouting: const Routing(mode: 'split', rules: [
          RoutingRule(type: 'domain-suffix', value: 'ads.example', action: 'block'),
          RoutingRule(type: 'domain-suffix', value: 'ip.me', action: 'proxy'),
        ]),
        providerRoutingSkipped: 1,
        refreshedAt: refreshedAt,
      );

  /// A panel whose policy points at a list file it hosts itself.
  Profile copyWithProviderLists({bool accepted = false}) => Profile(
        id: id,
        type: type,
        name: name,
        locations: locations,
        subscriptionUrl: subscriptionUrl,
        providerRouting: const Routing(
          mode: 'split',
          rules: [
            RoutingRule(type: 'rule-list', value: 'reject', action: 'block'),
            RoutingRule(type: 'domain-suffix', value: 'ip.me', action: 'proxy'),
          ],
          lists: [
            RuleList(name: 'reject', url: 'https://lists.example/r.yaml', behavior: 'domain'),
          ],
        ),
        providerRuleListsEnabled: accepted,
        refreshedAt: refreshedAt,
      );

  /// The shape a refused refresh leaves behind: the panel's placeholders as
  /// locations, and the flag that explains why they read like that.
  Profile copyWithDeviceLimitReached() => Profile(
        id: id,
        type: type,
        name: name,
        locations: [
          Location(id: 'stub', label: 'Device limit reached', proxy: {
            'type': 'vless',
            'server': '0.0.0.0',
            'port': 1,
          }),
        ],
        subscriptionUrl: subscriptionUrl,
        deviceLimitActive: true,
        deviceLimitReached: true,
        refreshedAt: refreshedAt,
      );
}

class _FixedProfiles extends ProfilesController {
  _FixedProfiles(this.profiles);
  final List<Profile> profiles;

  @override
  ProfilesState build() => ProfilesState(profiles: profiles, activeId: profiles.first.id);
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}
