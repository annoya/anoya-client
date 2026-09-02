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

  /// The most recent answer, kept across screens. Cleared when the tunnel goes
  /// down: a delay measured through a session that has ended describes nothing
  /// the user can act on, and a stale green line under a dead tunnel is worse
  /// than no line.
  final ConnectionCheck? last;
  final bool running;

  ConnectionCheckState copyWith({
    ConnectionCheckPrefs? prefs,
    ConnectionCheck? last,
    bool clearLast = false,
    bool? running,
  }) =>
      ConnectionCheckState(
        prefs: prefs ?? this.prefs,
        last: clearLast ? null : (last ?? this.last),
        running: running ?? this.running,
      );
}

/// Runs the probe and remembers its answer.
///
/// Separate from the profiles controller on purpose: what it measures belongs
/// to the *session*, not to a configuration, and a configuration switch must
/// not carry an old measurement with it.
class ConnectionCheckController extends Notifier<ConnectionCheckState> with ReadyGate {
  StreamSubscription<VpnStatus>? _sub;

  @override
  ConnectionCheckState build() {
    ready = _load();
    // The trigger is the session coming up, not the Connect button: a tunnel
    // raised by an on-demand rule or by Android's always-on switch is exactly
    // the one nobody is watching, and "up but carrying nothing" is worth
    // knowing there most of all.
    final core = ref.read(vpnCoreProvider);
    _sub = core.statusStream().listen((s) {
      if (s == VpnStatus.connected) {
        unawaited(runAfterConnect());
      } else {
        forget();
      }
    });
    ref.onDispose(() => _sub?.cancel());
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

  /// Forgets the last answer — called when the tunnel stops.
  void forget() => state = state.copyWith(clearLast: true, running: false);

  /// What the app does after a connect, when the check is on.
  ///
  /// Silent on success: the tunnel coming up is already the message, and a
  /// second "all good" after every connect is a line people stop reading
  /// exactly by the time it says something.
  ///
  /// It does not ask straight away, and it does not believe the first no.
  /// Between "the system says connected" and "traffic crosses the tunnel"
  /// there is a handshake: an AmneziaWG peer only starts one when the first
  /// packet asks for it, and amneziawg-go retries a lost initiation after
  /// `RekeyTimeout` — five seconds, exactly the probe's own default. A probe
  /// fired at zero lost that race and reported "No answer" on a server that
  /// was about to work; pressing Test now a moment later passed. A newly
  /// issued config (ADR-009) is the same story on the server's side.
  Future<void> runAfterConnect() async {
    await ready;
    if (!state.prefs.enabled || state.running) return;
    state = state.copyWith(running: true);
    try {
      await Future<void>.delayed(kCheckWarmUp);
      for (var attempt = 1; attempt <= kCheckAttempts; attempt++) {
        // The session can end mid-sequence — a manual disconnect, a drop —
        // and a verdict about a tunnel that no longer exists is noise.
        if (ref.read(vpnCoreProvider).status != VpnStatus.connected) return;
        // The best probe is the one nobody had to send. Bytes that already
        // came back through this server prove the tunnel carries traffic, and
        // prove it with the user's own traffic — so no request leaves the
        // device at all. Silence is not a failure here, only "nothing to look
        // at yet", and then we ask.
        final observed = await _observe();
        if (observed != null) {
          if (ref.mounted) state = state.copyWith(last: observed);
          return;
        }
        final result = await _probe();
        // Only the last word is published: an intermediate failure would flash
        // the banner on the home screen and then take it back.
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

  /// One probe, on demand. Never throws — the failure *is* the result.
  ///
  /// A single attempt, unlike the automatic run: the user pressed the button
  /// now and is owed the answer to *now*, not to a sequence that keeps trying
  /// while they watch a spinner.
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

  /// The server a result belongs to, named the way the user's own screens name
  /// it.
  ///
  /// Not the engine's answer: inside a rendered config a single server is
  /// called `proxy` and a group's members `p0`, `p1` — names the renderer
  /// invented, which appear nowhere the user has ever looked. For a group the
  /// engine picks the member, so the app resolves its positional name back to
  /// the provider's label, the same way the home screen does.
  Future<String> _serverLabel() async {
    final profiles = ref.read(profilesControllerProvider);
    final group = profiles.selectedGroup;
    if (group == null) return profiles.selectedLocation?.label ?? '';
    final picked = await NetworkExtensionCore.groupMember(kGroupName);
    return labelForGroupMember(picked, profiles.selectedGroupMembers);
  }

  /// A pass we did not have to ask for, or null when nothing has come back yet.
  Future<ConnectionCheck?> _observe() async {
    final counters = await ref.read(vpnCoreProvider).proxyBytes();
    if (ConnectionCheck.downloadedFrom(counters) <= 0) return null;
    final via = await _serverLabel();
    Log.i('connection check: traffic already flowing through '
        '${via.isEmpty ? 'the tunnel' : via} ($counters) — not probing');
    return ConnectionCheck.observed(at: DateTime.now(), via: via);
  }

  Future<ConnectionCheck> _probe() async {
    final prefs = state.prefs;
    final core = ref.read(vpnCoreProvider);
    // Asked before the probe, not after: a group can move to another member
    // while a dead one is timing out, and the name then belongs to a server
    // the measurement never touched.
    final via = await _serverLabel();
    final answer = await core.urlTest(prefs.url, prefs.timeout);
    final result = ConnectionCheck.parse(answer, at: DateTime.now(), via: via);
    // The engine's own words go here and nowhere else: the screen shows a
    // sentence, and this is where the dial chain is still readable when
    // somebody has to work out which hop failed.
    Log.i(result.passed
        ? 'connection check: ${result.delayMs} ms through ${via.isEmpty ? 'the tunnel' : via}'
        : 'connection check failed: $answer');
    return result;
  }
}

/// How long a tunnel gets between "connected" and the first question about it.
const kCheckWarmUp = Duration(seconds: 2);

/// Attempts the automatic check makes before it calls the tunnel silent. Three
/// spans the AmneziaWG rekey retry with room to spare; more would only make an
/// actually dead tunnel take longer to say so.
const kCheckAttempts = 3;

const kCheckRetryGap = Duration(seconds: 2);

final connectionCheckProvider =
    NotifierProvider<ConnectionCheckController, ConnectionCheckState>(
        ConnectionCheckController.new);
