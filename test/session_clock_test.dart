import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/vpn_core.dart';
import 'package:vpn_client/state/providers.dart';
import 'package:vpn_client/state/session.dart';

/// How long the tunnel has been up.
///
/// The app is not always present at the start: iOS raises the tunnel from its
/// own VPN switch and from on-demand rules, and the app may be opened hours
/// later. Stamping the moment we first looked counted from the wrong event, so
/// a session that had been up all day read a few seconds.
void main() {
  /// The provisional start is set synchronously, so waiting for "not null"
  /// would return before the system's answer replaces it. Wait for the value to
  /// stop moving instead.
  Future<SessionState> settle(ProviderContainer c) async {
    DateTime? last;
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final now = c.read(sessionProvider).startedAt;
      if (i > 2 && now == last) break;
      last = now;
    }
    return c.read(sessionProvider);
  }

  test('a tunnel already up is timed from when the system raised it', () async {
    final since = DateTime.now().subtract(const Duration(hours: 3));
    final c = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(_Core(VpnStatus.connected, since)),
      ],
    );
    addTearDown(c.dispose);

    final s = await settle(c);
    expect(
      s.startedAt!.difference(since).abs(),
      lessThan(const Duration(seconds: 1)),
    );
    expect(
      sessionClock(s.startedAt),
      startsWith('03:'),
      reason: 'opening the app is not when the tunnel came up',
    );
  });

  test('a platform with no answer keeps the app’s own sighting', () async {
    // Better a clock that is honestly short than no clock at all.
    final c = ProviderContainer(
      overrides: [
        vpnCoreProvider.overrideWithValue(_Core(VpnStatus.connected, null)),
      ],
    );
    addTearDown(c.dispose);

    final s = await settle(c);
    expect(s.startedAt, isNotNull);
    expect(sessionClock(s.startedAt), startsWith('00:00:'));
  });

  test('the status is not held up waiting for the answer', () async {
    // The ring turns green on the status, not on a round trip to the platform.
    final core = _Core(VpnStatus.connected, DateTime.now(), slow: true);
    final c = ProviderContainer(
      overrides: [vpnCoreProvider.overrideWithValue(core)],
    );
    addTearDown(c.dispose);
    expect(c.read(sessionProvider).status, VpnStatus.connected);
  });

  test(
    'a session that ended before the answer arrived does not get a clock',
    () async {
      // The reply can land after the tunnel is down; a start time on a dead
      // session would carry into the next one.
      final core = _Core(VpnStatus.connected, DateTime.now(), slow: true);
      final c = ProviderContainer(
        overrides: [vpnCoreProvider.overrideWithValue(core)],
      );
      addTearDown(c.dispose);
      c.read(sessionProvider); // build, which asks
      core.emit(VpnStatus.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.read(sessionProvider).startedAt, isNull);
    },
  );
}

class _Core extends VpnCore {
  _Core(this._status, this._since, {this.slow = false});
  final VpnStatus _status;
  final DateTime? _since;
  final bool slow;
  final _statuses = StreamController<VpnStatus>.broadcast();

  void emit(VpnStatus s) => _statuses.add(s);

  @override
  VpnStatus get status => _status;

  @override
  Stream<VpnStatus> statusStream() => _statuses.stream;

  @override
  Future<DateTime?> connectedSince() async {
    if (slow) await Future<void>.delayed(const Duration(milliseconds: 60));
    return _since;
  }

  @override
  Future<void> load(NormConfig config) async {}

  @override
  Future<void> connect(String locationId) async {}

  @override
  Future<void> disconnect() async {}
}
