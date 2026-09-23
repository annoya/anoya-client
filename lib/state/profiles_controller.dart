import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/app_error.dart';
import '../core/config_source.dart';
import '../core/effective_config.dart';
import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';
import '../core/profile_import.dart';
import '../core/profile_store.dart';
import '../core/rule_list_store.dart';
import '../core/vpn_core.dart';
import '../l10n/l10n.dart';
import 'favorites_controller.dart';
import 'on_demand_controller.dart';
import 'profiles_state.dart';
import 'providers.dart';
import 'ready_gate.dart';

export 'profiles_state.dart';

// The timer tick, not the refresh cadence (that is refreshGapFor): fast so
// a provider asking for five minutes gets five minutes.
const kConfigPollInterval = kMinRefreshGap;

// Rate limit so a flapping source can't loop the tunnel.
const kReapplyMinGap = Duration(minutes: 1);

class ProfilesController extends Notifier<ProfilesState> with ReadyGate {
  Timer? _timer;
  DateTime _lastReapply = DateTime.fromMillisecondsSinceEpoch(0);

  bool _reapplyPending = false;

  bool _stopExpected = false;
  StreamSubscription<VpnStatus>? _statusSub;

  @override
  ProfilesState build() {
    _timer = Timer.periodic(kConfigPollInterval, (_) => _poll());
    ref.onDispose(() => _timer?.cancel());
    _watchForSilentFailures();
    _rememberSelection();
    ready = _init();
    return const ProfilesState(loading: true);
  }

  void _rememberSelection() {
    String? lastProfile;
    String? lastSelection;
    listenSelf((_, next) {
      if (next.loading) return;
      final profileId = next.active?.id;
      final selectionId = next.selectionId;
      if (profileId == lastProfile && selectionId == lastSelection) return;
      lastProfile = profileId;
      lastSelection = selectionId;
      // catchError: a throwing fire-and-forget future is an uncaught async error.
      unawaited(
        ProfileStore.saveSelection(
          profileId,
          selectionId,
        ).catchError((Object e) => Log.e('selection not saved', '$e')),
      );
    });
  }

  Future<void> _init() async {
    unawaited(GeoStore.maybeAutoUpdate());
    final profiles = await ProfileStore.load();
    final saved = await ProfileStore.loadSelection();
    final active =
        profiles.where((p) => p.id == saved.profileId).firstOrNull ??
        (profiles.isEmpty ? null : profiles.first);
    // A selection saved for another configuration is not carried over, even if
    // the id happens to match.
    final restored = active?.id == saved.profileId
        ? _knownSelection(active, saved.selectionId)
        : null;
    // The container can be gone after the reads; assigning state would throw.
    if (!ref.mounted) return;
    state = ProfilesState(
      profiles: profiles,
      activeId: active?.id,
      selectedLocationId: restored ?? _firstLocation(active),
    );
  }

  static String? _knownSelection(Profile? p, String? id) {
    if (p == null || id == null) return null;
    if (ProxyGroup.isGroupId(id)) {
      return p.groups.any((g) => g.id == id) ? id : null;
    }
    return p.locations.any((l) => l.id == id) ? id : null;
  }

  Future<void> addSelfhosted(
    String serverUrl,
    String username,
    String password,
  ) async => _append(await importSelfhosted(serverUrl, username, password));

  Future<void> addSelfhostedOIDC(
    String serverUrl,
    AuthProvider provider,
  ) async => _append(await importSelfhostedOIDC(serverUrl, provider));

  Future<AuthConfig> authConfig(String serverUrl) =>
      ApiClient(serverUrl).authConfig();

  Future<void> addSubscriptionUrl(String name, String url) async =>
      _append(await importSubscriptionUrl(name, url));

  Future<void> addFromText(String text, {String? name}) async =>
      _append(await importText(text, name: name));

  Future<void> addAmneziaKey(String text) async =>
      _append(await importAmneziaKey(text));

  Future<void> _append(Profile p) async {
    await ready;
    final profiles = [...state.profiles, p];
    await ProfileStore.save(profiles);
    state = ProfilesState(
      profiles: profiles,
      activeId: p.id,
      selectedLocationId: _firstLocation(p),
    );
    await syncTunnelConfig();
  }

  Future<Profile> _resolveSelection(
    Profile p,
    String selectionId, {
    bool force = false,
  }) async {
    final resolved = await configSourceFor(
      p,
    ).resolveSelection(selectionId, force: force);
    if (identical(resolved, p)) return p;
    await _replace(resolved);
    return resolved;
  }

