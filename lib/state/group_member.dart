import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mihomo_tun_config.dart';
import '../core/network_extension_core.dart';
import 'profiles_controller.dart';
import 'session.dart';

/// Which server a selected group is currently sending traffic through, as the
/// label the provider gave it.
///
/// The engine decides this and re-decides it on its own schedule, so the app
/// can only ask. It asks while a group is selected and the tunnel is up, and
/// says nothing otherwise: a name from a previous session would be a claim
/// about where traffic goes right now.
final groupMemberProvider = StreamProvider<String>((ref) async* {
  final profiles = ref.watch(profilesControllerProvider);
  final connected = ref.watch(sessionProvider).connected;
  final group = profiles.selectedGroup;
  if (group == null || !connected) {
    yield '';
    return;
  }
  // The engine names members positionally (`p0`, `p1`, …) — the names the
  // renderer generated — so the provider's own text never has to cross the
  // extension boundary.
  final members = profiles.selectedGroupMembers;
  while (true) {
    final picked = await NetworkExtensionCore.groupMember(kGroupName);
    yield _labelFor(picked, members);
    await Future<void>.delayed(kGroupMemberPoll);
  }
});

/// How often the app asks. Slower than the engine's own health check on
/// purpose: this only feeds a subtitle, and each ask is an IPC round trip to
/// the extension.
const kGroupMemberPoll = Duration(seconds: 10);

String _labelFor(String engineName, List<dynamic> members) {
  if (!engineName.startsWith('p')) return '';
  final index = int.tryParse(engineName.substring(1));
  if (index == null || index < 0 || index >= members.length) return '';
  return members[index].label as String;
}
