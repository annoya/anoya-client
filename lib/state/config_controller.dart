import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/routing_store.dart';
import '../core/vpn_core.dart';
import 'providers.dart';

/// How often the client re-pulls the config bundle while the app is running.
/// Pull (not push) matches the rest of the system: workers poll management the
/// same way, and policy changes only need minutes-level propagation.
const kConfigPollInterval = Duration(minutes: 5);

/// Minimum gap between automatic policy re-applies (reconnects), so a flapping
/// server config cannot bounce the tunnel in a loop.
const kReapplyMinGap = Duration(minutes: 1);

class ConfigState {
  const ConfigState({this.config, this.selectedId, this.loading = false, this.error});

  final NormConfig? config;
  final String? selectedId;
  final bool loading;
  final String? error;

  Location? get selectedLocation {
    final locs = config?.locations ?? [];
    for (final l in locs) {
      if (l.id == selectedId) return l;
    }
    return locs.isNotEmpty ? locs.first : null;
  }

  ConfigState copyWith({NormConfig? config, String? selectedId, bool? loading, String? error}) =>
      ConfigState(
        config: config ?? this.config,
        selectedId: selectedId ?? this.selectedId,
        loading: loading ?? this.loading,
        error: error, // deliberately not preserved: each transition resets it
      );
}

/// Owns the config bundle: fetches it on startup, before every connect, and on
/// a poll timer. When the server-side policy changes while the tunnel is up,
/// re-applies it by reconnecting (rate-limited).
class ConfigController extends Notifier<ConfigState> {
  Timer? _timer;
  DateTime _lastReapply = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  ConfigState build() {
    _timer = Timer.periodic(kConfigPollInterval, (_) => _poll());
    ref.onDispose(() => _timer?.cancel());
    // Initial load once the app shell is up.
    Future.microtask(refresh);
    return const ConfigState(loading: true);
  }

  Future<ApiClient> _api() async {
    final session = ref.read(sessionProvider);
    final server = await session.serverUrl();
    final token = await session.token();
    if (server == null) throw StateError('not logged in');
    return ApiClient(server, token: token);
  }

  /// Fetch the bundle and update state. Returns the fresh config.
  Future<NormConfig> refresh() async {
    state = state.copyWith(loading: true);
    try {
      final api = await _api();
      final cfg = await api.fetchConfig();
      Log.i('config: status=${cfg.account.status}, ${cfg.locations.length} location(s)');
      _accept(cfg);
      return cfg;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      rethrow;
    }
  }

  void select(String id) {
    state = state.copyWith(selectedId: id);
  }

  /// Connect to the selected location: mandatory re-fetch first, then hand the
  /// config (with effective routing) to the core. Errors land in state.error.
  Future<void> connect() async {
    final core = ref.read(vpnCoreProvider);
    state = state.copyWith(error: null);
    try {
      final cfg = await refresh();
      if (!cfg.account.canConnect) {
        state = state.copyWith(error: 'Account is ${cfg.account.status.replaceAll('_', ' ')}.');
        return;
      }
      final id = state.selectedLocation?.id;
      if (id == null) {
        state = state.copyWith(error: 'No location available.');
        return;
      }
      await core.load(await _withEffectiveRouting(cfg));
      await core.connect(id);
      _lastReapply = DateTime.now();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> disconnect() => ref.read(vpnCoreProvider).disconnect();

  /// Server-managed policy, or the device-local rules when the server sets
  /// none (same merge the connect path applies).
  Future<NormConfig> _withEffectiveRouting(NormConfig cfg) async {
    if (cfg.routing != null) return cfg;
    final local = await RoutingStore.load();
    return local != null ? cfg.withRouting(local) : cfg;
  }

  void _accept(NormConfig cfg) {
    var selected = state.selectedId;
    if (selected == null || cfg.locations.every((l) => l.id != selected)) {
      selected = cfg.locations.isNotEmpty ? cfg.locations.first.id : null;
    }
    state = ConfigState(config: cfg, selectedId: selected);
  }

  Future<void> _poll() async {
    if (!ref.read(authControllerProvider).loggedIn) return;
    final old = state.config;
    final NormConfig cfg;
    try {
      final api = await _api();
      cfg = await api.fetchConfig();
    } catch (e) {
      Log.e('config poll failed', '$e');
      return; // transient network problems must not disturb the UI/tunnel
    }
    final connectedTo = state.selectedLocation?.id;
    _accept(cfg);
    await _maybeReapply(old, cfg, connectedTo);
  }

  /// If the tunnel is up and the server changed something the tunnel embeds
  /// (routing policy or the active location's proxy config), reconnect to
  /// apply it. Account gone inactive → disconnect (the worker has already cut
  /// the traffic server-side; this syncs the client state).
  Future<void> _maybeReapply(NormConfig? old, NormConfig cfg, String? locationId) async {
    final core = ref.read(vpnCoreProvider);
    if (core.status != VpnStatus.connected) return;

    if (!cfg.account.canConnect) {
      Log.i('config poll: account ${cfg.account.status} — disconnecting');
      await core.disconnect();
      return;
    }
    if (old == null || locationId == null) return;

    final reasons = <String>[
      if (routingChanged(old, cfg)) 'routing policy',
      if (proxyChanged(old, cfg, locationId)) 'location config',
    ];
    if (reasons.isEmpty) return;
    if (DateTime.now().difference(_lastReapply) < kReapplyMinGap) {
      Log.i('config poll: ${reasons.join('+')} changed, reapply skipped (rate limit)');
      return;
    }
    if (cfg.locations.every((l) => l.id != locationId)) {
      Log.i('config poll: connected location disappeared — disconnecting');
      await core.disconnect();
      return;
    }
    Log.i('config poll: ${reasons.join(' + ')} changed — reconnecting to apply');
    _lastReapply = DateTime.now();
    await core.load(await _withEffectiveRouting(cfg));
    await core.connect(locationId);
  }
}

/// True when the server-managed routing policy differs (including appearing
/// or disappearing). Local rules are not involved: they change only on this
/// device, through screens that the user drives.
bool routingChanged(NormConfig old, NormConfig fresh) =>
    jsonEncode(old.routing?.toJson()) != jsonEncode(fresh.routing?.toJson());

/// True when the proxy config of the given location differs (keys, SNI,
/// endpoint...), meaning the running tunnel was built from stale data.
bool proxyChanged(NormConfig old, NormConfig fresh, String locationId) {
  Map<String, dynamic>? proxyOf(NormConfig c) {
    for (final l in c.locations) {
      if (l.id == locationId) return l.proxy;
    }
    return null;
  }

  final a = proxyOf(old);
  final b = proxyOf(fresh);
  if (a == null || b == null) return a != b;
  return jsonEncode(a) != jsonEncode(b);
}

final configControllerProvider =
    NotifierProvider<ConfigController, ConfigState>(ConfigController.new);