  Future<void> _replace(Profile p) async {
    state = state.copyWith(
      profiles: [
        for (final existing in state.profiles)
          existing.id == p.id ? p : existing,
      ],
    );
    await ProfileStore.save(state.profiles);
  }

  String _selectionLabel(String selectionId) {
    for (final l in state.locations) {
      if (l.id == selectionId) return l.label;
    }
    return state.active?.name ?? '';
  }

  Profile? _byId(String id) {
    for (final p in state.profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  static String? _firstLocation(Profile? p) =>
      p == null || p.locations.isEmpty ? null : p.locations.first.id;

  Future<void> removeProfile(String id) async {
    await ready;
    final removed = _byId(id);
    if (removed != null) await configSourceFor(removed).dispose();
    final wasActive = id == state.activeId;
    final profiles = state.profiles.where((p) => p.id != id).toList();
    await ProfileStore.save(profiles);
    await ref.read(favoritesProvider.notifier).forgetProfile(id);
    final newActive = profiles.isEmpty ? null : profiles.first;
    state = ProfilesState(
      profiles: profiles,
      activeId: newActive?.id,
      selectedLocationId: _firstLocation(newActive),
    );
    if (profiles.isEmpty) {
      // The system profile takes its on-demand rules with it, so on-demand is
      // cleared locally only: a disarm push would recreate the profile first.
      await ref.read(vpnCoreProvider).removeSystemProfile();
      await ref.read(onDemandProvider.notifier).forget();
    } else if (wasActive) {
      await syncTunnelConfig();
    }
  }

  Future<void> setActive(String id) async {
    await ready;
    final p = _byId(id);
    // Not copyWith: it cannot null the selection, and location ids are only
    // unique within a profile.
    state = ProfilesState(
      profiles: state.profiles,
      activeId: id,
      selectedLocationId: _firstLocation(p),
    );
    await _applySelection();
  }

  Future<void> selectLocation(String id) async {
    state = state.copyWith(selectedLocationId: id);
    await _applySelection();
  }

  Future<void> _applySelection() async {
    final core = ref.read(vpnCoreProvider);
    var p = state.active;
    final selection = state.selectionId;
    if (p == null || selection == null) return;

    // Resolved even with the tunnel down: the system may start the stored
    // config with no app to fetch a server. Forced: the gateway may have rotated
    // a previously issued server off the account.
    state = state.copyWith(switching: true);
    try {
      p = await _resolveSelection(p, selection, force: true);
    } catch (e) {
      Log.e('issuing the selected server failed', '$e');
      state = state.copyWith(
        switching: false,
        notice: AppError(
          L10n.current.profilesCouldntGetServer(_selectionLabel(selection)),
          detail:
              describeError(e).detail ??
              L10n.current.profilesPreviousServerStillInUse,
        ),
      );
      return;
    }
    state = state.copyWith(switching: false);

    if (core.status != VpnStatus.connected) {
      await syncTunnelConfig();
      return;
    }
    state = state.copyWith(switching: true);
    try {
      await core.reload(await buildNormConfig(p), selection);
      _reapplyPending = false;
      state = state.copyWith(switching: false);
    } catch (e) {
      Log.e('hot switch failed', '$e');
      state = state.copyWith(
        switching: false,
        error: AppError(
          L10n.current.profilesCouldntSwitch,
          detail: L10n.current.profilesCouldntSwitchDetail,
        ),
      );
    }
  }

  Future<Profile> refreshActive() async {
    final p = state.active;
    if (p == null) throw StateError('no active profile');
    return refreshProfile(p.id);
  }

  Future<Profile> refreshProfile(String id) async {
    await ready;
    final p = _byId(id);
    if (p == null) throw StateError('unknown profile $id');
    final updated = await configSourceFor(p).refresh();
    if (identical(updated, p)) return p;
    // Graft onto the profile as it is now: local edits made while the request
    // was in flight must not be reverted by the snapshot.
    final current = _byId(id) ?? p;
    final merged = current.withBundle(
      locations: updated.locations,
      account: updated.account,
      routing: updated.routing,
      dns: updated.dns,
      deviceLimitActive: updated.deviceLimitActive,
      deviceLimitReached: updated.deviceLimitReached,
      unsupportedServers: updated.unsupportedServers,
      groups: updated.groups,
      providerRouting: updated.providerRouting,
      providerRoutingSkipped: updated.providerRoutingSkipped,
      providerRoutingProbed: updated.providerRoutingProbed,
      providerInfo: updated.providerInfo,
      usedFallback: updated.usedFallback,
      rendering: updated.rendering,
      renderingProbed: updated.renderingProbed,
      refreshedAt: updated.refreshedAt ?? DateTime.now(),
      // Issued servers are ours; only the account comes from the gateway.
      amnezia: updated.amnezia == null
          ? current.amnezia
          : (current.amnezia ?? updated.amnezia!).copyWith(
              account: updated.amnezia!.account,
            ),
    );
    await _replace(merged);
    // Pruned against every profile: the list files share one directory.
    await RuleListStore.prune(_liveRuleLists());
    if (id == state.activeId) await syncTunnelConfig();
    return merged;
  }

  Future<void> setRefreshHours(String profileId, int? hours) async {
    await ready;
    final p = _byId(profileId);
    if (p == null) return;
    await _replace(p.copyWith(refreshHours: (value: hours)));
  }

  Future<void> setRuleSet(String profileId, String ruleSetId) => _updateRouting(
    profileId,
    (p) => p.copyWith(ruleSetId: ruleSetId, routingEnabled: true),
  );

  Future<void> setRoutingEnabled(String profileId, bool enabled) =>
      _updateRouting(profileId, (p) => p.copyWith(routingEnabled: enabled));

  Future<void> setProviderRoutingEnabled(String profileId, bool enabled) =>
      _updateRouting(
        profileId,
        (p) => p.copyWith(providerRoutingEnabled: enabled),
      );

  // Downloaded before the flag flips: the engine must never get a rule whose
  // file it would fetch itself. Turning off keeps the files.
  Future<void> setProviderRuleListsEnabled(
    String profileId,
    bool enabled,
  ) async {
    await ready;
    final p = _byId(profileId);
    if (p == null) return;
    if (enabled) await syncRuleLists(profileId);
    await _updateRouting(
      profileId,
      (p) => p.copyWith(providerRuleListsEnabled: enabled),
    );
  }

  Future<List<RuleListStatus>> syncRuleLists(String profileId) async {
    await ready;
    final lists =
        _byId(profileId)?.providerRouting?.lists ?? const <RuleList>[];
    if (lists.isEmpty) return const [];
    final status = await RuleListStore.sync(lists);
    if (profileId == state.activeId) await _applySelection();
    return status;
  }

  // Not filtered by the switch: switched-off lists stay for a free re-enable.
  Iterable<RuleList> _liveRuleLists() => state.profiles.expand(
    (p) => p.providerRouting?.lists ?? const <RuleList>[],
  );

  Future<void> _updateRouting(
    String profileId,
    Profile Function(Profile) change,
  ) async {
    await ready;
    final p = _byId(profileId);
    if (p == null) return;
    await _replace(change(p));
    if (profileId == state.activeId) await _applySelection();
  }

  // A second tap joins the running connect: the pre-connect refresh can take
  // seconds while the core still reports disconnected.
  Future<void>? _connecting;

  Future<void> connect() =>
      _connecting ??= _connect().whenComplete(() => _connecting = null);

  Future<void> _connect() async {
    await ready;
    final core = ref.read(vpnCoreProvider);
    state = state.copyWith(error: null);
    try {
      var p = state.active;
      if (p == null) {
        state = state.copyWith(
          error: AppError(
            L10n.current.statusNoConfiguration,
            detail: L10n.current.profilesNoConfigurationDetail,
          ),
        );
        return;
      }
      if (configSourceFor(p).refreshBeforeConnect) {
        p = await refreshActive();
      }
      if (p.account != null && !p.account!.canConnect) {
        state = state.copyWith(error: describeAccountStatus(p.account!.status));
        return;
      }
      final selection = state.selectionId;
      if (selection == null) {
        state = state.copyWith(
          error: AppError(
            L10n.current.profilesNoServers,
            detail: L10n.current.profilesNoServersDetail,
          ),
        );
        return;
      }
      // Again at connect: an issued server may have expired since selection.
      p = await _resolveSelection(p, selection);
      await core.load(await buildNormConfig(p));
      await core.connect(selection);
      _lastReapply = DateTime.now();
      _reapplyPending = false;
      await ref.read(onDemandProvider.notifier).onConnected();
    } catch (e) {
      Log.e('connect failed', '$e');
      // By label, not address: the endpoint stays out of the interface.
      state = state.copyWith(
        error: describeError(e, subject: state.selectedLocation?.label),
      );
    }
  }

  void clearError() => state = state.copyWith(error: null);

  void clearNotice() => state = state.copyWith(notice: null);

  Future<void> disconnect() async {
    _stopExpected = true;
    await ref.read(onDemandProvider.notifier).pause();
    await ref.read(vpnCoreProvider).disconnect();
  }

  void _watchForSilentFailures() {
    final core = ref.read(vpnCoreProvider);
    var previous = core.status;
    _statusSub = core.statusStream().listen((status) async {
      final wasComing =
          previous == VpnStatus.connecting || previous == VpnStatus.connected;
      previous = status;
      if (status != VpnStatus.disconnected || !wasComing) return;
      if (_stopExpected) {
        _stopExpected = false;
        return;
      }
      final reason = await core.lastDisconnectError();
      // The platform can answer after dispose; assigning state would throw.
      if (!ref.mounted || reason.isEmpty) return;
      Log.e('tunnel stopped on its own', reason);
      state = state.copyWith(
        error: AppError(L10n.current.profilesTunnelStopped, detail: reason),
      );
    });
    ref.onDispose(() => _statusSub?.cancel());
  }

  Future<void> syncTunnelConfig() async {
    var p = state.active;
    final selection = state.selectionId;
    if (p == null || selection == null) return;
    try {
      // Stored config must be runnable on its own: a system start has no app.
      p = await _resolveSelection(p, selection);
      await ref
          .read(vpnCoreProvider)
          .syncConfig(await buildNormConfig(p), selection);
    } catch (e) {
      Log.e('tunnel config sync failed', '$e');
    }
  }

  Future<NormConfig> effectiveConfig(Profile p) async {
    final selection = state.selectionId;
    final resolved = selection == null
        ? p
        : await _resolveSelection(p, selection);
    return buildNormConfig(resolved);
  }

  Future<void> _poll() async {
    final p = state.active;
    if (p == null || !p.isRefreshable) return;
    if (!isDueForRefresh(p)) return;
    // Reapply inside the try: a Timer callback has no other catch above it.
    try {
      final after = await refreshActive();
      await maybeReapply(p, after);
    } catch (e) {
      Log.e('profile poll failed', '$e');
    }
  }

  @visibleForTesting
  Future<void> maybeReapply(Profile before, Profile after) async {
    final core = ref.read(vpnCoreProvider);
    if (core.status != VpnStatus.connected) return;

    if (after.account != null && !after.account!.canConnect) {
      Log.i('poll: account ${after.account!.status} — disconnecting');
      await core.disconnect();
      return;
    }
    final locId = state.selectionId;
    if (locId == null) return;
    final gone = ProxyGroup.isGroupId(locId)
        ? after.groups.every((g) => g.id != locId)
        : after.locations.every((l) => l.id != locId);
    if (gone) {
      Log.i('poll: connected server disappeared — disconnecting');
      await core.disconnect();
      return;
    }

    final routingDiff =
        jsonEncode(before.routing?.toJson()) !=
        jsonEncode(after.routing?.toJson());
    final proxyDiff =
        jsonEncode(_proxyOf(before, locId)) !=
        jsonEncode(_proxyOf(after, locId));
    if (!routingDiff && !proxyDiff && !_reapplyPending) return;
    if (DateTime.now().difference(_lastReapply) < kReapplyMinGap) {
      // The next poll diffs new against new: without this flag a rate-limited
      // reapply would be dropped and the tunnel left on dead credentials.
      _reapplyPending = true;
      Log.i('poll: active config changed, reapply deferred (rate limit)');
      return;
    }
    _reapplyPending = false;
    // Hot reload, never load+connect: a live session ignores startTunnel
    // options and a prefs save re-asserts the tunnel (the ADR-002 leak).
    Log.i('poll: active config changed — hot-reloading to apply');
    _lastReapply = DateTime.now();
    await core.reload(await buildNormConfig(after), locId);
  }

  // For a group, include every member's proxy: rotating one member's
  // credentials must reapply.
  Object? _proxyOf(Profile p, String locId) {
    if (ProxyGroup.isGroupId(locId)) {
      for (final g in p.groups) {
        if (g.id != locId) continue;
        final byId = {for (final l in p.locations) l.id: l.proxy};
        return [g.toJson(), for (final m in g.members) byId[m]];
      }
      return null;
    }
    for (final l in p.locations) {
      if (l.id == locId) return l.proxy;
    }
    return null;
  }
}

final profilesControllerProvider =
    NotifierProvider<ProfilesController, ProfilesState>(ProfilesController.new);
