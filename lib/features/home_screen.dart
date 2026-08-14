import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/norm_config.dart';
import '../core/on_demand.dart';
import '../core/profile.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../state/favorites_controller.dart';
import '../state/on_demand_controller.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import '../state/routing_status.dart';
import 'config_screen.dart';
import 'logs_screen.dart';
import 'on_demand_screen.dart';
import 'rule_sets_screen.dart';
import 'settings_screen.dart';
import 'start_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  VpnStatus _status = VpnStatus.disconnected;
  StreamSubscription<VpnStatus>? _statusSub;
  DateTime? _connectedAt;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    final core = ref.read(vpnCoreProvider);
    _status = core.status;
    _onStatus(core.status);
    _statusSub = core.statusStream().listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      _onStatus(s);
    });
  }

  /// Track the session start so the label can show "Connected · 00:12:34";
  /// tick once a second only while connected.
  void _onStatus(VpnStatus s) {
    if (s == VpnStatus.connected) {
      _connectedAt ??= DateTime.now();
      _sessionTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _connectedAt = null;
      _sessionTimer?.cancel();
      _sessionTimer = null;
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  bool get _busy => _status == VpnStatus.connected || _status == VpnStatus.connecting;

  /// When the pickers refuse taps. A connected tunnel is NOT locked: switching
  /// is a hot reload under the live session. Locked only while the initial
  /// connect is in flight, or during the (brief) hot switch itself.
  bool get _locked =>
      _status == VpnStatus.connecting || ref.read(profilesControllerProvider).switching;

  Future<void> _toggle() async {
    final ctrl = ref.read(profilesControllerProvider.notifier);
    if (_busy) {
      await ctrl.disconnect();
    } else {
      await ctrl.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profilesControllerProvider);
    final active = st.active;

    // A connect failure floats above the screen until dismissed: the layout
    // must not jump, and a cause that vanished on its own tells the user
    // nothing about what to fix.
    ref.listen(profilesControllerProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        showErrorDialog(context, error,
            onDismiss: ref.read(profilesControllerProvider.notifier).clearError);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add configuration',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StartScreen()),
          ),
        ),
        title: const Text('VPN'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      // The ring owns the free space and stays centred in it; the pickers are
      // pinned to the bottom edge, within thumb reach and steady when a banner
      // appears above them.
      body: PageBody(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    _statusStrip(),
                    Expanded(
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          _statusLabel(),
                          const SizedBox(height: 28),
                          _ConnectButton(status: _status, onTap: _toggle),
                        ]),
                      ),
                    ),
                    ?_onDemandBanner(),
                    if (active != null) _profileRow(st, active),
                    if (active != null) _locationRow(st, active),
                    if (active != null && active.hasAccount && active.account != null) ...[
                      const SizedBox(height: 12),
                      _accountRow(active.account!),
                    ],
                    const SizedBox(height: kGutter),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _session() {
    final at = _connectedAt;
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    String two(int n) => n.toString().padLeft(2, '0');
    return ' · ${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  Widget _statusLabel() {
    final vpn = context.vpnColors;
    // "· auto" only when the OS confirmed it is auto-connecting.
    final auto = ref.watch(onDemandProvider).systemArmed ? ' · auto' : '';
    if (ref.watch(profilesControllerProvider.select((s) => s.switching))) {
      // The ring stays green (the session never dropped); the status line is
      // the only telltale of the in-flight switch.
      return Text('Switching server…',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: vpn.connecting, fontWeight: FontWeight.w600));
    }
    final (text, color) = switch (_status) {
      VpnStatus.connected => ('Connected${_session()}$auto', vpn.connected),
      VpnStatus.connecting => ('Connecting…', vpn.connecting),
      VpnStatus.error => ('Error', Theme.of(context).colorScheme.error),
      VpnStatus.disconnected => ('Not connected', Theme.of(context).colorScheme.onSurfaceVariant),
    };
    return Text(text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600));
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// The three things that change how the tunnel behaves and otherwise live on
  /// three separate settings screens: whether the system connects on its own,
  /// whether any traffic is routed around the tunnel, and whether anything is
  /// written to the log. Each chip opens the screen that owns it — the off ones
  /// too, since that is where they get turned on.
  Widget _statusStrip() {
    final onDemand = ref.watch(onDemandProvider);
    final collectLogs = ref.watch(appPrefsProvider).collectLogs;
    final routing = ref.watch(routingStatusProvider).value;
    final active = ref.watch(profilesControllerProvider).active;

    // "Enabled but not currently working" is its own state: showing it as off
    // would send the user to a screen where the switch is already on. Only the
    // last case means the OS confirmed it is auto-connecting.
    final (autoLabel, autoTone) = switch (onDemand) {
      OnDemandPrefs(enabled: false) => ('off', _ChipTone.off),
      OnDemandPrefs(paused: true) => ('paused', _ChipTone.pending),
      OnDemandPrefs(rules: []) => ('no rules', _ChipTone.pending),
      OnDemandPrefs(systemArmed: false) => ('not armed', _ChipTone.pending),
      _ => ('on', _ChipTone.on),
    };

    return Padding(
      padding: const EdgeInsets.only(left: kGutter, right: kGutter, top: 8, bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusChip(
            icon: Icons.bolt_outlined,
            label: 'Auto · $autoLabel',
            tone: autoTone,
            onTap: () => _push(const OnDemandScreen()),
          ),
          _StatusChip(
            icon: Icons.alt_route,
            // The value is unknown only until the rule set is read off disk, so
            // it holds its place with an ellipsis instead of the chip appearing
            // a frame late and shifting the row.
            label: 'Routing · ${routing?.label ?? '…'}',
            tone: routing == null || routing == RoutingStatus.off ? _ChipTone.off : _ChipTone.on,
            // Routing is a per-configuration setting, so the chip leads to the
            // active configuration; with none added yet, to the sets themselves.
            onTap: () => _push(
                active == null ? const RuleSetsScreen() : ConfigScreen(profileId: active.id)),
          ),
          _StatusChip(
            icon: Icons.description_outlined,
            label: 'Logs · ${collectLogs ? 'on' : 'off'}',
            tone: collectLogs ? _ChipTone.on : _ChipTone.off,
            onTap: () => _push(const LogsScreen()),
          ),
        ],
      ),
    );
  }

  /// Explains why the system is not auto-connecting: either the user paused it
  /// with a manual disconnect, or it is enabled but has no tunnel config to
  /// start from yet (the system only accepts on-demand after one connect).
  Widget? _onDemandBanner() {
    final onDemand = ref.watch(onDemandProvider);
    if (!onDemand.enabled || _busy) return null;
    final (title, subtitle) = switch (onDemand) {
      OnDemandPrefs(paused: true) => ('Auto-connect paused', 'Press Connect to arm it again'),
      OnDemandPrefs(awaitingFirstConnect: true) => (
          'Auto-connect not armed yet',
          'Connect once so the system can take over',
        ),
      _ => (null, null),
    };
    if (title == null) return null;
    return Card(
      margin: kCardMargin,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: const Icon(Icons.bolt_outlined),
        title: Text(title),
        subtitle: Text(subtitle!),
      ),
    );
  }

  /// The active configuration is always on screen, even when it is the only
  /// one: the gear jumps straight into its settings, while the chevron (and the
  /// row tap) only offer a choice when there is something to choose between.
  Widget _profileRow(ProfilesState st, Profile active) {
    final pickable = st.profiles.length > 1;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: Icon(profileIcon(active.type)),
        title: Text(active.name),
        subtitle: Text(profileKind(active)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Configuration settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ConfigScreen(profileId: active.id)),
            ),
          ),
          if (pickable)
            _status == VpnStatus.connecting
                ? const Icon(Icons.lock_outline, size: 18)
                : const Icon(Icons.expand_more),
        ]),
        onTap: (!pickable || _locked) ? null : () => _pickProfile(st),
      ),
    );
  }

  Widget _locationRow(ProfilesState st, Profile active) {
    final loc = st.selectedLocation;
    // A single-server profile (a plain link) has nothing to pick between: show
    // the server but no dropdown affordance or picker.
    final pickable = !active.isSingleServer && st.locations.length > 1;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: _flagOrIcon(loc?.label),
        title: Text(loc != null ? stripLeadingFlag(loc.label) : 'No servers'),
        subtitle: loc != null ? Text('${loc.proxyType} · ${loc.proxy['server']}') : null,
        trailing: !pickable
            ? null
            : _status == VpnStatus.connecting
                ? const Icon(Icons.lock_outline, size: 18)
                : const Icon(Icons.chevron_right),
        onTap: (!pickable || _locked) ? null : () => _pickLocation(st, active),
      ),
    );
  }

  Widget _accountRow(Account account) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Text(
        account.expiresAt != null
            ? '${account.status} · until ${account.expiresAt!.toLocal().toString().split('.').first}'
            : account.status,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
      ),
    );
  }

  Future<void> _pickProfile(ProfilesState st) async {
    final favorites = ref.read(favoritesProvider);
    final picked = await pickOption<String>(
      context,
      title: 'Configuration',
      selected: st.activeId,
      itemNoun: 'configuration',
      favorites: favorites.profiles,
      onToggleFavorite: (id) => ref.read(favoritesProvider.notifier).toggleProfile(id),
      onOpenSettings: (id) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConfigScreen(profileId: id)),
      ),
      options: st.profiles
          .map((p) => Option(
                p.id,
                p.name,
                subtitle: profileKind(p),
                leading: Icon(profileIcon(p.type)),
              ))
          .toList(),
    );
    if (picked != null) ref.read(profilesControllerProvider.notifier).setActive(picked);
  }

  Future<void> _pickLocation(ProfilesState st, Profile active) async {
    final favorites = ref.read(favoritesProvider);
    final picked = await pickOption<String>(
      context,
      title: 'Server',
      selected: st.selectedLocation?.id,
      itemNoun: 'server',
      favorites: favorites.locationsOf(active.id),
      onToggleFavorite: (id) =>
          ref.read(favoritesProvider.notifier).toggleLocation(active.id, id),
      options: st.locations
          .map((l) => Option(
                l.id,
                stripLeadingFlag(l.label),
                subtitle: '${l.proxyType} · ${l.proxy['server']}',
                leading: _flagOrIcon(l.label),
              ))
          .toList(),
    );
    if (picked != null) ref.read(profilesControllerProvider.notifier).selectLocation(picked);
  }
}

