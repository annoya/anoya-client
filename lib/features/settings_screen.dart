import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/norm_config.dart';
import '../core/ui.dart';
import '../state/providers.dart';
import 'logs_screen.dart';
import 'routing_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.account, this.managedRouting});

  /// Optional account snapshot from the home screen, for display.
  final Account? account;

  /// The server-managed routing policy from the last config fetch (null when
  /// the server sets none and local rules apply).
  final Routing? managedRouting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider);
    final core = ref.read(vpnCoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        child: ListView(
        children: [
          const SectionHeader('ACCOUNT'),
          if (account != null)
            Card(
              margin: kCardMargin,
              child: ListTile(
                title: Text(account!.displayName.isEmpty ? 'Account' : account!.displayName),
                subtitle: Text(_accountSummary(account!)),
              ),
            ),
          if (account != null && account!.dataLimit > 0)
            Card(
              margin: kCardMargin,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Traffic: ${_bytes(account!.usedBytes)} of ${_bytes(account!.dataLimit)}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (account!.usedBytes / account!.dataLimit).clamp(0.0, 1.0),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          FutureBuilder<String?>(
            future: session.serverUrl(),
            builder: (context, snap) => Card(
              margin: kCardMargin,
              child: ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Server'),
                subtitle: Text(snap.data ?? '—'),
              ),
            ),
          ),

          const SectionHeader('VPN'),
          Card(
            margin: kCardMargin,
            child: ListTile(
              leading: const Icon(Icons.alt_route_outlined),
              title: const Text('Split tunneling'),
              subtitle: Text(managedRouting != null
                  ? 'Managed by your organization (${managedRouting!.mode}, ${managedRouting!.rules.length} rules)'
                  : 'Configure which traffic uses the VPN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RoutingScreen(managed: managedRouting)),
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

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () {
                ref.read(authControllerProvider.notifier).logout(core);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

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

