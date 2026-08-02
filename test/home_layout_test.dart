import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/vpn_core.dart';
import 'package:vpn_client/features/home_screen.dart';
import 'package:vpn_client/state/on_demand_controller.dart';
import 'package:vpn_client/state/profiles_controller.dart';
import 'package:vpn_client/state/providers.dart';

/// The home screen contract from the spec: the configuration is always on
/// screen (a single one still gets its gear), the picker chevron only appears
/// when there is a choice, and both pickers sit at the bottom edge.
void main() {
  Profile profile(String id, String name) => Profile(
        id: id,
        type: ProfileType.link,
        name: name,
        locations: [
          Location(id: '$id-l', label: 'Germany', proxy: {
            'type': 'vless',
            'server': '94.159.101.110',
          }),
        ],
      );

  Future<void> pump(WidgetTester tester, List<Profile> profiles) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vpnCoreProvider.overrideWithValue(_IdleCore()),
        onDemandProvider.overrideWith(_QuietOnDemand.new),
        profilesControllerProvider.overrideWith(() => _FixedProfiles(profiles)),
      ],
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const HomeScreen()),
    ));
    await tester.pump();
  }

  // The app bar carries a gear of its own (app settings), so every icon
  // expectation is scoped to the configuration card.
  Finder inConfigCard(IconData icon) => find.descendant(
        of: find.widgetWithText(Card, 'backup.single'),
        matching: find.byIcon(icon),
      );

  testWidgets('a single configuration is still shown, with a gear but no chevron',
      (tester) async {
    await pump(tester, [profile('p1', 'backup.single')]);

    expect(find.text('backup.single'), findsOneWidget);
    expect(inConfigCard(Icons.settings_outlined), findsOneWidget);
    expect(inConfigCard(Icons.expand_more), findsNothing,
        reason: 'nothing to pick between');
  });

  testWidgets('a second configuration adds the picker chevron', (tester) async {
    await pump(tester, [profile('p1', 'backup.single'), profile('p2', 'work')]);

    expect(inConfigCard(Icons.settings_outlined), findsOneWidget);
    expect(inConfigCard(Icons.expand_more), findsOneWidget);
  });

  testWidgets('the pickers sit at the bottom, the ring above them', (tester) async {
    await pump(tester, [profile('p1', 'backup.single')]);

    final screen = tester.getSize(find.byType(MaterialApp));
    final serverRow = tester.getRect(find.widgetWithText(Card, 'Germany'));
    expect(screen.height - serverRow.bottom, lessThan(28),
        reason: 'the last card hugs the bottom edge (16 padding + card margin)');

    expect(tester.getRect(find.text('Connect')).bottom, lessThan(serverRow.top));
  });
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

class _IdleCore extends VpnCore {
  @override
  VpnStatus get status => VpnStatus.disconnected;

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
