import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/ds.dart';
import 'package:anoya/core/theme.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    testWidgets('nav icons sit as far from either edge on ${platform.name}', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const SizedBox()),
            onGenerateInitialRoutes: (navigator, _) => [
              MaterialPageRoute(builder: (_) => const SizedBox()),
              MaterialPageRoute(
                builder: (_) => DsPage(
                  title: 'Rule sets',
                  actions: [
                    DsNavButton(
                      key: const Key('a'),
                      glyph: Glyph.share,
                      onPressed: () {},
                    ),
                    DsNavButton(
                      key: const Key('b'),
                      glyph: Glyph.trash,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      final width = tester.getSize(find.byType(DsNavBar)).width;
      final back = tester.getCenter(find.byType(DsNavButton).first).dx;
      final last = width - tester.getCenter(find.byKey(const Key('b'))).dx;
      final gap =
          tester.getCenter(find.byKey(const Key('b'))).dx -
          tester.getCenter(find.byKey(const Key('a'))).dx;
      debugDefaultTargetPlatformOverride = null;
      expect(back, closeTo(15 + kNavButton / 2, 0.5));
      expect(
        last,
        closeTo(back - 1, 0.5),
        reason: 'the last action sits as far from the right edge',
      );
      expect(
        gap,
        kNavButton + 16,
        reason: 'two actions sit 16 apart, as in the navigation bar',
      );
    });
  }
}
