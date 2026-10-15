import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dns_plan.dart';
import '../core/ds.dart';
import '../core/mihomo_tun_config.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';

class DnsScreen extends ConsumerWidget {
  const DnsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = dnsPlanForProfile(ref, profile);
    final origin = dnsOriginLabel(profile, plan);
    final l10n = context.l10n;
    return DsPage(
      title: l10n.dnsTitle,
      children: [
        DsGroup(
          caption: l10n.dnsSectionInEffect,
          note: plan.resolvers.length > 1
              ? l10n.dnsParallelNote
              : plan.usingFallback
              ? l10n.dnsFallbackNote
              : l10n.dnsProviderNote,
          children: [
            for (final r in plan.resolvers)
              _ResolverRow(resolver: r, origin: origin),
          ],
        ),
        if (plan.dropped.isNotEmpty)
          DsGroup(
            caption: l10n.dnsSectionDropped,
            child: DsStack(
              gap: kNoteGap,
              children: [
                for (final d in plan.dropped)
                  DsNotification.warning(title: d.address, body: d.explanation),
              ],
            ),
          ),
        DsNote(l10n.dnsProxyResolvedDirectlyNote),
      ],
    );
  }
}

class _ResolverRow extends StatelessWidget {
  const _ResolverRow({required this.resolver, required this.origin});

  final DnsResolver resolver;
  final String origin;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return DsRow(
      glyph: Glyph.server,
      title: resolver.address,
      subtitle: context.l10n.dnsResolverSubtitle(resolver.protocol, origin),
      trailing: [
        Text(
          resolver.routing,
          style: DsType.small.copyWith(
            color: resolver.viaTunnel ? ds.success : ds.text3,
          ),
        ),
        if (resolver.pinIgnored)
          Tooltip(
            message: context.l10n.dnsPinIgnoredTooltip,
            child: const DsAction(glyph: Glyph.info),
          ),
      ],
    );
  }
}

DnsPlan dnsPlanForProfile(WidgetRef ref, Profile profile) {
  final state = ref.watch(profilesControllerProvider);
  final fallback = ref.watch(routingPrefsProvider.select((p) => p.defaultDns));
  final active = state.active?.id == profile.id;
  final group = active ? state.selectedGroup : null;
  final members = active ? state.selectedGroupMembers : const <Location>[];
  final location =
      (active ? state.selectedLocation : null) ??
      (profile.locations.isEmpty ? null : profile.locations.first);
  if (location == null) {
    return dnsPlanFor(
      dns: profile.dns,
      outbounds: const {},
      carriesUdp: false,
      fallback: fallback,
    );
  }
  final shape = engineShape(location, group: group, members: members);
  return dnsPlanFor(
    dns: profile.dns,
    outbounds: shape.outbounds,
    carriesUdp: shape.carriesUdp,
    fallback: fallback,
  );
}

String dnsOriginLabel(Profile profile, DnsPlan plan) {
  final l10n = L10n.current;
  if (plan.usingFallback) return l10n.dnsOriginAppDefault;
  return switch (profile.type) {
    ProfileType.subscription => l10n.dnsOriginSubscription,
    ProfileType.selfhosted => l10n.dnsOriginOrganisation,
    ProfileType.amnezia => l10n.dnsOriginSubscription,
    ProfileType.link => l10n.dnsOriginConfiguration,
  };
}
