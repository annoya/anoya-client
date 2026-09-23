import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/vpn_core.dart';
import 'providers.dart';

class SessionState {
  const SessionState({this.status = VpnStatus.disconnected, this.startedAt});

  final VpnStatus status;

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
    state = SessionState(
      status: s,
      startedAt: state.startedAt ?? DateTime.now(),
    );
    unawaited(_askTheSystem());
  }

  Future<void> _askTheSystem() async {
    final core = ref.read(vpnCoreProvider);
    final since = await core.connectedSince();
    // The answer can land after dispose or disconnect; a stale start would
    // restart the next session's clock.
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

String sessionClock(DateTime? startedAt) {
  if (startedAt == null) return '';
  final d = DateTime.now().difference(startedAt);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}
