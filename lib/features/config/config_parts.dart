import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/device_identity.dart';
import '../../core/app_error.dart';
import '../../core/norm_config.dart';
import '../../core/subscription_info.dart';
import '../../core/profile.dart';
import '../../core/rule_set.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';
import '../../state/routing_status.dart';
import '../routing_screen.dart';

/// Pieces every configuration screen shares. The three domains (ADR-005) differ in
/// what a configuration *is* — an account, a feed of servers, or a single
/// server — so they get a screen each; what they have in common lives here
/// rather than in a chain of conditionals none of the three reads cleanly.

IconData profileIcon(ProfileType t) => switch (t) {
      ProfileType.selfhosted => Icons.business_outlined,
      ProfileType.subscription => Icons.folder_outlined,
      ProfileType.link => Icons.link,
    };

String profileKind(Profile p) => switch (p.type) {
      ProfileType.selfhosted => 'Self-hosted · ${p.locations.length} servers',
      ProfileType.subscription => 'Subscription · ${p.locations.length} servers',
      ProfileType.link => 'Single server',
    };

/// Identity card at the top of every configuration screen. The check mark is
/// how "set active" reports itself: the button below disappears and the mark
/// appears here, so the result is visible without leaving the screen.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key, required this.profile, required this.isActive});

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
              ? Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary, size: 20)
              : null,
        ),
      );
}

/// Where the configuration came from, and the one thing worth doing with it.
///
/// A subscription has a page meant for people — the panel even says which one
/// (`profile-web-page-url`) — so tapping opens it. A bare link has nothing to
/// open, so tapping copies it. The trailing icon names which of the two will
/// happen, so one row behaves differently without surprising anyone.
///
/// The value is shown elided in the middle: this is a credential, and the row
/// exists for recognition, not for reading it off the screen.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.value, this.openUrl});

  final String value;

  /// The page to open on tap. Null → the value is copied instead.
  final String? openUrl;

  @override
  Widget build(BuildContext context) {
    final opens = (openUrl ?? '').isNotEmpty;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.link),
        title: const Text('Source'),
        subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(opens ? Icons.open_in_new : Icons.copy_all_outlined, size: 18),
        onTap: () => opens ? _open(context, openUrl!) : _copy(context),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showToast(context, 'Couldn’t open that page.');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showToast(context, 'Link copied');
  }
}

/// The panel refused this device: its limit is full.
///
/// A warning rather than an error, and above everything else on the screen:
/// the configuration still exists and can be repaired, but every list below it
/// is now the provider's placeholder rather than servers, and reading them
/// without this card would be baffling.
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

/// Everything the subscription's panel reported, marked as its own voice.
///
/// It sits under a header that names the source rather than the subject: the
/// same numbers under "ACCOUNT" would claim an authority a subscription does
/// not have (ADR-005). The panel can stop returning servers; it cannot tell us
/// a verdict, and nothing here gates connecting.
class ProviderSection extends StatelessWidget {
  const ProviderSection({super.key, required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('FROM YOUR PROVIDER'),
      if (info.announce.isNotEmpty)
        Card(
          margin: kCardMargin,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            // Their text, rendered as text: no links made clickable out of it,
            // and no warning icon lent to it. A provider's message is not a
            // state of the app.
            child: Text(info.announce, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      if (info.hasPlan) _PlanCard(info: info),
      if (info.supportUrl.isNotEmpty)
        Card(
          margin: kCardMargin,
          child: ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Contact your provider'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.tryParse(info.supportUrl);
              if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) showToast(context, 'Couldn’t open that link.');
              }
            },
          ),
        ),
      if (!info.hasPlan && info.announce.isEmpty && info.supportUrl.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
          child: Text('Your provider reported no plan details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
        ),
    ]);
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final warn = Theme.of(context).colorScheme.error;
    return Card(
      margin: kCardMargin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            info.unlimited
                // A share of zero is not a number: a bar here would read as
                // "all used up" for a plan that has no ceiling at all.
                ? 'Used ${formatBytes(info.usedBytes)} · no limit'
                : 'Traffic: ${formatBytes(info.usedBytes)} of ${formatBytes(info.totalBytes)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!info.unlimited) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (info.usedBytes / info.totalBytes).clamp(0.0, 1.0),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _planLine(info),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: info.expired ? warn : muted),
          ),
        ]),
      ),
    );
  }

  String _planLine(SubscriptionInfo info) {
    final at = info.expiresAt;
    final when = at == null
        ? 'No expiry date given'
        : '${info.expired ? 'Expired' : 'Active until'} ${_date(at)}';
    return '$when · what the subscription reports, not verified here';
  }

  String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// Age of the cached servers plus a manual re-pull. Only for configurations
/// with an origin to ask — a link has none.
class RefreshCard extends StatelessWidget {
  const RefreshCard({
    super.key,
    required this.profile,
    required this.refreshing,
    required this.onRefresh,
  });

  final Profile profile;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Card(
        margin: kCardMargin,
        child: ListTile(
          title: const Text('Last refreshed'),
          subtitle: Text(refreshedAtLabel(profile)),
          trailing: refreshing
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh now',
                  onPressed: onRefresh,
                ),
        ),
      );
}

String refreshedAtLabel(Profile p) {
  final at = p.refreshedAt;
  final every = _cadence(p);
  if (at == null) return 'never · $every';
  final d = DateTime.now().difference(at);
  final ago = d.inDays > 0
      ? '${d.inDays} day${d.inDays > 1 ? 's' : ''} ago'
      : d.inHours > 0
          ? '${d.inHours} hour${d.inHours > 1 ? 's' : ''} ago'
          : d.inMinutes > 0
              ? '${d.inMinutes} min ago'
              : 'just now';
  return '$ago · $every';
}

