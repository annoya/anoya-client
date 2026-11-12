import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/on_demand.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/on_demand_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/on_demand_controller.dart';

void main() {
  testWidgets('removing the only rule can be undone, switch and all', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onDemandProvider.overrideWith(_InMemoryOnDemand.new)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const OnDemandScreen();
            },
          ),
        ),
      ),
    );
    OnDemandPrefs prefs() => container.read(onDemandProvider);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(prefs().rules, isEmpty);
    expect(prefs().enabled, isFalse);
    expect(find.text('Rule removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(prefs().rules.map((r) => r.name), ['Office']);
    expect(prefs().enabled, isTrue);
  });
}

class _InMemoryOnDemand extends OnDemandController {
  @override
  OnDemandPrefs build() => const OnDemandPrefs(
    enabled: true,
    rules: [OnDemandRule(id: 'r1', name: 'Office')],
  );

  @override
  Future<void> removeRule(String id) async {
    final rules = state.rules.where((r) => r.id != id).toList();
    state = state.copyWith(rules: rules, enabled: rules.isNotEmpty);
  }

  @override
  Future<void> restoreRules(OnDemandPrefs before) async =>
      state = state.copyWith(rules: before.rules, enabled: before.enabled);
}
