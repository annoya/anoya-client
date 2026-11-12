import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/log.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/log_viewer_screen.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  testWidgets('a burst of log lines redraws the app log once', (tester) async {
    Log.clear();
    Log.i('before the burst');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LogViewerScreen(title: 'App', appLog: true),
      ),
    );
    await tester.pump();

    String shown() =>
        tester.widget<SelectableText>(find.byType(SelectableText)).data!;

    for (var i = 0; i < 20; i++) {
      Log.i('line $i');
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(shown(), isNot(contains('line 19')));

    await tester.pump(kLogViewerRefreshDelay);
    expect(shown(), contains('line 19'));
  });

  testWidgets('a log being read holds still until the reader is back at the '
      'end', (tester) async {
    Log.clear();
    for (var i = 0; i < 200; i++) {
      Log.i('line $i');
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LogViewerScreen(title: 'App', appLog: true),
      ),
    );
    await tester.pumpAndSettle();

    String shown() =>
        tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, position.maxScrollExtent);

    position.jumpTo(position.maxScrollExtent / 2);
    final reading = position.pixels;
    Log.i('arrived while reading');
    await tester.pump(kLogViewerRefreshDelay);
    await tester.pump();
    expect(position.pixels, reading);
    expect(shown(), isNot(contains('arrived while reading')));

    position.jumpTo(position.maxScrollExtent);
    Log.i('arrived at the end');
    await tester.pump(kLogViewerRefreshDelay);
    await tester.pump();
    expect(shown(), contains('arrived while reading'));
    expect(shown(), contains('arrived at the end'));
    expect(position.pixels, position.maxScrollExtent);
  });
}
