import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/json_file_store.dart';
import 'providers.dart';
import 'ready_gate.dart';

/// "Connect when Windows starts", and nothing else.
///
/// Kept apart from [OnDemandPrefs] deliberately: that models Apple's rules —
/// conditions, an armed system side, a pause a manual disconnect causes — and
/// none of it exists here. The condition is the machine starting, so the whole
/// setting is one bool, and pretending otherwise would put vocabulary on the
/// screen that answers to nothing.
class AutoConnectController extends Notifier<bool> with ReadyGate {
  static final _store = JsonFileStore('auto_connect.json');

  @override
  bool build() {
    ready = _load();
    return false;
  }

  Future<void> _load() async {
    final on = await _store.load<bool>((j) => (j as Map)['enabled'] as bool? ?? false, false);
    if (!ref.mounted) return;
    state = on;
    // The service keeps its own copy — it has to answer at boot with no app
    // running — and a reinstall or a wiped data directory can lose it. Saying
    // it again on every start costs one pipe call and keeps the two honest.
    await ref.read(vpnCoreProvider).setAutoConnect(on);
  }

  Future<void> set(bool enabled) async {
    await ready;
    state = enabled;
    await _store.save({'enabled': enabled});
    await ref.read(vpnCoreProvider).setAutoConnect(enabled);
  }
}

/// False everywhere the facility does not exist, so a screen can read it
/// without asking which platform it is on first.
final autoConnectProvider = NotifierProvider<AutoConnectController, bool>(
  AutoConnectController.new,
);
