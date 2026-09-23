import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/platform_support.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/always_on_screen.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('describes the switch and offers no toggle of its own', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AlwaysOnScreen(),
      ),
    );
    expect(find.text('Started by the system'), findsOneWidget);
    expect(find.text('Block connections without VPN'), findsOneWidget);
    expect(
      find.byType(Switch),
      findsNothing,
      reason: 'the switch is the system’s; ours would show a guess',
    );
  });

  testWidgets('the one button opens the system’s VPN settings', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vpn/control'), (
          call,
        ) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('vpn/control'), null),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AlwaysOnScreen(),
      ),
    );
    await tester.tap(find.text('Open system VPN settings'));
    await tester.pump();
    expect(calls, ['open_vpn_settings']);
  });

  test('the platforms split auto-connect between them, with no overlap', () {
    for (final (platform, onDemand) in [
      (TargetPlatform.iOS, true),
      (TargetPlatform.macOS, true),
      (TargetPlatform.android, false),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(supportsOnDemand, onDemand, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
