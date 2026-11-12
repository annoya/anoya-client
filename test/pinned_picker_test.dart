import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ds.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/ui.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  Future<void> open(WidgetTester tester, int members) async {
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
                title: 'Group',
                selected: 'm0',
                pinnedHeader: 'From the subscription',
                pinned: [
                  for (var i = 0; i < members; i++) Option('m$i', 'member-$i'),
                ],
                options: const [],
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

  testWidgets('a list of pinned rows alone does not say nothing matches', (
    tester,
  ) async {
    await open(tester, 3);

    expect(find.text('member-2'), findsOneWidget);
    expect(find.textContaining('Clear the search'), findsNothing);
    expect(find.byType(DsSearchField), findsNothing);
  });

  testWidgets('pinned rows count towards offering a search', (tester) async {
    await open(tester, kSearchThreshold);

    await tester.enterText(find.byType(TextField), 'ber-4');
    await tester.pumpAndSettle();
    expect(find.text('member-4'), findsOneWidget);
    expect(find.text('member-1'), findsNothing);
    expect(find.textContaining('Clear the search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Clear the search to see all $kSearchThreshold'),
      findsOneWidget,
    );
  });
}
