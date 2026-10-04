import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/features/routing_widgets.dart';
import 'package:anoya/features/rule_screen.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  String? clipboard;

  setUp(() {
    clipboard = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboard == null ? null : {'text': clipboard};
      }
      return null;
    });
  });
  tearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<List<RoutingRule>? Function()> open(
    WidgetTester tester, {
    RoutingRule? initial,
  }) async {
    List<RoutingRule>? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                saved = await Navigator.of(context).push<List<RoutingRule>>(
                  MaterialPageRoute(
                    builder: (_) =>
                        RuleScreen(initial: initial, geoReady: true),
                  ),
                ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => saved;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the domain field keeps the URL keyboard and takes a list', (
    tester,
  ) async {
    await open(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.keyboardType,
      TextInputType.url,
      reason:
          'the text keyboard on Android inserts a space after every full stop',
    );
    expect(field.textInputAction, TextInputAction.newline);
    expect(field.maxLines, greaterThan(1));
    expect(find.byTooltip('Paste'), findsOneWidget, reason: 'in the field');
    expect(find.widgetWithText(OutlinedButton, 'Add from a file…'), findsOne);
    expect(find.text('domain and subdomains'), findsOneWidget);
  });

  testWidgets('a pasted mixed list saves as a domain rule and its subnets', (
    tester,
  ) async {
    final saved = await open(tester);
    clipboard =
        'youtube.com\nhttps://www.youtube.com/watch?v=1\nytimg.com\n'
        '142.250.0.0/15\nyoutube_com';

    await tester.tap(find.byTooltip('Paste'));
    await tester.pumpAndSettle();

    expect(find.text('2 domains'), findsOneWidget);
    expect(find.text('1 subnet'), findsOneWidget);
    expect(
      find.text('Saved as a separate ip-cidr rule right after this one'),
      findsOneWidget,
    );
    expect(find.text('1 duplicate removed'), findsOneWidget);
    expect(find.text('1 line not recognized'), findsOneWidget);

    await save(tester);

    final rules = saved()!;
    expect(
      [for (final r in rules) r.toJson()],
      [
        {
          'type': 'domain-suffix',
          'values': ['youtube.com', 'ytimg.com'],
          'action': 'proxy',
        },
        {
          'type': 'ip-cidr',
          'values': ['142.250.0.0/15'],
          'action': 'proxy',
        },
      ],
    );
  });

  testWidgets('lines that were not recognized are listed with their line', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'a.com\nb_c\n300.1.1.0/24');
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 lines not recognized'));
    await tester.pumpAndSettle();

    expect(find.text('b_c'), findsOneWidget);
    expect(find.text('line 2 · not a domain'), findsOneWidget);
    expect(find.text('line 3 · not an address'), findsOneWidget);
  });

  testWidgets('Save waits for at least one value', (tester) async {
    await open(tester);

    final button = find.widgetWithIcon(IconButton, Icons.check);
    expect(tester.widget<IconButton>(button).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'not_a_domain');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(button).onPressed, isNull);
  });

  testWidgets('an existing list opens one value per line', (tester) async {
    await open(
      tester,
      initial: const RoutingRule(
        type: 'domain-suffix',
        values: ['a.com', 'b.com'],
        action: 'direct',
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'a.com\nb.com',
    );
  });

  testWidgets('several countries are one rule, and chips remove them', (
    tester,
  ) async {
    final saved = await open(
      tester,
      initial: const RoutingRule(
        type: 'geoip',
        values: ['ru'],
        action: 'direct',
      ),
    );

    await tester.tap(find.text('1 selected'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'BY');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Belarus'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'KZ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kazakhstan'));
    await tester.pump();
    await tester.tap(find.text('Done · 3'));
    await tester.pumpAndSettle();

    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, '🇧🇾 BY'),
        matching: find.byTooltip('Remove'),
      ),
    );
    await tester.pumpAndSettle();
    await save(tester);

    final rule = saved()!.single;
    expect(rule.type, 'geoip');
    expect(rule.values.toSet(), {'ru', 'kz'});
  });

  testWidgets('a list reads as one row with its count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: RuleTile(
            geoReady: true,
            rule: RoutingRule(
              type: 'domain-suffix',
              values: ['youtube.com', 'ytimg.com', 'youtu.be'],
              action: 'proxy',
            ),
          ),
        ),
      ),
    );

    expect(find.text('youtube.com, ytimg.com, youtu.be'), findsOneWidget);
    expect(find.text('domain-suffix · 3 domains'), findsOneWidget);
  });
}
