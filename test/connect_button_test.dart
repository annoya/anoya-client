import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/home_widgets.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    VoidCallback? onTap, {
    VpnStatus status = VpnStatus.disconnected,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: ConnectButton(status: status, onTap: onTap)),
      ),
    ),
  );

  bool focused(WidgetTester tester) =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<ConnectButton>() !=
      null;

  testWidgets('Tab reaches the connect button and Enter presses it', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, () => taps++);
    expect(focused(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(tester), isTrue, reason: 'keyboard focus lands on it');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the pointer is a hand over a button that can be pressed', (
    tester,
  ) async {
    await pump(tester, () {});
    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(ConnectButton),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.onTap, isNotNull);
    expect(ink.mouseCursor ?? SystemMouseCursors.click, SystemMouseCursors.click);
  });

  testWidgets('a button with nothing to connect takes no focus', (
    tester,
  ) async {
    await pump(tester, null);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(focused(tester), isFalse);
  });

  testWidgets('the label names what the press does', (tester) async {
    await pump(tester, () {}, status: VpnStatus.connected);
    expect(find.text('Disconnect'), findsOneWidget);
    await pump(tester, () {}, status: VpnStatus.connecting);
    expect(find.text('Cancel'), findsOneWidget);
    await pump(tester, () {});
    expect(find.text('Connect'), findsOneWidget);
  });
}
