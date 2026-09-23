import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/on_demand.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/features/config/config_screen.dart';
import 'package:vpn_client/l10n/l10n.dart';
import 'package:vpn_client/state/on_demand_controller.dart';
import 'package:vpn_client/state/profiles_controller.dart';

/// Removing a configuration from its own settings screen.
///
/// The screen describes something that no longer exists, so it has to close
/// itself. It stopped doing that for the *active* configuration: removing that
/// one also re-points the tunnel, and that extra await lets a frame through —
/// by the time the pop was reached, the widget asking for it had already been
/// replaced by the screen's "nothing to show" placeholder, and the user was
/// left on a blank page with a back arrow.
///
/// Removal outliving the widget that asked for it is normal, so the removal
/// here is deliberately slower than one frame: that is the case that broke.
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

  /// The settings screen as the user reaches it: pushed on top of something.
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

/// Removal that takes longer than the frame in which the state changed — the
/// real one writes the list, drops the favourites and re-renders the tunnel
/// config for the engine.
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
    // A frame goes by before the removal finishes — which is what happens on a
    // device the moment anything after the state change touches the disk or the
    // engine, and the condition the screen has to survive.
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
