import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/start_screen.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StartScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Finder chip(String text) => find.textContaining(text);

  testWidgets('a recognised link is confirmed immediately', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.byType(TextField),
      'vless://uuid@1.2.3.4:443?type=tcp#Tokyo',
    );
    await tester.pump();
    expect(chip('server · Tokyo'), findsOneWidget);
    expect(chip('Can’t use this'), findsNothing);
  });

  testWidgets('a refusal waits for the typing to stop, then says why', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'tuic://a:b@h.example:443');
    await tester.pump();
    expect(
      chip('Can’t use this'),
      findsNothing,
      reason: 'half a paste is not a verdict yet',
    );

    await tester.pump(const Duration(milliseconds: 700));
    expect(chip('Can’t use this · tuic:// isn’t supported'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'more typing restarts the wait; a recognised link clears the verdict',
    (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'vless://asd');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'vless://asdasd');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        chip('Can’t use this'),
        findsNothing,
        reason: 'the clock restarts on every change',
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(chip('vless:// link can’t be read'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'vless://uuid@1.2.3.4:443?type=tcp#Tokyo',
      );
      await tester.pump();
      expect(chip('Can’t use this'), findsNothing);
      expect(chip('server · Tokyo'), findsOneWidget);
    },
  );

  testWidgets('clearing the field says nothing', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'nonsense');
    await tester.pump(const Duration(milliseconds: 700));
    expect(chip('Can’t use this'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 700));
    expect(chip('Can’t use this'), findsNothing);
  });
}
