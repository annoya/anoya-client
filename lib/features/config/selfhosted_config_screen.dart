import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/norm_config.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import 'config_parts.dart';

/// Settings of a self-hosted configuration.
///
/// The only domain with an account behind it (ADR-005): a management service
/// owns identity, access and policy, so this is the one screen that can show a
/// status, a quota and a routing policy the device does not control.
class SelfhostedConfigScreen extends ConsumerStatefulWidget {
  const SelfhostedConfigScreen({super.key, required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  ConsumerState<SelfhostedConfigScreen> createState() => _SelfhostedConfigScreenState();
}

class _SelfhostedConfigScreenState extends ConsumerState<SelfhostedConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final account = p.account;
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: PageBody(
        child: ListView(children: [
          const SizedBox(height: 8),
          ProfileHeaderCard(profile: p, isActive: widget.isActive),
          if (p.serverUrl != null) SourceCard(value: p.serverUrl!),
          RefreshCard(profile: p),
          RoutingRow(profile: p),
          if (account != null) ...[
            Card(
              margin: kCardMargin,
              child: ListTile(
                title: const Text('Account'),
                subtitle: Text(_accountSummary(account)),
              ),
            ),
            if (account.dataLimit > 0) _TrafficCard(account: account),
          ],
          ConfigActions(profile: p, isActive: widget.isActive),
        ]),
      ),
    );
  }

  String _accountSummary(Account a) {
    final status = a.status.replaceAll('_', ' ');
    if (a.status == 'on_hold') return 'Status: $status · starts on first use';
    if (a.expiresAt != null) {
      return 'Status: $status · expires ${a.expiresAt!.toLocal().toString().split('.').first}';
    }
    return 'Status: $status';
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) => Card(
        margin: kCardMargin,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'Traffic: ${formatBytes(account.usedBytes)} of ${formatBytes(account.dataLimit)}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (account.usedBytes / account.dataLimit).clamp(0.0, 1.0),
                minHeight: 6,
              ),
            ),
          ]),
        ),
      );
}

