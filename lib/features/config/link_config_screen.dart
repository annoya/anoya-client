import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/ui.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: PageBody(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            ProfileHeaderCard(profile: profile, isActive: isActive),
            RoutingRow(profile: profile),
            ConfigActions(profile: profile, isActive: isActive),
          ],
        ),
      ),
    );
  }
}
