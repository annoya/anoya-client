import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/state/desktop_notices.dart';
import 'package:anoya/state/launch_action.dart';
import 'package:anoya/state/providers.dart';

void main() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const notify = MethodChannel('vpn/notify');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(notify, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(notify, null));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [vpnCoreProvider.overrideWithValue(_Core())],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a silent server is shown once and withdrawn when it answers', () async {
    final c = container();
    final notices = c.read(desktopNoticesProvider);

    await notices.handle(kNoticeSilent);
    await notices.handle(kNoticeAnswers);

    expect(calls.map((c) => c.method), ['notify', 'withdraw']);
    final shown = Map<String, Object?>.from(calls.first.arguments as Map);
    expect(shown['id'], kNoticeSilent);
    expect(shown['title'], 'The server is not answering');
    expect(shown['action'], kLaunchServerPicker);
    expect((calls.last.arguments as Map)['id'], kNoticeSilent);
  });

  test(
    'a start that failed without the app is shown without an action',
    () async {
      final c = container();
      await c.read(desktopNoticesProvider).handle(kNoticeStartFailed);

      final shown = Map<String, Object?>.from(calls.single.arguments as Map);
      expect(shown['title'], 'The VPN could not start');
      expect(shown.containsKey('action'), isFalse);
    },
  );

  test('a click on the notification opens the server picker', () async {
    final c = container();
    c.read(desktopNoticesProvider);

    await messenger.handlePlatformMessage(
      'vpn/notify',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('clicked', kLaunchServerPicker),
      ),
      (_) {},
    );

    expect(c.read(launchActionProvider), kLaunchServerPicker);
  });
}

class _Core extends VpnCore {
  @override
  VpnStatus get status => VpnStatus.connected;

  @override
  Stream<VpnStatus> statusStream() => const Stream.empty();

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}
}
