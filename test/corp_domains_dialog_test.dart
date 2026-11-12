import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ds.dart';
import 'package:anoya/core/routing_prefs.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/corp_domains_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/providers.dart';

void main() {
  testWidgets('a wrong value is named under its own field, inside the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [routingPrefsProvider.overrideWith(_NoPrefs.new)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CorpDomainsScreen(),
        ),
      ),
    );
    await tester.tap(find.text('Add domains…'));
    await tester.pumpAndSettle();

    DsDialogAction save() => tester.widget<DsDialogAction>(
      find.widgetWithText(DsDialogAction, 'Save'),
    );

    await tester.enterText(
      find.byType(TextField).first,
      'corp.local, not a/domain',
    );
    await tester.enterText(find.byType(TextField).last, '10.0.0.53');
    await tester.pump();
    expect(find.textContaining('is not a domain name'), findsOneWidget);
    expect(save().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'corp.local');
    await tester.enterText(find.byType(TextField).last, 'not-an-address');
    await tester.pump();
    expect(find.textContaining('is not a domain name'), findsNothing);
    expect(save().onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, '10.0.0.53');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });
}

class _NoPrefs extends RoutingPrefsController {
  @override
  RoutingPrefs build() => const RoutingPrefs();
}