/// A country flag emoji for the location (rendered natively on Apple
/// platforms), falling back to a globe icon when no country is inferred.
Widget _flagOrIcon(String? label) {
  final flag = label == null ? null : flagEmoji(label);
  if (flag == null) return const Icon(Icons.public);
  return Text(flag, style: const TextStyle(fontSize: 26));
}

/// Big circular connect button whose color reflects status.
class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.status, required this.onTap});
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
                  child: CircularProgressIndicator(strokeWidth: 3, color: color))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.power_settings_new, size: 56, color: color),
                  const SizedBox(height: 8),
                  Text(connected ? 'Disconnect' : 'Connect',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ]),
          ),
        ),
      ),
    );
  }
}

/// Tone of a status chip: on = the feature is doing something, off = it is not,
/// pending = it is switched on but not in effect right now.
enum _ChipTone { on, off, pending }

/// Reports one piece of tunnel state and opens the screen that owns it. Not a
/// Material chip: those are sized for selection and filtering, and this one has
/// to stay 30pt so three of them read as a status line rather than a toolbar.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _ChipTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (fg, bg, border) = switch (tone) {
      _ChipTone.on => (cs.onPrimaryContainer, cs.primaryContainer, null),
      _ChipTone.off => (cs.onSurfaceVariant, null, cs.outlineVariant),
      _ChipTone.pending => (
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
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: fg, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}
