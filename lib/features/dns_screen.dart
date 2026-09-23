import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dns_plan.dart';
import '../core/mihomo_tun_config.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';

class DnsScreen extends ConsumerWidget {
  const DnsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = _planFor(ref);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dnsTitle)),
      body: PageBody(
        child: ListView(
          children: [
            SectionHeader(l10n.dnsSectionInEffect),
            Card(
              margin: kCardMargin,
              child: Column(
                children: [
                  for (final (i, r) in plan.resolvers.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    _ResolverRow(resolver: r, origin: _origin(plan)),
                  ],
                ],
              ),
            ),
            SectionNote(
              plan.resolvers.length > 1
                  ? l10n.dnsParallelNote
                  : _originNote(l10n, plan),
            ),
            if (plan.dropped.isNotEmpty) ...[
              SectionHeader(l10n.dnsSectionDropped),
              for (final d in plan.dropped) _Dropped(drop: d),
            ],
            SectionNote(l10n.dnsProxyResolvedDirectlyNote),
          ],
        ),
      ),
    );
  }

  DnsPlan _planFor(WidgetRef ref) => dnsPlanForProfile(ref, profile);

  String _origin(DnsPlan plan) => dnsOriginLabel(profile, plan);

  String _originNote(AppLocalizations l10n, DnsPlan plan) =>
      plan.usingFallback ? l10n.dnsFallbackNote : l10n.dnsProviderNote;
}

class _ResolverRow extends StatelessWidget {
  const _ResolverRow({required this.resolver, required this.origin});

  final DnsResolver resolver;
  final String origin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(resolver.address, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(
            resolver.routing,
            style: text.bodySmall?.copyWith(
              color: resolver.viaTunnel ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Text(
        context.l10n.dnsResolverSubtitle(resolver.protocol, origin),
      ),
      isThreeLine: resolver.pinIgnored,
      trailing: resolver.pinIgnored
          ? Tooltip(
              message: context.l10n.dnsPinIgnoredTooltip,
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}

class _Dropped extends StatelessWidget {
  const _Dropped({required this.drop});

  final DnsDrop drop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: kCardMargin,
      color: cs.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: cs.onErrorContainer),
        title: Text(
          drop.address,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onErrorContainer),
        ),
        subtitle: Text(
          drop.explanation,
          style: TextStyle(color: cs.onErrorContainer),
        ),
      ),
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
