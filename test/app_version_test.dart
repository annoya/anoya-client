import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/app_version.dart';
import 'package:vpn_client/core/device_identity.dart';

/// The versions the app shows, against the files that actually decide them.
///
/// The app cannot read `pubspec.yaml` or `go.mod` at runtime, so those numbers
/// are duplicated in Dart. This is what keeps the duplicate honest: bumping a
/// version without updating the constant fails here rather than shipping a
/// build that misreports itself to support — and to a panel, since the
/// User-Agent is built from the same strings.
void main() {
  test('the app version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*(\S+)\+(\S+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec must carry version: <name>+<build>');
    expect(kAppVersion, m!.group(1));
    expect(kAppBuild, m.group(2));
  });

  test('the engine pin matches go.mod', () {
    final gomod = File('native/mihomocore/go.mod').readAsStringSync();
    final m = RegExp(r'github\.com/metacubex/mihomo (\S+)').firstMatch(gomod);
    expect(m, isNotNull);
    expect(kEnginePin, m!.group(1),
        reason: 'the About section would otherwise name an engine we do not build');
  });

  test('the app name matches the bundle it ships as', () {
    // The name is what a panel matches its template rules against, so a rename
    // that misses one of the two places is a silent capability loss.
    final xcconfig = File('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync();
    final m = RegExp(r'^PRODUCT_NAME\s*=\s*(\S+)\s*$', multiLine: true).firstMatch(xcconfig);
    expect(m, isNotNull);
    expect(kAppName, m!.group(1));
  });

  test('the User-Agent is built from those same strings', () {
    expect(DeviceIdentity.kUserAgent, '$kAppName/$kAppVersion');
  });

  group('what the About section reads out', () {
    test('the engine line names the version and the commit, not the whole pin', () {
      // The full pseudo-version is 44 characters of timestamp; the version and
      // the commit are the two halves anyone acts on.
      expect(engineVersionLabel, 'mihomo 1.19.28-24b6de71fc1c');
    });

    test('the app line pairs version and build, the way Apple shows it', () {
      expect(appVersionLabel, '$kAppVersion ($kAppBuild)');
    });
  });
}
