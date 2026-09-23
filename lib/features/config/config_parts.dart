import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';

export 'device_section.dart';
export 'names_section.dart';
export 'provider_routing_card.dart';
export 'provider_section.dart';
export 'refresh_card.dart';
export 'routing_cards.dart';

IconData profileIcon(ProfileType t) => switch (t) {
  ProfileType.selfhosted => Icons.business_outlined,
  ProfileType.subscription => Icons.folder_outlined,
  ProfileType.amnezia => Icons.shield_outlined,
  ProfileType.link => Icons.link,
};

String profileKind(Profile p) {
  final l10n = L10n.current;
  return switch (p.type) {
    ProfileType.selfhosted => l10n.configKindSelfhosted(_servers(p)),
    ProfileType.subscription => l10n.configKindSubscription(
      _servers(p),
      _groups(p),
    ),
    ProfileType.amnezia =>
      p.amnezia?.offersLocations == false
          ? l10n.configKindSubscriptionPlain
          : l10n.configKindSubscription(_servers(p), ''),
    ProfileType.link => l10n.configKindSingleServer,
  };
}

String _servers(Profile p) {
  final offered = p.offeredServers;
  final ours = p.locations.length;
  return ours == offered
      ? L10n.current.commonServersCount(ours)
      : L10n.current.configServersOfOffered(ours, offered);
}

String _groups(Profile p) {
  final n = p.groups.length;
  if (n == 0) return '';
  return L10n.current.configGroupsSuffix(n);
}

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.isActive,
  });

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context) => Card(
    margin: kCardMargin,
    child: ListTile(
      leading: Icon(profileIcon(profile.type)),
      title: Text(profile.name),
      subtitle: Text(profileKind(profile)),
      trailing: isActive
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            )
          : null,
    ),
  );
}

class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.value,
    this.openUrl,
    this.viaFallback = false,
  });

  final String value;

  final String? openUrl;

  final bool viaFallback;

  @override
  Widget build(BuildContext context) {
    final opens = (openUrl ?? '').isNotEmpty;
    final l10n = context.l10n;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.link),
        title: Text(l10n.configSource),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (viaFallback)
              Text(
                l10n.configSourceViaFallback,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        isThreeLine: viaFallback,
        trailing: Icon(
          opens ? Icons.open_in_new : Icons.copy_all_outlined,
          size: 18,
        ),
        onTap: () => opens ? _open(context, openUrl!) : _copy(context),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        showToast(context, context.l10n.uiCouldNotOpenPage);
      }
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showToast(context, context.l10n.configLinkCopied);
  }
}

class UnsupportedServersCard extends StatelessWidget {
  const UnsupportedServersCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skipped = profile.offeredServers - profile.locations.length;
    final kinds = (profile.unsupportedServers.keys.toList()..sort()).join(', ');
    final l10n = context.l10n;
    return Card(
      margin: kCardMargin,
      color: cs.tertiaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
        title: Text(
          l10n.configUnsupportedTitle(skipped, profile.offeredServers),
        ),
        subtitle: Text(
          l10n.configUnsupportedDetail(kinds, profile.locations.length),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class DeviceLimitCard extends StatelessWidget {
  const DeviceLimitCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: kCardMargin,
      color: cs.errorContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: cs.error),
        title: Text(kDeviceLimitReached.title),
        subtitle: Text(kDeviceLimitReached.detail!),
        isThreeLine: true,
      ),
    );
  }
}

class ConfigActions extends ConsumerWidget {
  const ConfigActions({
    super.key,
    required this.profile,
    required this.isActive,
  });

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(profilesControllerProvider.notifier);
    final l10n = context.l10n;
    // Stretch, or the buttons hug their labels instead of spanning the width.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        if (!isActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kGutter),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.configSetActive),
              onPressed: () => ctrl.setActive(profile.id),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.configRemoveConfiguration),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _remove(context, ref),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    // Captured before the removal: afterwards this element is replaced by a
    // placeholder, and popping through it does nothing (blank page).
    final nav = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.configRemoveTitle(profile.name)),
        content: Text(l10n.configRemoveDetail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    if (ref.read(profilesControllerProvider).activeId == profile.id) {
      try {
        // Through the controller, not the raw core: it records the on-demand pause.
        await ctrl.disconnect();
      } catch (_) {
        /* ignore */
      }
    }
    await ctrl.removeProfile(profile.id);
    // Only while others remain: after the last one the app shell unwinds, and
    // popping here too would race it and pop the root route (black screen).
    if (container.read(profilesControllerProvider).hasProfiles && nav.mounted) {
      nav.pop();
    }
  }
}
