import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dns_plan.dart';
import '../../core/mihomo_tun_config.dart';
import '../../core/norm_config.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../../state/providers.dart';
import '../dns_screen.dart';

class NamesSection extends ConsumerWidget {
  const NamesSection({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesControllerProvider);
    final active = state.active?.id == profile.id;
    final group = active ? state.selectedGroup : null;
    final members = active ? state.selectedGroupMembers : const <Location>[];
    final location =
        (active ? state.selectedLocation : null) ??
        (profile.locations.isEmpty ? null : profile.locations.first);
    final shape = location == null
        ? (outbounds: const <String>{}, carriesUdp: false)
        : engineShape(location, group: group, members: members);
    final plan = dnsPlanFor(
      dns: profile.dns,
      outbounds: shape.outbounds,
      carriesUdp: shape.carriesUdp,
      fallback: ref.watch(routingPrefsProvider.select((p) => p.defaultDns)),
    );
    final first = plan.resolvers.first;
    final l10n = context.l10n;
    final more = plan.resolvers.length - 1;

    return Column(
      // Stretch, or this header is centred unlike every other on the page.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.dnsTitle),
        Card(
          margin: kCardMargin,
          child: ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.dnsTitle),
            subtitle: Text(
              l10n.configDnsSummary(_host(first.address), first.routing) +
                  (more > 0 ? l10n.configDnsMore(more) : ''),
            ),
            trailing: plan.dropped.isEmpty
                ? const Icon(Icons.chevron_right)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.configDnsDropped(plan.dropped.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DnsScreen(profile: profile)),
            ),
          ),
        ),
      ],
    );
  }

  String _host(String address) {
    final at = address.indexOf('://');
    if (at < 0) return address;
    return Uri.tryParse(address)?.host ?? address.substring(at + 3);
  }
}
