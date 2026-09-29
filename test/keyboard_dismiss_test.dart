import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/theme.dart';
import 'package:anoya/core/ui.dart';

void main() {
  final field = FocusNode();
  const outside = Key('outside');

  Widget harness({required bool wrapped}) {
    final body = Scaffold(
      body: Column(
        children: [
          TextField(focusNode: field),
          const SizedBox(
            height: 300,
            width: 300,
            child: ColoredBox(key: outside, color: Color(0xFFEEEEEE)),
          ),
        ],
      ),
    );
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: wrapped ? DismissKeyboardOnTapOutside(child: body) : body,
    );
  }

  tearDown(() => field.unfocus());

  testWidgets('a touch outside the field closes the keyboard', (tester) async {
    await tester.pumpWidget(harness(wrapped: true));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      field.hasFocus,
      isTrue,
      reason: 'the field is where the keyboard came from',
    );

    await tester.tap(find.byKey(outside));
    await tester.pump();

    expect(field.hasFocus, isFalse);
  });

  testWidgets('without it the framework keeps the keyboard up on a touch', (
    tester,
  ) async {
    await tester.pumpWidget(harness(wrapped: false));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.tap(find.byKey(outside));
    await tester.pump();

    expect(field.hasFocus, isTrue);
  });
}
