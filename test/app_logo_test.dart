import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/app_logo.dart';

void main() {
  testWidgets('a stretched column does not blow the logo up past its size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [AppLogo(size: 56, color: Color(0xFF000000))],
            ),
          ),
        ),
      ),
    );

    final paint = tester.renderObject(
      find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      paint,
      paints..path(
        includes: [const Offset(172 + 2.8, 2.8)],
        excludes: [const Offset(2.8, 2.8), const Offset(200, 380)],
      ),
    );
  });
}
