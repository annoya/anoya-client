import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/geosite_index.dart';
import 'package:anoya/core/json_file_store.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/rule_set.dart';
import 'package:anoya/core/service_catalog.dart';
import 'package:anoya/core/theme.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/features/rule_set_editor_screen.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/providers.dart';
import 'package:anoya/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() async {
    JsonFileStore.pending = 0;
    tmp = Directory.systemTemp.createTempSync('vpn-simple-routing');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('vpn/control'), (
      call,
    ) async {
      if (call.method == 'shared_dir') return tmp.path;
      throw PlatformException(code: 'no platform in tests');
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      null,
    );
    tmp.deleteSync(recursive: true);
  });

  group('geosite index scanner', () {
    test('reads category names and domain counts', () {
      final dat = geoSiteList({'YOUTUBE': 3, 'NETFLIX': 1, 'TELEGRAM': 2});

      final scanned = GeositeIndex.scan(dat);

      expect(
        [for (final c in scanned) c.name],
        ['netflix', 'telegram', 'youtube'],
      );
      expect(scanned.firstWhere((c) => c.name == 'youtube').domainCount, 3);
    });

    test('a truncated file yields what was parsed, not a crash', () {
      final dat = geoSiteList({'YOUTUBE': 2, 'NETFLIX': 1});
      final cut = Uint8List.sublistView(dat, 0, dat.length - 3);

      final scanned = GeositeIndex.scan(cut);

      expect(scanned.length, lessThan(2));
    });
  });

  group('simple editor', () {
    Future<void> writeGeo({List<String>? categories}) async {
      File('${tmp.path}/geoip.metadb').writeAsBytesSync([1, 2, 3]);
      File('${tmp.path}/GeoSite.dat').writeAsBytesSync(
        geoSiteList({
          for (final c
              in categories ??
                  [for (final s in kServiceCatalog) s.category.toUpperCase()])
            c: 2,
        }),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12 || (JsonFileStore.pending > 0 && i < 200); i++) {
        // Real I/O futures never complete in FakeAsync without runAsync.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vpnCoreProvider.overrideWithValue(_QuietCore()),
            profilesControllerProvider.overrideWith(_NoProfiles.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RuleSetEditorScreen(RuleSet.defaultId),
          ),
        ),
      );
      await settle(tester);
      await settle(tester);
    }

    Future<RuleSet> storedDefault(WidgetTester tester) async =>
        (await tester.runAsync(() => RuleSetStore.byId(RuleSet.defaultId)))!;

    Finder switchOf(String title) => find.descendant(
      of: find.widgetWithText(SwitchListTile, title),
      matching: find.byType(Switch),
    );

    Future<void> scrollBy(WidgetTester tester, double dy) async {
      await tester.drag(find.byType(ListView).first, Offset(0, dy));
      await tester.pump();
    }

    testWidgets(
      'a toggle writes a real rule with the direction-implied action',
      (tester) async {
        await writeGeo();
        await pump(tester);

        await scrollBy(tester, -400);
        await tester.tap(switchOf('YouTube'));
        await settle(tester);

        final set = await storedDefault(tester);
        expect(set.rules, hasLength(1));
        expect(set.rules.single.type, 'geosite');
        expect(set.rules.single.value, 'youtube');
        expect(set.rules.single.action, 'direct');

        await tester.tap(switchOf('YouTube'));
        await settle(tester);
        expect((await storedDefault(tester)).rules, isEmpty);
      },
    );

    testWidgets('flipping the direction re-tags the selections', (
      tester,
    ) async {
      await writeGeo();
      await pump(tester);

      await scrollBy(tester, -400);
      await tester.tap(switchOf('YouTube'));
      await settle(tester);
      await scrollBy(tester, 600);
      await tester.tap(find.text('Only selected'));
      await settle(tester);
      await scrollBy(tester, -400);

      final set = await storedDefault(tester);
      expect(set.mode, RoutingMode.split);
      expect(
        set.rules.single.action,
        'proxy',
        reason:
            'the user changed what "selected" means, not what is selected — '
            'the toggle must stay on, so the rule follows the new direction',
      );
      expect(tester.widget<Switch>(switchOf('YouTube')).value, true);
    });

    testWidgets('rules the catalog cannot express are surfaced, not hidden', (
      tester,
    ) async {
      await writeGeo();
      await tester.runAsync(
        () => RuleSetStore.save([
          const RuleSet(
            id: RuleSet.defaultId,
            name: 'Default',
            rules: [
              RoutingRule(
                type: 'domain-suffix',
                values: ['corp.example.com'],
                action: 'proxy',
              ),
              RoutingRule(
                type: 'ip-cidr',
                values: ['10.0.0.0/8'],
                action: 'direct',
              ),
            ],
          ),
        ]),
      );
      await pump(tester);

      expect(find.text('Advanced rules · 2'), findsOneWidget);

      await tester.tap(find.text('Advanced rules · 2'));
      await settle(tester);
      expect(find.text('corp.example.com'), findsOneWidget);

      expect((await storedDefault(tester)).rules, hasLength(2));
    });

    testWidgets('a list of countries is not shown as one of them', (
      tester,
    ) async {
      await writeGeo();
      await tester.runAsync(
        () => RuleSetStore.save([
          const RuleSet(
            id: RuleSet.defaultId,
            name: 'Default',
            rules: [
              RoutingRule(
                type: 'geoip',
                values: ['ru', 'by'],
                action: 'direct',
              ),
              RoutingRule(
                type: 'geosite',
                values: ['youtube', 'netflix'],
                action: 'direct',
              ),
            ],
          ),
        ]),
      );
      await pump(tester);

      expect(find.text('Advanced rules · 2'), findsOneWidget);
      expect(find.text('Russia'), findsNothing);

      await scrollBy(tester, -400);
      expect(
        tester.widget<Switch>(switchOf('YouTube')).value,
        isFalse,
        reason: 'turning it off would have to edit a list Simple cannot show',
      );
    });

    testWidgets('catalog entries missing from the database are hidden', (
      tester,
    ) async {
      await writeGeo(categories: ['YOUTUBE', 'NETFLIX']);
      await pump(tester);

      expect(find.widgetWithText(SwitchListTile, 'YouTube'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, 'Telegram'), findsNothing);
    });

    testWidgets(
      'any category from the database can be added, not just the catalog',
      (tester) async {
        await writeGeo(categories: ['YOUTUBE', 'YANDEX']);
        await pump(tester);

        await tester.tap(find.text('Add category'));
        await settle(tester);
        await tester.tap(find.text('yandex'));
        await settle(tester);

        final set = await storedDefault(tester);
        expect(set.rules.single.value, 'yandex');
        expect(
          set.rules.single.action,
          'direct',
          reason: 'ad-hoc categories follow the direction like catalog toggles',
        );

        expect(find.text('yandex'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, 'yandex'),
            matching: find.byIcon(Icons.delete_outline),
          ),
        );
        await settle(tester);

        expect((await storedDefault(tester)).rules, isEmpty);
        expect(find.text('yandex'), findsNothing);
      },
    );

    testWidgets('without the databases the catalog is gated behind download', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Download the site lists first'), findsOneWidget);
      final sw = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'YouTube'),
      );
      expect(sw.onChanged, isNull);
    });

    testWidgets('a service reached by address brings its addresses along', (
      tester,
    ) async {
      await writeGeo();
      await pump(tester);

      await tester.scrollUntilVisible(
        switchOf('Telegram'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(switchOf('Telegram'));
      await settle(tester);

      final rules = (await storedDefault(tester)).rules;
      expect(
        [for (final r in rules) (r.type, r.value, r.action)],
        [('geosite', 'telegram', 'direct'), ('geoip', 'telegram', 'direct')],
      );
      expect(rules.last.noResolve, isTrue);
      final count = find.textContaining(' selected · ');
      await tester.scrollUntilVisible(
        count,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<Text>(count).data,
        startsWith('1 selected'),
        reason: 'one toggle is one service, however many rules it takes',
      );
      expect(find.text('TELEGRAM'), findsNothing);

      await tester.scrollUntilVisible(
        switchOf('Telegram'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(switchOf('Telegram'));
      await tester.pump();
      await tester.tap(switchOf('Telegram'));
      await settle(tester);
      expect((await storedDefault(tester)).rules, isEmpty);
    });

    testWidgets('addresses two services share stay while either is on', (
      tester,
    ) async {
      await writeGeo();
      await pump(tester);

      Future<void> toggle(String name) async {
        await tester.scrollUntilVisible(
          switchOf(name),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(switchOf(name));
        await tester.pump();
        await tester.tap(switchOf(name));
        await settle(tester);
      }

      Future<List<String>> geoip() async => [
        for (final r in (await storedDefault(tester)).rules)
          if (r.type == 'geoip') r.value,
      ];

      await toggle('WhatsApp');
      await toggle('Instagram');
      expect(await geoip(), ['facebook']);

      await toggle('Instagram');
      expect(await geoip(), [
        'facebook',
      ], reason: 'WhatsApp still needs the addresses Instagram shared');

      await tester.scrollUntilVisible(
        switchOf('WhatsApp'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await toggle('WhatsApp');
      expect((await storedDefault(tester)).rules, isEmpty);
    });

    test('every address tag in the catalog reaches the engine', () {
      for (final s in kServiceCatalog) {
        if (s.geoip case final tag?) {
          expect(
            RoutingRule.isValidValue('geoip', tag),
            isTrue,
            reason: '${s.name} names $tag',
          );
        }
      }
    });

    testWidgets('a set saved before the addresses existed gains them', (
      tester,
    ) async {
      await tester.runAsync(
        () => RuleSetStore.save([
          const RuleSet(
            id: RuleSet.defaultId,
            name: 'Default',
            mode: RoutingMode.split,
            rules: [
              RoutingRule(
                type: 'geosite',
                values: ['telegram'],
                action: 'proxy',
              ),
            ],
          ),
          const RuleSet(
            id: 'hand-written',
            name: 'Hand-written',
            mode: RoutingMode.split,
            editor: RuleEditor.advanced,
            rules: [
              RoutingRule(
                type: 'geosite',
                values: ['telegram'],
                action: 'proxy',
              ),
            ],
          ),
        ]),
      );

      final simple = await storedDefault(tester);
      expect(simple.rules.last.type, 'geoip');
      expect(simple.rules.last.value, 'telegram');
      expect(simple.rules.last.action, 'proxy');

      final advanced = (await tester.runAsync(
        () => RuleSetStore.byId('hand-written'),
      ))!;
      expect(
        advanced.rules,
        hasLength(1),
        reason: 'the advanced editor shows rules as written',
      );
    });

    testWidgets('the editor choice is remembered on the set', (tester) async {
      await writeGeo();
      await pump(tester);

      await tester.tap(find.text('Advanced'));
      await settle(tester);
      expect(find.text('RULES — FIRST MATCH WINS'), findsOneWidget);

      expect((await storedDefault(tester)).editor, RuleEditor.advanced);
    });
  });

  group('process rules', () {
    Future<Routing> effective(List<RoutingRule> rules) async {
      final container = ProviderContainer(
        overrides: [
          vpnCoreProvider.overrideWithValue(_QuietCore()),
          profilesControllerProvider.overrideWith(_NoProfiles.new),
        ],
      );
      addTearDown(container.dispose);
      final ctrl = container.read(profilesControllerProvider.notifier);
      final config = await ctrl.effectiveConfig(
        Profile(
          id: 'p1',
          type: ProfileType.link,
          name: 'link',
          routingEnabled: true,
          routing: Routing(mode: 'full', rules: rules),
          locations: [
            Location(
              id: 'a',
              label: 'DE',
              proxy: const {'type': 'vless', 'server': '1.1.1.1'},
            ),
          ],
        ),
      );
      return config.routing!;
    }

    const processRule = RoutingRule(
      type: 'process-name',
      values: ['Slack'],
      action: 'direct',
    );
    const domainRule = RoutingRule(
      type: 'domain-suffix',
      values: ['corp.example.com'],
      action: 'proxy',
    );

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('reach the engine on desktop', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final routing = await effective([processRule, domainRule]);

      expect([for (final r in routing.rules) r.type], contains('process-name'));
    });

    test('are dropped on mobile, where nothing can match them', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final routing = await effective([processRule, domainRule]);

      expect([
        for (final r in routing.rules) r.type,
      ], isNot(contains('process-name')));
      expect([
        for (final r in routing.rules) r.type,
      ], contains('domain-suffix'));
    });
  });
}

Uint8List geoSiteList(Map<String, int> domainsPerCategory) {
  final out = BytesBuilder();
  domainsPerCategory.forEach((name, domains) {
    final entry = BytesBuilder();
    entry.add(_lengthDelimited(1, Uint8List.fromList(name.codeUnits)));
    for (var i = 0; i < domains; i++) {
      final domain = BytesBuilder();
      domain.add([0x08, 2]);
      domain.add(
        _lengthDelimited(2, Uint8List.fromList('d$i.example.com'.codeUnits)),
      );
      entry.add(_lengthDelimited(2, domain.toBytes()));
    }
    out.add(_lengthDelimited(1, entry.toBytes()));
  });
  return out.toBytes();
}

Uint8List _lengthDelimited(int field, Uint8List payload) {
  final out = BytesBuilder();
  out.addByte(field << 3 | 2);
  var n = payload.length;
  while (n >= 0x80) {
    out.addByte(n & 0x7f | 0x80);
    n >>= 7;
  }
  out.addByte(n);
  out.add(payload);
  return out.toBytes();
}

class _NoProfiles extends ProfilesController {
  @override
  ProfilesState build() => const ProfilesState();
}

class _QuietCore extends VpnCore {
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
