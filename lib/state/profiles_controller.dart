import 'dart:async';
import 'dart:convert';

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
import '../core/proxy_uri.dart';
import '../core/routing_prefs.dart';
import '../core/rule_set.dart';
import '../core/vpn_core.dart';
import 'favorites_controller.dart';
import 'on_demand_controller.dart';
import 'providers.dart';

/// How often a refreshable profile (self-hosted / subscription) is re-pulled.
const kConfigPollInterval = Duration(minutes: 5);

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
  int _idSeq = 0;

  @override
  ProfilesState build() {
    _timer = Timer.periodic(kConfigPollInterval, (_) => _poll());
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(_init);
    return const ProfilesState(loading: true);
  }

  Future<void> _init() async {
    unawaited(GeoStore.maybeAutoUpdate()); // weekly refresh, never a first download
    final profiles = await ProfileStore.load();
    state = ProfilesState(
      profiles: profiles,
      activeId: profiles.isEmpty ? null : profiles.first.id,
      selectedLocationId:
          profiles.isEmpty || profiles.first.locations.isEmpty ? null : profiles.first.locations.first.id,
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
      refreshedAt: DateTime.now(),
    );
    await _append(profile);
  }

  /// Add a subscription by URL (fetched now and on the poll timer).
  Future<void> addSubscriptionUrl(String name, String url) async {
    final body = await httpGet(url);
    final locations = parseSubscription(body);
    if (locations.isEmpty) throw const FormatException('No servers found in the subscription.');
    await _append(Profile(
      id: _newId(),
      type: ProfileType.subscription,
      name: name.trim().isNotEmpty ? name.trim() : Uri.parse(url).host,
      locations: locations,
      subscriptionUrl: url,
      refreshedAt: DateTime.now(),
    ));
  }

  /// Add from pasted text or a file's contents: a single share link becomes a
  /// `link` profile (no location picker); multiple servers become a static
  /// `subscription` snapshot (no refresh URL).
  Future<void> addFromText(String text, {String? name}) async {
    final locations = parseSubscription(text);
    if (locations.isEmpty) {
      throw const FormatException('No valid vless://vmess://trojan://ss:// link or subscription found.');
    }
    final single = locations.length == 1;
    await _append(Profile(
      id: _newId(),
      type: single ? ProfileType.link : ProfileType.subscription,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : (single ? locations.first.label : 'Imported (${locations.length})'),
      locations: locations,
      refreshedAt: DateTime.now(),
    ));
  }

  Future<void> _append(Profile p) async {
    final profiles = [...state.profiles, p];
    await ProfileStore.save(profiles);
    state = ProfilesState(
      profiles: profiles,
      activeId: p.id,
      selectedLocationId: p.locations.isEmpty ? null : p.locations.first.id,
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

  Future<void> removeProfile(String id) async {
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
      selectedLocationId:
          newActive == null || newActive.locations.isEmpty ? null : newActive.locations.first.id,
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
    final p = _byId(id);
    state = state.copyWith(
      activeId: id,
      selectedLocationId: p == null || p.locations.isEmpty ? null : p.locations.first.id,
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
    final loc = state.selectedLocation;
    if (p == null || loc == null) return;
    state = state.copyWith(switching: true);
    try {
      await core.reload(await _normConfig(p), loc.id);
      state = state.copyWith(switching: false);
    } catch (e) {
      Log.e('hot switch failed', '$e');
      state = state.copyWith(
        switching: false,
        error: const AppError('Couldn’t switch',
            detail: 'The tunnel kept the previous server. Try again, or reconnect.'),
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
    final p = _byId(id);
    if (p == null) throw StateError('unknown profile $id');
    final updated = await configSourceFor(p).refresh();
    if (identical(updated, p)) return p;
    _replaceProfile(updated);
    await ProfileStore.save(state.profiles);
    if (id == state.activeId) await syncTunnelConfig();
    return updated;
  }

  /// Apply a global rule set to a profile (takes effect on the next connect,
  /// same as editing the set itself).
  Future<void> setRuleSet(String profileId, String ruleSetId) async {
    final p = _byId(profileId);
    if (p == null) return;
    _replaceProfile(p.copyWith(ruleSetId: ruleSetId));
    await ProfileStore.save(state.profiles);
    if (profileId == state.activeId) await syncTunnelConfig();
  }

  void _replaceProfile(Profile updated) {
    state = state.copyWith(
      profiles: [for (final p in state.profiles) p.id == updated.id ? updated : p],
    );
  }

  // --- connect ---

  Future<void> connect() async {
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
      final loc = state.selectedLocation;
      if (loc == null) {
        state = state.copyWith(
            error: const AppError('This configuration has no servers',
                detail: 'Refresh it, or add another configuration.'));
        return;
      }
      await core.load(await _normConfig(p));
      await core.connect(loc.id);
      _lastReapply = DateTime.now();
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
    // The native stop disarms the system side; record the pause so the UI
    // explains why auto-connect is not active and the next connect re-arms.
    await ref.read(onDemandProvider.notifier).pause();
    await ref.read(vpnCoreProvider).disconnect();
  }

  /// Mirror the current selection into the system's saved tunnel config, so an
  /// on-demand start always brings up what the app is showing — not whatever
  /// was selected at the last manual connect. Best-effort and silent: it does
  /// nothing until a VPN profile exists (creating one would pop the system
  /// approval dialog at a surprising moment).
  Future<void> syncTunnelConfig() async {
    final p = state.active;
    final loc = state.selectedLocation;
    if (p == null || loc == null) return;
    try {
      await ref.read(vpnCoreProvider).syncConfig(await _normConfig(p), loc.id);
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
    Routing? routing = p.routing;
    if (routing == null) {
      final set = await RuleSetStore.byId(p.ruleSetId);
      routing = set.toRouting();
    }

    if (routing.rules.any((r) => r.needsGeoData) &&
        !(await GeoStore.status()).downloaded) {
      Log.e('routing', 'geo rules skipped: databases not downloaded');
      routing = Routing(
        mode: routing.mode,
        rules: routing.rules.where((r) => !r.needsGeoData).toList(),
      );
    }

    final prefs = await RoutingPrefsStore.load();
    if (prefs.lanDirect) {
      routing = Routing(mode: routing.mode, rules: [...kLanDirectRules, ...routing.rules]);
    }

    return NormConfig(
      version: 1,
      account: p.account ?? Account(displayName: p.name, status: 'active'),
      locations: p.locations,
      routing: routing,
    );
  }

  Future<void> _poll() async {
    final p = state.active;
    if (p == null || !p.isRefreshable) return;
    final before = p;
    Profile after;
    try {
      after = await refreshActive();
    } catch (e) {
      Log.e('profile poll failed', '$e');
      return;
    }
    await _maybeReapply(before, after);
  }

  /// Reconnect the running tunnel when a refresh changed the active server's
  /// proxy or the managed routing; disconnect if the account went inactive or
  /// the connected server disappeared. Rate-limited.
  Future<void> _maybeReapply(Profile before, Profile after) async {
    final core = ref.read(vpnCoreProvider);
    if (core.status != VpnStatus.connected) return;

    if (after.account != null && !after.account!.canConnect) {
      Log.i('poll: account ${after.account!.status} — disconnecting');
      await core.disconnect();
      return;
    }
    final locId = state.selectedLocation?.id;
    if (locId == null) return;
    if (after.locations.every((l) => l.id != locId)) {
      Log.i('poll: connected server disappeared — disconnecting');
      await core.disconnect();
      return;
    }

    final routingDiff = jsonEncode(before.routing?.toJson()) != jsonEncode(after.routing?.toJson());
    final proxyDiff = jsonEncode(_proxyOf(before, locId)) != jsonEncode(_proxyOf(after, locId));
    if (!routingDiff && !proxyDiff) return;
    if (DateTime.now().difference(_lastReapply) < kReapplyMinGap) {
      Log.i('poll: active config changed, reapply skipped (rate limit)');
      return;
    }
    Log.i('poll: active config changed — reconnecting to apply');
    _lastReapply = DateTime.now();
    await core.load(await _normConfig(after));
    await core.connect(locId);
  }

  Map<String, dynamic>? _proxyOf(Profile p, String locId) {
    for (final l in p.locations) {
      if (l.id == locId) return l.proxy;
    }
    return null;
  }
}

final profilesControllerProvider =
    NotifierProvider<ProfilesController, ProfilesState>(ProfilesController.new);
