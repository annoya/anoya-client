import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/rule_set.dart';
import 'package:anoya/core/rule_set_transfer.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/rule_set_import_screen.dart';
import 'package:anoya/features/rule_sets_screen.dart';
import 'package:anoya/l10n/l10n.dart';
import 'package:anoya/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-rule-set-names');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    tmp.deleteSync(recursive: true);
  });

  Future<void> show(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vpnCoreProvider.overrideWithValue(_Core())],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
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

  test('case and surrounding spaces do not make a name new', () {
    expect(takenRuleSetName(['Default', 'China'], '  china '), 'China');
    expect(takenRuleSetName(['Default', 'China'], 'China 2'), isNull);
    expect(takenRuleSetName(['Default'], '   '), isNull);
  });

  testWidgets('a new set cannot take a name already in use', (tester) async {
    File('${tmp.path}/rule_sets.json').writeAsStringSync(
      jsonEncode([
        {'id': 'default', 'name': 'Default'},
        {'id': 'rs1', 'name': 'China', 'mode': 'full'},
      ]),
    );
    await show(tester, const RuleSetsScreen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' china ');
    await tester.pump();

    expect(find.text('There is already a set named “China”'), findsOneWidget);
    final create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(create.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'China work');
    await tester.pump();
    expect(find.textContaining('There is already'), findsNothing);
  });

  testWidgets('an import cannot be renamed onto an existing set', (
    tester,
  ) async {
    await show(
      tester,
      const RuleSetImportScreen(
        import: RuleSetImport(
          source: RuleSetSource.anoya,
          name: 'China',
          mode: RoutingMode.full,
          rules: [],
        ),
        takenNames: ['Default', 'China'],
      ),
    );

    expect(find.text('China 2'), findsOneWidget);
    FilledButton add() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add rule set'),
    );
    expect(add().onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'CHINA');
    await tester.pump();
    expect(find.text('There is already a set named “China”'), findsOneWidget);
    expect(add().onPressed, isNull);
  });
}

class _Core extends VpnCore {
  @override
  VpnStatus get status => VpnStatus.disconnected;

  @override
  Stream<VpnStatus> statusStream() => const Stream.empty();

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}
}
