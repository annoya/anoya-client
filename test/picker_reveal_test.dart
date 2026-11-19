import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ds.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/ui.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  Future<void> open(WidgetTester tester, {required String selected}) async {
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
                selected: selected,
                favorites: const {'s3'},
                onToggleFavorite: (_) {},
                options: [
                  for (var i = 0; i < 60; i++) Option('s$i', 'server-$i'),
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
  }

  bool onScreen(WidgetTester tester, String title) {
    final at = tester.getRect(find.text(title, skipOffstage: false));
    final screen = tester.getRect(find.byType(Scaffold).first);
    return at.top >= screen.top && at.bottom <= screen.bottom;
  }

  testWidgets('the list opens on the server in use, not at its top', (
    tester,
  ) async {
    await open(tester, selected: 's45');

    expect(onScreen(tester, 'server-45'), isTrue);
    expect(onScreen(tester, 'server-3'), isFalse);
  });

  testWidgets('a choice already in view leaves the list where it starts', (
    tester,
  ) async {
    await open(tester, selected: 's3');

    expect(onScreen(tester, 'server-3'), isTrue);
    expect(onScreen(tester, 'Favorites'), isTrue);
  });
}
