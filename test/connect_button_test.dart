import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/home_widgets.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoidCallback? onTap) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ConnectButton(
                status: VpnStatus.disconnected,
                onTap: onTap,
              ),
            ),
          ),
        ),
      );

  Finder outline() => find.descendant(
    of: find.byType(ConnectButton),
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border != null &&
          (w.decoration as BoxDecoration).color == null,
    ),
  );

  testWidgets('Tab reaches the ring and Enter presses it', (tester) async {
    var taps = 0;
    await pump(tester, () => taps++);
    expect(outline(), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(outline(), findsOneWidget, reason: 'keyboard focus is shown');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the pointer is a hand over a ring that can be pressed', (
    tester,
  ) async {
    await pump(tester, () {});
    final ring = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byType(ConnectButton),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    expect(ring.mouseCursor, SystemMouseCursors.click);
  });

  testWidgets('a ring with nothing to connect takes no focus', (tester) async {
    await pump(tester, null);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(outline(), findsNothing);
  });
}
