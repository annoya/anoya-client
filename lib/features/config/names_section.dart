import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dns_plan.dart';
import '../../core/mihomo_tun_config.dart';
import '../../core/norm_config.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';
import '../../state/providers.dart';
import '../dns_screen.dart';

/// Which resolvers this configuration uses, and a way to see why some of them
/// are not being used.
///
/// A section of its own rather than a line inside `ROUTING`: routing decides
/// where a connection goes, this decides who is asked for the address, and the
/// two are answered by different halves of the engine config. The subtitle
/// names the resolver and how it is reached, because "1 resolver" answers
/// neither of the questions a person opens this for.
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

    return Column(
      // Without this a Column hands its children their intrinsic width and
      // centres them — which is exactly what happened to this header while
      // every other one on the page stayed flush left.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('DNS'),
        Card(
          margin: kCardMargin,
          child: ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('DNS'),
            // Host and routing, not a count: the first is what the user came to
            // check, the second is the one that decides who else sees the query.
            subtitle: Text(
              '${_host(first.address)} · ${first.routing}'
              '${plan.resolvers.length > 1 ? ' · +${plan.resolvers.length - 1} more' : ''}',
            ),
            // Refusals are the reason this row leads anywhere at all, so they are
            // announced before the screen is opened.
            trailing: plan.dropped.isEmpty
                ? const Icon(Icons.chevron_right)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${plan.dropped.length} dropped',
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

  /// The host alone. A DoH resolver's path (`/dns-query`) is the same on every
  /// server that has one and only costs the row the width it needs for the name.
  String _host(String address) {
    final at = address.indexOf('://');
    if (at < 0) return address;
    return Uri.tryParse(address)?.host ?? address.substring(at + 3);
  }
}
