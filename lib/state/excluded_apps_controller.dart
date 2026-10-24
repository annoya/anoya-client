import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/android_apps.dart';
import 'ready_gate.dart';
import 'session.dart';

@immutable
class ExcludedApps {
  const ExcludedApps({this.packages = const [], this.inUse});

  final List<String> packages;

  final List<String>? inUse;

  bool get pending =>
      inUse != null && !setEquals(inUse!.toSet(), packages.toSet());
}

class ExcludedAppsController extends Notifier<ExcludedApps> with ReadyGate {
  @override
  ExcludedApps build() {
    ref.listen(
      sessionProvider.select((s) => s.connected),
      (_, _) => _refreshInUse(),
    );
    ready = _load();
    return const ExcludedApps();
  }

  Future<void> _load() async {
    final packages = await AndroidApps.excluded();
    final inUse = await AndroidApps.excludedInUse();
    if (!ref.mounted) return;
    state = ExcludedApps(packages: packages, inUse: inUse);
  }

  Future<void> _refreshInUse() async {
    await ready;
    final inUse = await AndroidApps.excludedInUse();
    if (!ref.mounted) return;
    state = ExcludedApps(packages: state.packages, inUse: inUse);
  }

  Future<void> setApps(Iterable<String> packages) async {
    await ready;
    final list = packages.toSet().toList()..sort();
    state = ExcludedApps(packages: list, inUse: state.inUse);
    await AndroidApps.setExcluded(list);
  }

  Future<void> remove(String package) =>
      setApps(state.packages.where((p) => p != package));

  Future<void> applyNow() => AndroidApps.restartTunnel();
}

final excludedAppsProvider =
    NotifierProvider<ExcludedAppsController, ExcludedApps>(
      ExcludedAppsController.new,
    );
