import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/on_demand.dart';
import 'profiles_controller.dart';
import 'providers.dart';
import 'ready_gate.dart';

/// Owns on-demand preferences and keeps the system side in sync: every state
/// change is persisted and pushed to the core (which saves NEOnDemandRules
/// into the system VPN preferences).
class OnDemandController extends Notifier<OnDemandPrefs> with ReadyGate {
  int _idSeq = 0;

  @override
  OnDemandPrefs build() {
    ready = OnDemandStore.load().then((v) {
      state = v;
    });
    return const OnDemandPrefs();
  }

  String _newId() => 'od${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_idSeq++}';

  /// Toggle the feature. Enabling clears a pause and seeds the default
  /// "Connect · Any network" rule when the list is empty.
  Future<void> setEnabled(bool enabled) async {
    var rules = state.rules;
    if (enabled && rules.isEmpty) {
      rules = [OnDemandRule(id: _newId(), name: 'Everywhere')];
    }
    await _apply(state.copyWith(enabled: enabled, paused: false, rules: rules));
  }

  Future<void> setDisconnectOnSleep(bool value) =>
      _apply(state.copyWith(disconnectOnSleep: value));

  /// Manual disconnect while armed: keep the user's intent, stop auto-connect
  /// until the next connect. The native stop already disarmed the system side.
  Future<void> pause() async {
    if (!state.armed) return;
    state = state.copyWith(paused: true, systemArmed: false);
    await OnDemandStore.save(state);
  }

  /// A successful connect re-arms a paused (or freshly enabled) on-demand. Runs
  /// even with on-demand off: the profile now exists, so this is also when the
  /// disconnect-on-sleep flag reaches the system.
  Future<void> onConnected() => _apply(state.copyWith(paused: false));

  /// Forget on-demand locally, without touching the system. Used when the VPN
  /// profile is being removed anyway: pushing a "disarm" first would recreate
  /// the profile (and pop the approval dialog) just to delete it a moment
  /// later.
  Future<void> forget() async {
    state = state.copyWith(enabled: false, paused: false, systemArmed: false);
    await OnDemandStore.save(state);
  }

  OnDemandRule newRule() => OnDemandRule(id: _newId());

  Future<void> upsertRule(OnDemandRule rule) async {
    final rules = [...state.rules];
    final i = rules.indexWhere((r) => r.id == rule.id);
    if (i >= 0) {
      rules[i] = rule;
    } else {
      rules.add(rule);
    }
    await _apply(state.copyWith(rules: rules));
  }

  Future<void> removeRule(String id) async {
    final rules = state.rules.where((r) => r.id != id).toList();
    // The last rule going away disables the feature (armed requires rules).
    await _apply(state.copyWith(rules: rules, enabled: state.enabled && rules.isNotEmpty));
  }

  Future<void> reorderRules(int oldIndex, int newIndex) async {
    final rules = [...state.rules];
    rules.insert(newIndex, rules.removeAt(oldIndex));
    await _apply(state.copyWith(rules: rules));
  }

  /// Persist + push to the system, then record what the system actually did.
  /// Persisting first keeps the app's view consistent even when the platform
  /// call fails (e.g. no VPN approval yet); the push error is logged and the
  /// state falls back to "not armed" so the UI never claims auto-connect that
  /// isn't running.
  Future<void> _apply(OnDemandPrefs prefs) async {
    await ready;
    state = prefs;
    await OnDemandStore.save(prefs);
    bool armed = false;
    try {
      // Hand the current selection along: arming needs something for the system
      // to bring up, and this is also what creates the VPN profile the first
      // time (the approval dialog belongs to an explicit arm, not to adding a
      // configuration).
      final profiles = ref.read(profilesControllerProvider);
      final active = profiles.active;
      final loc = profiles.selectedLocation;
      armed = await ref.read(vpnCoreProvider).applyOnDemand(
            prefs,
            config: active == null
                ? null
                : await ref.read(profilesControllerProvider.notifier).effectiveConfig(active),
            locationId: loc?.id,
          );
    } catch (e) {
      Log.e('on-demand apply failed', '$e');
    }
    state = state.copyWith(systemArmed: armed);
  }
}

final onDemandProvider =
    NotifierProvider<OnDemandController, OnDemandPrefs>(OnDemandController.new);
