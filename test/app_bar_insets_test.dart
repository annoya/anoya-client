import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/theme.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    testWidgets(
      'app bar icons sit as far from either edge on ${platform.name}',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    leading: const BackButton(),
                    title: const Text('Rule sets'),
                    actions: [
                      IconButton(
                        key: const Key('a'),
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () {},
                      ),
                      IconButton(
                        key: const Key('b'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final width = tester.getSize(find.byType(AppBar)).width;
        final back = tester.getCenter(find.byType(BackButton)).dx;
        final last = width - tester.getCenter(find.byKey(const Key('b'))).dx;
        final gap =
            tester.getCenter(find.byKey(const Key('b'))).dx -
            tester.getCenter(find.byKey(const Key('a'))).dx;
        debugDefaultTargetPlatformOverride = null;
        expect(
          last,
          back,
          reason:
              'desktop shrink-wraps icon buttons to 40 unless told otherwise',
        );
        expect(
          gap,
          48,
          reason: 'two actions sit a full 48 apart, as on phones',
        );
      },
    );
  }
}
