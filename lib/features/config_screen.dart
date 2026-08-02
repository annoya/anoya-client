import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log.dart';
import '../core/norm_config.dart';
import '../core/profile.dart';
import '../core/rule_set.dart';
import '../core/ui.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import 'routing_screen.dart';

/// Settings of one configuration (any, not just the active one): source,
/// refresh, applied rule set (or the managed-policy banner), account for
/// self-hosted, set-active and remove.
class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  bool _refreshing = false;
  List<RuleSet> _sets = [];

  @override
  void initState() {
    super.initState();
    RuleSetStore.load().then((s) {
      if (mounted) setState(() => _sets = s);
    });
  }

  ProfilesController get _ctrl => ref.read(profilesControllerProvider.notifier);

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await _ctrl.refreshProfile(widget.profileId);
    } catch (e) {
      Log.e('manual refresh failed', '$e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pickRuleSet(Profile p) async {
    final picked = await pickOption<String>(
      context,
      title: 'Rule set',
      selected: p.ruleSetId ?? RuleSet.defaultId,
      options: _sets
          .map((s) => Option(
                s.id,
                s.name,
                subtitle:
                    '${s.mode == 'split' ? 'Split' : 'Full tunnel'} · ${s.rules.isEmpty ? 'no rules' : '${s.rules.length} rules'}',
                leading: const Icon(Icons.layers_outlined),
              ))
          .toList(),
    );
    if (picked != null) await _ctrl.setRuleSet(widget.profileId, picked);
  }

  Future<void> _remove(Profile p) async {
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
    final st = ref.read(profilesControllerProvider);
    if (st.activeId == p.id) {
      try {
        await ref.read(vpnCoreProvider).disconnect();
      } catch (_) {/* ignore */}
    }
    await _ctrl.removeProfile(p.id);
    if (!mounted) return;
    // Only close ourselves while other configurations remain. When that was the
    // last one, the app shell unwinds to the add screen on its own — popping
    // here as well would race it and take the root route down too (leaving an
    // empty navigator, i.e. a black screen).
    if (ref.read(profilesControllerProvider).hasProfiles) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profilesControllerProvider);
    Profile? p;
    for (final x in st.profiles) {
      if (x.id == widget.profileId) p = x;
    }
    if (p == null) {
      // Removed while open — nothing to show.
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final profile = p;
    final isActive = st.activeId == profile.id;
    final ruleSet = _sets.where((s) => s.id == (profile.ruleSetId ?? RuleSet.defaultId)).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: PageBody(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Card(
              margin: kCardMargin,
              child: ListTile(
                leading: Icon(profileIcon(profile.type)),
                title: Text(profile.name),
                subtitle: Text(profileKind(profile)),
                trailing: isActive
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary, size: 20)
                    : null,
              ),
            ),
            if (profile.serverUrl != null || profile.subscriptionUrl != null)
              Card(
                margin: kCardMargin,
                child: ListTile(
                  title: const Text('Source'),
                  subtitle: Text(profile.serverUrl ?? profile.subscriptionUrl!),
                ),
              ),
            if (profile.isRefreshable)
              Card(
                margin: kCardMargin,
                child: ListTile(
                  title: const Text('Last refreshed'),
                  subtitle: Text(_refreshedAt(profile)),
                  trailing: _refreshing
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh now',
                          onPressed: _refresh,
                        ),
                ),
              ),

            // Account (self-hosted only).
            if (profile.hasAccount && profile.account != null) ...[
              Card(
                margin: kCardMargin,
                child: ListTile(
                  title: const Text('Account'),
                  subtitle: Text(_accountSummary(profile.account!)),
                ),
              ),
              if (profile.account!.dataLimit > 0)
                Card(
                  margin: kCardMargin,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                          'Traffic: ${_bytes(profile.account!.usedBytes)} of ${_bytes(profile.account!.dataLimit)}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (profile.account!.usedBytes / profile.account!.dataLimit)
                              .clamp(0.0, 1.0),
                          minHeight: 6,
                        ),
                      ),
                    ]),
                  ),
                ),
            ],

            const SectionHeader('ROUTING'),
            if (profile.routing != null)
              Card(
                margin: kCardMargin,
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Managed by your organization'),
                  subtitle: Text(
                      '${profile.routing!.mode == 'split' ? 'Split' : 'Full tunnel'} · ${profile.routing!.rules.length} rules, set on the server'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RoutingScreen.managed(profile.routing!))),
                ),
              )
            else
              Card(
                margin: kCardMargin,
                child: ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Rule set'),
                  subtitle: Text(ruleSet?.name ?? 'Default'),
                  trailing: const Icon(Icons.expand_more),
                  onTap: () => _pickRuleSet(profile),
                ),
              ),

            const SizedBox(height: 20),
            if (!isActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Set active'),
                  // Stays open: the check mark moves to the header card and the
                  // button disappears, so the result is visible in place.
                  onPressed: () => _ctrl.setActive(profile.id),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove configuration'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => _remove(profile),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _refreshedAt(Profile p) {
    final at = p.refreshedAt;
    if (at == null) return 'never';
    final d = DateTime.now().difference(at);
    final ago = d.inDays > 0
        ? '${d.inDays} day${d.inDays > 1 ? 's' : ''} ago'
        : d.inHours > 0
            ? '${d.inHours} hour${d.inHours > 1 ? 's' : ''} ago'
            : d.inMinutes > 0
                ? '${d.inMinutes} min ago'
                : 'just now';
    return '$ago · auto every 5 min';
  }

  String _accountSummary(Account a) {
    final status = a.status.replaceAll('_', ' ');
    if (a.status == 'on_hold') return 'Status: $status · starts on first use';
    if (a.expiresAt != null) {
      return 'Status: $status · expires ${a.expiresAt!.toLocal().toString().split('.').first}';
    }
    return 'Status: $status';
  }

  String _bytes(int n) {
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (n >= gb) return '${(n / gb).toStringAsFixed(2)} GB';
    if (n >= mb) return '${(n / mb).toStringAsFixed(1)} MB';
    return '${(n / 1024).toStringAsFixed(0)} KB';
  }
}

IconData profileIcon(ProfileType t) => switch (t) {
      ProfileType.selfhosted => Icons.business_outlined,
      ProfileType.subscription => Icons.folder_outlined,
      ProfileType.link => Icons.link,
    };

String profileKind(Profile p) => switch (p.type) {
      ProfileType.selfhosted => 'Self-hosted · ${p.locations.length} servers',
      ProfileType.subscription => 'Subscription · ${p.locations.length} servers',
      ProfileType.link => 'Single server',
    };
