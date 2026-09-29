import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mihomo_tun_config.dart';
import '../core/network_extension_core.dart';
import 'profiles_controller.dart';
import 'session.dart';

final groupMemberProvider = StreamProvider<String>((ref) async* {
  final profiles = ref.watch(profilesControllerProvider);
  final connected = ref.watch(sessionProvider).connected;
  final group = profiles.selectedGroup;
  if (group == null || !connected) {
    yield '';
    return;
  }
  final members = profiles.selectedGroupMembers;
  while (true) {
    final picked = await NetworkExtensionCore.groupMember(kGroupName);
    yield labelForGroupMember(picked, members);
    await Future<void>.delayed(kGroupMemberPoll);
  }
});

const kGroupMemberPoll = Duration(seconds: 10);

String labelForGroupMember(String engineName, List<dynamic> members) {
  if (!engineName.startsWith('p')) return '';
  final index = int.tryParse(engineName.substring(1));
  if (index == null || index < 0 || index >= members.length) return '';
  return members[index].label as String;
}
