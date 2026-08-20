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

  /// When this session began, as observed by the app. Null unless connected.
  ///
  /// Observed, not authoritative: a tunnel the system started on its own
  /// (on-demand) was already up when the app first heard about it, so the
  /// clock starts from when we learned, not from when it did. The extension
  /// does not report a start time, and inventing one would be worse than a
  /// clock that is honestly short.
  final DateTime? startedAt;

  bool get connected => status == VpnStatus.connected;
  bool get busy => status == VpnStatus.connected || status == VpnStatus.connecting;
}

class SessionController extends Notifier<SessionState> {
  StreamSubscription<VpnStatus>? _sub;

  @override
  SessionState build() {
    final core = ref.watch(vpnCoreProvider);
    _sub = core.statusStream().listen(_onStatus);
    ref.onDispose(() => _sub?.cancel());
    return SessionState(
      status: core.status,
      startedAt: core.status == VpnStatus.connected ? DateTime.now() : null,
    );
  }

  void _onStatus(VpnStatus s) {
    if (s == VpnStatus.connected) {
      state = SessionState(status: s, startedAt: state.startedAt ?? DateTime.now());
    } else {
      state = SessionState(status: s);
    }
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The session clock as `HH:MM:SS`, empty when there is no session.
String sessionClock(DateTime? startedAt) {
  if (startedAt == null) return '';
  final d = DateTime.now().difference(startedAt);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}
