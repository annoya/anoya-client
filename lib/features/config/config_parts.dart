import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart';
import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';

export 'device_section.dart';
export 'names_section.dart';
export 'provider_routing_card.dart';
export 'plan_group.dart';
export 'refresh_card.dart';
export 'routing_cards.dart';

Glyph profileIcon(ProfileType t) => switch (t) {
  ProfileType.selfhosted => Glyph.building2,
  ProfileType.subscription => Glyph.folder,
  ProfileType.amnezia => Glyph.shield,
  ProfileType.link => Glyph.link,
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

class ProfileHeaderRow extends StatelessWidget {
  const ProfileHeaderRow({
    super.key,
    required this.profile,
    required this.isActive,
  });

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context) => DsRow(
    glyph: profileIcon(profile.type),
    title: profile.name,
    subtitle: profileKind(profile),
    trailing: [
      if (isActive) DsAction(glyph: Glyph.check, color: context.ds.accent),
    ],
  );
}

class SourceRow extends StatelessWidget {
  const SourceRow({super.key, required this.value, this.openUrl});

  final String value;

  final String? openUrl;

  @override
  Widget build(BuildContext context) {
    final opens = (openUrl ?? '').isNotEmpty;
    void act() => opens ? _open(context, openUrl!) : _copy(context);
    return DsRow(
      glyph: Glyph.link,
      title: context.l10n.configSource,
      subtitle: value,
      subtitleMaxLines: 1,
      trailing: [
        DsAction(
          glyph: opens ? Glyph.externalLink : Glyph.copy,
          onPressed: act,
        ),
      ],
      onTap: act,
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

class FallbackSourceNote extends StatelessWidget {
  const FallbackSourceNote({super.key});

  @override
  Widget build(BuildContext context) => DsNotification(
    title: context.l10n.configSourceViaFallback,
    glyph: Glyph.info,
    small: true,
  );
}

class ConfigAlert extends StatelessWidget {
  const ConfigAlert({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) =>
      DsNotification.warning(title: title, body: body);
}

class UnsupportedServersAlert extends StatelessWidget {
  const UnsupportedServersAlert({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final skipped = profile.offeredServers - profile.locations.length;
    final kinds = (profile.unsupportedServers.keys.toList()..sort()).join(', ');
    final l10n = context.l10n;
    return ConfigAlert(
      title: l10n.configUnsupportedTitle(skipped, profile.offeredServers),
      body: l10n.configUnsupportedDetail(kinds, profile.locations.length),
    );
  }
}

class DeviceLimitAlert extends StatelessWidget {
  const DeviceLimitAlert({super.key});

  @override
  Widget build(BuildContext context) => ConfigAlert(
    title: kDeviceLimitReached.title,
    body: kDeviceLimitReached.detail!,
  );
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
    return DsStack(
      children: [
        if (!isActive)
          DsButton.secondary(
            label: l10n.configSetActive,
            glyph: Glyph.check,
            onPressed: () => ctrl.setActive(profile.id),
          ),
        DsButton.destructive(
          label: l10n.configRemoveConfiguration,
          glyph: Glyph.trash,
          onPressed: () => _remove(context, ref),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmAction(
      context,
      title: l10n.configRemoveTitle(profile.name),
      body: l10n.configRemoveDetail,
      confirmLabel: l10n.commonRemove,
    );
    if (!ok) return;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    if (ref.read(profilesControllerProvider).activeId == profile.id) {
      try {
        await ctrl.disconnect();
      } catch (_) {
        /* ignore */
      }
    }
    await ctrl.removeProfile(profile.id);
  }
}
