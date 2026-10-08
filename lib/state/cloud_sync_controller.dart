import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/cloud_sync.dart';
import '../core/connection_check.dart';
import '../core/favorites.dart';
import '../core/json_file_store.dart';
import '../core/log.dart';
import '../core/on_demand.dart';
import '../core/routing_prefs.dart';
import '../core/rule_set.dart';
import 'connection_check_controller.dart';
import 'favorites_controller.dart';
import 'on_demand_controller.dart';
import 'profiles_controller.dart';
import 'providers.dart';
import 'ready_gate.dart';
import 'routing_status.dart';

class CloudSyncState {
  const CloudSyncState({
    this.supported = false,
    this.enabled = false,
    this.available = true,
    this.waitingForKey = false,
  });

  final bool supported;
  final bool enabled;
  final bool available;
  final bool waitingForKey;

  CloudSyncState copyWith({
    bool? enabled,
    bool? available,
    bool? waitingForKey,
  }) => CloudSyncState(
    supported: supported,
    enabled: enabled ?? this.enabled,
    available: available ?? this.available,
    waitingForKey: waitingForKey ?? this.waitingForKey,
  );
}

const kCloudSyncDebounce = Duration(seconds: 1);

const kCloudKeyRetry = Duration(seconds: 30);

const kCloudFirstDownloadWait = Duration(seconds: 15);

class CloudSyncController extends Notifier<CloudSyncState> with ReadyGate {
  CloudSyncController({bool? supported})
    : _supported =
          supported ??
          ((Platform.isIOS || Platform.isMacOS) &&
              !Platform.environment.containsKey('FLUTTER_TEST'));

  static const fileName = 'icloud_sync.json';
  static final _store = JsonFileStore(fileName);

  final bool _supported;

  String? _fingerprint;
  Map<String, String> _seen = {};
  bool _waitedForFirstDownload = false;

  StreamSubscription<String>? _saves;
  StreamSubscription<int>? _changes;
  Timer? _debounce;
  Timer? _retry;
  Future<void>? _running;
  bool _rerun = false;

  @override
  CloudSyncState build() {
    ref.onDispose(_stop);
    if (!_supported) return const CloudSyncState();
    ready = _load();
    return const CloudSyncState(supported: true);
  }

