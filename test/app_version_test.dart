import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/app_version.dart';
import 'package:vpn_client/core/device_identity.dart';

/// The versions the app shows, against the files that actually decide them.
///
/// `pubspec.yaml` decides the app's version and is read at runtime, so there is
/// no copy to drift — what these tests check is that the read works at all: an
/// asset that stops being declared would leave every build calling itself
/// "unknown", to the user and to a panel, since the User-Agent is built from
/// the same string. The engine pin and the app name are still stated in Dart,
/// and those two are guarded the old way.
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
      // The one way this arrangement can break: the asset entry goes away and
      // every build starts reporting "unknown".
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
    // The name is what a panel matches its template rules against, so a rename
    // that misses one of the two places is a silent capability loss.
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
    // Headers are ASCII; whatever the version turns out to be, it cannot make
    // this one unsendable.
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
