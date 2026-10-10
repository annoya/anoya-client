import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/on_demand_rule_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/on_demand_controller.dart';

void main() {
  const office = OnDemandRule(id: 'r1', name: 'Office');

  Future<_RecordingOnDemand> open(
    WidgetTester tester, {
    bool isNew = false,
  }) async {
    final ctrl = _RecordingOnDemand();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onDemandProvider.overrideWith(() => ctrl)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OnDemandRuleScreen(rule: office, isNew: isNew),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return ctrl;
  }

  testWidgets('an edit is kept only when Save is pressed', (tester) async {
    final ctrl = await open(tester);

    await tester.enterText(find.byType(TextField).first, 'Office HQ');
    await tester.pump(const Duration(seconds: 2));
    expect(ctrl.saved, isEmpty, reason: 'typing alone saves nothing');

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(ctrl.saved.map((r) => r.name), ['Office HQ']);
    expect(find.text('open'), findsOneWidget, reason: 'Save closes the editor');
  });

  testWidgets('Close leaves without saving, a new rule included', (
    tester,
  ) async {
    final ctrl = await open(tester, isNew: true);

    await tester.enterText(find.byType(TextField).first, 'Office HQ');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(ctrl.saved, isEmpty);
    expect(find.text('open'), findsOneWidget);
  });
}

class _RecordingOnDemand extends OnDemandController {
  final saved = <OnDemandRule>[];

  @override
  OnDemandPrefs build() => const OnDemandPrefs();

  @override
  Future<void> upsertRule(OnDemandRule rule) async => saved.add(rule);
}
