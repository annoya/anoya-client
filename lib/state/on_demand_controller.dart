import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/on_demand.dart';
import '../l10n/l10n.dart';
import 'profiles_controller.dart';
import 'providers.dart';
import 'ready_gate.dart';

class OnDemandController extends Notifier<OnDemandPrefs> with ReadyGate {
  int _idSeq = 0;

  @override
  OnDemandPrefs build() {
    ready = OnDemandStore.load().then((v) {
      state = v;
    });
    return const OnDemandPrefs();
  }

  String _newId() =>
      'od${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_idSeq++}';

  Future<void> setEnabled(bool enabled) async {
    var rules = state.rules;
    if (enabled && rules.isEmpty) {
      rules = [
        OnDemandRule(id: _newId(), name: L10n.current.onDemandDefaultRuleName),
      ];
    }
    await _apply(state.copyWith(enabled: enabled, paused: false, rules: rules));
  }

  Future<void> setDisconnectOnSleep(bool value) =>
      _apply(state.copyWith(disconnectOnSleep: value));

  Future<void> pause() async {
    if (!state.armed) return;
    state = state.copyWith(paused: true, systemArmed: false);
    await OnDemandStore.save(state);
  }

  Future<void> onConnected() => _apply(state.copyWith(paused: false));

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
    await _apply(
      state.copyWith(rules: rules, enabled: state.enabled && rules.isNotEmpty),
    );
  }

  Future<void> reorderRules(int oldIndex, int newIndex) async {
    final rules = [...state.rules];
    rules.insert(newIndex, rules.removeAt(oldIndex));
    await _apply(state.copyWith(rules: rules));
  }

  Future<void> _apply(OnDemandPrefs prefs) async {
    await ready;
    state = prefs;
    await OnDemandStore.save(prefs);
    bool armed = false;
    try {
      final profiles = ref.read(profilesControllerProvider);
      final active = profiles.active;
      final loc = profiles.selectedLocation;
      armed = await ref
          .read(vpnCoreProvider)
          .applyOnDemand(
            prefs,
            config: active == null
                ? null
                : await ref
                      .read(profilesControllerProvider.notifier)
                      .effectiveConfig(active),
            locationId: loc?.id,
          );
    } catch (e) {
      Log.e('on-demand apply failed', '$e');
    }
    state = state.copyWith(systemArmed: armed);
  }
}

final onDemandProvider = NotifierProvider<OnDemandController, OnDemandPrefs>(
  OnDemandController.new,
);
