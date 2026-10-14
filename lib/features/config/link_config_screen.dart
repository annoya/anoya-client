import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import 'config_parts.dart';

class LinkConfigScreen extends ConsumerWidget {
  const LinkConfigScreen({
    super.key,
    required this.profile,
    required this.isActive,
  });

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DsPage(
    title: profile.name,
    children: [
      DsCard(
        children: [ProfileHeaderRow(profile: profile, isActive: isActive)],
      ),
      RoutingRow(profile: profile),
      ConfigActions(profile: profile, isActive: isActive),
    ],
  );
}
