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
}
