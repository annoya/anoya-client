import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/ext_logs.dart';

// No handler throws MissingPluginException, not PlatformException; mocking
// it as the latter hides the difference.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a log fetch with no platform side explains itself instead of throwing',
    () async {
      final text = await fetchExtensionLog('tunnel');
      expect(text, contains('only while the tunnel is running'));
    },
  );

  test(
    'clearing logs with no platform side reports failure, never throws',
    () async {
      expect(await clearExtensionLogs(), isFalse);
    },
  );

  test('pushing the log switch with no platform side is a no-op', () async {
    await expectLater(setExtensionLogging(false), completes);
  });
}
