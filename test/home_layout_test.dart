import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    type: ProfileType.link,
    name: name,
    locations: [
      Location(
        id: '$id-l',
        label: 'Germany',
        proxy: {'type': 'vless', 'server': '94.159.101.110'},
      ),
    ],
  );

  Profile withGroups() => Profile(
    id: 'sub',
    type: ProfileType.subscription,
    name: 'Remnawave',
    subscriptionUrl: 'https://sub.example/t',
    locations: [
      for (var i = 1; i <= 3; i++)
        Location(
          id: 's$i',
          label: 'VLESS Reality $i',
          proxy: {'type': 'vless', 'server': '10.0.0.$i'},
        ),
    ],
    groups: const [
      ProxyGroup(
        name: '⚡️ Fastest',
        type: 'url-test',
        members: ['s1', 's2', 's3'],
        intervalSeconds: 300,
        tolerance: 150,
      ),
      ProxyGroup(
        name: '🛟 Failover',
        type: 'fallback',
        members: ['s1', 's2', 's3'],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, List<Profile> profiles) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnCoreProvider.overrideWithValue(_IdleCore()),
          onDemandProvider.overrideWith(_QuietOnDemand.new),
          profilesControllerProvider.overrideWith(
            () => _FixedProfiles(profiles),
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

  Finder inConfigCard(IconData icon) => find.descendant(
    of: find.widgetWithText(Card, 'backup.single'),
    matching: find.byIcon(icon),
  );

  testWidgets(
    'a single configuration is still shown, with a gear but no chevron',
    (tester) async {
      await pump(tester, [profile('p1', 'backup.single')]);

      expect(find.text('backup.single'), findsOneWidget);
      expect(inConfigCard(Icons.settings_outlined), findsOneWidget);
      expect(
        inConfigCard(Icons.expand_more),
        findsNothing,
        reason: 'nothing to pick between',
      );
    },
  );

  testWidgets('a second configuration adds the picker chevron', (tester) async {
    await pump(tester, [profile('p1', 'backup.single'), profile('p2', 'work')]);

    expect(inConfigCard(Icons.settings_outlined), findsOneWidget);
    expect(inConfigCard(Icons.expand_more), findsOneWidget);
  });

  testWidgets('the pickers sit at the bottom, the ring above them', (
    tester,
  ) async {
    await pump(tester, [profile('p1', 'backup.single')]);

    final screen = tester.getSize(find.byType(MaterialApp));
    final serverRow = tester.getRect(find.widgetWithText(Card, 'Germany'));
    expect(
      screen.height - serverRow.bottom,
      lessThan(28),
      reason: 'the last card hugs the bottom edge (16 padding + card margin)',
    );

    expect(
      tester.getRect(find.text('Connect')).bottom,
      lessThan(serverRow.top),
    );
  });
  testWidgets('a subscription\'s groups reach the picker, above the servers', (
    tester,
  ) async {
    await pump(tester, [withGroups()]);
    await tester.tap(find.byIcon(Icons.chevron_right).last);
    await tester.pumpAndSettle();

    expect(find.text('CHOSEN BY THE ENGINE'), findsOneWidget);
    expect(find.text('⚡️ Fastest'), findsOneWidget);
    expect(find.text('🛟 Failover'), findsOneWidget);
    expect(
      find.textContaining('Lowest latency of 3'),
      findsOneWidget,
      reason: 'the row says what the group does, not what its type is called',
    );
    expect(
      find.text('VLESS Reality 1'),
      findsNWidgets(2),
      reason: 'the servers are still there, below',
    );

    final header = tester.getTopLeft(find.text('CHOSEN BY THE ENGINE')).dy;
    expect(
      header,
      lessThan(tester.getTopLeft(find.text('VLESS Reality 1').last).dy),
    );
  });

  testWidgets('the configuration line counts the groups it offers', (
    tester,
  ) async {
    await pump(tester, [withGroups()]);
    expect(find.textContaining('3 servers · 2 groups'), findsOneWidget);
  });

  testWidgets(
    'a refreshable configuration can be refreshed from the home screen',
    (tester) async {
      await pump(tester, [
        Profile(
          id: 'sub',
          type: ProfileType.subscription,
          name: 'Remnawave',
          subscriptionUrl: 'https://sub.example/t',
          locations: [
            Location(
              id: 's1',
              label: 'Germany',
              proxy: {'type': 'vless', 'server': '1.2.3.4'},
            ),
          ],
        ),
      ]);
      final card = find.widgetWithText(Card, 'Remnawave');
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.refresh)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsOneWidget,
        reason: 'refresh sits beside the gear, it does not replace it',
      );
    },
  );

  testWidgets('a single link has no refresh button, having nothing to re-ask', (
    tester,
  ) async {
    await pump(tester, [profile('a', 'Config')]);
    expect(find.byIcon(Icons.refresh), findsNothing);
  });

  testWidgets('the server row names the transport, not just the protocol', (
    tester,
  ) async {
    await pump(tester, [
      Profile(
        id: 'sub',
        type: ProfileType.subscription,
        name: 'Remnawave',
        subscriptionUrl: 'https://sub.example/t',
        locations: [
          Location(
            id: 's1',
            label: 'Germany',
            proxy: {'type': 'vless', 'server': '1.2.3.4', 'network': 'xhttp'},
          ),
        ],
      ),
    ]);
    expect(find.text('VLESS · XHTTP · No TLS'), findsOneWidget);
    expect(
      find.textContaining('1.2.3.4'),
      findsNothing,
      reason: 'the endpoint is not something the interface shows',
    );
  });
}

class _FixedProfiles extends ProfilesController {
  _FixedProfiles(this.profiles);
  final List<Profile> profiles;

  @override
  ProfilesState build() =>
      ProfilesState(profiles: profiles, activeId: profiles.first.id);
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}

class _IdleCore extends VpnCore {
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
