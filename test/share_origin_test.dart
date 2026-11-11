import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ui.dart';

void main() {
  testWidgets('a share sheet is anchored to a place on the screen', (
    tester,
  ) async {
    late BuildContext screen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            screen = context;
            return const Scaffold();
          },
        ),
      ),
    );

    final origin = shareOrigin(screen);

    expect(
      origin.isEmpty,
      isFalse,
      reason: 'an iPad refuses to open the sheet without an anchor',
    );
    expect(
      (Offset.zero & tester.view.physicalSize).contains(origin.center),
      isTrue,
    );
  });
}
