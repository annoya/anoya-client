import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/ext_logs.dart';

/// What the app does when there is no tunnel extension to talk to. The channel
/// throws MissingPluginException — NOT a PlatformException — when no handler is
/// registered, which is exactly the "tunnel is down" case these calls describe;
/// mocking it as a PlatformException (as other tests do) hides the difference.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a log fetch with no platform side explains itself instead of throwing', () async {
    final text = await fetchExtensionLog('tunnel');
    expect(text, contains('only while the VPN is connected'));
  });

  test('clearing logs with no platform side reports failure, never throws', () async {
    expect(await clearExtensionLogs(), isFalse);
  });

  test('pushing the log switch with no platform side is a no-op', () async {
    await expectLater(setExtensionLogging(false), completes);
  });
}
