import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/vpn_core.dart';
import 'providers.dart';

/// The tunnel's status and when the current session started.
///
/// One owner for both, because two of them disagree: the home screen and the
/// menu bar show the same session clock, and each keeping its own start time
/// means the window and the menu can print different durations for the same
/// tunnel.
class SessionState {
  const SessionState({this.status = VpnStatus.disconnected, this.startedAt});

  final VpnStatus status;

  /// When this session began. Null unless connected.
  ///
  /// The system's own answer where it has one (`NEVPNConnection.connectedDate`),
  /// because the app is not always present at the start: a tunnel raised from
  /// the system's VPN switch, or by an on-demand rule, was running long before
  /// the app was opened. Stamping the moment we first looked made the clock
  /// count from the wrong event — it read seconds for a session hours old.
  ///
  /// The app's own first sighting is the fallback, for a platform that cannot
  /// say. A clock that is honestly short beats no clock.
  final DateTime? startedAt;

  bool get connected => status == VpnStatus.connected;
  bool get busy =>
      status == VpnStatus.connected || status == VpnStatus.connecting;
}

class SessionController extends Notifier<SessionState> {
  StreamSubscription<VpnStatus>? _sub;

  @override
  SessionState build() {
    final core = ref.watch(vpnCoreProvider);
    _sub = core.statusStream().listen(_onStatus);
    ref.onDispose(() => _sub?.cancel());
    if (core.status == VpnStatus.connected) unawaited(_askTheSystem());
    return SessionState(
      status: core.status,
      startedAt: core.status == VpnStatus.connected ? DateTime.now() : null,
    );
  }

  void _onStatus(VpnStatus s) {
    if (s != VpnStatus.connected) {
      state = SessionState(status: s);
      return;
    }
    // The status is applied at once — the ring must not wait on a round trip
    // to the platform — with our own sighting standing in until the system's
    // answer arrives a frame or two later.
    state = SessionState(
      status: s,
      startedAt: state.startedAt ?? DateTime.now(),
    );
    unawaited(_askTheSystem());
  }

  /// Replaces the provisional start with the system's, when it has one and it
  /// differs. Guarded on still being connected: the answer can arrive after the
  /// tunnel has gone down, and a start time on a dead session would restart the
  /// clock on the next one.
  Future<void> _askTheSystem() async {
    final core = ref.read(vpnCoreProvider);
    final since = await core.connectedSince();
    // The provider can be gone by the time the platform answers — a rebuild, a
    // container torn down — and touching state then throws rather than being
    // ignored.
    if (!ref.mounted || since == null || !state.connected) return;
    final known = state.startedAt;
    if (known != null &&
        known.difference(since).abs() < const Duration(seconds: 1)) {
      return;
    }
    state = SessionState(status: state.status, startedAt: since);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The session clock as `HH:MM:SS`, empty when there is no session.
String sessionClock(DateTime? startedAt) {
  if (startedAt == null) return '';
  final d = DateTime.now().difference(startedAt);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}
