import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import 'config_screen.dart';
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
      body: PageBody(
        child: ListView(
          children: [
            // Spec: 24 above the status, 28 between status and ring, 40 below.
            const SizedBox(height: 24),
            Center(child: _statusLabel()),
            const SizedBox(height: 28),
            Center(child: _ConnectButton(status: _status, onTap: _toggle)),
            const SizedBox(height: 40),
            if (st.profiles.length > 1) _profileRow(st, active),
            if (active != null) _locationRow(st, active),
            if (active != null && active.hasAccount && active.account != null) ...[
              const SizedBox(height: 12),
              _accountRow(active.account!),
            ],
            if (st.error != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: Text(st.error!, textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
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
    final (text, color) = switch (_status) {
      VpnStatus.connected => ('Connected${_session()}', vpn.connected),
      VpnStatus.connecting => ('Connecting…', vpn.connecting),
      VpnStatus.error => ('Error', Theme.of(context).colorScheme.error),
      VpnStatus.disconnected => ('Not connected', Theme.of(context).colorScheme.onSurfaceVariant),
    };
    return Text(text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600));
  }

  Widget _profileRow(ProfilesState st, Profile? active) {
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: Icon(active == null ? Icons.folder_outlined : profileIcon(active.type)),
        title: Text(active?.name ?? 'Configuration'),
        subtitle: Text(_profileSubtitle(active)),
        trailing: _busy ? const Icon(Icons.lock_outline, size: 18) : const Icon(Icons.expand_more),
        onTap: _busy ? null : () => _pickProfile(st),
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
            : _busy
                ? const Icon(Icons.lock_outline, size: 18)
                : const Icon(Icons.chevron_right),
        onTap: (!pickable || _busy) ? null : () => _pickLocation(st),
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

  String _profileSubtitle(Profile? p) => p == null ? '' : profileKind(p);

  Future<void> _pickProfile(ProfilesState st) async {
    final picked = await pickOption<String>(
      context,
      title: 'Configuration',
      selected: st.activeId,
      options: st.profiles
          .map((p) => Option(
                p.id,
                p.name,
                subtitle: _profileSubtitle(p),
                leading: Icon(profileIcon(p.type)),
              ))
          .toList(),
    );
    if (picked != null) ref.read(profilesControllerProvider.notifier).setActive(picked);
  }

  Future<void> _pickLocation(ProfilesState st) async {
    final picked = await pickOption<String>(
      context,
      title: 'Server',
      selected: st.selectedLocation?.id,
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

    return GestureDetector(
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
    );
  }
}
