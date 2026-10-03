import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/theme.dart';
import 'package:anoya/features/logs_screen.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  testWidgets('clearing shows it is under way until the tunnel answers', (
    tester,
  ) async {
    final answer = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async {
        if (call.method == 'clear_logs') await answer.future;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('vpn/control'),
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LogsScreen(),
        ),
      ),
    );
    await tester.pump();

    final clear = find.widgetWithText(OutlinedButton, 'Clear all logs');
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pump();

    expect(
      find.descendant(
        of: clear,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
      reason: 'a silent button read as nothing happening',
    );
    expect(tester.widget<OutlinedButton>(clear).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Save all logs (.zip)'),
          )
          .onPressed,
      isNull,
    );

    answer.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Logs cleared.'), findsOneWidget);
    expect(
      find.descendant(
        of: clear,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });
}
