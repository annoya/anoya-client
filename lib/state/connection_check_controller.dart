import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_check.dart';
import '../core/log.dart';
import '../core/mihomo_tun_config.dart' show kGroupName;
import '../core/network_extension_core.dart';
import '../core/vpn_core.dart';
import 'group_member.dart';
import 'profiles_controller.dart';
import 'providers.dart';
import 'ready_gate.dart';

class ConnectionCheckState {
  const ConnectionCheckState({
    this.prefs = const ConnectionCheckPrefs(),
    this.last,
    this.running = false,
  });

  final ConnectionCheckPrefs prefs;

  final ConnectionCheck? last;
  final bool running;

  ConnectionCheckState copyWith({
    ConnectionCheckPrefs? prefs,
    ConnectionCheck? last,
    bool clearLast = false,
    bool? running,
  }) => ConnectionCheckState(
    prefs: prefs ?? this.prefs,
    last: clearLast ? null : (last ?? this.last),
    running: running ?? this.running,
  );
}

class ConnectionCheckController extends Notifier<ConnectionCheckState>
    with ReadyGate {
  StreamSubscription<VpnStatus>? _sub;

  @override
  ConnectionCheckState build() {
    ready = _load();
    final core = ref.read(vpnCoreProvider);
    _sub = core.statusStream().listen((s) {
      if (s == VpnStatus.connected) {
        unawaited(runAfterConnect());
      } else {
        forget();
      }
    });
    ref.onDispose(() => _sub?.cancel());
    ref.listen(profilesControllerProvider.select((s) => s.selectionId), (
      was,
      now,
    ) {
      if (was != null && was != now) forget();
    });
    ref.listen(profilesControllerProvider.select((s) => s.switching), (
      was,
      now,
    ) {
      if (was == true && now == false && core.status == VpnStatus.connected) {
        unawaited(runAfterConnect());
      }
    });
    return const ConnectionCheckState();
  }

  Future<void> _load() async {
    final prefs = await ConnectionCheckStore.load();
    if (ref.mounted) state = state.copyWith(prefs: prefs);
  }

  Future<void> setEnabled(bool v) => _save(state.prefs.copyWith(enabled: v));

  Future<void> setUrl(String v) => _save(state.prefs.copyWith(url: v));

  Future<void> setTimeout(int seconds) =>
      _save(state.prefs.copyWith(timeoutSeconds: seconds));

  Future<void> _save(ConnectionCheckPrefs next) async {
    await ready;
    state = state.copyWith(prefs: next);
    await ConnectionCheckStore.save(next);
  }

  void forget() => state = state.copyWith(clearLast: true, running: false);

  Future<void> runAfterConnect() async {
    await ready;
    if (!state.prefs.enabled || state.running) return;
    state = state.copyWith(running: true);
    try {
      await Future<void>.delayed(kCheckWarmUp);
      for (var attempt = 1; attempt <= kCheckAttempts; attempt++) {
        if (ref.read(vpnCoreProvider).status != VpnStatus.connected) return;
        final observed = await _observe();
        if (observed != null) {
          if (ref.mounted) state = state.copyWith(last: observed);
          return;
        }
        final result = await _probe();
        if (result.passed || attempt == kCheckAttempts) {
          if (ref.mounted) state = state.copyWith(last: result);
          return;
        }
        await Future<void>.delayed(kCheckRetryGap);
      }
    } finally {
      if (ref.mounted) state = state.copyWith(running: false);
    }
  }

  Future<ConnectionCheck> run() async {
    await ready;
    if (state.running) return state.last ?? ConnectionCheck(at: DateTime.now());
    state = state.copyWith(running: true);
    try {
      final result = await _probe();
      if (ref.mounted) state = state.copyWith(last: result, running: false);
      return result;
    } finally {
      if (ref.mounted && state.running) state = state.copyWith(running: false);
    }
  }

  Future<String> _serverLabel() async {
    final profiles = ref.read(profilesControllerProvider);
    final group = profiles.selectedGroup;
    if (group == null) return profiles.selectedLocation?.label ?? '';
    final picked = await NetworkExtensionCore.groupMember(kGroupName);
    return labelForGroupMember(picked, profiles.selectedGroupMembers);
  }

  Future<ConnectionCheck?> _observe() async {
    final counters = await ref.read(vpnCoreProvider).proxyBytes();
    if (ConnectionCheck.downloadedFrom(counters) <= 0) return null;
    final via = await _serverLabel();
    Log.i(
      'connection check: traffic already flowing through '
      '${via.isEmpty ? 'the tunnel' : via} ($counters) — not probing',
    );
    return ConnectionCheck.observed(at: DateTime.now(), via: via);
  }

  Future<ConnectionCheck> _probe() async {
    final prefs = state.prefs;
    final core = ref.read(vpnCoreProvider);
    final via = await _serverLabel();
    final answer = await core.urlTest(prefs.url, prefs.timeout);
    final result = ConnectionCheck.parse(answer, at: DateTime.now(), via: via);
    Log.i(
      result.passed
          ? 'connection check: ${result.delayMs} ms through ${via.isEmpty ? 'the tunnel' : via}'
          : 'connection check failed: $answer',
    );
    return result;
  }
}

const kCheckWarmUp = Duration(seconds: 2);

const kCheckAttempts = 3;

const kCheckRetryGap = Duration(seconds: 2);

final connectionCheckProvider =
    NotifierProvider<ConnectionCheckController, ConnectionCheckState>(
      ConnectionCheckController.new,
    );
