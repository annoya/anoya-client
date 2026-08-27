import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../core/app_error.dart';
import '../core/config_source.dart';
import '../core/geo_store.dart';
import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/oidc_login.dart';
import '../core/profile.dart';
import '../core/profile_store.dart';
import '../core/parsers/subscription.dart';
import '../core/platform_support.dart';
import '../core/subscription_fetch.dart';
import '../core/routing_prefs.dart';
import '../core/routing_policy.dart';
import '../core/rule_list_store.dart';
import '../core/rule_set.dart';
import '../core/vpn_core.dart';
import 'favorites_controller.dart';
import 'on_demand_controller.dart';
import 'providers.dart';

/// How often a refreshable profile (self-hosted / subscription) is re-pulled.
/// How often the poll timer fires. Not how often a source is re-read: that is
/// [refreshGapFor], which honours a panel's own cadence. The timer stays fast
/// so a configuration whose provider asks for five minutes gets five minutes.
const kConfigPollInterval = kMinRefreshGap;

/// Minimum gap between automatic reconnects when a refresh changes the active
/// server/routing while connected (so a flapping source can't loop the tunnel).
const kReapplyMinGap = Duration(minutes: 1);

class ProfilesState {
  const ProfilesState({
    this.profiles = const [],
    this.activeId,
    this.selectedLocationId,
    this.loading = false,
    this.switching = false,
    this.error,
  });

  final List<Profile> profiles;
  final String? activeId;
  final String? selectedLocationId;
  final bool loading;

  /// A hot switch is in flight: the tunnel is up and the engine is being
  /// swapped onto another location/profile. Rows ignore taps meanwhile.
  final bool switching;

  final AppError? error;

  bool get hasProfiles => profiles.isNotEmpty;

