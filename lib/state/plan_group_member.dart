import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/mihomo_tun_config.dart';
import '../core/network_extension_core.dart';
import '../core/profile.dart';
import '../l10n/l10n.dart';
import 'group_member.dart';
import 'profiles_controller.dart';
import 'session.dart';

final planGroupMemberProvider = StreamProvider.family<String, int>((
  ref,
  index,
) async* {
  final profile = ref.watch(profilesControllerProvider.select((s) => s.active));
  final connected = ref.watch(sessionProvider).connected;
  if (!connected || profile == null || !profile.usesSubscriptionRules) {
    yield '';
    return;
  }
  while (true) {
    final picked = await NetworkExtensionCore.groupMember(planGroupName(index));
    yield planMemberLabel(picked, profile);
    await Future<void>.delayed(kGroupMemberPoll);
  }
});

String planMemberLabel(String engineName, Profile p) {
  if (engineName == 'DIRECT') return L10n.current.proxyGroupsDirect;
  if (engineName == 'REJECT') return L10n.current.proxyGroupsBlocked;
  final index = int.tryParse(
    engineName.length > 1 ? engineName.substring(1) : '',
  );
  if (index == null || index < 0) return '';
  if (engineName.startsWith('p') && index < p.locations.length) {
    return stripLeadingFlag(p.locations[index].label);
  }
  final groups = p.plan?.groups ?? const [];
  if (engineName.startsWith('g') && index < groups.length) {
    return groups[index].name;
  }
  return '';
}
