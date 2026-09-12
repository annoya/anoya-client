import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/mihomo_tun_config.dart';
import '../core/norm_config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../state/on_demand_controller.dart';
import '../state/profiles_controller.dart';
import '../state/session.dart';

/// The home screen's own widgets: the status line with its clock, the ring,
/// the status chips, and how a server or a group is drawn in the picker.

/// "Connected · 00:12:03 · auto", or the wait that is in progress.
///
/// Owns the once-a-second repaint. The clock is the only thing on the home
/// screen that changes without an event, and nothing else there needs a frame
/// per second — the timer used to live on the screen and repaint all of it.
class StatusLabel extends ConsumerStatefulWidget {
  const StatusLabel({super.key});

  @override
  ConsumerState<StatusLabel> createState() => _StatusLabelState();
}

class _StatusLabelState extends ConsumerState<StatusLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The clock only ticks while there is a session to time.
    ref.listenManual(
      sessionProvider.select((s) => s.connected),
      (_, connected) => _tick(connected),
      fireImmediately: true,
    );
  }

  void _tick(bool connected) {
    if (connected) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.vpnColors;
    final session = ref.watch(sessionProvider);
    final style = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    if (ref.watch(profilesControllerProvider.select((s) => s.switching))) {
      // Two different waits wear different words. With a live session the
      // server is being swapped under it; with the tunnel down there is no
      // session to switch, only a server still being fetched, and promising a
      // switch would describe something that is not happening.
      final label = session.connected
          ? 'Switching server…'
          : 'Getting the server…';
      // The ring stays green (the session never dropped); the status line is
      // the only telltale of the in-flight switch.
      return Text(label, style: style?.copyWith(color: vpn.connecting));
    }
    // "· auto" only when the OS confirmed it is auto-connecting.
    final auto = ref.watch(onDemandProvider.select((p) => p.systemArmed))
        ? ' · auto'
        : '';
    final clock = sessionClock(session.startedAt);
    final (text, color) = switch (session.status) {
      VpnStatus.connected => (
        'Connected${clock.isEmpty ? '' : ' · $clock'}$auto',
        vpn.connected,
      ),
      VpnStatus.connecting => ('Connecting…', vpn.connecting),
      VpnStatus.error => ('Error', Theme.of(context).colorScheme.error),
      VpnStatus.disconnected => (
        'Not connected',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Text(text, style: style?.copyWith(color: color));
  }
}

/// Big circular connect button whose color reflects status.
class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key, required this.status, required this.onTap});

  final VpnStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = status == VpnStatus.connected;
    final connecting = status == VpnStatus.connecting;
    final vpn = context.vpnColors;
    final color = connected
        ? vpn.connected
        : connecting
        ? vpn.connecting
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      enabled: !connecting,
      label: connected ? 'Disconnect' : 'Connect',
      child: GestureDetector(
        onTap: connecting ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: connecting
                ? SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: color,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.power_settings_new, size: 56, color: color),
                      const SizedBox(height: 8),
                      Text(
                        connected ? 'Disconnect' : 'Connect',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Tone of a status chip: on = the feature is doing something, off = it is not,
/// pending = it is switched on but not in effect right now.
enum ChipTone { on, off, pending }

/// Reports one piece of tunnel state and opens the screen that owns it. Not a
/// Material chip: those are sized for selection and filtering, and this one has
/// to stay 30pt so three of them read as a status line rather than a toolbar.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ChipTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (fg, bg, border) = switch (tone) {
      ChipTone.on => (cs.onPrimaryContainer, cs.primaryContainer, null),
      ChipTone.off => (cs.onSurfaceVariant, null, cs.outlineVariant),
      ChipTone.pending => (
        context.vpnColors.connecting,
        null,
        context.vpnColors.connecting.withValues(alpha: 0.45),
      ),
    };
    return Material(
      color: bg ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: border == null ? BorderSide.none : BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: kStatusChipHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How many of a group's members this device can actually run, and what the
/// group does with them. The count is the live one, not the provider's: a group
/// naming twelve servers of which we can run nine is a group of nine.
String describeGroup(ProxyGroup g, List<Location> locations) {
  final ids = {for (final l in locations) l.id};
  final n = g.members.where(ids.contains).length;
  final every =
      g.type == 'url-test' || g.type == 'fallback' || g.type == 'load-balance';
  final interval = Duration(seconds: g.intervalSeconds) < kMinGroupInterval
      ? kMinGroupInterval
      : Duration(seconds: g.intervalSeconds);
  return every
      ? '${g.describe(n)} · rechecks every ${interval.inMinutes} min'
      : g.describe(n);
}

/// The shape that says what a group does. Colour cannot: the row is a list
/// item like any other.
IconData groupIcon(String type) => switch (type) {
  'url-test' => Icons.bolt,
  'fallback' => Icons.shield_outlined,
  'load-balance' => Icons.balance,
  'relay' => Icons.alt_route,
  _ => Icons.groups_outlined,
};

/// A country flag emoji for the location (rendered natively on Apple
/// platforms), falling back to a globe icon when no country is inferred.
Widget flagOrIcon(String? label) {
  final flag = label == null ? null : flagEmoji(label);
  if (flag == null) return const Icon(Icons.public);
  return Text(flag, style: const TextStyle(fontSize: 26));
}