  Future<void> _load() async {
    final saved = await _store.load<Map>(
      (j) => j is Map ? j : const {},
      const {},
    );
    _fingerprint = saved['fingerprint'] as String?;
    _seen = {
      for (final e in ((saved['seen'] as Map?) ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    final enabled = saved['enabled'] == true;
    if (!ref.mounted) return;
    state = state.copyWith(enabled: enabled);
    if (enabled) _start();
  }

  Future<void> setEnabled(bool enabled) async {
    await ready;
    if (!state.supported || enabled == state.enabled) return;
    state = state.copyWith(enabled: enabled, waitingForKey: false);
    if (enabled) {
      _seen = {};
      await _persist();
      _start();
    } else {
      _stop();
      await _persist();
    }
  }

  Future<void> refreshAvailability() async {
    if (!state.supported) return;
    try {
      final available = await CloudStore.available();
      if (ref.mounted) state = state.copyWith(available: available);
    } catch (e) {
      Log.e('icloud: availability unknown', '$e');
    }
  }

  void _start() {
    _saves ??= JsonFileStore.saved
        .where((name) => name != fileName)
        .listen((_) => _schedule());
    _changes ??= CloudStore.changes().listen((reason) {
      if (reason == CloudStore.quotaViolation) {
        Log.e('icloud: key-value storage is over its quota');
      }
      _schedule(immediately: true);
    }, onError: (Object e) => Log.e('icloud: change feed failed', '$e'));
    _schedule(immediately: true);
  }

  void _stop() {
    _saves?.cancel();
    _saves = null;
    _changes?.cancel();
    _changes = null;
    _debounce?.cancel();
    _retry?.cancel();
  }

  void _schedule({bool immediately = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      immediately ? Duration.zero : kCloudSyncDebounce,
      () => unawaited(syncNow()),
    );
  }

  void _retryLater(Duration after) {
    _retry?.cancel();
    _retry = Timer(after, () => _schedule(immediately: true));
  }

  Future<void> syncNow() async {
    if (_running != null) {
      _rerun = true;
      return _running;
    }
    final run = _runUntilSettled();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
    }
  }

  Future<void> _runUntilSettled() async {
    do {
      _rerun = false;
      if (!ref.mounted || !state.enabled) return;
      try {
        await _syncOnce();
      } catch (e) {
        Log.e('icloud: sync failed', '$e');
      }
    } while (_rerun);
  }

  Future<void> _syncOnce() async {
    final available = await CloudStore.available();
    if (!ref.mounted) return;
    state = state.copyWith(available: available);
    if (!available) return;

    final snapshot = await CloudStore.snapshot();
    final marker = snapshot[SyncItem.keyMarker];
    final cloudEmpty = marker == null && !snapshot.keys.any(SyncItem.isItem);
    var key = await SyncKey.load();
    if (key == null && cloudEmpty && !_waitedForFirstDownload) {
      _waitedForFirstDownload = true;
      _retryLater(kCloudFirstDownloadWait);
      return;
    }
    if ((key == null && !cloudEmpty) ||
        (key != null && marker != null && marker != key.fingerprint)) {
      state = state.copyWith(waitingForKey: true);
      _retryLater(kCloudKeyRetry);
      return;
    }
    key ??= await SyncKey.create();
    if (marker == null) {
      await CloudStore.set(SyncItem.keyMarker, key.fingerprint);
    }
    if (_fingerprint != key.fingerprint) {
      _fingerprint = key.fingerprint;
      _seen = {};
    }
    state = state.copyWith(waitingForKey: false);

    final remote = <String, String>{};
    final unreadable = <String>{};
    for (final e in snapshot.entries) {
      if (!SyncItem.isItem(e.key)) continue;
      final plain = await key.open(e.key, e.value);
      if (plain == null) {
        unreadable.add(e.key);
      } else {
        remote[e.key] = plain;
      }
    }
    final local = {
      for (final e in (await localSyncItems()).entries)
        e.key: canonicalJson(e.value),
    };
    final plan = reconcile(
      local: local,
      remote: remote,
      unreadable: unreadable,
      seen: _seen,
    );
    if (unreadable.isNotEmpty) {
      Log.e('icloud: ${unreadable.length} items sealed with another key');
    }

    await _applyRemote(plan);
    for (final e in plan.push.entries) {
      await CloudStore.set(e.key, await key.seal(e.key, e.value));
    }
    for (final k in plan.removeRemote) {
      await CloudStore.remove(k);
    }
    _seen = plan.seen;
    await _persist();
    final changed =
        plan.apply.length +
        plan.deleteLocal.length +
        plan.push.length +
        plan.removeRemote.length;
    if (changed > 0) {
      Log.i(
        'icloud: received ${plan.apply.length + plan.deleteLocal.length}, '
        'sent ${plan.push.length + plan.removeRemote.length}',
      );
    }
  }

  Future<void> _applyRemote(SyncPlan plan) async {
    var routingTouched = false;
    final sets = <String, RuleSet?>{};
    final profiles = <String, Map<String, dynamic>?>{};

    for (final e in plan.apply.entries) {
      final json = Map<String, dynamic>.from(jsonDecode(e.value) as Map);
      switch (e.key) {
        case SyncItem.app:
          await ref
              .read(appPrefsProvider.notifier)
              .replace(AppPrefs.fromJson(json));
        case SyncItem.routing:
          await ref
              .read(routingPrefsProvider.notifier)
              .update(
                (p) => RoutingPrefs.fromJson(
                  json,
                ).copyWith(geoUpdatedAt: p.geoUpdatedAt),
              );
          routingTouched = true;
        case SyncItem.check:
          await ref
              .read(connectionCheckProvider.notifier)
              .replacePrefs(ConnectionCheckPrefs.fromJson(json));
        case SyncItem.onDemand:
          await ref
              .read(onDemandProvider.notifier)
              .replaceRules(OnDemandPrefs.fromJson(json).rules);
        case SyncItem.favorites:
          await ref
              .read(favoritesProvider.notifier)
              .replace(Favorites.fromJson(json));
        case final k when k.startsWith(SyncItem.ruleSetPrefix):
          sets[k.substring(SyncItem.ruleSetPrefix.length)] = RuleSet.fromJson(
            json,
          );
        case final k when k.startsWith(SyncItem.profilePrefix):
          profiles[k.substring(SyncItem.profilePrefix.length)] = json;
      }
    }
    for (final k in plan.deleteLocal) {
      if (k.startsWith(SyncItem.ruleSetPrefix)) {
        sets[k.substring(SyncItem.ruleSetPrefix.length)] = null;
      } else if (k.startsWith(SyncItem.profilePrefix)) {
        profiles[k.substring(SyncItem.profilePrefix.length)] = null;
      }
    }

    if (sets.isNotEmpty) {
      final current = await RuleSetStore.load();
      final known = {for (final s in current) s.id};
      await RuleSetStore.save([
        for (final s in current)
          if (!sets.containsKey(s.id))
            s
          else if (sets[s.id] case final RuleSet updated)
            updated,
        for (final e in sets.entries)
          if (!known.contains(e.key) && e.value != null) e.value!,
      ]);
      ref.read(ruleSetRevisionProvider.notifier).bump();
      routingTouched = true;
    }

    final controller = ref.read(profilesControllerProvider.notifier);
    for (final e in profiles.entries) {
      final recipe = e.value;
      if (recipe == null) {
        await controller.removeProfile(e.key);
      } else {
        await controller.applyFromCloud(recipe);
      }
    }
    if (routingTouched) await controller.syncTunnelConfig();
  }

  Future<void> _persist() => _store.save({
    'enabled': state.enabled,
    'fingerprint': ?_fingerprint,
    'seen': _seen,
  });
}

final cloudSyncProvider = NotifierProvider<CloudSyncController, CloudSyncState>(
  CloudSyncController.new,
);
