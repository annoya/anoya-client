import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/norm_config.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../state/config_controller.dart';
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

  Future<void> _toggleConnect() async {
    final controller = ref.read(configControllerProvider.notifier);
    if (_busy) {
      await controller.disconnect();
    } else {
      await controller.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfgState = ref.watch(configControllerProvider);
    final config = cfgState.config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsScreen(
                account: config?.account,
                managedRouting: config?.routing,
              ),
            )),
          ),
        ],
      ),
      body: PageBody(
        child: RefreshIndicator(
          onRefresh: () async {
            try {
              await ref.read(configControllerProvider.notifier).refresh();
            } catch (_) {/* surfaced via state.error */}
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            children: [
              const SizedBox(height: 24),
              Center(child: _statusLabel()),
              const SizedBox(height: 28),
              Center(child: _ConnectButton(status: _status, onTap: _toggleConnect)),
              const SizedBox(height: 40),
              _locationRow(cfgState),
              if (config?.account != null) ...[
                const SizedBox(height: 12),
                _accountRow(config!.account),
              ],
              if (cfgState.error != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Text(cfgState.error!, textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ],
          ),
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
    return Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600));
  }

  Widget _locationRow(ConfigState cfgState) {
    final loc = cfgState.selectedLocation;
    final empty = cfgState.config?.locations.isEmpty ?? true;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.public),
        title: Text(loc?.label ?? (cfgState.loading ? 'Loading…' : 'No locations')),
        subtitle: loc != null ? Text('${loc.proxyType} · ${loc.proxy['server']}') : null,
        trailing: _busy ? const Icon(Icons.lock_outline, size: 18) : const Icon(Icons.chevron_right),
        onTap: (_busy || empty) ? null : () => _pickLocation(cfgState),
      ),
    );
  }

  Widget _accountRow(Account account) {
    final color = switch (account.status) {
      'active' => Colors.green,
      'expired' => Colors.orange,
      _ => Colors.grey,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              account.expiresAt != null
                  ? '${account.status} · until ${account.expiresAt!.toLocal().toString().split('.').first}'
                  : account.status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLocation(ConfigState cfgState) async {
    final locs = cfgState.config?.locations ?? [];
    final selectedId = cfgState.selectedLocation?.id;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Location', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...locs.map((l) => ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(l.label),
                  subtitle: Text('${l.proxyType} · ${l.proxy['server']}'),
                  trailing: l.id == selectedId ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () => Navigator.of(context).pop(l.id),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) ref.read(configControllerProvider.notifier).select(picked);
  }
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
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.power_settings_new, size: 56, color: color),
                    const SizedBox(height: 8),
                    Text(connected ? 'Disconnect' : 'Connect', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      ),
    );
  }
}
