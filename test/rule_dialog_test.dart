import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/rule_dialog.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  testWidgets('a space never reaches the value, typed or pasted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: RuleDialog(geoReady: true)),
      ),
    );
    await tester.pump();

    final field = find.byType(TextField);
    expect(
      tester.widget<TextField>(field).keyboardType,
      TextInputType.url,
      reason:
          'the text keyboard on Android inserts a space after every full stop',
    );
    await tester.enterText(field, 'vk. ru ');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'vk.ru');
  });
}
