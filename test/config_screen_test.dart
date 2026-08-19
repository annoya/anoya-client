import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/ui.dart';
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

  Future<void> pump(WidgetTester tester, Profile p) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onDemandProvider.overrideWith(_QuietOnDemand.new),
        profilesControllerProvider.overrideWith(() => _FixedProfiles([p])),
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

  testWidgets('the active configuration offers no "set active" button', (tester) async {
    await pump(tester, profile(ProfileType.link));
    expect(find.text('Set active'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}

extension on Profile {
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
