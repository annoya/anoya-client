import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/rule_list_store.dart';
import 'profiles_controller.dart';

/// Disk state of the lists a profile's provider policy names. Read from the
/// store, not from the profile: the files are the truth here, and a profile
/// that says "enabled" tells us nothing about what actually arrived.
final providerRuleListsProvider =
    FutureProvider.family<List<RuleListStatus>, String>((ref, profileId) async {
  final profile = ref.watch(profilesControllerProvider
      .select((s) => s.profiles.where((p) => p.id == profileId).firstOrNull));
  final lists = profile?.providerRouting?.lists ?? const <RuleList>[];
  if (lists.isEmpty) return const [];
  try {
    return await RuleListStore.status(lists);
  } catch (e) {
    // A container we cannot read means we hold nothing, which is a fact worth
    // reporting rather than an error to hide behind: null is reserved for "not
    // known yet", and callers treat that optimistically.
    Log.e('rule list status unavailable', '$e');
    return [for (final l in lists) RuleListStatus(list: l, error: '$e')];
  }
});
