import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/control_transport.dart';
import 'package:anoya/core/network_extension_core.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/state/launch_action.dart';

void main() {
  test(
    'the tunnel learns what to say about this server, never its address',
    () async {
      final transport = _Recording();
      final core = NetworkExtensionCore(transport: transport);
      addTearDown(() => NetworkExtensionCore(transport: ChannelTransport()));
      await core.load(
        NormConfig(
          version: 1,
          account: Account(displayName: 'SwagaVPN', status: 'active'),
          name: 'SwagaVPN',
          locations: [
            Location(
              id: 'fi',
              label: 'FL [VLESS - tcp]',
              proxy: const {
                'type': 'vless',
                'server': 'fi.example.net',
                'port': 443,
                'uuid': 'secret-uuid',
              },
            ),
          ],
        ),
      );
      await core.connect('fi');

      final args = transport.calls['start']!;
      final notice = args['notice'] as String;
      final texts = Map<String, String>.from(jsonDecode(notice) as Map);
      expect(texts['configuration'], 'SwagaVPN');
      expect(texts['connected'], 'Connected · FL [VLESS - tcp]');
      expect(texts['silent_body'], contains('FL [VLESS - tcp]'));
      expect(notice, isNot(contains('fi.example.net')));
      expect(notice, isNot(contains('secret-uuid')));
    },
  );

  test('a notification tap is taken once', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const control = MethodChannel('vpn/control');
    var pending = kLaunchServerPicker as String?;
    messenger.setMockMethodCallHandler(control, (call) async {
      if (call.method != 'take_launch_action') return null;
      final action = pending;
      pending = null;
      return action;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(control, null));
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await c.read(launchActionProvider.notifier).check();
    expect(c.read(launchActionProvider), kLaunchServerPicker);
    c.read(launchActionProvider.notifier).consume();
    await c.read(launchActionProvider.notifier).check();
    expect(c.read(launchActionProvider), isNull);
  });
}

class _Recording implements ControlTransport {
  final calls = <String, Map<String, Object?>>{};

  @override
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
    calls[method] = args ?? const {};
    return null;
  }

  @override
  Stream<String?> get statusEvents => const Stream.empty();

  @override
  Stream<String> get noticeEvents => const Stream.empty();
}
