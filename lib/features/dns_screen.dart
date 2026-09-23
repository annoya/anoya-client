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

/// Who answers when an app asks for an address, and what we did not use.
///
/// Read-only on purpose. The resolvers belong to the configuration — a
/// subscription's panel or a self-hosted bundle chose them (ADR-008) — so this
/// screen's job is to say what is in force and where it came from, not to offer
/// a fourth source on top of the three that already exist.
///
/// The section that earns the screen is [_Dropped]. We refuse resolvers for
/// three good reasons and, until now, said so only in a log file nobody reads:
/// a configuration could lose its provider's DNS and look untouched. That is
/// the same shape of defect as a tunnel that stopped without saying why.
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

/// One resolver: where it is, how it is reached, and whose choice it was.
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
          // Routing is the one property that changes who can see the query, so it
          // gets the end of the top line. The word carries it; the colour only
          // agrees with the word.
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
      // Only said when it happened: the provider asked for one of its own
      // outbounds, and ours are not theirs.
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

/// A resolver we are not sending, with the reason in the reader's language.
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

/// The plan for a configuration as it would actually be rendered.
///
/// Which servers are in play changes the answer — a group must be carried by
/// every member, and a member without UDP costs a plain resolver — so the
/// active configuration is asked about its live selection rather than about its
/// first server. Shared by the screen and by the row that leads to it: two
/// answers to this question is how a summary starts contradicting the page
/// under it.
DnsPlan dnsPlanForProfile(WidgetRef ref, Profile profile) {
  final state = ref.watch(profilesControllerProvider);
  // While the preference is still loading the built-in default stands in: the
  // row would otherwise flash a resolver the user replaced.
  final fallback = ref.watch(routingPrefsProvider.select((p) => p.defaultDns));
  final active = state.active?.id == profile.id;
  final group = active ? state.selectedGroup : null;
  final members = active ? state.selectedGroupMembers : const <Location>[];
  final location =
      (active ? state.selectedLocation : null) ??
      (profile.locations.isEmpty ? null : profile.locations.first);
  if (location == null) {
    // No server to render means no tunnel to reason about; the resolvers
    // themselves are still worth showing, and none of them can be pinned.
    // (A server that exists but has not been issued yet gets the same answer,
    // from [engineShape] itself.)
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

/// Whose choice the resolvers are. Short, because it sits at the end of a line
/// that already carries something else.
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
