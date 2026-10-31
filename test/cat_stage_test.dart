import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/cat_sprite.dart';
import 'package:anoya/core/theme.dart';

void main() {
  setUp(CatStage.resetForTests);

  Future<void> pump(
    WidgetTester tester,
    CatMood mood, {
    bool connected = false,
    Brightness brightness = Brightness.dark,
    bool reduceMotion = false,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness),
        home: Scaffold(
          body: Center(
            child: CatStage(mood: mood, strongGlow: connected),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  CatFrame frame(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<CatPainter>()
      .single
      .frame;

  Future<void> taps(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump(const Duration(milliseconds: 90));
    }
  }

  Future<void> rest(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('the glow', () {
    testWidgets('is violet only while connected', (tester) async {
      await pump(tester, CatMood.awake, connected: true);
      expect(find.byKey(const ValueKey('cat-glow-violet')), findsOneWidget);
    });

    testWidgets('is a grey haze otherwise, and only in the dark', (
      tester,
    ) async {
      await pump(tester, CatMood.asleep);
      expect(find.byKey(const ValueKey('cat-glow-muted')), findsOneWidget);

      await pump(tester, CatMood.asleep, brightness: Brightness.light);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('cat-glow-muted')), findsNothing);
      expect(find.byKey(const ValueKey('cat-glow-violet')), findsNothing);
    });
  });

  group('petting the connected cat', () {
    testWidgets('a tap squints it happily, then it settles back', (
      tester,
    ) async {
      await pump(tester, CatMood.awake);
      await taps(tester, 1);
      expect(frame(tester), CatFrame.happy);
      await rest(tester);
      expect(frame(tester), CatFrame.on);
    });

    testWidgets('the fifth tap of a series sends three hearts up', (
      tester,
    ) async {
      await pump(tester, CatMood.awake);
      await taps(tester, 4);
      expect(find.byKey(const ValueKey('cat-heart')), findsNothing);
      await taps(tester, 1);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('cat-heart')), findsNWidgets(3));
      await rest(tester);
      expect(find.byKey(const ValueKey('cat-heart')), findsNothing);
    });

    testWidgets('a theme change mid-series keeps the count', (tester) async {
      await pump(tester, CatMood.awake);
      await taps(tester, 3);
      await pump(tester, CatMood.awake, brightness: Brightness.light);
      await taps(tester, 2);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('cat-heart')), findsNWidgets(3));
    });

    testWidgets('a pause starts a new series', (tester) async {
      await pump(tester, CatMood.awake);
      await taps(tester, 3);
      await rest(tester);
      await taps(tester, 3);
      expect(
        find.byKey(const ValueKey('cat-heart')),
        findsNothing,
        reason: 'three and three are not five',
      );
    });

    testWidgets('the fifteenth tap brings the iron, once per run', (
      tester,
    ) async {
      await pump(tester, CatMood.awake);
      await taps(tester, 15);
      expect(find.byKey(const ValueKey('cat-iron')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('cat-flat')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(frame(tester), CatFrame.error, reason: 'dizzy after the iron');
      await rest(tester);
      expect(find.byKey(const ValueKey('cat-iron')), findsNothing);
      expect(frame(tester), CatFrame.on);

      await taps(tester, 15);
      expect(
        find.byKey(const ValueKey('cat-iron')),
        findsNothing,
        reason: 'after the iron, the fifteenth tap hides the cat instead',
      );
    });

    testWidgets('after the iron, every other series ends in hiding', (
      tester,
    ) async {
      await pump(tester, CatMood.awake);
      await taps(tester, 15);
      await rest(tester);

      await taps(tester, 15);
      await tester.pump(const Duration(milliseconds: 450));
      expect(frame(tester), CatFrame.lookL, reason: 'peeking out');
      await rest(tester);

      await taps(tester, 15);
      await tester.pump(const Duration(milliseconds: 450));
      expect(frame(tester), isNot(CatFrame.lookL), reason: 'not this time');
      await rest(tester);

      await taps(tester, 15);
      await tester.pump(const Duration(milliseconds: 450));
      expect(frame(tester), CatFrame.lookL, reason: 'and again');
      await rest(tester);
    });
  });

  group('the cat at rest', () {
    testWidgets('asks for no frames between blinks', (tester) async {
      await pump(tester, CatMood.awake, connected: true);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('still blinks', (tester) async {
      await pump(tester, CatMood.awake, connected: true);
      final seen = <CatFrame>{};
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        seen.add(frame(tester));
      }
      expect(seen, contains(CatFrame.happy));
      expect(frame(tester), CatFrame.on);
    });

    testWidgets('looks around while connecting', (tester) async {
      await pump(tester, CatMood.looking);
      final first = frame(tester);
      await tester.pump(kCatLookFrame);
      expect(frame(tester), isNot(first));
    });
  });

  group('the sleeping cat', () {
    testWidgets('opens one eye for a moment when tapped', (tester) async {
      await pump(tester, CatMood.asleep);
      expect(frame(tester), CatFrame.off);
      await taps(tester, 1);
      expect(frame(tester), CatFrame.peek);
      await tester.pump(const Duration(milliseconds: 600));
      expect(frame(tester), CatFrame.off);
    });

    testWidgets('does the same under Reduce Motion', (tester) async {
      await pump(tester, CatMood.asleep, reduceMotion: true);
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      expect(frame(tester), CatFrame.peek);
      await tester.pump(const Duration(milliseconds: 700));
      expect(frame(tester), CatFrame.off);
    });
  });

  testWidgets('Reduce Motion pets without the iron or hiding', (tester) async {
    await pump(tester, CatMood.awake, reduceMotion: true);
    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(frame(tester), CatFrame.happy);
    expect(find.byKey(const ValueKey('cat-iron')), findsNothing);
    expect(find.byKey(const ValueKey('cat-heart')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(frame(tester), CatFrame.on);
  });
}
