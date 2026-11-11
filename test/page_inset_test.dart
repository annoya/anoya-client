import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ds.dart';
import 'package:anoya/core/theme.dart';

void main() {
  testWidgets('the last row scrolls clear of the home indicator', (
    tester,
  ) async {
    const indicator = 34.0;
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(
            size: screen,
            padding: const EdgeInsets.only(bottom: indicator),
          ),
          child: DsPage(
            title: 'Rows',
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(key: ValueKey(i), height: 56, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.byKey(const ValueKey(39)), 400);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey(39))).bottom,
      screen.height - indicator - kScrollPadding.bottom,
    );
  });
}
