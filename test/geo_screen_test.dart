import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/geo_store.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/geo_screen.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-geo-screen');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => call.method == 'shared_dir' ? tmp.path : null,
    );
  });

  tearDown(() {
    for (final c in [
      const MethodChannel('plugins.flutter.io/path_provider'),
      const MethodChannel('vpn/control'),
    ]) {
      messenger.setMockMethodCallHandler(c, null);
    }
    tmp.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GeoScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('the button says the update is running, not just spins', (
    tester,
  ) async {
    File('${tmp.path}/${GeoStore.geoipFile}').writeAsBytesSync([1, 2, 3]);
    File('${tmp.path}/${GeoStore.geositeFile}').writeAsBytesSync([1, 2, 3]);
    await open(tester);

    await tester.tap(find.text('Update now'));
    await tester.pump();

    expect(find.text('Updating…'), findsOneWidget);
    expect(find.text('Update now'), findsNothing);
  });

  testWidgets('a first download says so too', (tester) async {
    await open(tester);

    await tester.tap(find.text('Download (~25 MB)'));
    await tester.pump();

    expect(find.text('Downloading…'), findsOneWidget);
  });
}
