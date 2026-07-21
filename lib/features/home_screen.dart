import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  VpnStatus _status = VpnStatus.disconnected;
  StreamSubscription<VpnStatus>? _statusSub;

  @override
  void initState() {
    super.initState();
    final core = ref.read(vpnCoreProvider);
    _status = core.status;
    _statusSub = core.statusStream().listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
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
        title: const Text('VPN'),
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
          padding: const EdgeInsets.symmetric(vertical: 32),
          children: [
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

  Widget _statusLabel() {
    final (text, color) = switch (_status) {
      VpnStatus.connected => ('Connected', Colors.green),
      VpnStatus.connecting => ('Connecting…', Colors.orange),
      VpnStatus.error => ('Error', Theme.of(context).colorScheme.error),
      VpnStatus.disconnected => ('Not connected', Colors.grey),
    };
    return Text(text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600));
  }

  Widget _profileRow(ProfilesState st, Profile? active) {
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
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

  String _profileSubtitle(Profile? p) {
    if (p == null) return '';
    final kind = switch (p.type) {
      ProfileType.selfhosted => 'Self-hosted',
      ProfileType.subscription => 'Subscription',
      ProfileType.link => 'Link',
    };
    return p.isSingleServer ? kind : '$kind · ${p.locations.length} servers';
  }

  Future<void> _pickProfile(ProfilesState st) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Configuration', style: Theme.of(context).textTheme.titleMedium)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: st.profiles
                  .map((p) => ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(p.name),
                        subtitle: Text(_profileSubtitle(p)),
                        trailing: p.id == st.activeId ? const Icon(Icons.check, color: Colors.green) : null,
                        onTap: () => Navigator.of(context).pop(p.id),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked != null) ref.read(profilesControllerProvider.notifier).setActive(picked);
  }

  Future<void> _pickLocation(ProfilesState st) async {
    final selectedId = st.selectedLocation?.id;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Server', style: Theme.of(context).textTheme.titleMedium)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: st.locations
                  .map((l) => ListTile(
                        leading: _flagOrIcon(l.label),
                        title: Text(stripLeadingFlag(l.label)),
                        subtitle: Text('${l.proxyType} · ${l.proxy['server']}'),
                        trailing: l.id == selectedId ? const Icon(Icons.check, color: Colors.green) : null,
                        onTap: () => Navigator.of(context).pop(l.id),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
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
    final color = connected
        ? Colors.green
        : connecting
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: connecting ? null : onTap,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color, width: 3),
        ),
        child: Center(
          child: connecting
              ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3))
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
