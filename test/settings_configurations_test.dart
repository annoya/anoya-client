import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/app_version.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/about_screen.dart';
import 'package:anoya/features/settings_screen.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  setUpAll(loadAppVersion);

  Profile profile(String id, String name) => Profile(
    id: id,
    type: ProfileType.link,
    name: name,
    locations: [
      Location(
        id: '$id-l',
        label: 'Germany',
        proxy: {'type': 'vless', 'server': '1.2.3.4'},
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, List<Profile> profiles) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onDemandProvider.overrideWith(_QuietOnDemand.new),
          profilesControllerProvider.overrideWith(
            () => _FixedProfiles(profiles),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a single configuration is named inline and opens directly', (
    tester,
  ) async {
    await pump(tester, [profile('p1', 'backup.single')]);

    expect(find.text('backup.single'), findsOneWidget);
    expect(
      find.text('Configurations'),
      findsNothing,
      reason: 'no aggregate row — the sheet would hold a single entry',
    );
  });

  testWidgets('several configurations collapse into a sheet', (tester) async {
    await pump(tester, [
      profile('p1', 'backup.single'),
      profile('p2', 'work'),
      profile('p3', 'travel'),
    ]);

    expect(find.text('3 configurations'), findsOneWidget);
    expect(
      find.text('backup.single'),
      findsNothing,
      reason: 'no list on the settings screen',
    );

    await tester.tap(find.text('3 configurations'));
    await tester.pumpAndSettle();

    expect(find.text('backup.single'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
    expect(find.text('travel'), findsOneWidget);
    expect(
      find.byIcon(Icons.radio_button_off),
      findsNothing,
      reason: 'the sheet navigates, it does not select the active one',
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('Windows shows no auto-connect card, but keeps Advanced', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await pump(tester, [profile('a', 'Config')]);

    expect(find.text('CONNECTION'), findsOneWidget);
    expect(find.text('On demand'), findsNothing);
    expect(find.text('Always-on VPN'), findsNothing);
    expect(find.text('Advanced'), findsOneWidget);
    // The binding checks foundation overrides before tearDown runs.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('About is one row that already names the build', (tester) async {
    await pump(tester, [profile('a', 'Config')]);
    await tester.scrollUntilVisible(find.text('About'), 200);

    expect(
      find.text('$kAppName $appVersionLabel'),
      findsOneWidget,
      reason: 'the version is what most visits come for',
    );
    expect(
      find.text('Not published yet'),
      findsNothing,
      reason: 'the documents live on the About screen now',
    );
  });

  testWidgets('the row opens the About screen', (tester) async {
    await pump(tester, [profile('a', 'Config')]);
    // scrollUntilVisible stops while the row is still off-screen in the cache extent.
    await tester.scrollUntilVisible(find.text('About'), 200);
    await tester.ensureVisible(find.text('About'));
    await tester.pump();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text(kAppName), findsOneWidget);
    expect(find.text('Version $appVersionLabel'), findsOneWidget);
    expect(find.text(engineVersionLabel), findsOneWidget);

    for (final title in ['Terms of Service', 'Privacy Policy']) {
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, title),
      );
      expect(tile.onTap, isNull, reason: '$title has nowhere to go yet');
    }
    expect(find.text('Not published yet'), findsNWidgets(2));
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
