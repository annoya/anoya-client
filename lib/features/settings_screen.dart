import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/geo_store.dart';
import '../core/norm_config.dart';
import '../core/routing_prefs.dart';
import '../core/rule_set.dart';
import '../core/ui.dart';
import '../state/on_demand_controller.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import 'config_screen.dart';
import 'geo_screen.dart';
import 'logs_screen.dart';
import 'on_demand_screen.dart';
import 'rule_sets_screen.dart';

/// App settings. Top: the active configuration (tap → pick the active one; a
/// gear per row opens that configuration's own settings). Then the global
/// ROUTING section (LAN switch, rule sets, geo databases) and diagnostics.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  RoutingPrefs _prefs = const RoutingPrefs();
  int _setCount = 1;
  GeoStatus _geo = const GeoStatus();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await RoutingPrefsStore.load();
    final sets = await RuleSetStore.load();
    final geo = await GeoStore.status();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _setCount = sets.length;
      _geo = geo;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _load(); // pushed screens may change prefs/sets/geo
    // Rule sets and geo databases both change what the tunnel would run, and
    // those screens don't know about profiles — resync here on the way back.
    if (mounted) await ref.read(profilesControllerProvider.notifier).syncTunnelConfig();
  }

  Future<void> _pickTheme() async {
    final picked = await pickOption<ThemeMode>(
      context,
      title: 'Appearance',
      selected: ref.read(appPrefsProvider).themeMode,
      options: const [
        Option(ThemeMode.system, 'System', subtitle: 'Follow the device setting'),
        Option(ThemeMode.light, 'Light'),
        Option(ThemeMode.dark, 'Dark'),
      ],
    );
    if (picked != null) await ref.read(appPrefsProvider.notifier).setThemeMode(picked);
  }

  Future<void> _pickLanguage() async {
    final picked = await pickOption<AppLanguage>(
      context,
      title: 'Language',
      selected: ref.read(appPrefsProvider).language,
      options: AppLanguage.values.map((l) => Option(l, l.label)).toList(),
    );
    if (picked != null) await ref.read(appPrefsProvider.notifier).setLanguage(picked);
  }

  Future<void> _pickActive() async {
    final st = ref.read(profilesControllerProvider);
    final ctrl = ref.read(profilesControllerProvider.notifier);
    // Not pickOption: each row carries a second action (the gear opens that
    // configuration's own settings, active or not).
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Text('Active configuration', style: Theme.of(context).textTheme.titleMedium)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: st.profiles
                  .map((p) => ListTile(
                        leading: p.id == st.activeId
                            ? Icon(Icons.radio_button_checked,
                                color: Theme.of(context).colorScheme.primary)
                            : const Icon(Icons.radio_button_off),
                        title: Text(p.name),
                        subtitle: Text(profileKind(p)),
                        trailing: IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          tooltip: 'Configuration settings',
                          onPressed: () => Navigator.of(context).pop('cfg:${p.id}'),
                        ),
                        onTap: () => Navigator.of(context).pop(p.id),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    if (picked.startsWith('cfg:')) {
      await _push(ConfigScreen(profileId: picked.substring(4)));
    } else {
      ctrl.setActive(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profilesControllerProvider);
    final appPrefs = ref.watch(appPrefsProvider);
    final onDemand = ref.watch(onDemandProvider);
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
                  leading: Icon(profileIcon(p.type)),
                  title: Text(p.name),
                  subtitle: Text(p.serverUrl ?? p.subscriptionUrl ?? profileKind(p)),
                  trailing: st.profiles.length > 1
                      ? const Icon(Icons.expand_more)
                      : const Icon(Icons.chevron_right),
                  onTap: st.profiles.length > 1
                      ? _pickActive
                      : () => _push(ConfigScreen(profileId: p.id)),
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
                        Text(
                            'Traffic: ${_bytes(p.account!.usedBytes)} of ${_bytes(p.account!.dataLimit)}',
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
            ],

            const SectionHeader('CONNECTION'),
            Card(
              margin: kCardMargin,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: const Text('On demand'),
                  subtitle: Text(onDemand.statusLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(const OnDemandScreen()),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.bedtime_outlined),
                  title: const Text('Disconnect on sleep'),
                  subtitle: const Text('Drop the tunnel when the device sleeps'),
                  value: onDemand.disconnectOnSleep,
                  onChanged: (v) =>
                      ref.read(onDemandProvider.notifier).setDisconnectOnSleep(v),
                ),
              ]),
            ),

            const SectionHeader('ROUTING'),
            Card(
              margin: kCardMargin,
              child: Column(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.wifi),
                  title: const Text('Local network direct'),
                  subtitle: const Text('LAN traffic bypasses the VPN'),
                  value: _prefs.lanDirect,
                  onChanged: (v) async {
                    final updated = _prefs.copyWith(lanDirect: v);
                    await RoutingPrefsStore.save(updated);
                    setState(() => _prefs = updated);
                    // Changes the rendered rules, so the system's saved config
                    // must follow.
                    await ref.read(profilesControllerProvider.notifier).syncTunnelConfig();
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Rule sets'),
                  subtitle: Text('$_setCount set${_setCount > 1 ? 's' : ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(const RuleSetsScreen()),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('GeoIP & GeoSite'),
                  subtitle: Text(_geo.downloaded
                      ? 'downloaded · ${_bytes(_geo.geoipBytes + _geo.geositeBytes)}'
                      : 'not downloaded'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(const GeoScreen()),
                ),
              ]),
            ),

            const SectionHeader('GENERAL'),
            Card(
              margin: kCardMargin,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Appearance'),
                  subtitle: Text(appPrefs.themeLabel),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _pickTheme,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('Language'),
                  subtitle: Text(appPrefs.language.label),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _pickLanguage,
                ),
              ]),
            ),

            const SectionHeader('DIAGNOSTICS'),
            Card(
              margin: kCardMargin,
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Logs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const LogsScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
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
