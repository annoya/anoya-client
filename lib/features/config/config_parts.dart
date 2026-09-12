import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';

export 'device_section.dart';
export 'names_section.dart';
export 'provider_routing_card.dart';
export 'provider_section.dart';
export 'refresh_card.dart';
export 'routing_cards.dart';

/// Pieces every configuration screen shares. The three domains (ADR-005) differ in
/// what a configuration *is* — an account, a feed of servers, or a single
/// server — so they get a screen each; what they have in common lives here
/// rather than in a chain of conditionals none of the three reads cleanly.

IconData profileIcon(ProfileType t) => switch (t) {
  ProfileType.selfhosted => Icons.business_outlined,
  ProfileType.subscription => Icons.folder_outlined,
  ProfileType.amnezia => Icons.shield_outlined,
  ProfileType.link => Icons.link,
};

String profileKind(Profile p) => switch (p.type) {
  ProfileType.selfhosted => 'Self-hosted · ${_servers(p)}',
  ProfileType.subscription => 'Subscription · ${_servers(p)}${_groups(p)}',
  // A free subscription has one config and nowhere to choose, so counting
  // "1 server" would dress a fact up as a choice. Named no more precisely
  // than a panel's: the key carries whoever sold it, and that name is
  // already the title above this line.
  ProfileType.amnezia =>
    p.amnezia?.offersLocations == false
        ? 'Subscription'
        : 'Subscription · ${_servers(p)}',
  ProfileType.link => 'Single server',
};

/// "12 servers", or "294 of 306 servers" when the source offered protocols this
/// app cannot run. The second form exists so the number here matches what the
/// provider's own panel shows, minus an explanation the card below supplies.
String _servers(Profile p) {
  final offered = p.offeredServers;
  final ours = p.locations.length;
  final noun = offered == 1 ? 'server' : 'servers';
  return ours == offered ? '$ours $noun' : '$ours of $offered $noun';
}

/// "· 3 groups", when the subscription offered sets the engine picks from.
///
/// Counted where the servers are counted, because a section appearing in the
/// picker that was not there before otherwise reads as a new feature of the app
/// rather than as something the provider sent.
String _groups(Profile p) {
  final n = p.groups.length;
  if (n == 0) return '';
  return ' · $n group${n > 1 ? 's' : ''}';
}

/// Identity card at the top of every configuration screen. The check mark is
/// how "set active" reports itself: the button below disappears and the mark
/// appears here, so the result is visible without leaving the screen.
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
  const SourceCard({
    super.key,
    required this.value,
    this.openUrl,
    this.viaFallback = false,
  });

  final String value;

  /// The page to open on tap. Null → the value is copied instead.
  final String? openUrl;

  /// The last refresh came from the provider's backup address. The row keeps
  /// showing the address the user added — that is what they chose and what they
  /// would share — and says the backup carried it underneath. Swapping the line
  /// silently would hide that their provider's main address is unreachable.
  final bool viaFallback;

  @override
  Widget build(BuildContext context) {
    final opens = (openUrl ?? '').isNotEmpty;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.link),
        title: const Text('Source'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (viaFallback)
              Text(
                'Last refresh used the subscription’s backup address',
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
      if (context.mounted) showToast(context, 'Couldn’t open that page.');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showToast(context, 'Link copied');
  }
}

/// Names the servers the source offered and this app cannot run.
///
/// Dropping them silently is the tempting option and the wrong one: the user
/// counted the locations in their provider's panel, and a smaller number here
/// with no reason given reads as the app losing them. A warning, not an error —
/// the rest of the servers work and connecting is available right now.
class UnsupportedServersCard extends StatelessWidget {
  const UnsupportedServersCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skipped = profile.offeredServers - profile.locations.length;
    final kinds = (profile.unsupportedServers.keys.toList()..sort()).join(', ');
    return Card(
      margin: kCardMargin,
      color: cs.tertiaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
        title: Text(
          '$skipped of ${profile.offeredServers} servers unsupported',
        ),
        subtitle: Text(
          'They use $kinds, which this app cannot run yet. '
          'The other ${profile.locations.length} are available.',
        ),
        isThreeLine: true,
      ),
    );
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

/// Set active / remove, in that order, at the bottom of every screen.
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
    // stretch, not the default centre: a Column hands its children their
    // intrinsic width, which made these buttons hug their labels instead of
    // spanning the content width the way every other screen's do.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    // Both captured before the removal, and used instead of `context`/`ref`
    // after it: the moment the configuration is gone this widget is replaced by
    // the screen's "nothing to show" placeholder, and asking a dead element to
    // pop does nothing. That is how removing the *active* configuration left
    // the user on a blank page — re-pointing the tunnel let a frame through
    // first, so by the time the pop was reached there was nobody to ask.
    final nav = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${profile.name}?'),
        content: const Text(
          'This configuration will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
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
      } catch (_) {
        /* ignore */
      }
    }
    await ctrl.removeProfile(profile.id);
    // Only close ourselves while other configurations remain. When that was the
    // last one, the app shell unwinds to the add screen on its own — popping
    // here as well would race it and take the root route down too (leaving an
    // empty navigator, i.e. a black screen).
    if (container.read(profilesControllerProvider).hasProfiles && nav.mounted) {
      nav.pop();
    }
  }
}
