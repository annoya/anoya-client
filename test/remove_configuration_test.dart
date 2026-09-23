import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/config/config_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/on_demand_controller.dart';
import 'package:anoya/state/profiles_controller.dart';

void main() {
  Profile profile(String id, String name) => Profile(
    id: id,
    type: ProfileType.subscription,
    name: name,
    subscriptionUrl: 'https://panel.example/s/$id',
    locations: [
      Location(
        id: '$id-a',
        label: 'Germany',
        proxy: {'type': 'vless', 'server': '1.1.1.1'},
      ),
    ],
  );

  Future<_SlowRemoval> open(WidgetTester tester, String id) async {
    final ctrl = _SlowRemoval([profile('p1', 'nexus'), profile('p2', 'work')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onDemandProvider.overrideWith(_QuietOnDemand.new),
          profilesControllerProvider.overrideWith(() => ctrl),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConfigScreen(profileId: id),
                    ),
                  ),
                  child: const Text('home'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    return ctrl;
  }

  Future<void> remove(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Remove configuration'), 200);
    await tester.tap(find.text('Remove configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
  }

  testWidgets('the active one: the screen closes instead of emptying out', (
    tester,
  ) async {
    final ctrl = await open(tester, 'p1');
    await remove(tester);
    expect(ctrl.removed, ['p1']);
    expect(
      find.text('home'),
      findsOneWidget,
      reason: 'a screen describing a configuration that is gone must close',
    );
    expect(find.byType(ConfigScreen), findsNothing);
  });

  testWidgets('one that is not active closes just the same', (tester) async {
    final ctrl = await open(tester, 'p2');
    await remove(tester);
    expect(ctrl.removed, ['p2']);
    expect(find.byType(ConfigScreen), findsNothing);
  });
}

class _SlowRemoval extends ProfilesController {
  _SlowRemoval(this.profiles);
  final List<Profile> profiles;
  final removed = <String>[];

  @override
  ProfilesState build() =>
      ProfilesState(profiles: profiles, activeId: profiles.first.id);

  @override
  Future<void> removeProfile(String id) async {
    removed.add(id);
    final left = state.profiles.where((p) => p.id != id).toList();
    state = ProfilesState(profiles: left, activeId: left.first.id);
    // A frame must pass before the removal finishes: that is the case that broke.
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> disconnect({bool byUser = true}) async {}
}

class _QuietOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs();
}
