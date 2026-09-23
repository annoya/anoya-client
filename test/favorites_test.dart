import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/favorites.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/ui.dart';
import 'package:vpn_client/l10n/l10n.dart';

void main() {
  group('model', () {
    test('locations are keyed per profile — two profiles may reuse an id', () {
      var f = const Favorites();
      f = f.toggleLocation('p1', 'de-1');
      expect(f.locationsOf('p1'), {'de-1'});
      expect(
        f.locationsOf('p2'),
        isEmpty,
        reason: 'a location id is only unique inside its profile',
      );
    });

    test('toggle adds then removes', () {
      final on = const Favorites().toggleProfile('p1');
      expect(on.profiles, {'p1'});
      expect(on.toggleProfile('p1').profiles, isEmpty);
    });

    test('removing a configuration takes its servers with it', () {
      final f = const Favorites()
          .toggleProfile('p1')
          .toggleLocation('p1', 'de-1')
          .toggleLocation('p2', 'nl-1')
          .forgetProfile('p1');
      expect(f.profiles, isEmpty);
      expect(f.locationsOf('p1'), isEmpty);
      expect(f.locationsOf('p2'), {'nl-1'}, reason: 'other profiles untouched');
    });

    test('json round-trip', () {
      final f = const Favorites()
          .toggleProfile('p1')
          .toggleLocation('p1', 'de-1');
      final back = Favorites.fromJson(f.toJson());
      expect(back.profiles, {'p1'});
      expect(back.locations, {'p1/de-1'});
    });
  });

  group('picker', () {
    final options = [
      for (var i = 1; i <= 7; i++)
        Option('s$i', 'server-$i', subtitle: '10.0.0.$i'),
    ];

    Future<void> open(
      WidgetTester tester, {
      Set<String> favorites = const {},
      ValueChanged<String>? onToggleFavorite,
      ValueChanged<String>? onOpenSettings,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickOption<String>(
                  context,
                  title: 'Server',
                  options: options,
                  selected: 's1',
                  itemNoun: 'server',
                  favorites: favorites,
                  onToggleFavorite: onToggleFavorite,
                  onOpenSettings: onOpenSettings,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('favourites sit above the rest', (tester) async {
      await open(tester, favorites: {'s5'}, onToggleFavorite: (_) {});

      expect(find.text('FAVORITES'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(
        tester.getRect(find.text('server-5')).top,
        lessThan(tester.getRect(find.text('server-1')).top),
      );
    });

    testWidgets('the star reports the toggle and keeps the sheet open', (
      tester,
    ) async {
      final toggled = <String>[];
      await open(tester, onToggleFavorite: toggled.add);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'server-3'),
          matching: find.byIcon(Icons.star_border),
        ),
      );
      await tester.pumpAndSettle();

      expect(toggled, ['s3']);
      expect(
        find.text('Server'),
        findsOneWidget,
        reason: 'the sheet stays open',
      );
      expect(
        tester.getRect(find.text('server-3')).top,
        lessThan(tester.getRect(find.text('server-1')).top),
        reason: 'it moves into FAVORITES immediately',
      );
    });

    testWidgets('search filters both groups and counts the matches', (
      tester,
    ) async {
      await open(tester, favorites: {'s5'}, onToggleFavorite: (_) {});

      await tester.enterText(find.byType(TextField), '10.0.0.2');
      await tester.pumpAndSettle();

      expect(find.text('server-2'), findsOneWidget);
      expect(find.text('server-1'), findsNothing);
      expect(
        find.text('server-5'),
        findsNothing,
        reason: 'a favourite that does not match is filtered out like the rest',
      );
      expect(find.text('FAVORITES'), findsNothing);
      expect(find.text('ALL · 1 OF 7 MATCH'), findsOneWidget);
    });

    testWidgets('a matching favourite keeps its place on top', (tester) async {
      await open(tester, favorites: {'s5'}, onToggleFavorite: (_) {});

      await tester.enterText(find.byType(TextField), 'server-');
      await tester.pumpAndSettle();

      expect(find.text('FAVORITES'), findsOneWidget);
      expect(
        tester.getRect(find.text('server-5')).top,
        lessThan(tester.getRect(find.text('server-1')).top),
      );
    });

    testWidgets('a search with no match says so and names the total', (
      tester,
    ) async {
      await open(tester, favorites: {'s5'}, onToggleFavorite: (_) {});

      await tester.enterText(find.byType(TextField), 'reykjavik');
      await tester.pumpAndSettle();

      expect(find.text('ALL · NOTHING MATCHES'), findsOneWidget);
      expect(
        find.textContaining('Clear the search to see all 7'),
        findsOneWidget,
      );
    });

    testWidgets('without favourites the sheet stays a plain list', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('FAVORITES'), findsNothing);
      expect(find.text('ALL'), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
    });

    testWidgets('the current value is a filled, selected row — no check mark', (
      tester,
    ) async {
      await open(tester);

      expect(find.byIcon(Icons.check), findsNothing);
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      final selected = tiles.where((t) => t.selected).toList();
      expect(selected.length, 1, reason: 'exactly the current value');
      expect(selected.single.selectedTileColor, isNotNull);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'server-1'))
            .selected,
        true,
      );
    });

    testWidgets(
      'a long list stops at 80% of the screen, leaving scrim to tap',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => pickOption<String>(
                    context,
                    title: 'Server',
                    options: [
                      for (var i = 0; i < 40; i++)
                        Option('s$i', 'server-$i', subtitle: 'host-$i'),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final screen = tester.getSize(find.byType(MaterialApp)).height;
        final sheet = tester.getRect(find.byType(BottomSheet));
        expect(
          sheet.height,
          lessThanOrEqualTo(screen * kSheetMaxHeightFraction + 1),
        );
        expect(
          sheet.top,
          greaterThan(0),
          reason: 'the scrim above the sheet is what a tap closes it with',
        );
      },
    );

    testWidgets('the list hosts its own ink, inside a clip', (tester) async {
      await open(tester);

      final clip = find.ancestor(
        of: find.byType(ListView),
        matching: find.byType(ClipRect),
      );
      expect(clip, findsWidgets);
      final inkHost = find.descendant(
        of: clip.first,
        matching: find.byType(Material),
      );
      expect(
        find.descendant(of: inkHost.first, matching: find.byType(ListView)),
        findsOneWidget,
      );
    });

    testWidgets('the gear closes the sheet and reports the value', (
      tester,
    ) async {
      final opened = <String>[];
      await open(tester, onOpenSettings: opened.add);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'server-4'),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(opened, ['s4']);
      expect(
        find.text('Server'),
        findsNothing,
        reason: 'the settings screen would otherwise open behind the sheet',
      );
    });
  });
}
