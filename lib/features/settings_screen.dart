import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/app_version.dart';
import '../core/geo_store.dart';
import '../core/dns_plan.dart';
import '../core/on_demand.dart';
import '../core/rule_set.dart';
import '../core/ds.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/favorites_controller.dart';
import '../state/auto_connect_controller.dart';
import '../state/cloud_sync_controller.dart';
import '../state/excluded_apps_controller.dart';
import '../state/connection_check_controller.dart';
import '../state/on_demand_controller.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import '../core/platform_support.dart';
import 'about_screen.dart';
import 'advanced_connection_screen.dart';
import 'always_on_screen.dart';
import 'config/config_screen.dart';
import 'excluded_apps_screen.dart';
import 'geo_screen.dart';
import 'logs_screen.dart';
import 'on_demand_screen.dart';
import 'receive_screen.dart';
import 'rule_sets_screen.dart';
import 'send_screen.dart';

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
    ref.read(cloudSyncProvider.notifier).checkNow();
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
    await _load();
    if (mounted) {
      await ref.read(profilesControllerProvider.notifier).syncTunnelConfig();
    }
  }

  Future<void> _pickDefaultDns() async {
    const custom = '__custom__';
    final l10n = context.l10n;
    final current = ref.read(routingPrefsProvider).defaultDns;
    final picked = await pickOption<String>(
      context,
      title: l10n.settingsDefaultDns,
      radio: true,
      selected: kDnsPresets.any((p) => p.address == current) ? current : custom,
      options: [
        for (final p in kDnsPresets)
          Option(
            p.address,
            p.name,
            subtitle: p.note.isEmpty ? p.address : '${p.address} · ${p.note}',
          ),
        Option(
          custom,
          l10n.settingsDnsCustom,
          subtitle: l10n.settingsDnsCustomSubtitle,
        ),
      ],
    );
    if (picked == null || !mounted) return;

    var value = picked;
    if (picked == custom) {
      final typed = await promptText(
        context,
        title: l10n.settingsDefaultDns,
        label: l10n.settingsDnsResolverLabel,
        confirmLabel: l10n.commonSave,
        initial: current,
        hint: 'https://1.1.1.1/dns-query',
        autocorrect: false,
        resetLabel: l10n.settingsDnsUseCloudflare,
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

    await ref
        .read(routingPrefsProvider.notifier)
        .update((p) => p.copyWith(defaultDns: value));
  }

  Future<void> _pickTheme() async {
    final l10n = context.l10n;
    final picked = await pickOption<ThemeMode>(
      context,
      title: l10n.settingsAppearance,
      radio: true,
      selected: ref.read(appPrefsProvider).themeMode,
      options: [
        Option(
          ThemeMode.system,
          l10n.themeSystem,
          subtitle: l10n.settingsThemeSystemSubtitle,
        ),
        Option(ThemeMode.light, l10n.themeLight),
        Option(ThemeMode.dark, l10n.themeDark),
      ],
    );
    if (picked != null) {
      await ref.read(appPrefsProvider.notifier).setThemeMode(picked);
    }
  }

  Future<void> _pickLanguage() async {
    final picked = await pickOption<AppLanguage>(
      context,
      title: context.l10n.settingsLanguage,
      radio: true,
      selected: ref.read(appPrefsProvider).language,
      options: AppLanguage.values.map((l) => Option(l, l.label)).toList(),
    );
    if (picked != null) {
      await ref.read(appPrefsProvider.notifier).setLanguage(picked);
    }
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => context.l10n.themeSystem,
    ThemeMode.light => context.l10n.themeLight,
    ThemeMode.dark => context.l10n.themeDark,
  };

  Widget _configurationsRow(ProfilesState st) {
    if (st.profiles.length == 1) {
      final only = st.profiles.single;
      return DsRow(
        glyph: profileIcon(only.type),
        title: only.name,
        subtitle: profileKind(only),
        trailing: const [DsChevron()],
        onTap: () => _push(ConfigScreen(profileId: only.id)),
      );
    }
    return DsRow(
      glyph: Glyph.folder,
      title: context.l10n.settingsConfigurations,
      subtitle: context.l10n.settingsConfigurationsCount(st.profiles.length),
      trailing: const [DsChevron(down: true)],
      onTap: _openConfigurations,
    );
  }

  Future<void> _openConfigurations() async {
    final favorites = await ref.read(favoritesProvider.notifier).loaded();
    if (!mounted) return;
    final st = ref.read(profilesControllerProvider);
    final picked = await pickOption<String>(
      context,
      title: context.l10n.settingsConfigurations,
      selected: st.activeId,
      favorites: favorites.profiles,
      navigational: true,
      itemNoun: context.l10n.uiNounConfiguration,
      options: st.profiles
          .map(
            (p) => Option(
              p.id,
              p.name,
              subtitle: profileKind(p),
              leading: GlyphIcon(profileIcon(p.type)),
            ),
          )
          .toList(),
    );
    if (picked != null && mounted) await _push(ConfigScreen(profileId: picked));
  }

  Widget _cloudSyncRow(CloudSyncState cloud) {
    final l10n = context.l10n;
    final usable = cloud.available || cloud.enabled;
    void set(bool v) => ref.read(cloudSyncProvider.notifier).setEnabled(v);
    return DsRow(
      glyph: Glyph.cloud,
      title: l10n.settingsCloudSync,
      subtitle: cloudSyncStatus(l10n, cloud),
      enabled: usable,
      onTap: usable ? () => set(!cloud.enabled) : null,
      trailing: [
        DsToggle(value: cloud.enabled, onChanged: usable ? set : null),
      ],
    );
  }

  List<Widget> _connectionRows({
    required bool autoConnect,
    required OnDemandPrefs onDemand,
  }) {
    final l10n = context.l10n;
    return [
      if (hasAutoConnect)
        if (supportsBootAutoConnect)
          DsRow(
            glyph: Glyph.zap,
            title: l10n.settingsAutoConnect,
            subtitle: l10n.settingsAutoConnectSubtitle,
            onTap: () =>
                ref.read(autoConnectProvider.notifier).set(!autoConnect),
            trailing: [
              DsToggle(
                value: autoConnect,
                onChanged: (v) => ref.read(autoConnectProvider.notifier).set(v),
              ),
            ],
          )
        else if (supportsOnDemand) ...[
          DsRow(
            glyph: Glyph.zap,
            title: l10n.onDemandTitle,
            subtitle: onDemand.statusLabel,
            trailing: const [DsChevron()],
            onTap: () => _push(const OnDemandScreen()),
          ),
          DsRow(
            glyph: Glyph.moon,
            title: l10n.settingsDisconnectOnSleep,
            subtitle: l10n.settingsDisconnectOnSleepSubtitle,
            onTap: () => ref
                .read(onDemandProvider.notifier)
                .setDisconnectOnSleep(!onDemand.disconnectOnSleep),
            trailing: [
              DsToggle(
                value: onDemand.disconnectOnSleep,
                onChanged: (v) =>
                    ref.read(onDemandProvider.notifier).setDisconnectOnSleep(v),
              ),
            ],
          ),
        ] else
          DsRow(
            glyph: Glyph.zap,
            title: l10n.alwaysOnTitle,
            subtitle: l10n.settingsAlwaysOnSubtitle,
            trailing: const [DsChevron()],
            onTap: () => _push(const AlwaysOnScreen()),
          ),
    ];
  }

  Widget _advancedRow(bool checkEnabled, bool dnsProtection) {
    final l10n = context.l10n;
    return DsRow(
      glyph: Glyph.settings,
      title: l10n.settingsAdvanced,
      subtitle: hasDnsProtection
          ? [
              dnsProtection
                  ? l10n.settingsDnsProtectionOn
                  : l10n.settingsDnsProtectionOff,
              checkEnabled ? l10n.settingsCheckOn : l10n.settingsCheckOff,
            ].join(' · ')
          : checkEnabled
          ? l10n.settingsConnectionCheckOn
          : l10n.settingsConnectionCheckOff,
      trailing: const [DsChevron()],
      onTap: () => _push(const AdvancedConnectionScreen()),
    );
  }

  Future<void> _setLanDirect(bool v) async {
    await ref
        .read(routingPrefsProvider.notifier)
        .update((p) => p.copyWith(lanDirect: v));
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profilesControllerProvider);
    final appPrefs = ref.watch(appPrefsProvider);
    final prefs = ref.watch(routingPrefsProvider);
    final onDemand = ref.watch(onDemandProvider);
    final check = ref.watch(connectionCheckProvider).prefs;
    final autoConnect = ref.watch(autoConnectProvider);
    final cloud = ref.watch(cloudSyncProvider);
    final l10n = context.l10n;

    return DsPage(
      title: l10n.commonSettings,
      children: [
        if (st.profiles.isNotEmpty || !canScanQr)
          DsGroup(
            caption: l10n.settingsSectionConfigurations,
            children: [
              if (st.profiles.isNotEmpty) _configurationsRow(st),
              if (canScanQr && st.profiles.isNotEmpty)
                DsRow(
                  glyph: Glyph.send,
                  title: l10n.transferSend,
                  subtitle: l10n.transferSendSubtitle,
                  trailing: const [DsChevron()],
                  onTap: () => sendToAnotherDevice(context),
                ),
              if (!canScanQr)
                DsRow(
                  glyph: Glyph.smartphone,
                  title: l10n.transferReceive,
                  subtitle: l10n.transferReceiveSubtitle,
                  trailing: const [DsChevron()],
                  onTap: () => _push(const ReceiveScreen()),
                ),
            ],
          ),
        DsGroup(
          caption: l10n.settingsSectionConnection,
          child: DsStack(
            gap: 8,
            children: [
              if (hasAutoConnect)
                DsCard(
                  children: _connectionRows(
                    autoConnect: autoConnect,
                    onDemand: onDemand,
                  ),
                ),
              DsCard(
                children: [_advancedRow(check.enabled, prefs.dnsProtection)],
              ),
            ],
          ),
        ),
        DsGroup(
          caption: l10n.settingsSectionRouting,
          children: [
            DsRow(
              glyph: Glyph.wifi,
              title: l10n.settingsLanDirect,
              subtitle: l10n.settingsLanDirectSubtitle,
              onTap: () => _setLanDirect(!prefs.lanDirect),
              trailing: [
                DsToggle(value: prefs.lanDirect, onChanged: _setLanDirect),
              ],
            ),
            if (supportsExcludedApps)
              DsRow(
                glyph: Glyph.smartphone,
                title: l10n.settingsExcludedApps,
                subtitle: l10n.settingsExcludedAppsCount(
                  ref.watch(excludedAppsProvider).packages.length,
                ),
                trailing: const [DsChevron()],
                onTap: () => _push(const ExcludedAppsScreen()),
              ),
            DsRow(
              glyph: Glyph.layers,
              title: l10n.ruleSetsTitle,
              subtitle: l10n.settingsRuleSetCount(_setCount),
              trailing: const [DsChevron()],
              onTap: () => _push(const RuleSetsScreen()),
            ),
            DsRow(
              glyph: Glyph.globe,
              title: l10n.settingsDefaultDns,
              subtitle: l10n.settingsDefaultDnsSubtitle(
                dnsPresetName(prefs.defaultDns),
              ),
              trailing: const [DsChevron(down: true)],
              onTap: _pickDefaultDns,
            ),
            DsRow(
              glyph: Glyph.globe,
              title: l10n.geoTitle,
              subtitle: _geo.downloaded
                  ? l10n.settingsGeoDownloaded(
                      formatBytes(_geo.geoipBytes + _geo.geositeBytes),
                    )
                  : l10n.geoNotDownloaded,
              trailing: const [DsChevron()],
              onTap: () => _push(const GeoScreen()),
            ),
          ],
        ),
        DsGroup(
          caption: l10n.settingsSectionGeneral,
          children: [
            DsRow(
              glyph: Glyph.sunMoon,
              title: l10n.settingsAppearance,
              subtitle: _themeLabel(appPrefs.themeMode),
              trailing: const [DsChevron(down: true)],
              onTap: _pickTheme,
            ),
            DsRow(
              glyph: Glyph.languages,
              title: l10n.settingsLanguage,
              subtitle: appPrefs.language.label,
              trailing: const [DsChevron(down: true)],
              onTap: _pickLanguage,
            ),
            if (cloud.supported) _cloudSyncRow(cloud),
          ],
        ),
        DsGroup(
          caption: l10n.settingsSectionDiagnostics,
          children: [
            DsRow(
              glyph: Glyph.fileText,
              title: l10n.logsTitle,
              trailing: const [DsChevron()],
              onTap: () => _push(const LogsScreen()),
            ),
          ],
        ),
        DsGroup(
          caption: l10n.settingsSectionAbout,
          children: [
            DsRow(
              glyph: Glyph.shield,
              title: l10n.aboutTitle,
              subtitle: '$kAppName $appVersionLabel',
              trailing: const [DsChevron()],
              onTap: () => _push(const AboutScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

String cloudSyncStatus(AppLocalizations l10n, CloudSyncState cloud) {
  final at = cloud.lastSyncedAt;
  if (!cloud.available) return l10n.settingsCloudSyncUnavailable;
  if (!cloud.enabled) return l10n.commonOff;
  if (cloud.waitingForKey) return l10n.settingsCloudSyncWaitingForKey;
  if (cloud.syncing || (at == null && !cloud.failed)) {
    return l10n.settingsCloudSyncing;
  }
  if (cloud.failed) {
    return at == null
        ? l10n.settingsCloudSyncFailedNever
        : l10n.settingsCloudSyncFailed(agoLabel(l10n, at));
  }
  return l10n.settingsCloudSynced(agoLabel(l10n, at!));
}
