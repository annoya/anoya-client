import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/ui.dart';
import 'config_parts.dart';

/// Settings of a single share link.
///
/// The shortest of the three screens, and deliberately so: a link is a static
/// snapshot of one server (ADR-005). There is no origin to re-ask, so no
/// refresh; no account, so no status or quota; no server picker, because there
/// is one server. What remains is routing — which is the device's own — and
/// the two actions every configuration has.
class LinkConfigScreen extends ConsumerWidget {
  const LinkConfigScreen({super.key, required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: PageBody(
        child: ListView(children: [
          const SizedBox(height: 8),
          ProfileHeaderCard(profile: profile, isActive: isActive),
          const SectionHeader('ROUTING'),
          LocalRoutingCard(profile: profile),
          ConfigActions(profile: profile, isActive: isActive),
        ]),
      ),
    );
  }
}
