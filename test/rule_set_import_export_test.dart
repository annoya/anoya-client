import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/rule_set.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/rule_set_editor_screen.dart';
import 'package:anoya/features/rule_sets_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/profiles_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;
  String? clipboard;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-rule-transfer');
    clipboard = null;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboard == null ? null : {'text': clipboard};
      }
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => throw PlatformException(code: 'no platform in tests'),
    );
  });

  tearDown(() {
    for (final c in [
      const MethodChannel('plugins.flutter.io/path_provider'),
      SystemChannels.platform,
      const MethodChannel('vpn/control'),
    ]) {
      messenger.setMockMethodCallHandler(c, null);
    }
    tmp.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profilesControllerProvider.overrideWith(_NoProfiles.new)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('a Happ profile from the clipboard becomes a new rule set', (
    tester,
  ) async {
    final profile = {
      'Name': 'Russia direct',
      'GlobalProxy': true,
      'RemoteDNSType': 'DoH',
      'DirectSites': ['geosite:ru'],
      'DirectIp': ['geoip:ru'],
      'ProxySites': ['domain:youtube.com'],
      'BlockSites': ['geosite:category-ads-all'],
    };
    clipboard =
        'happ://routing/add/${base64.encode(utf8.encode(jsonEncode(profile)))}';
    await pump(tester, const RuleSetsScreen());

    await tester.tap(find.byTooltip('Import a rule set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste from clipboard'));
    await settle(tester);

    expect(find.text('Happ routing profile'), findsOneWidget);
    expect(find.text('Migrated to an Anoya rule set'), findsOneWidget);
    expect(find.text('4 rules'), findsOneWidget);
    expect(find.text('2 direct · 1 via VPN · 1 blocked'), findsOneWidget);
    expect(
      find.text('DNS servers'),
      findsOneWidget,
      reason: 'what does not move is named, not dropped',
    );

    await tester.tap(find.text('Add rule set'));
    await settle(tester);

    final sets = (await tester.runAsync(RuleSetStore.load))!;
    final added = sets.singleWhere((s) => s.name == 'Russia direct');
    expect(added.mode, RoutingMode.full);
    expect(added.rules, hasLength(4));
    expect(find.text('Rule set “Russia direct” added'), findsOneWidget);
  });

  testWidgets('a profile named like ours is renamed, and its rules can be read', (
    tester,
  ) async {
    final profile = {
      'Name': 'Default',
      'DirectSites': ['domain:yandex.ru'],
      'ProxySites': ['full:www.youtube.com'],
    };
    clipboard =
        'happ://routing/add/${base64.encode(utf8.encode(jsonEncode(profile)))}';
    await pump(tester, const RuleSetsScreen());

    await tester.tap(find.byTooltip('Import a rule set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste from clipboard'));
    await settle(tester);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Default 2',
      reason: 'two sets called Default could not be told apart',
    );

    await tester.tap(find.text('2 rules'));
    await settle(tester);

    expect(find.text('www.youtube.com'), findsOneWidget);
    expect(find.text('yandex.ru'), findsOneWidget);
    expect(
      find.byIcon(Icons.delete_outline),
      findsNothing,
      reason: 'read-only',
    );
  });

  testWidgets('text that is not a rule set is refused with the formats', (
    tester,
  ) async {
    clipboard = 'just some words';
    await pump(tester, const RuleSetsScreen());

    await tester.tap(find.byTooltip('Import a rule set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste from clipboard'));
    await settle(tester);

    expect(find.textContaining('Couldn’t read a rule set'), findsOneWidget);
    expect(find.text('Import rule set'), findsNothing);
  });

  testWidgets('export copies an anoya link that imports back whole', (
    tester,
  ) async {
    await tester.runAsync(
      () => RuleSetStore.save([
        const RuleSet(id: RuleSet.defaultId, name: 'Default'),
        const RuleSet(
          id: 'work',
          name: 'Work',
          mode: RoutingMode.split,
          rules: [
            RoutingRule(
              type: 'domain-suffix',
              value: 'corp.example',
              action: 'proxy',
            ),
          ],
        ),
      ]),
    );
    await pump(tester, const RuleSetEditorScreen('work'));

    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy to clipboard'));
    await settle(tester);

    expect(clipboard, startsWith('anoya://ruleset/add/'));
  });

  testWidgets('a set too large for one QR code says so instead', (
    tester,
  ) async {
    await tester.runAsync(
      () => RuleSetStore.save([
        const RuleSet(id: RuleSet.defaultId, name: 'Default'),
        RuleSet(
          id: 'big',
          name: 'Big',
          rules: [
            for (var i = 0; i < 400; i++)
              RoutingRule(
                type: 'domain-suffix',
                value:
                    '${(i * 2654435761 % 4294967296).toRadixString(36)}.example',
                action: 'direct',
              ),
          ],
        ),
      ]),
    );
    await pump(tester, const RuleSetEditorScreen('big'));

    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too large for a QR code — share it as a file'),
      findsOneWidget,
    );
  });
}

class _NoProfiles extends ProfilesController {
  @override
  ProfilesState build() => const ProfilesState();

  @override
  Future<void> syncTunnelConfig() async {}
}
