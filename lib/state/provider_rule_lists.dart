import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/rule_list_store.dart';
import 'profiles_controller.dart';

final providerRuleListsProvider =
    FutureProvider.family<List<RuleListStatus>, String>((ref, profileId) async {
      final profile = ref.watch(
        profilesControllerProvider.select(
          (s) => s.profiles.where((p) => p.id == profileId).firstOrNull,
        ),
      );
      final lists = profile?.providerRouting?.lists ?? const <RuleList>[];
      if (lists.isEmpty) return const [];
      try {
        return await RuleListStore.status(lists);
      } catch (e) {
        Log.e('rule list status unavailable', '$e');
        return [for (final l in lists) RuleListStatus(list: l, error: '$e')];
      }
    });
