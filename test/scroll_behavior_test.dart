import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/ui.dart';

void main() {
  Future<(double, double)> fling(WidgetTester tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 200,
            itemBuilder: (_, i) => SizedBox(height: 56, child: Text('$i')),
          ),
        ),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, -200), 4000);
    await tester.pump();
    final released = controller.offset;
    await tester.pumpAndSettle();
    return (released, controller.offset);
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('on Linux a list stops where the fingers left it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final (released, settled) = await fling(tester);
    debugDefaultTargetPlatformOverride = null;

    expect(
      settled,
      released,
      reason:
          'GTK3 never reports fingers landing on a touchpad, so a fling '
          'could not be stopped by touching it again',
    );
  });

  testWidgets('elsewhere a fling still carries on', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final (released, settled) = await fling(tester);
    debugDefaultTargetPlatformOverride = null;

    expect(settled, greaterThan(released));
  });
}
