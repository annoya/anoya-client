import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/platform_support.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('files are offered to share everywhere but Linux', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        canShareFiles,
        platform != TargetPlatform.linux,
        reason: '$platform',
      );
    }
  });

  test('app rules work on desktops and Android 10+, never on iOS', () {
    addTearDown(() => androidSdk = 0);
    final expected = {
      TargetPlatform.macOS: true,
      TargetPlatform.windows: true,
      TargetPlatform.linux: true,
      TargetPlatform.iOS: false,
    };
    for (final MapEntry(key: platform, value: want) in expected.entries) {
      debugDefaultTargetPlatformOverride = platform;
      expect(supportsProcessRules, want, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    androidSdk = 28;
    expect(
      supportsProcessRules,
      isFalse,
      reason: 'Android 9 cannot name the app',
    );
    androidSdk = 29;
    expect(supportsProcessRules, isTrue);
  });

  test('apps outside the VPN is an Android-only setting', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        supportsExcludedApps,
        platform == TargetPlatform.android,
        reason: '$platform',
      );
    }
  });
}
