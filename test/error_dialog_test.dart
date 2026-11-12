import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/app_error.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/ui.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  for (final key in [LogicalKeyboardKey.escape, LogicalKeyboardKey.enter]) {
    testWidgets('${key.keyLabel} closes an error on a keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showErrorDialog(
                  context,
                  const AppError('Couldn’t connect', detail: 'No answer.'),
                ),
                child: const Text('fail'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('fail'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t connect'), findsOneWidget);

      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t connect'), findsNothing);
    });
  }
}