  Profile? get active {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  List<Location> get locations => active?.locations ?? const [];

  /// The group the selection names, when it names one. Groups and servers share
  /// the one selection the app already has: the user answers a single question
  /// — what carries my traffic — and a group is one of the answers.
  ProxyGroup? get selectedGroup {
    final id = selectedLocationId;
    if (id == null || !ProxyGroup.isGroupId(id)) return null;
    for (final g in active?.groups ?? const <ProxyGroup>[]) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// What the tunnel should carry traffic through: a group when one is chosen,
  /// otherwise a server. Every path that hands an id to the core uses this —
  /// [selectedLocation] falls back to the first server, which would silently
  /// turn a chosen group into one of its members.
  String? get selectionId => selectedGroup?.id ?? selectedLocation?.id;

  /// The servers a selected group would pick from, in the provider's order.
  List<Location> get selectedGroupMembers {
    final g = selectedGroup;
    if (g == null) return const [];
    final byId = {for (final l in locations) l.id: l};
    return [for (final id in g.members) if (byId[id] != null) byId[id]!];
  }

  Location? get selectedLocation {
    final locs = locations;
    for (final l in locs) {
      if (l.id == selectedLocationId) return l;
    }
    return locs.isEmpty ? null : locs.first;
  }

  ProfilesState copyWith({
    List<Profile>? profiles,
    String? activeId,
    String? selectedLocationId,
    bool? loading,
    bool? switching,
    AppError? error,
  }) =>
      ProfilesState(
        profiles: profiles ?? this.profiles,
        activeId: activeId ?? this.activeId,
        selectedLocationId: selectedLocationId ?? this.selectedLocationId,
        loading: loading ?? this.loading,
        switching: switching ?? this.switching,
        error: error, // reset each transition unless passed
      );
}

/// Owns the list of config sources (profiles), the active profile + selected
/// location, and the connect lifecycle. Replaces the old single-config
/// controller; self-hosted login/SSO now create a profile rather than a global
/// session.
class ProfilesController extends Notifier<ProfilesState> {
  Timer? _timer;
  DateTime _lastReapply = DateTime.fromMillisecondsSinceEpoch(0);

  /// A poll found a change but the rate limit blocked the reapply; the next
  /// poll owes one even if it sees no new diff.
  bool _reapplyPending = false;
  int _idSeq = 0;

  /// The user asked for this stop, so a status falling back to disconnected is
  /// the answer rather than a failure to explain.
  bool _stopExpected = false;
  StreamSubscription<VpnStatus>? _statusSub;

  /// Completes when the persisted state is in [state]. Mutations await it:
  /// here the stakes are higher than a reverted field, because `_append` saves
  /// `[...state.profiles, p]` — an add landing before the load would persist a
  /// list missing every stored profile.
  ///
  /// Already complete until [build] replaces it, which is the truth for any
  /// controller that never scheduled a load: its state is the default, and
  /// there is nothing to wait for.
  Future<void> _ready = Future.value();

  @override
  ProfilesState build() {
    _timer = Timer.periodic(kConfigPollInterval, (_) => _poll());
    ref.onDispose(() => _timer?.cancel());
    _watchForSilentFailures();
    _ready = _init();
    return const ProfilesState(loading: true);
  }

  Future<void> _init() async {
    unawaited(GeoStore.maybeAutoUpdate()); // weekly refresh, never a first download
    final profiles = await ProfileStore.load();
    state = ProfilesState(
      profiles: profiles,
      activeId: profiles.isEmpty ? null : profiles.first.id,
      selectedLocationId: _firstLocation(profiles.isEmpty ? null : profiles.first),
    );
  }

  String _newId() => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_idSeq++}';

  // --- adding profiles ---

  /// Self-hosted sign-in with username/password. Fetches the config bundle and
  /// stores a profile + its session token (Keychain).
  Future<void> addSelfhosted(String serverUrl, String username, String password) async {
    final api = ApiClient(serverUrl);
    final res = await api.login(username, password);
    api.token = res.token;
    await _addSelfhostedFromApi(api, res.token);
  }

  /// Self-hosted sign-in via an OIDC provider (SSO).
  Future<void> addSelfhostedOIDC(String serverUrl, AuthProvider provider) async {
    final api = ApiClient(serverUrl);
    final idToken = await obtainOidcIdToken(provider);
    final res = await api.loginOIDC(provider.id, idToken);
    api.token = res.token;
    await _addSelfhostedFromApi(api, res.token);
  }

  /// Which auth methods a self-hosted server offers (password + SSO providers).
  Future<AuthConfig> authConfig(String serverUrl) => ApiClient(serverUrl).authConfig();

  Future<void> _addSelfhostedFromApi(ApiClient api, String token) async {
    final cfg = await api.fetchConfig();
    final id = _newId();
    await ProfileStore.saveToken(id, token);
    final name = cfg.account.displayName.isNotEmpty
        ? cfg.account.displayName
        : Uri.parse(api.baseUrl).host;
    final profile = Profile(
      id: id,
      type: ProfileType.selfhosted,
      name: name,
      locations: cfg.locations,
      serverUrl: api.baseUrl,
      account: cfg.account,
      routing: cfg.routing,
      dns: cfg.dns,
      refreshedAt: DateTime.now(),
    );
    await _append(profile);
  }

  /// Add a subscription by URL (fetched now and on the poll timer).
  Future<void> addSubscriptionUrl(String name, String url) async {
    final res = await fetchSubscription(url);
    var parsed = parseSubscriptionBody(res.body);
    if (parsed.providers.isNotEmpty) parsed = await withProxyProviders(parsed);
    final page = res.info.webPageUrl.isNotEmpty ? res.info.webPageUrl : url;
    if (parsed.locations.isEmpty) {
      throw SubscriptionFormatException(_whyNothingUsable(parsed), openUrl: page);
    }
    // Placeholders are servers only when the panel told us why it sent them: a
    // full device limit is a state the app shows and keeps (the entries carry
    // the panel's message). Without that signal they are just text, and adding
    // locations that can never connect would be the app's own invention.
    if (parsed.allPlaceholders && !res.deviceLimitReached) {
      throw SubscriptionFormatException(
        providerMessageInstead(parsed.placeholderLines),
        openUrl: page,
      );
    }
    // The panel's own name for the subscription beats a hostname, and the user's
    // beats both — they typed it on purpose.
    final title = res.info.title.trim();
    await _append(Profile(
      id: _newId(),
      type: ProfileType.subscription,
      name: name.trim().isNotEmpty
          ? name.trim()
          : (title.isNotEmpty ? title : Uri.parse(url).host),
      locations: parsed.locations,
      subscriptionUrl: url,
      dns: parsed.dns,
      deviceLimitActive: res.deviceLimitActive,
      deviceLimitReached: res.deviceLimitReached,
      unsupportedServers: parsed.unsupported,
      groups: parsed.groups,
      rendering: res.rendering,
      renderingProbed: res.renderingProbed,
      // The panel's routing was already fetched with the body; without this it
      // would only appear after the first poll, which reads as the app losing it.
      providerRouting: res.routing?.routing,
      providerRoutingSkipped: res.routing?.skipped ?? 0,
      providerRoutingProbed: res.routingProbed,
      providerInfo: res.info.isEmpty ? null : res.info,
      refreshedAt: DateTime.now(),
    ));
  }

  /// Which of the two "nothing usable" problems this was. They send the user to
  /// different places — one to their provider for a different template, the
  /// other to a client that speaks the protocols theirs uses.
  AppError _whyNothingUsable(ParsedSubscription parsed) {
    if (parsed.hasUnsupported) {
      return noRunnableServers(parsed.total, parsed.unsupportedList);
    }
    // Read it and found nothing, versus could not read it at all: the first is
    // the provider's answer, the second is the format.
    return parsed.format == SubscriptionFormat.unknown
        ? kUnreadableSubscription
        : emptySubscription(parsed.format.label);
  }

  /// Add from pasted text or a file's contents: a single share link becomes a
  /// `link` profile (no location picker); multiple servers become a static
  /// `subscription` snapshot (no refresh URL).
  Future<void> addFromText(String text, {String? name}) async {
    final parsed = parseSubscriptionBody(text);
    final locations = parsed.locations;
    if (locations.isEmpty) {
      // Pasted text that is not a link at all keeps the generic message: at
      // that point "we could not read this format" would be pedantic about
      // something the user can see is a typo.
      if (parsed.format == SubscriptionFormat.unknown && !text.contains('://')) {
        throw const FormatException(
            'No valid vless://vmess://trojan://ss:// link or subscription found.');
      }
      throw SubscriptionFormatException(_whyNothingUsable(parsed));
    }
    final single = locations.length == 1;
    await _append(Profile(
      id: _newId(),
      type: single ? ProfileType.link : ProfileType.subscription,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : (single ? locations.first.label : 'Imported (${locations.length})'),
      locations: locations,
      dns: parsed.dns,
      unsupportedServers: parsed.unsupported,
      refreshedAt: DateTime.now(),
    ));
  }

  Future<void> _append(Profile p) async {
    await _ready;
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
    await _ready;
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
    await _ready;
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
    if (core.status != VpnStatus.connected) {
      await syncTunnelConfig();
      return;
    }
    final p = state.active;
    final selection = state.selectionId;
    if (p == null || selection == null) return;
    state = state.copyWith(switching: true);
    try {
      await core.reload(await _normConfig(p), selection);
      _reapplyPending = false; // the core just got the current config
      state = state.copyWith(switching: false);
    } catch (e) {
      Log.e('hot switch failed', '$e');
      state = state.copyWith(
        switching: false,
        error: const AppError('Couldn’t switch',
            detail: 'The tunnel kept the previous configuration. Try again, or reconnect.'),
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
    await _ready;
    final p = _byId(id);
    if (p == null) throw StateError('unknown profile $id');
    final updated = await configSourceFor(p).refresh();
    if (identical(updated, p)) return p;
    // The fetch ran against a snapshot taken when it started. Graft its
    // remote-owned fields onto the profile as it is NOW — the user may have
    // edited the local half (rule set, routing switch) while the request was
    // in flight, and persisting the snapshot would silently revert that.
    final merged = (_byId(id) ?? p).withBundle(
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
    );
    _replaceProfile(merged);
    await ProfileStore.save(state.profiles);
    // Pruned against every profile, not just this one: the list files are one
    // shared directory, and pruning against a single policy would delete the
    // files another configuration is using.
    await RuleListStore.prune(_liveRuleLists());
    if (id == state.activeId) await syncTunnelConfig();
    return merged;
  }

  /// Apply a global rule set to a profile. Picking a set also turns routing on:
  /// choosing one and seeing nothing happen would read as a bug.
  Future<void> setRuleSet(String profileId, String ruleSetId) =>
      _updateRouting(profileId, (p) => p.copyWith(ruleSetId: ruleSetId, routingEnabled: true));

  /// Turn this configuration's rule set on or off. Off leaves the chosen set
  /// remembered — it comes back when routing is switched on again.
  Future<void> setRoutingEnabled(String profileId, bool enabled) =>
      _updateRouting(profileId, (p) => p.copyWith(routingEnabled: enabled));

  /// Accept or refuse the routing a subscription's panel sent. Reaches the
  /// tunnel exactly like the local switch — the rules differ only in authorship.
  Future<void> setProviderRoutingEnabled(String profileId, bool enabled) =>
      _updateRouting(profileId, (p) => p.copyWith(providerRoutingEnabled: enabled));

  /// Accept or refuse holding the provider's rule-list files on this device.
  ///
  /// Turning it on downloads them before the tunnel is told anything: the
  /// engine must never be handed a rule whose file it would have to fetch
  /// itself, and the switch would otherwise report success while the rules it
  /// enables still match nothing.
  Future<void> setProviderRuleListsEnabled(String profileId, bool enabled) async {
    await _ready;
    final p = _byId(profileId);
    if (p == null) return;
    if (enabled) await syncRuleLists(profileId);
    await _updateRouting(
        profileId, (p) => p.copyWith(providerRuleListsEnabled: enabled));
    if (!enabled) await RuleListStore.prune(_liveRuleLists());
  }

  /// Download whatever of a provider's lists we do not have. Also the retry
  /// path: a list that failed is worth one more attempt on demand.
  Future<List<RuleListStatus>> syncRuleLists(String profileId) async {
    await _ready;
    final lists = _byId(profileId)?.providerRouting?.lists ?? const <RuleList>[];
    if (lists.isEmpty) return const [];
    final status = await RuleListStore.sync(lists);
    // A list that just arrived changes what the engine can run.
    if (profileId == state.activeId) await _applySelection();
    return status;
  }

  /// Every list any live configuration still refers to.
  Iterable<RuleList> _liveRuleLists() => state.profiles
      .where((p) => p.providerRuleListsEnabled)
      .expand((p) => p.providerRouting?.lists ?? const <RuleList>[]);

  /// Routing changes reach the tunnel the same way a server switch does: hot on
  /// a live session, persisted otherwise.
  Future<void> _updateRouting(String profileId, Profile Function(Profile) change) async {
    await _ready;
    final p = _byId(profileId);
    if (p == null) return;
    _replaceProfile(change(p));
    await ProfileStore.save(state.profiles);
    if (profileId == state.activeId) await _applySelection();
  }

  void _replaceProfile(Profile updated) {
    state = state.copyWith(
      profiles: [for (final p in state.profiles) p.id == updated.id ? updated : p],
    );
  }

  // --- connect ---

  /// One connect at a time: the pre-connect refresh can take seconds, during
  /// which the core still reports "disconnected" and the button stays live —
  /// a second tap must join the first attempt, not start a parallel one.
  Future<void>? _connecting;

  Future<void> connect() => _connecting ??= _connect().whenComplete(() => _connecting = null);

  Future<void> _connect() async {
    await _ready;
    final core = ref.read(vpnCoreProvider);
    state = state.copyWith(error: null);
    try {
      var p = state.active;
      if (p == null) {
        state = state.copyWith(
            error: const AppError('No configuration',
                detail: 'Add a link, a subscription, or sign in to your server.'));
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
            error: const AppError('This configuration has no servers',
                detail: 'Refresh it, or add another configuration.'));
        return;
      }
      await core.load(await _normConfig(p));
      await core.connect(selection);
      _lastReapply = DateTime.now();
      _reapplyPending = false;
      // Re-arm (or arm) system auto-connect now that a working config is
      // persisted on the native side.
      await ref.read(onDemandProvider.notifier).onConnected();
    } catch (e) {
      Log.e('connect failed', '$e');
      // The server/host is what the user can act on, so name it in the message.
      final host = state.selectedLocation?.proxy['server'] as String?;
      state = state.copyWith(error: describeError(e, subject: host));
    }
  }

  /// Drops the banner the user just dismissed.
  void clearError() => state = state.copyWith(error: null);

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
      if (reason.isEmpty) return;
      Log.e('tunnel stopped on its own', reason);
      state = state.copyWith(
        error: AppError('The tunnel stopped', detail: reason),
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
    final p = state.active;
    final selection = state.selectionId;
    if (p == null || selection == null) return;
    try {
      await ref.read(vpnCoreProvider).syncConfig(await _normConfig(p), selection);
    } catch (e) {
      Log.e('tunnel config sync failed', '$e');
    }
  }

  /// The config the core would run for [p] right now (routing resolved, LAN
  /// rules and geo availability applied). Exposed so on-demand can hand it to
  /// the system when arming.
  Future<NormConfig> effectiveConfig(Profile p) => _normConfig(p);

  /// Builds a NormConfig for the core from a profile: its locations + the
  /// effective routing. Precedence: server-managed policy (self-hosted), else
  /// the profile's global rule set. Device-level extras are applied on top:
  /// LAN-direct rules are prepended, and geo rules are dropped (with a log)
  /// while the databases aren't downloaded — a rule that can't match must not
  /// stall the engine into fetching 20+ MB mid-connect.
  Future<NormConfig> _normConfig(Profile p) async {
    // Whose rules apply is the policy's decision, not this method's: one of
    // three classes answers it (ADR-005), and what is left here is the
    // device-level trimming that applies to any of them.
    final policy = routingPolicyFor(p, loadRuleSet: RuleSetStore.byId);
    Routing routing = await policy.resolve();

    if (routing.rules.any((r) => r.needsGeoData) &&
        !(await GeoStore.status()).downloaded) {
      Log.e('routing', 'geo rules skipped: databases not downloaded');
      routing = Routing(
        mode: routing.mode,
        rules: routing.rules.where((r) => !r.needsGeoData).toList(),
        lists: routing.lists,
      );
    }

    // A set authored on a desktop can travel to a phone (same account, same
    // sets). Its process rules cannot match there, and leaving them in would
    // turn find-process-mode on for nothing.
    if (!supportsProcessRules && routing.rules.any((r) => r.type == 'process-name')) {
      Log.e('routing', 'process rules skipped: this platform cannot resolve processes');
      routing = Routing(
        mode: routing.mode,
        rules: routing.rules.where((r) => r.type != 'process-name').toList(),
        lists: routing.lists,
      );
    }

    final prefs = await RoutingPrefsStore.load();
    if (prefs.lanDirect) {
      routing = Routing(
          mode: routing.mode,
          rules: [...kLanDirectRules, ...routing.rules],
          lists: routing.lists);
    }

    return NormConfig(
      version: 1,
      account: p.account ?? Account(displayName: p.name, status: 'active'),
      locations: p.locations,
      groups: p.groups,
      routing: routing,
      dns: p.dns,
    );
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

    final routingDiff = jsonEncode(before.routing?.toJson()) != jsonEncode(after.routing?.toJson());
    final proxyDiff = jsonEncode(_proxyOf(before, locId)) != jsonEncode(_proxyOf(after, locId));
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
    await core.reload(await _normConfig(after), locId);
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
