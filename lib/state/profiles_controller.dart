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

/// How often the poll timer fires. Not how often a source is re-read: that is
/// [refreshGapFor], which honours a panel's own cadence. The timer stays fast
/// so a configuration whose provider asks for five minutes gets five minutes.
const kConfigPollInterval = kMinRefreshGap;

/// Minimum gap between automatic reconnects when a refresh changes the active
/// server/routing while connected (so a flapping source can't loop the tunnel).
const kReapplyMinGap = Duration(minutes: 1);

/// Owns the list of config sources (profiles), the active profile + selected
/// location, and the connect lifecycle. Replaces the old single-config
/// controller; self-hosted login/SSO now create a profile rather than a global
/// session.
class ProfilesController extends Notifier<ProfilesState> with ReadyGate {
  Timer? _timer;
  DateTime _lastReapply = DateTime.fromMillisecondsSinceEpoch(0);

  /// A poll found a change but the rate limit blocked the reapply; the next
  /// poll owes one even if it sees no new diff.
  bool _reapplyPending = false;

  /// The user asked for this stop, so a status falling back to disconnected is
  /// the answer rather than a failure to explain.
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

  /// Persists the active configuration and what it connects through, from the
  /// one place every change passes through.
  ///
  /// Not at the call sites: the selection moves in six of them — adding,
  /// removing, setting active, picking a server, and twice while refreshing —
  /// and a seventh added later would have silently gone back to forgetting.
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
      // Nothing waits on this and nothing should: the selection is already in
      // state, and the write only matters to the next launch. But a fire-and-
      // forget future that throws is an uncaught async error, and a write can
      // fail for reasons this app has no answer to — a full disk, a container
      // that went away. Losing the memory of a choice is not worth that.
      unawaited(
        ProfileStore.saveSelection(
          profileId,
          selectionId,
        ).catchError((Object e) => Log.e('selection not saved', '$e')),
      );
    });
  }

  Future<void> _init() async {
    unawaited(
      GeoStore.maybeAutoUpdate(),
    ); // weekly refresh, never a first download
    final profiles = await ProfileStore.load();
    final saved = await ProfileStore.loadSelection();
    // Ids outlive what they name: a configuration can be gone and a server can
    // disappear from the next refresh of the list it came from. Both are
    // checked against what actually loaded, and the old first-in-the-list
    // behaviour is what remains when either check fails.
    final active =
        profiles.where((p) => p.id == saved.profileId).firstOrNull ??
        (profiles.isEmpty ? null : profiles.first);
    // The saved selection belongs to the saved configuration. When that one is
    // gone and another takes its place, the id is not carried over even if it
    // happens to match something there — a server chosen inside one
    // subscription is not a choice about a different one.
    final restored = active?.id == saved.profileId
        ? _knownSelection(active, saved.selectionId)
        : null;
    // The load is two file reads long, and the container can be gone by the
    // time they finish — a screen torn down, a test ending. Assigning state
    // then throws out of an unawaited future, where nothing catches it.
    if (!ref.mounted) return;
    state = ProfilesState(
      profiles: profiles,
      activeId: active?.id,
      selectedLocationId: restored ?? _firstLocation(active),
    );
  }

  /// The saved selection if the configuration still offers it — as a group or
  /// as a server, since one id names either.
  static String? _knownSelection(Profile? p, String? id) {
    if (p == null || id == null) return null;
    if (ProxyGroup.isGroupId(id)) {
      return p.groups.any((g) => g.id == id) ? id : null;
    }
    return p.locations.any((l) => l.id == id) ? id : null;
  }

  // --- adding profiles ---
  //
  // What a configuration is made of — the fetch, the parse, the diagnosis —
  // lives in core/profile_import.dart. Here it only becomes the active one.

  Future<void> addSelfhosted(
    String serverUrl,
    String username,
    String password,
  ) async => _append(await importSelfhosted(serverUrl, username, password));

  Future<void> addSelfhostedOIDC(
    String serverUrl,
    AuthProvider provider,
  ) async => _append(await importSelfhostedOIDC(serverUrl, provider));

  /// Which auth methods a self-hosted server offers (password + SSO providers).
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
    // A new configuration becomes the active one, so it is what on-demand
    // should bring up from now on.
    await syncTunnelConfig();
  }

  /// Asks the source to fill in whatever the chosen server still needs, and
  /// keeps the answer. Returns the profile unchanged when there was nothing to
  /// do, which is every source but one.
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

  /// Stores an updated profile in place — in state and on disk — leaving the
  /// rest of the state alone.
  Future<void> _replace(Profile p) async {
    state = state.copyWith(
      profiles: [
        for (final existing in state.profiles)
          existing.id == p.id ? p : existing,
      ],
    );
    await ProfileStore.save(state.profiles);
  }

  /// What to call the selection in a message to the user.
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

  /// The default location selection for a profile — its first server, if any.
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
      // The user removed their last configuration: take the VPN profile out of
      // the system settings too, rather than leaving an entry that could still
      // auto-start. It comes back on the next connect. Removing the profile
      // drops its on-demand rules with it, so on-demand is only cleared
      // locally — pushing a disarm would recreate the profile first.
      await ref.read(vpnCoreProvider).removeSystemProfile();
      await ref.read(onDemandProvider.notifier).forget();
    } else if (wasActive) {
      await syncTunnelConfig();
    }
  }

  Future<void> setActive(String id) async {
    await ready;
    final p = _byId(id);
    // Not copyWith: it cannot null the selection out, and a zero-location
    // profile must not inherit the previous profile's location id — ids are
    // only unique within a profile, so a later refresh could turn the stale
    // id into a selection the user never made.
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

  /// Pushes the new selection to the tunnel. On a live session this is a hot
  /// reload — the engine swaps configs under the standing NE session, so the
  /// VPN never drops and no traffic escapes mid-switch. Otherwise the change
  /// only needs to reach the persisted config for the next start.
  Future<void> _applySelection() async {
    final core = ref.read(vpnCoreProvider);
    var p = state.active;
    final selection = state.selectionId;
    if (p == null || selection == null) return;

    // Ask the source for the server first, whether or not a tunnel is running.
    // On a live tunnel this *is* the switch. With the tunnel down it is what
    // makes the stored config runnable: the system can start it later with no
    // app in memory — from the VPN switch in settings, or from always-on — and
    // a place with no server behind it would fail there, where there is nobody
    // to tell. It is also what keeps the configuration screen describing the
    // server the user actually picked.
    //
    // Held under `switching` because it is not instant: a gateway round trip
    // with no sign of it would leave Connect tappable before there is anything
    // to connect with, and the user would meet a refusal whose only cause is
    // that we had not asked yet.
    // Forced: the user just chose this place, and what it is belongs to the
    // source. Reusing a server it issued earlier would mean connecting through
    // something the gateway may already have rotated off the account.
    state = state.copyWith(switching: true);
    try {
      p = await _resolveSelection(p, selection, force: true);
    } catch (e) {
      Log.e('issuing the selected server failed', '$e');
      // Nothing is blocked: the previous server still works and Connect still
      // does something. That makes this a notice, not a dialog (spec §9).
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
      _reapplyPending = false; // the core just got the current config
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

  // --- refresh ---

  /// Re-pull the active profile from its source; returns the refreshed profile
  /// (the same instance when the source is static or the pull found nothing).
  Future<Profile> refreshActive() async {
    final p = state.active;
    if (p == null) throw StateError('no active profile');
    return refreshProfile(p.id);
  }

  /// Re-pull any profile by id (the per-configuration screen's manual refresh).
  Future<Profile> refreshProfile(String id) async {
    await ready;
    final p = _byId(id);
    if (p == null) throw StateError('unknown profile $id');
    final updated = await configSourceFor(p).refresh();
    if (identical(updated, p)) return p;
    // The fetch ran against a snapshot taken when it started. Graft its
    // remote-owned fields onto the profile as it is NOW — the user may have
    // edited the local half (rule set, routing switch) while the request was
    // in flight, and persisting the snapshot would silently revert that.
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
      // The gateway owns what the subscription *is*; which servers we have
      // been issued and when they expire is ours, and a config resolved while
      // this request was in flight must not be undone by an older snapshot.
      amnezia: updated.amnezia == null
          ? current.amnezia
          : (current.amnezia ?? updated.amnezia!).copyWith(
              account: updated.amnezia!.account,
            ),
    );
    await _replace(merged);
    // Pruned against every profile, not just this one: the list files are one
    // shared directory, and pruning against a single policy would delete the
    // files another configuration is using.
    await RuleListStore.prune(_liveRuleLists());
    if (id == state.activeId) await syncTunnelConfig();
    return merged;
  }

  /// How often this configuration re-reads itself, in hours. Null hands the
  /// choice back to the source.
  Future<void> setRefreshHours(String profileId, int? hours) async {
    await ready;
    final p = _byId(profileId);
    if (p == null) return;
    await _replace(p.copyWith(refreshHours: (value: hours)));
  }

  /// Apply a global rule set to a profile. Picking a set also turns routing on:
  /// choosing one and seeing nothing happen would read as a bug.
  Future<void> setRuleSet(String profileId, String ruleSetId) => _updateRouting(
    profileId,
    (p) => p.copyWith(ruleSetId: ruleSetId, routingEnabled: true),
  );

  /// Turn this configuration's rule set on or off. Off leaves the chosen set
  /// remembered — it comes back when routing is switched on again.
  Future<void> setRoutingEnabled(String profileId, bool enabled) =>
      _updateRouting(profileId, (p) => p.copyWith(routingEnabled: enabled));

  /// Accept or refuse the routing a subscription's panel sent. Reaches the
  /// tunnel exactly like the local switch — the rules differ only in authorship.
  Future<void> setProviderRoutingEnabled(String profileId, bool enabled) =>
      _updateRouting(
        profileId,
        (p) => p.copyWith(providerRoutingEnabled: enabled),
      );

  /// Apply or stop applying the provider's rule lists.
  ///
  /// Turning it on downloads them before the tunnel is told anything: the
  /// engine must never be handed a rule whose file it would have to fetch
  /// itself, and the switch would otherwise report success while the rules it
  /// enables still match nothing. That is also why the flag is set *after* the
  /// download rather than optimistically — the caller shows progress instead.
  ///
  /// Turning it off does not delete the files. It used to, which looked
  /// consistent until the cost showed: a live subscription carries a dozen
  /// lists, so changing one's mind cost the whole download again. The switch
  /// promises to apply their rules, not to manage this device's disk; the files
  /// go stale in a week on their own, and the sweep that removes what nothing
  /// points at any more belongs to a refresh, where a provider may genuinely
  /// have dropped a list.
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

  /// Download whatever of a provider's lists we do not have. Also the retry
  /// path: a list that failed is worth one more attempt on demand.
  Future<List<RuleListStatus>> syncRuleLists(String profileId) async {
    await ready;
    final lists =
        _byId(profileId)?.providerRouting?.lists ?? const <RuleList>[];
    if (lists.isEmpty) return const [];
    final status = await RuleListStore.sync(lists);
    // A list that just arrived changes what the engine can run.
    if (profileId == state.activeId) await _applySelection();
    return status;
  }

  /// Every list any live configuration still names.
  ///
  /// Not filtered by the switch: a configuration whose lists are switched off
  /// still refers to them, and its files are worth keeping so turning the
  /// switch back on is free. What this excludes is what nothing points at — a
  /// list the provider dropped, or a configuration the user removed.
  Iterable<RuleList> _liveRuleLists() => state.profiles.expand(
    (p) => p.providerRouting?.lists ?? const <RuleList>[],
  );

  /// Routing changes reach the tunnel the same way a server switch does: hot on
  /// a live session, persisted otherwise.
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

  // --- connect ---

  /// One connect at a time: the pre-connect refresh can take seconds, during
  /// which the core still reports "disconnected" and the button stays live —
  /// a second tap must join the first attempt, not start a parallel one.
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
      // Server-managed profiles force a refresh before connect (enforces
      // account status, key rotation). Others use the cached set.
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
      // Some sources issue a server only when it is asked for, and one may
      // have expired since it was last used. Done here rather than at
      // selection time as well: the tunnel is about to carry traffic, and this
      // is the last moment a stale config can still be replaced quietly.
      p = await _resolveSelection(p, selection);
      await core.load(await buildNormConfig(p));
      await core.connect(selection);
      _lastReapply = DateTime.now();
      _reapplyPending = false;
      // Re-arm (or arm) system auto-connect now that a working config is
      // persisted on the native side.
      await ref.read(onDemandProvider.notifier).onConnected();
    } catch (e) {
      Log.e('connect failed', '$e');
      // Named by its label, not its address: the message stays specific about
      // which server failed, and the endpoint stays out of the interface.
      state = state.copyWith(
        error: describeError(e, subject: state.selectedLocation?.label),
      );
    }
  }

  /// Drops the banner the user just dismissed.
  void clearError() => state = state.copyWith(error: null);

  void clearNotice() => state = state.copyWith(notice: null);

  Future<void> disconnect() async {
    _stopExpected = true;
    // The native stop disarms the system side; record the pause so the UI
    // explains why auto-connect is not active and the next connect re-arms.
    await ref.read(onDemandProvider.notifier).pause();
    await ref.read(vpnCoreProvider).disconnect();
  }

  /// Watches for a tunnel that stopped on its own and says why.
  ///
  /// A packet-tunnel provider that refuses a config reports it to the system,
  /// not to the call that started it: the app used to see the status go
  /// connecting → disconnected and nothing more, which reads as a connect that
  /// hung and then gave up. The system does keep the reason.
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
      // The platform can answer after the container is gone — a rebuild, a
      // test tearing down — and assigning state then throws out of a stream
      // callback, where nothing catches it.
      if (!ref.mounted || reason.isEmpty) return;
      Log.e('tunnel stopped on its own', reason);
      state = state.copyWith(
        error: AppError(L10n.current.profilesTunnelStopped, detail: reason),
      );
    });
    ref.onDispose(() => _statusSub?.cancel());
  }

  /// Mirror the current selection into the system's saved tunnel config, so an
  /// on-demand start always brings up what the app is showing — not whatever
  /// was selected at the last manual connect. Best-effort and silent: it does
  /// nothing until a VPN profile exists (creating one would pop the system
  /// approval dialog at a surprising moment).
  Future<void> syncTunnelConfig() async {
    var p = state.active;
    final selection = state.selectionId;
    if (p == null || selection == null) return;
    try {
      // Whatever is stored must be runnable on its own: a system-initiated
      // start has no app to fetch anything for it. Costs nothing for a source
      // that publishes its servers, and nothing again for one that issues them
      // once the config in hand is still good.
      p = await _resolveSelection(p, selection);
      await ref
          .read(vpnCoreProvider)
          .syncConfig(await buildNormConfig(p), selection);
    } catch (e) {
      // Best-effort by design: every caller here is a side effect of something
      // else the user did, and the next connect writes the config anyway.
      Log.e('tunnel config sync failed', '$e');
    }
  }

  /// The config the core would run for [p] right now (routing resolved, LAN
  /// rules and geo availability applied). Exposed so on-demand can hand it to
  /// the system when arming.
  ///
  /// Arming is the one moment outside a connect that genuinely needs a server
  /// in hand: the system will bring this up with no app running, so a source
  /// that issues servers on demand has to be asked now. Without this, arming
  /// an Amnezia subscription that had never connected reported "not armed"
  /// and gave no reason — the system had refused a config we never sent.
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
    // The reapply stays inside the try: it can throw too (NE call, config
    // build), and a Timer callback has no other catch above it — an escape
    // here is an unhandled zone error instead of a logged poll failure.
    try {
      final after = await refreshActive();
      await maybeReapply(p, after);
    } catch (e) {
      Log.e('profile poll failed', '$e');
    }
  }

  /// Reconnect the running tunnel when a refresh changed the active server's
  /// proxy or the managed routing; disconnect if the account went inactive or
  /// the connected server disappeared. Rate-limited. Public only for the
  /// leak-invariant test — nothing outside _poll should call it.
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
      // refreshActive already persisted the new profile, so the next poll
      // diffs new-against-new and sees no change — without this flag a
      // rate-limited reapply would be dropped forever, leaving the live
      // tunnel on dead credentials until a manual reconnect.
      _reapplyPending = true;
      Log.i('poll: active config changed, reapply deferred (rate limit)');
      return;
    }
    _reapplyPending = false;
    // Hot reload, never load+connect: startTunnel on a live session does not
    // deliver a config (options are read at extension launch only), and saving
    // preferences on a live session makes the system re-assert the tunnel —
    // the reconnect leak ADR-002 exists to avoid. Same path as a user switch.
    Log.i('poll: active config changed — hot-reloading to apply');
    _lastReapply = DateTime.now();
    await core.reload(await buildNormConfig(after), locId);
  }

  /// What the selection resolves to, for diffing one poll against the next.
  ///
  /// For a group that is the group itself plus every member's proxy: a provider
  /// rotating one member's credentials must reapply, and comparing only the
  /// group would miss it.
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
