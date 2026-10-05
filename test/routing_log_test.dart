import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/app_version.dart';
import 'package:anoya/core/effective_config.dart';
import 'package:anoya/core/log.dart';
import 'package:anoya/core/log_archive.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/rule_set.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vpn-routing-log');
    Log.clear();
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

  Profile profile({required bool routing, String? set}) => Profile(
    id: 'p',
    type: ProfileType.subscription,
    name: 'Nexus',
    locations: const [],
    routingEnabled: routing,
    ruleSetId: set,
  );

  test('routing switched off says so, not "full, 5 rules"', () async {
    await buildNormConfig(profile(routing: false));

    expect(Log.dump(), contains('routing: off for this configuration'));
  });

  test('a rule set is named, with what reaches the engine by kind', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await RuleSetStore.save([
      const RuleSet(id: RuleSet.defaultId, name: 'Default'),
      const RuleSet(
        id: 'work',
        name: 'Work',
        mode: RoutingMode.split,
        rules: [
          RoutingRule(
            type: 'domain-regex',
            values: [r'\.(ru|xn--p1ai)$'],
            action: 'proxy',
          ),
          RoutingRule(
            type: 'process-name',
            values: ['Telegram', 'Discord'],
            action: 'proxy',
          ),
          RoutingRule(type: 'geosite', values: ['youtube'], action: 'proxy'),
        ],
      ),
    ]);

    await buildNormConfig(profile(routing: true, set: 'work'));

    final log = Log.dump();
    expect(log, contains('geo rules skipped'));
    expect(
      log,
      contains(
        'routing: rule set "Work", split: '
        'domain-regex→proxy ×1, process-name→proxy ×2',
      ),
      reason: 'a report must show which rules the engine actually got',
    );
    expect(log, isNot(contains('xn--p1ai')), reason: 'kinds, not values');
  });

  test('an exported log starts with the version it came from', () {
    final header = logHeader(DateTime(2026, 10, 4, 23, 57));

    expect(header, startsWith('$kAppName $appVersionLabel · '));
    expect(header, contains(engineVersionLabel));
  });
}
