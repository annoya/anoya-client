import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cat_sprite.dart';
import '../core/country_flag.dart';
import '../core/ds.dart';
import '../core/mihomo_tun_config.dart';
import '../core/norm_config.dart';
import '../core/theme.dart';
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
    final ds = context.ds;
    final session = ref.watch(sessionProvider);
    final style = DsType.text;
    final empty = ref.watch(
      profilesControllerProvider.select((s) => s.active == null),
    );
    if (empty && !session.busy) {
      return Text(
        l10n.statusNoConfiguration,
        style: style.copyWith(color: ds.text2),
      );
    }
    if (ref.watch(profilesControllerProvider.select((s) => s.switching))) {
      return session.connected
          ? Text(
              l10n.homeSwitchingServer,
              style: style.copyWith(color: ds.text1),
            )
          : Text(
              l10n.homeGettingServer,
              style: style.copyWith(color: ds.text2),
            );
    }
    final auto = ref.watch(onDemandProvider.select((p) => p.systemArmed));
    final clock = sessionClock(session.startedAt);
    final connected = clock.isEmpty
        ? l10n.statusConnected
        : l10n.homeConnectedClock(clock);
    final (text, color) = switch (session.status) {
      VpnStatus.connected => (
        auto ? l10n.homeStatusAuto(connected) : connected,
        ds.text1,
      ),
      VpnStatus.connecting => (l10n.statusConnecting, ds.text2),
      VpnStatus.error => (l10n.statusError, ds.destructive),
      VpnStatus.disconnected => (l10n.statusNotConnected, ds.text2),
    };
    return Text(text, style: style.copyWith(color: color));
  }
}

// homeHero: catStage 240×200 · 16 · status 16/24 · 20 · primary button 200×48.
class HomeHero extends ConsumerWidget {
  const HomeHero({
    super.key,
    required this.status,
    required this.onTap,
    this.autofocus = false,
  });

  final VpnStatus status;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switching = ref.watch(
      profilesControllerProvider.select((s) => s.switching),
    );
    final connected = status == VpnStatus.connected;
    final mood = switch (status) {
      _ when onTap == null => CatMood.asleep,
      VpnStatus.connected => CatMood.awake,
      VpnStatus.connecting => CatMood.looking,
      VpnStatus.error => CatMood.error,
      VpnStatus.disconnected => switching ? CatMood.looking : CatMood.asleep,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CatStage(mood: mood, strongGlow: connected, dimmed: onTap == null),
        const SizedBox(height: 16),
        const StatusLabel(),
        const SizedBox(height: 20),
        ConnectButton(status: status, onTap: onTap, autofocus: autofocus),
      ],
    );
  }
}

class ConnectButton extends StatelessWidget {
  const ConnectButton({
    super.key,
    required this.status,
    required this.onTap,
    this.autofocus = false,
  });

  final VpnStatus status;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: kConnectButtonWidth,
      child: DsButton(
        kind: status == VpnStatus.connected || status == VpnStatus.connecting
            ? DsButtonKind.secondary
            : DsButtonKind.primary,
        label: switch (status) {
          VpnStatus.connected => l10n.commonDisconnect,
          VpnStatus.connecting => l10n.commonCancel,
          _ => l10n.commonConnect,
        },
        spinning: status == VpnStatus.connecting,
        autofocus: autofocus,
        onPressed: onTap,
      ),
    );
  }
}

// Chips size=S: the strip under the navigation; selected = the feature is doing something.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      DsChip(label: label, selected: on, onTap: onTap);
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

Glyph groupIcon(String type) => switch (type) {
  'url-test' => Glyph.zap,
  'fallback' => Glyph.shield,
  'load-balance' => Glyph.scale,
  'relay' => Glyph.route,
  _ => Glyph.users,
};

Widget flagOrIcon(Location? loc) {
  final flag = loc == null
      ? null
      : flagForCode(loc.countryCode) ?? flagEmoji(loc.label);
  if (flag == null) return const GlyphIcon(Glyph.globe);
  return SizedBox.square(
    dimension: kRowIcon,
    child: Center(child: Text(flag, style: const TextStyle(fontSize: 20))),
  );
}
