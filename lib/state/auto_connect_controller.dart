import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/json_file_store.dart';
import 'providers.dart';
import 'ready_gate.dart';

class AutoConnectController extends Notifier<bool> with ReadyGate {
  static final _store = JsonFileStore('auto_connect.json');

  @override
  bool build() {
    ready = _load();
    return false;
  }

  Future<void> _load() async {
    final on = await _store.load<bool>(
      (j) => (j as Map)['enabled'] as bool? ?? false,
      false,
    );
    if (!ref.mounted) return;
    state = on;
    // Re-sent on every start: the service's copy can be lost on reinstall.
    await ref.read(vpnCoreProvider).setAutoConnect(on);
  }

  Future<void> set(bool enabled) async {
    await ready;
    state = enabled;
    await _store.save({'enabled': enabled});
    await ref.read(vpnCoreProvider).setAutoConnect(enabled);
  }
}

final autoConnectProvider = NotifierProvider<AutoConnectController, bool>(
  AutoConnectController.new,
);
