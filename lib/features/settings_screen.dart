import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/norm_config.dart';
import '../core/profile.dart';
import '../core/ui.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import 'logs_screen.dart';
import 'routing_screen.dart';
import 'start_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(profilesControllerProvider);
    final ctrl = ref.read(profilesControllerProvider.notifier);
    final core = ref.read(vpnCoreProvider);
    final p = st.active;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        child: ListView(
          children: [
            if (p != null) ...[
              const SectionHeader('CONFIGURATION'),
              Card(
                margin: kCardMargin,
                child: ListTile(
                  leading: Icon(_icon(p.type)),
                  title: Text(p.name),
                  subtitle: Text(_source(p)),
                ),
              ),

              // Account (self-hosted only).
              if (p.hasAccount && p.account != null) ...[
                Card(
                  margin: kCardMargin,
                  child: ListTile(
                    title: const Text('Account'),
                    subtitle: Text(_accountSummary(p.account!)),
                  ),
                ),
                if (p.account!.dataLimit > 0)
                  Card(
                    margin: kCardMargin,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Traffic: ${_bytes(p.account!.usedBytes)} of ${_bytes(p.account!.dataLimit)}',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (p.account!.usedBytes / p.account!.dataLimit).clamp(0.0, 1.0),
                            minHeight: 6,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],

              const SectionHeader('VPN'),
              Card(
                margin: kCardMargin,
                child: ListTile(
                  leading: const Icon(Icons.alt_route_outlined),
                  title: const Text('Split tunneling'),
                  subtitle: Text(p.routing != null
                      ? 'Managed by your organization (${p.routing!.mode}, ${p.routing!.rules.length} rules)'
                      : 'Configure which traffic uses the VPN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RoutingScreen(managed: p.routing)),
                  ),
                ),
              ),
            ],

            const SectionHeader('CONFIGURATIONS'),
            Card(
              margin: kCardMargin,
              child: ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add configuration'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StartScreen()),
                ),
              ),
            ),

            const SectionHeader('DIAGNOSTICS'),
            Card(
              margin: kCardMargin,
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Logs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LogsScreen()),
                ),
              ),
            ),
            FutureBuilder<String?>(
              future: core.engineVersion(),
              builder: (context, snap) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text('Engine: ${snap.data ?? '…'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ),
            ),

            if (p != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text('Remove "${p.name}"'),
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Remove ${p.name}?'),
                        content: const Text('This configuration will be removed from this device.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    try {
                      await core.disconnect();
                    } catch (_) {/* ignore */}
                    await ctrl.removeProfile(p.id);
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

IconData _icon(ProfileType t) => switch (t) {
      ProfileType.selfhosted => Icons.dns_outlined,
      ProfileType.subscription => Icons.rss_feed,
      ProfileType.link => Icons.link,
    };

String _source(Profile p) => switch (p.type) {
      ProfileType.selfhosted => p.serverUrl ?? 'Self-hosted',
      ProfileType.subscription =>
        p.subscriptionUrl ?? 'Subscription · ${p.locations.length} servers',
      ProfileType.link => 'Single server${p.locations.isNotEmpty ? ' · ${p.locations.first.proxyType}' : ''}',
    };

String _accountSummary(Account a) {
  final status = a.status.replaceAll('_', ' ');
  if (a.status == 'on_hold') return 'Status: $status · starts on first use';
  if (a.expiresAt != null) return 'Status: $status · expires ${a.expiresAt!.toLocal().toString().split('.').first}';
  return 'Status: $status';
}

String _bytes(int n) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (n >= gb) return '${(n / gb).toStringAsFixed(2)} GB';
  if (n >= mb) return '${(n / mb).toStringAsFixed(1)} MB';
  return '${(n / 1024).toStringAsFixed(0)} KB';
}
