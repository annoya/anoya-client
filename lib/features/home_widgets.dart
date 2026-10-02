import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/mihomo_tun_config.dart';
import '../core/norm_config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../l10n/l10n.dart';
import '../state/on_demand_controller.dart';
import '../state/profiles_controller.dart';
import '../state/session.dart';

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
    final l10n = context.l10n;
    final vpn = context.vpnColors;
    final session = ref.watch(sessionProvider);
    final style = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final empty = ref.watch(
      profilesControllerProvider.select((s) => s.active == null),
    );
    if (empty && !session.busy) {
      return Text(
        l10n.statusNoConfiguration,
        style: style?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (ref.watch(profilesControllerProvider.select((s) => s.switching))) {
      final label = session.connected
          ? l10n.homeSwitchingServer
          : l10n.homeGettingServer;
      return Text(label, style: style?.copyWith(color: vpn.connecting));
    }
    final auto = ref.watch(onDemandProvider.select((p) => p.systemArmed));
    final clock = sessionClock(session.startedAt);
    final connected = clock.isEmpty
        ? l10n.statusConnected
        : l10n.homeConnectedClock(clock);
    final (text, color) = switch (session.status) {
      VpnStatus.connected => (
        auto ? l10n.homeStatusAuto(connected) : connected,
        vpn.connected,
      ),
      VpnStatus.connecting => (l10n.statusConnecting, vpn.connecting),
      VpnStatus.error => (
        l10n.statusError,
        Theme.of(context).colorScheme.error,
      ),
      VpnStatus.disconnected => (
        l10n.statusNotConnected,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Text(text, style: style?.copyWith(color: color));
  }
}

class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key, required this.status, required this.onTap});

  final VpnStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connected = status == VpnStatus.connected;
    final connecting = status == VpnStatus.connecting;
    final vpn = context.vpnColors;
    final color = connected
        ? vpn.connected
        : connecting
        ? vpn.connecting
        : Theme.of(context).colorScheme.primary;

    final enabled = !connecting && onTap != null;

    final ring = Semantics(
      button: true,
      enabled: enabled,
      label: connected ? l10n.commonDisconnect : l10n.commonConnect,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
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
                        connected ? l10n.commonDisconnect : l10n.commonConnect,
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
    return onTap == null ? Opacity(opacity: 0.38, child: ring) : ring;
  }
}

enum ChipTone { on, off, pending }

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

String describeGroup(ProxyGroup g, List<Location> locations) {
  final ids = {for (final l in locations) l.id};
  final n = g.members.where(ids.contains).length;
  final every =
      g.type == 'url-test' || g.type == 'fallback' || g.type == 'load-balance';
  final interval = Duration(seconds: g.intervalSeconds) < kMinGroupInterval
      ? kMinGroupInterval
      : Duration(seconds: g.intervalSeconds);
  return every
      ? L10n.current.homeGroupRechecks(g.describe(n), interval.inMinutes)
      : g.describe(n);
}

IconData groupIcon(String type) => switch (type) {
  'url-test' => Icons.bolt,
  'fallback' => Icons.shield_outlined,
  'load-balance' => Icons.balance,
  'relay' => Icons.alt_route,
  _ => Icons.groups_outlined,
};

Widget flagOrIcon(Location? loc) {
  final flag = loc == null
      ? null
      : flagForCode(loc.countryCode) ?? flagEmoji(loc.label);
  if (flag == null) return const Icon(Icons.public);
  return Text(flag, style: const TextStyle(fontSize: 26));
}