/// How often this configuration re-pulls. A panel may ask for a cadence
/// (`profile-update-interval`, in days); we say what we actually do, which is
/// its interval only where it is slower than our own polling — a panel must not
/// be able to make the app call it every minute.
String _cadence(Profile p) {
  final days = p.providerInfo?.updateInterval;
  if (days == null || days <= 0) return 'auto every 5 min';
  return 'auto every 5 min · your provider asks for '
      '${days == 1 ? 'daily' : 'every $days days'}';
}

/// The routing section for a configuration whose rules are the device's own:
/// an opt-in switch plus the rule set in force.
class LocalRoutingCard extends ConsumerWidget {
  const LocalRoutingCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(ruleSetsProvider).value ?? const <RuleSet>[];
    final ruleSet =
        sets.where((s) => s.id == (profile.ruleSetId ?? RuleSet.defaultId)).firstOrNull;
    final ctrl = ref.read(profilesControllerProvider.notifier);

    return Card(
      margin: kCardMargin,
      child: Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.alt_route),
          title: const Text('Routing'),
          // The subtitle is the policy in force, not a description of the
          // switch: the set itself is named in the row below, and repeating it
          // here would say nothing new.
          subtitle: Text(_summary(profile, ruleSet)),
          value: profile.routingEnabled,
          onChanged: (v) => ctrl.setRoutingEnabled(profile.id, v),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        // Kept visible while off — hiding it would make the switch look like it
        // controls nothing, and the chosen set is remembered for when routing
        // comes back on.
        Opacity(
          opacity: profile.routingEnabled ? 1 : 0.38,
          child: ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: const Text('Rule set'),
            subtitle: Text(ruleSet?.name ?? 'Default'),
            trailing: const Icon(Icons.expand_more),
            // Reachable with routing off: picking a set is how it gets turned on.
            onTap: () => _pick(context, ref, sets),
          ),
        ),
      ]),
    );
  }

  String _summary(Profile p, RuleSet? set) {
    if (!p.routingEnabled) return 'Off · everything through the VPN';
    final mode = (set?.mode ?? 'full') == 'split' ? 'Split' : 'Full tunnel';
    final rules = set?.rules.length ?? 0;
    return '$mode · ${rules == 0 ? 'no rules' : '$rules rule${rules > 1 ? 's' : ''}'}';
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, List<RuleSet> sets) async {
    final picked = await pickOption<String>(
      context,
      title: 'Rule set',
      selected: profile.ruleSetId ?? RuleSet.defaultId,
      options: sets
          .map((s) => Option(
                s.id,
                s.name,
                subtitle:
                    '${s.mode == 'split' ? 'Split' : 'Full tunnel'} · ${s.rules.isEmpty ? 'no rules' : '${s.rules.length} rules'}',
                leading: const Icon(Icons.layers_outlined),
              ))
          .toList(),
    );
    if (picked != null) {
      await ref.read(profilesControllerProvider.notifier).setRuleSet(profile.id, picked);
    }
  }
}

/// Set active / remove, in that order, at the bottom of every screen.
class ConfigActions extends ConsumerWidget {
  const ConfigActions({super.key, required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(profilesControllerProvider.notifier);
    // stretch, not the default centre: a Column hands its children their
    // intrinsic width, which made these buttons hug their labels instead of
    // spanning the content width the way every other screen's do.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      if (!isActive)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Set active'),
            onPressed: () => ctrl.setActive(profile.id),
          ),
        ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Remove configuration'),
          style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => _remove(context, ref),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${profile.name}?'),
        content: const Text('This configuration will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    if (ref.read(profilesControllerProvider).activeId == profile.id) {
      try {
        // Through the controller, not the raw core: it records the on-demand
        // pause first, so the home chips explain why auto-connect is off.
        await ctrl.disconnect();
      } catch (_) {/* ignore */}
    }
    await ctrl.removeProfile(profile.id);
    if (!context.mounted) return;
    // Only close ourselves while other configurations remain. When that was the
    // last one, the app shell unwinds to the add screen on its own — popping
    // here as well would race it and take the root route down too (leaving an
    // empty navigator, i.e. a black screen).
    if (ref.read(profilesControllerProvider).hasProfiles) Navigator.of(context).pop();
  }
}

/// Opens the read-only view of a policy the configuration did not choose.
void openManagedRouting(BuildContext context, Routing routing) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoutingScreen.managed(routing)));
}

/// Shown only for a configuration whose panel said it counts devices.
///
/// The panel reports *that* it counts and *that* it is full — never how many of
/// how many — so this says what we know and stops. What it must say is that
/// this installation occupies a slot: that is a consequence of using the app,
/// and learning it by hitting the limit somewhere else would be a surprise.
class ThisDeviceSection extends StatelessWidget {
  const ThisDeviceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceIdentity>(
      future: DeviceIdentityStore.load(),
      builder: (context, snap) {
        final id = snap.data;
        if (id == null) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader('THIS DEVICE'),
          Card(
            margin: kCardMargin,
            child: ListTile(
              leading: const Icon(Icons.smartphone_outlined),
              title: Text(id.label),
              subtitle: const Text('Identified to your provider, which counts devices'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
            child: Text(
              'Your provider counts devices by an id this app generates once and '
              'keeps. Reinstalling makes a new one, which takes another slot.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ]);
      },
    );
  }
}
