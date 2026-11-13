import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/json_file_store.dart';
import 'package:anoya/core/routing_prefs.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/dns_settings_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-dns-settings');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    tmp.deleteSync(recursive: true);
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.read(routingPrefsProvider);
      await container.read(routingPrefsProvider.notifier).reload();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DnsSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('each resolver is named by where its traffic goes', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Through the VPN'), findsOneWidget);
    expect(find.text('Outside the VPN'), findsOneWidget);
    expect(find.text('Company network'), findsOneWidget);
    expect(find.text('Cloudflare'), findsOneWidget);
    expect(find.text('Off'), findsNWidgets(2));
    expect(find.text('For sites that go through the VPN.'), findsOneWidget);
    expect(
      find.text('For sites your rules send past the VPN.'),
      findsOneWidget,
    );
    expect(find.textContaining('your company’s DNS server'), findsOneWidget);
    expect(find.textContaining('a server near you'), findsNothing);

    await tester.tap(find.text('Outside the VPN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a server near you'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a server near you'), findsNothing);
  });

  testWidgets('a local resolver is chosen from a short list and kept', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.text('Local DNS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Quad9'), findsNothing);
    expect(find.text('AdGuard'), findsNothing);

    await tester.tap(find.text('Google'));
    for (var i = 0; i < 12 || (JsonFileStore.pending > 0 && i < 200); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      container.read(routingPrefsProvider).localDns,
      'https://8.8.8.8/dns-query',
    );
    final saved = await tester.runAsync(RoutingPrefsStore.load);
    expect(saved!.localDns, 'https://8.8.8.8/dns-query');
    expect(find.text('Google'), findsOneWidget);
  });
}
