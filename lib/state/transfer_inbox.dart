import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_check.dart';
import '../core/device_transfer.dart';
import '../core/routing_prefs.dart';
import '../core/rule_set.dart';
import 'connection_check_controller.dart';
import 'profiles_controller.dart';
import 'providers.dart';
import 'routing_status.dart';

class TransferInbox {
  TransferInbox(this._ref);

  final Ref _ref;

  bool isKnown(String profileId) => _ref
      .read(profilesControllerProvider)
      .profiles
      .any((p) => p.id == profileId);

  Future<void> add(TransferPackage package) async {
    var routingTouched = false;
    if (package.ruleSets.isNotEmpty) {
      final incoming = {
        for (final j in package.ruleSets)
          j['id'] as String: RuleSet.fromJson(j),
      };
      final current = await RuleSetStore.load();
      final known = {for (final s in current) s.id};
      await RuleSetStore.save([
        for (final s in current) incoming[s.id] ?? s,
        for (final e in incoming.entries)
          if (!known.contains(e.key)) e.value,
      ]);
      _ref.read(ruleSetRevisionProvider.notifier).bump();
      routingTouched = true;
    }
    if (package.routing case final routing?) {
      await _ref
          .read(routingPrefsProvider.notifier)
          .update(
            (p) => RoutingPrefs.fromJson(
              routing,
            ).copyWith(geoUpdatedAt: p.geoUpdatedAt),
          );
      routingTouched = true;
    }
    if (package.check case final check?) {
      await _ref
          .read(connectionCheckProvider.notifier)
          .replacePrefs(ConnectionCheckPrefs.fromJson(check));
    }
    final controller = _ref.read(profilesControllerProvider.notifier);
    for (final recipe in package.profiles) {
      await controller.applyFromCloud(recipe);
    }
    if (_ref.read(profilesControllerProvider).active == null &&
        package.profiles.isNotEmpty) {
      await controller.setActive(package.profiles.first['id'] as String);
    } else if (routingTouched) {
      await controller.syncTunnelConfig();
    }
  }
}

final transferInboxProvider = Provider(TransferInbox.new);
