import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression for the black screen after deleting the last configuration.
///
/// The shell swaps `home` to the add screen and unwinds any pushed routes. A
/// screen that also pops itself in the same turn used to race that unwind and
/// take the root route down with it, leaving an empty navigator — a black
/// screen. These tests pin the two rules that prevent it: the unwind never
/// pops the root, and a screen only closes itself while something remains.
void main() {
  final navigator = GlobalKey<NavigatorState>();

  Widget shell({required bool hasProfiles}) => MaterialApp(
        navigatorKey: navigator,
        home: hasProfiles
            ? const Scaffold(body: Text('home'))
            : const Scaffold(body: Text('add a connection')),
      );

  testWidgets('unwinding to the root keeps one route, never empties the stack',
      (tester) async {
    await tester.pumpWidget(shell(hasProfiles: true));
    navigator.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('settings'))));
    await tester.pumpAndSettle();
    navigator.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('configuration'))));
    await tester.pumpAndSettle();
    expect(find.text('configuration'), findsOneWidget);

    // The shell reacts to the last configuration disappearing.
    await tester.pumpWidget(shell(hasProfiles: false));
    if (navigator.currentState!.canPop()) {
      navigator.currentState!.popUntil((r) => r.isFirst);
    }
    await tester.pumpAndSettle();

    expect(find.text('add a connection'), findsOneWidget);
    expect(find.text('configuration'), findsNothing);
    expect(find.text('settings'), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse,
        reason: 'the root route must survive the unwind');
  });

  testWidgets('a screen popping itself after the unwind would empty the stack',
      (tester) async {
    await tester.pumpWidget(shell(hasProfiles: true));
    navigator.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('configuration'))));
    await tester.pumpAndSettle();

    await tester.pumpWidget(shell(hasProfiles: false));
    navigator.currentState!.popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();

    // This is the extra pop the configuration screen used to do unconditionally.
    // Guarding it on "are there configurations left" is what keeps the shell
    // visible; without the guard the navigator ends up empty.
    final wouldPopRoot = navigator.currentState!.canPop();
    expect(wouldPopRoot, isFalse,
        reason: 'nothing left to pop — an unconditional pop here blanks the app');
  });
}
