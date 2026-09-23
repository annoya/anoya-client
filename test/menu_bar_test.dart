import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anoya/core/menu_bar.dart';
import 'package:anoya/core/norm_config.dart';
import 'package:anoya/core/profile.dart';
import 'package:anoya/core/vpn_core.dart';
import 'package:anoya/state/menu_bar_controller.dart';
import 'package:anoya/state/profiles_controller.dart';
import 'package:anoya/state/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Profile profile({String name = 'ТСПУ Дронов'}) => Profile(
    id: 'p1',
    type: ProfileType.subscription,
    name: name,
    locations: [
      Location(
        id: 'l1',
        label: 'Germany',
        proxy: {'type': 'vless', 'server': '1.2.3.4'},
      ),
    ],
  );

  ProfilesState profiles({Profile? p, bool switching = false}) => ProfilesState(
    profiles: p == null ? const [] : [p],
    activeId: p?.id,
    selectedLocationId: p == null ? null : 'l1',
    switching: switching,
  );

  SessionState session(VpnStatus status, {DateTime? at}) =>
      SessionState(status: status, startedAt: at);

  group('what the menu says', () {
    test(
      'a connected tunnel names where it goes and how long it has been up',
      () {
        final state = menuBarStateFor(
          session(
            VpnStatus.connected,
            at: DateTime.now().subtract(
              const Duration(hours: 1, minutes: 2, seconds: 3),
            ),
          ),
          profiles(p: profile()),
        );
        expect(state.status, 'Connected · Germany');
        expect(state.detail, '01:02:03 · ТСПУ Дронов');
        expect(
          state.tunnelUp,
          isTrue,
          reason: 'the icon and the Quit note ride on this',
        );
      },
    );

    test(
      'with no configuration the menu says so instead of offering actions',
      () {
        final state = menuBarStateFor(
          session(VpnStatus.disconnected),
          profiles(),
        );
        expect(state.status, 'No configuration');
        expect(state.canConnect, isFalse);
        expect(state.canDisconnect, isFalse);
        expect(
          state.detail,
          isEmpty,
          reason: 'a blank second line reads as a bug',
        );
      },
    );

    test('disconnected still names the configuration Connect would use', () {
      final state = menuBarStateFor(
        session(VpnStatus.disconnected),
        profiles(p: profile()),
      );
      expect(state.status, 'Not connected');
      expect(
        state.detail,
        'ТСПУ Дронов',
        reason: 'which config it will connect to is needed before the click',
      );
    });

    test('a hot switch is not called connecting', () {
      final state = menuBarStateFor(
        session(VpnStatus.connected, at: DateTime.now()),
        profiles(p: profile(), switching: true),
      );
      expect(state.status, 'Switching… · Germany');
      expect(
        state.connecting,
        isTrue,
        reason: 'the icon shows the in-flight state',
      );
    });
  });

  group('what the menu allows', () {
    test('connecting can be abandoned but not repeated', () {
      final state = menuBarStateFor(
        session(VpnStatus.connecting),
        profiles(p: profile()),
      );
      expect(
        state.canConnect,
        isFalse,
        reason:
            'pressing it again restarts the attempt rather than hurrying it',
      );
      expect(state.canDisconnect, isTrue);
      expect(state.tunnelUp, isFalse, reason: 'an attempt is not a tunnel');
    });

    test('exactly one of the two is available in every settled state', () {
      for (final s in [
        VpnStatus.disconnected,
        VpnStatus.connected,
        VpnStatus.error,
      ]) {
        final state = menuBarStateFor(session(s), profiles(p: profile()));
        expect(
          state.canConnect ^ state.canDisconnect,
          isTrue,
          reason: '$s offered ${state.canConnect}/${state.canDisconnect}',
        );
      }
    });
  });

  group('the channel', () {
    late List<MethodCall> sent;
    late MenuBar menu;

    setUp(() {
      sent = [];
      const channel = MethodChannel('vpn/tray');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            sent.add(call);
            return null;
          });
      menu = MenuBar(channel: channel);
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('vpn/tray'), null);
    });

    test('a menu bar exists only where the platform has one', () {
      expect(MenuBar.supported, Platform.isMacOS);
    });

    test('state that did not change is not pushed twice', () async {
      const state = MenuBarState(status: 'Connected', detail: '00:00:01 · X');
      await menu.update(state);
      await menu.update(state);
      expect(sent.map((c) => c.method), ['update']);

      await menu.update(const MenuBarState(status: 'Not connected'));
      expect(sent.length, 2, reason: 'a real change still goes through');
    }, skip: !MenuBar.supported ? 'no menu bar on this host' : null);

    test('every field the platform reads is on the wire', () {
      const state = MenuBarState(
        status: 'Connected · Germany',
        detail: '00:04:11 · X',
        canConnect: false,
        canDisconnect: true,
        tunnelUp: true,
        connecting: false,
      );
      expect(state.toChannel(), {
        'status': 'Connected · Germany',
        'detail': '00:04:11 · X',
        'can_connect': false,
        'can_disconnect': true,
        'tunnel_up': true,
        'connecting': false,
      });
    });
  });

  test('the session clock counts from when the app learned of the tunnel', () {
    expect(sessionClock(null), isEmpty);
    expect(
      sessionClock(DateTime.now().subtract(const Duration(seconds: 59))),
      '00:00:59',
    );
    expect(
      sessionClock(DateTime.now().subtract(const Duration(minutes: 90))),
      '01:30:00',
    );
  });
}
