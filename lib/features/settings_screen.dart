import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/app_version.dart';
import '../core/geo_store.dart';
import '../core/dns_plan.dart';
import '../core/rule_set.dart';
import '../core/ui.dart';
import '../state/favorites_controller.dart';
import '../state/auto_connect_controller.dart';
import '../state/connection_check_controller.dart';
import '../state/on_demand_controller.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import '../core/platform_support.dart';
import 'about_screen.dart';
import 'advanced_connection_screen.dart';
import 'always_on_screen.dart';
import 'config/config_screen.dart';
import 'geo_screen.dart';
import 'logs_screen.dart';
import 'on_demand_screen.dart';
import 'rule_sets_screen.dart';

/// App settings. Top: every configuration, each row a way into its own
/// settings — which one is active is decided on the home screen, not here.
/// Then the global CONNECTION, ROUTING, GENERAL and DIAGNOSTICS sections.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _setCount = 1;
  GeoStatus _geo = const GeoStatus();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await RuleSetStore.load();
    final geo = await GeoStore.status();
    if (!mounted) return;
    setState(() {
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

  /// The one resolver the user owns: it applies only where nobody else chose.
  ///
  /// Presets rather than a bare field — a typo here breaks every name lookup on
  /// the device, and four addresses cover almost everyone. "Custom" is the door
  /// for a private resolver, held to the same standard the renderer holds a
  /// subscription's to, plus one the renderer cannot check: a default named by
  /// domain would need resolving before it could resolve.
  Future<void> _pickDefaultDns() async {
    const custom = '__custom__';
    final current = ref.read(routingPrefsProvider).defaultDns;
    final picked = await pickOption<String>(
      context,
      title: 'Default DNS',
      selected: kDnsPresets.any((p) => p.address == current) ? current : custom,
      options: [
        for (final p in kDnsPresets)
          Option(p.address, p.name,
              subtitle: p.note.isEmpty ? p.address : '${p.address} · ${p.note}'),
        const Option(custom, 'Custom…', subtitle: 'any address the engine accepts'),
      ],
    );
    if (picked == null || !mounted) return;

    var value = picked;
    if (picked == custom) {
      final typed = await promptText(
        context,
        title: 'Default DNS',
        label: 'Resolver',
        confirmLabel: 'Save',
        initial: current,
        hint: 'https://1.1.1.1/dns-query',
        autocorrect: false,
        resetLabel: 'Use Cloudflare',
        resetValue: kFallbackNameserver,
      );
      if (typed == null || !mounted) return;
      final error = dnsDefaultError(typed.trim());
      if (error != null) {
        showToast(context, error);
        return;
      }
      value = typed.trim();
    }

    await ref.read(routingPrefsProvider.notifier).update((p) => p.copyWith(defaultDns: value));
    if (!mounted) return;
    // Only some configurations are affected, but the engine holds one config at
    // a time and the cheapest correct thing is to re-render the live one.
    await ref.read(profilesControllerProvider.notifier).syncTunnelConfig();
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

  /// The way into a configuration's own settings. A single configuration is
  /// named right here; several open as a sheet, so a long list never turns the
  /// settings screen into an endless scroll.
  Widget _configurationsRow(ProfilesState st) {
    if (st.profiles.length == 1) {
      final only = st.profiles.single;
      return ListTile(
        leading: Icon(profileIcon(only.type)),
        title: Text(only.name),
        subtitle: Text(profileKind(only)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _push(ConfigScreen(profileId: only.id)),
      );
    }
    return ListTile(
      leading: const Icon(Icons.folder_copy_outlined),
      title: const Text('Configurations'),
      subtitle: Text('${st.profiles.length} configurations'),
      trailing: const Icon(Icons.expand_more),
      onTap: _openConfigurations,
    );
  }

  Future<void> _openConfigurations() async {
    final st = ref.read(profilesControllerProvider);
    final favorites = ref.read(favoritesProvider);
    // The same sheet as the home-screen picker, in its navigational mode: the
    // returned value is "open this configuration", not "make it active" —
    // that choice belongs to the home screen. Passing the favourites still
    // buys the shared order (favourites first) without the stars, which are
    // edited where they are used.
    final picked = await pickOption<String>(
      context,
      title: 'Configurations',
      selected: st.activeId,
      favorites: favorites.profiles,
      navigational: true,
      itemNoun: 'configuration',
      options: st.profiles
          .map((p) => Option(
                p.id,
                p.name,
                subtitle: profileKind(p),
                leading: Icon(profileIcon(p.type)),
              ))
          .toList(),
    );
    if (picked != null && mounted) await _push(ConfigScreen(profileId: picked));
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profilesControllerProvider);
    final appPrefs = ref.watch(appPrefsProvider);
    final prefs = ref.watch(routingPrefsProvider);
    final onDemand = ref.watch(onDemandProvider);
    final check = ref.watch(connectionCheckProvider).prefs;
    final autoConnect = ref.watch(autoConnectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        child: ListView(
          children: [
            if (st.profiles.isNotEmpty) ...[
              const SectionHeader('CONFIGURATIONS'),
              Card(margin: kCardMargin, child: _configurationsRow(st)),
            ],

            // Auto-connect differs by platform in kind, not in detail: Apple
            // evaluates our on-demand rules, Android has the system's own
            // Always-on switch we can only point at, Windows has nothing of
            // the sort and shows no card. Disconnect-on-sleep is a flag of
            // Apple's VPN protocol and has no counterpart elsewhere.
            const SectionHeader('CONNECTION'),
            if (hasAutoConnect)
            Card(
              margin: kCardMargin,
              child: supportsBootAutoConnect
                  // Windows: our own service starts with the machine, so the
                  // facility is ours to offer — and one condition ("when
                  // Windows starts") is a switch, not a screen.
                  ? SwitchListTile(
                      secondary: const Icon(Icons.bolt_outlined),
                      title: const Text('Auto-connect'),
                      subtitle: const Text('Connect when Windows starts'),
                      value: autoConnect,
                      onChanged: (v) => ref.read(autoConnectProvider.notifier).set(v),
                    )
                  : supportsOnDemand
                  ? Column(children: [
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
                    ])
                  : ListTile(
                      leading: const Icon(Icons.bolt_outlined),
                      title: const Text('Always-on VPN'),
                      subtitle: const Text('A system switch — set in Android settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(const AlwaysOnScreen()),
                    ),
            ),
            Card(
              margin: kCardMargin,
              child: ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Advanced'),
                // The state of what is behind it, not a description of the
                // screen: a row that says only "Advanced" has to be opened to
                // learn whether the thing it holds is on.
                subtitle: Text('Connection check · ${check.enabled ? 'on' : 'off'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const AdvancedConnectionScreen()),
              ),
            ),

            const SectionHeader('ROUTING'),
            Card(
              margin: kCardMargin,
              child: Column(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.wifi),
                  title: const Text('Local network direct'),
                  subtitle: const Text('LAN traffic bypasses the VPN'),
                  value: prefs.lanDirect,
                  onChanged: (v) async {
                    await ref
                        .read(routingPrefsProvider.notifier)
                        .update((p) => p.copyWith(lanDirect: v));
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
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Default DNS'),
                  // Says when it applies, because most configurations bring
                  // their own and this setting then does nothing at all.
                  subtitle: Text('${dnsPresetName(prefs.defaultDns)} · '
                      'used when a configuration brings none'),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _pickDefaultDns,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('GeoIP & GeoSite'),
                  subtitle: Text(_geo.downloaded
                      ? 'downloaded · ${formatBytes(_geo.geoipBytes + _geo.geositeBytes)}'
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
            const SectionHeader('ABOUT'),
            Card(
              margin: kCardMargin,
              child: ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('About'),
                // The version in the subtitle is what most visits come for, so
                // it is readable without opening anything — and it marks the
                // row as a reference rather than a setting.
                subtitle: Text('$kAppName $appVersionLabel'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const AboutScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
