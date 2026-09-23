import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/app_version.dart';
import 'package:vpn_client/core/device_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppVersion);

  test('the version the app reports is the one pubspec carries', () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(
      r'^version:\s*(\S+?)\+(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec must carry version: <name>+<build>');
    expect(appVersion, m!.group(1));
    expect(appBuild, m.group(2));
  });

  test(
    'the pubspec is shipped as an asset — without it there is no version',
    () async {
      expect(appVersion, isNotEmpty);
      expect(appVersionLabel, isNot('unknown'));
    },
  );

  test('the engine pin matches go.mod', () {
    final gomod = File('native/mihomocore/go.mod').readAsStringSync();
    final m = RegExp(r'github\.com/metacubex/mihomo (\S+)').firstMatch(gomod);
    expect(m, isNotNull);
    expect(
      kEnginePin,
      m!.group(1),
      reason:
          'the About section would otherwise name an engine we do not build',
    );
  });

  test('the app name matches the bundle it ships as', () {
    final xcconfig = File(
      'macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final m = RegExp(
      r'^PRODUCT_NAME\s*=\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(xcconfig);
    expect(m, isNotNull);
    expect(kAppName, m!.group(1));
  });

  test('the User-Agent is the name and that version', () {
    expect(DeviceIdentity.userAgent, '$kAppName/$appVersion');
    expect(DeviceIdentity.userAgent, matches(RegExp(r'^[\x21-\x7E]+$')));
  });

  group('what the About section reads out', () {
    test('a release tag reads as a plain version', () {
      expect(engineVersionLabel, 'mihomo 1.19.30');
    });

    test('the app line pairs version and build, the way Apple shows it', () {
      expect(appVersionLabel, '$appVersion ($appBuild)');
    });
  });
}
