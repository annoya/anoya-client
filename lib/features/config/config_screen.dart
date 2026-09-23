import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../state/profiles_controller.dart';
import 'amnezia_config_screen.dart';
import 'link_config_screen.dart';
import 'selfhosted_config_screen.dart';
import 'subscription_config_screen.dart';

export 'config_parts.dart' show profileIcon, profileKind;

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(profilesControllerProvider);
    Profile? profile;
    for (final p in st.profiles) {
      if (p.id == profileId) profile = p;
    }
    if (profile == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final isActive = st.activeId == profile.id;
    return switch (profile.type) {
      ProfileType.selfhosted => SelfhostedConfigScreen(
        profile: profile,
        isActive: isActive,
      ),
      ProfileType.subscription => SubscriptionConfigScreen(
        profile: profile,
        isActive: isActive,
      ),
      ProfileType.amnezia => AmneziaConfigScreen(
        profile: profile,
        isActive: isActive,
      ),
      ProfileType.link => LinkConfigScreen(
        profile: profile,
        isActive: isActive,
      ),
    };
  }
}
