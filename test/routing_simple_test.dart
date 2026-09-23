import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/geosite_index.dart';
import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/profile.dart';
import 'package:vpn_client/core/rule_set.dart';
import 'package:vpn_client/core/service_catalog.dart';
import 'package:vpn_client/core/theme.dart';
import 'package:vpn_client/core/vpn_core.dart';
import 'package:vpn_client/features/rule_set_editor_screen.dart';
import 'package:vpn_client/state/profiles_controller.dart';
import 'package:vpn_client/state/providers.dart';
import 'package:vpn_client/l10n/l10n.dart';

/// Simple mode of the rule-set editor: a catalog view over ordinary
/// geosite/geoip rules. The contract pinned here: toggles write real rules
/// with the direction-implied action, flipping the direction re-tags the
/// selections, rules the catalog can't express are surfaced (never hidden or
/// dropped), and the catalog only offers what the local database contains.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('vpn-simple-routing');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    // The shared dir hosts the geo databases; everything else has no platform
    // side in tests.
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

  // --- GeoSite.dat scanner --------------------------------------------------

  group('geosite index scanner', () {
    test('reads category names and domain counts', () {
      final dat = geoSiteList({'YOUTUBE': 3, 'NETFLIX': 1, 'TELEGRAM': 2});

      final scanned = GeositeIndex.scan(dat);

      // Sorted, lower-cased, with per-category domain counts.
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

      // The picker being shorter beats the editor dying on a bad download.
      expect(scanned.length, lessThan(2));
    });
  });

  // --- Simple mode ----------------------------------------------------------

  group('simple editor', () {
    Future<void> writeGeo({List<String>? categories}) async {
      // Both databases present = geo rules work; the .dat carries real
      // (synthetic) protobuf so the index scanner runs the honest path.
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
      for (var i = 0; i < 12; i++) {
        // runAsync turns the real event loop (file I/O in stores and the index
        // scan); the timed pump advances the fake clock so route/sheet
        // animations actually finish.
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
      // _load does real file I/O (rule sets, geo status, the index scan).
      // testWidgets runs inside FakeAsync where real futures never complete on
      // their own — runAsync lets the actual event loop turn, then a pump
      // renders what arrived. pumpAndSettle would be worse than useless here:
      // it spins the fake clock, not the event loop.
      await settle(tester);
      await settle(tester);
    }

    Future<RuleSet> storedDefault(WidgetTester tester) async =>
        (await tester.runAsync(() => RuleSetStore.byId(RuleSet.defaultId)))!;

    Finder switchOf(String title) => find.descendant(
      of: find.widgetWithText(SwitchListTile, title),
      matching: find.byType(Switch),
    );

    // The screen is one lazy list; rows outside the viewport have no elements
    // yet, so a finder-driven tap needs the list scrolled first.
    Future<void> scrollBy(WidgetTester tester, double dy) async {
      await tester.drag(find.byType(ListView).first, Offset(0, dy));
      await tester.pump();
    }

    testWidgets(
      'a toggle writes a real rule with the direction-implied action',
      (tester) async {
        await writeGeo();
        await pump(tester);

        // Default set: mode full → picked things bypass the VPN.
        await scrollBy(tester, -400);
        await tester.tap(switchOf('YouTube'));
        await settle(tester);

        final set = await storedDefault(tester);
        expect(set.rules, hasLength(1));
        expect(set.rules.single.type, 'geosite');
        expect(set.rules.single.value, 'youtube');
        expect(set.rules.single.action, 'direct');

        // Off removes it again.
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
                value: 'corp.example.com',
                action: 'proxy',
              ),
              RoutingRule(
                type: 'ip-cidr',
                value: '10.0.0.0/8',
                action: 'direct',
              ),
            ],
          ),
        ]),
      );
      await pump(tester);

      expect(find.text('Advanced rules · 2'), findsOneWidget);

      // The row leads to the editor that can show them.
      await tester.tap(find.text('Advanced rules · 2'));
      await settle(tester);
      expect(find.text('corp.example.com'), findsOneWidget);

      // And nothing was dropped by the round trip.
      expect((await storedDefault(tester)).rules, hasLength(2));
    });

    testWidgets('catalog entries missing from the database are hidden', (
      tester,
    ) async {
      await writeGeo(categories: ['YOUTUBE', 'NETFLIX']);
      await pump(tester);

      expect(find.widgetWithText(SwitchListTile, 'YouTube'), findsOneWidget);
      // In the db catalog but absent from the local one — a switch that cannot
      // work is worse than none.
      expect(find.widgetWithText(SwitchListTile, 'Telegram'), findsNothing);
    });

    testWidgets(
      'any category from the database can be added, not just the catalog',
      (tester) async {
        // 'yandex' exists in the database but not in the curated catalog.
        await writeGeo(categories: ['YOUTUBE', 'YANDEX']);
        await pump(tester);

        // The add row leads the section — reachable without scrolling.
        await tester.tap(find.text('Add category'));
        await settle(tester); // the sheet scans the database for its list
        await tester.tap(find.text('yandex'));
        await settle(tester);

        final set = await storedDefault(tester);
        expect(set.rules.single.value, 'yandex');
        expect(
          set.rules.single.action,
          'direct',
          reason: 'ad-hoc categories follow the direction like catalog toggles',
        );

        // It lands right under the Add-category row that created it, with a
        // delete button rather than a switch: added items are add/remove, and a
        // switch whose off state deletes the row would be lying about that.
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

    testWidgets('the editor choice is remembered on the set', (tester) async {
      await writeGeo();
      await pump(tester);

      await tester.tap(find.text('Advanced'));
      await settle(tester);
      expect(find.text('RULES — FIRST MATCH WINS'), findsOneWidget);

      expect((await storedDefault(tester)).editor, RuleEditor.advanced);
    });
  });

  // --- platform-gated rule types -------------------------------------------

  group('process rules', () {
    // Ordinary routing prefs/geo lookups run through the same tmp dir.
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
      value: 'Slack',
      action: 'direct',
    );
    const domainRule = RoutingRule(
      type: 'domain-suffix',
      value: 'corp.example.com',
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

      // A set authored on a Mac travels to the phone; the rule that cannot work
      // there must not reach the engine (nor switch find-process-mode on).
      expect([
        for (final r in routing.rules) r.type,
      ], isNot(contains('process-name')));
      expect([
        for (final r in routing.rules) r.type,
      ], contains('domain-suffix'));
    });
  });
}

/// Builds a valid GeoSiteList protobuf:
///   GeoSiteList { repeated GeoSite entry = 1; }
///   GeoSite     { string country_code = 1; repeated Domain domain = 2; }
Uint8List geoSiteList(Map<String, int> domainsPerCategory) {
  final out = BytesBuilder();
  domainsPerCategory.forEach((name, domains) {
    final entry = BytesBuilder();
    entry.add(_lengthDelimited(1, Uint8List.fromList(name.codeUnits)));
    for (var i = 0; i < domains; i++) {
      // Domain { type = 1 (varint); value = 2 (string) } — content is
      // irrelevant to the scanner, only the field count matters.
      final domain = BytesBuilder();
      domain.add([0x08, 2]); // type = 2 (Domain.RootDomain)
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
