// Minimal smoke test. UI flows depend on the macOS Keychain and the mihomo
// subprocess, which aren't available in the headless test environment, so we
// keep this to a trivial parsing sanity check.
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';

void main() {
  test('NormConfig parses a bundle', () {
    final cfg = NormConfig.fromJson({
      'version': 1,
      'account': {'display_name': 'Alice', 'status': 'active'},
      'locations': [
        {
          'id': 'worker_1',
          'label': 'Amsterdam #1',
          'proxy': {'type': 'vless', 'server': '1.2.3.4', 'port': 443},
        }
      ],
    });
    expect(cfg.account.isActive, true);
    expect(cfg.locations.length, 1);
    expect(cfg.locations.first.proxyType, 'vless');
  });
}
