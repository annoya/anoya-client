import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/state/config_controller.dart';

NormConfig cfg({Map<String, dynamic>? routing, Map<String, dynamic>? proxy}) =>
    NormConfig.fromJson({
      'version': 1,
      'account': {'status': 'active'},
      'locations': [
        {'id': 'worker_1', 'label': 'L1', 'proxy': proxy ?? {'type': 'vless', 'server': '1.2.3.4', 'uuid': 'u'}},
      ],
      'routing': ?routing,
    });

void main() {
  const split = {
    'mode': 'split',
    'rules': [
      {'type': 'domain-suffix', 'value': 'corp.example.com', 'action': 'proxy'},
    ],
  };

  test('routingChanged detects appear/disappear/edit and ignores no-op', () {
    expect(routingChanged(cfg(), cfg()), isFalse);
    expect(routingChanged(cfg(routing: split), cfg(routing: split)), isFalse);
    expect(routingChanged(cfg(), cfg(routing: split)), isTrue); // appeared
    expect(routingChanged(cfg(routing: split), cfg()), isTrue); // disappeared
    final edited = {
      'mode': 'split',
      'rules': [
        {'type': 'domain-suffix', 'value': 'other.example.com', 'action': 'proxy'},
      ],
    };
    expect(routingChanged(cfg(routing: split), cfg(routing: edited)), isTrue);
  });

  test('proxyChanged detects key rotation for the connected location only', () {
    final a = cfg(proxy: {'type': 'vless', 'server': '1.2.3.4', 'uuid': 'old'});
    final b = cfg(proxy: {'type': 'vless', 'server': '1.2.3.4', 'uuid': 'new'});
    expect(proxyChanged(a, a, 'worker_1'), isFalse);
    expect(proxyChanged(a, b, 'worker_1'), isTrue);
    expect(proxyChanged(a, b, 'worker_2'), isFalse); // both missing → equal
  });
}
