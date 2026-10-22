import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/ds.dart';
import '../core/on_demand.dart';
import '../core/platform_support.dart';
import '../core/profile.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/vpn_core.dart';
import '../l10n/l10n.dart';
import '../state/connection_check_controller.dart';
import '../state/favorites_controller.dart';
import '../state/group_member.dart';
import '../state/on_demand_controller.dart';
import '../state/profiles_controller.dart';
import '../state/providers.dart';
import '../state/routing_status.dart';
import '../state/session.dart';
import 'config/config_screen.dart';
import 'config/routing_config_screen.dart';
import 'home_widgets.dart';
import 'logs_screen.dart';
import 'on_demand_screen.dart';
import 'refresh_button.dart';
import 'rule_sets_screen.dart';
import 'settings_screen.dart';
import 'start_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  VpnStatus get _status => ref.watch(sessionProvider.select((s) => s.status));

  bool get _locked =>
      _status == VpnStatus.connecting ||
      ref.watch(profilesControllerProvider.select((s) => s.switching));

  Future<void> _toggle() async {
    final ctrl = ref.read(profilesControllerProvider.notifier);
    if (ref.read(sessionProvider).busy) {
      await ctrl.disconnect();
    } else {
      await ctrl.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = ref.watch(
      profilesControllerProvider.select((s) => s.active),
    );

    ref.listen(profilesControllerProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        showErrorDialog(
          context,
          error,
          onDismiss: ref.read(profilesControllerProvider.notifier).clearError,
        );
      }
    });

    ref.listen(profilesControllerProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showToast(context, notice.line);
      ref.read(profilesControllerProvider.notifier).clearNotice();
    });

    final busy = ref.watch(sessionProvider.select((s) => s.busy));
    return Scaffold(
      appBar: DsNavBar(
        lead: DsNavButton(
          glyph: Glyph.plus,
          tooltip: l10n.homeAddConfiguration,
          onPressed: () => _push(const StartScreen()),
        ),
        actions: [
          DsNavButton(
            glyph: Glyph.settings,
            tooltip: l10n.commonSettings,
            onPressed: () => _push(const SettingsScreen()),
          ),
        ],
      ),
      body: PageBody(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    _statusStrip(active),
                    Expanded(
                      child: Center(
                        child: HomeHero(
                          status: _status,
                          onTap: active == null && !busy ? null : _toggle,
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          kGutter,
                          8,
                          kGutter,
                          0,
                        ),
                        child: DsStack(
                          gap: 8,
                          children: [
                            ?_checkBanner(),
                            ?_onDemandBanner(),
                            ?_expiryCard(active),
                            if (active != null)
                              _profileRow(active)
                            else
                              _addRow(),
                            if (active != null) _locationRow(active),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Widget _statusStrip(Profile? active) {
    final l10n = context.l10n;
    final onDemand = ref.watch(onDemandProvider);
    final collectLogs = ref.watch(
      appPrefsProvider.select((p) => p.collectLogs),
    );
    final routing = ref.watch(routingStatusProvider).value;

    final (autoLabel, autoOn) = switch (onDemand) {
      OnDemandPrefs(enabled: false) => (l10n.homeStateOff, false),
      OnDemandPrefs(paused: true) => (l10n.homeAutoPaused, false),
      OnDemandPrefs(rules: []) => (l10n.ruleSetNoRules, false),
      OnDemandPrefs(systemArmed: false) => (l10n.homeAutoNotArmed, false),
      _ => (l10n.homeStateOn, true),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (supportsOnDemand)
            StatusChip(
              label: l10n.homeChipAuto(autoLabel),
              on: autoOn,
              onTap: () => _push(const OnDemandScreen()),
            ),
          StatusChip(
            label: l10n.homeChipRouting(switch (routing) {
              null => '…',
              RoutingStatus.off => l10n.homeStateOff,
              _ => l10n.homeStateOn,
            }),
            on: routing != null && routing != RoutingStatus.off,
            onTap: () => _push(
              active == null
                  ? const RuleSetsScreen()
                  : RoutingConfigScreen(profileId: active.id),
            ),
          ),
          StatusChip(
            label: l10n.homeChipLogs(
              collectLogs ? l10n.homeStateOn : l10n.homeStateOff,
            ),
            on: collectLogs,
            onTap: () => _push(const LogsScreen()),
          ),
        ],
      ),
    );
  }

  Widget? _checkBanner() {
    final check = ref.watch(connectionCheckProvider.select((s) => s.last));
    if (check == null || check.passed) return null;
    final l10n = context.l10n;
    return DsNotification.warning(
      title: l10n.homeCheckFailedTitle,
      body: l10n.homeCheckFailedDetail,
    );
  }

  Widget? _onDemandBanner() {
    final onDemand = ref.watch(onDemandProvider);
    final busy = ref.watch(sessionProvider.select((s) => s.busy));
    if (!onDemand.enabled || busy) return null;
    final l10n = context.l10n;
    final (title, subtitle) = switch (onDemand) {
      OnDemandPrefs(paused: true) => (
        l10n.homeAutoConnectPausedTitle,
        l10n.homeAutoConnectPausedDetail,
      ),
      OnDemandPrefs(awaitingFirstConnect: true) => (
        l10n.homeAutoConnectNotArmedTitle,
        l10n.homeAutoConnectNotArmedDetail,
      ),
      _ => (null, null),
    };
    if (title == null) return null;
    return DsStickyAlert(title: title, body: subtitle);
  }

  // Subscription ending: three days before the date or at 90% of the traffic.
  Widget? _expiryCard(Profile? active) {
    final account = active?.account;
    if (account == null) return null;
    final l10n = context.l10n;
    final until = account.expiresAt?.toLocal();
    final daysLeft = until == null
        ? null
        : until.difference(DateTime.now()).inHours / 24;
    final usedShare = account.dataLimit > 0
        ? account.usedBytes / account.dataLimit
        : 0.0;
    final ending =
        daysLeft != null && daysLeft >= 0 && daysLeft <= kExpiryWarnDays;
    final drained = usedShare >= kExpiryWarnTraffic;
    if (!ending && !drained) return null;
    return DsCard(
      children: [
        DsRow(
          glyph: Glyph.clock,
          title: ending
              ? l10n.homeExpiryEndsIn(daysLeft.ceil())
              : l10n.homeExpiryTraffic((usedShare * 100).floor()),
          subtitle: until == null
              ? null
              : l10n.homeExpiryValidUntil(
                  MaterialLocalizations.of(context).formatMediumDate(until),
                ),
          trailing: const [DsChevron()],
          onTap: () => _push(ConfigScreen(profileId: active!.id)),
        ),
      ],
    );
  }

  Widget _addRow() {
    final l10n = context.l10n;
    return DsCard(
      children: [
        DsRow(
          glyph: Glyph.plus,
          title: l10n.startAddConnection,
          subtitle: l10n.startSubtitle,
          trailing: const [DsChevron()],
          onTap: () => _push(const StartScreen()),
        ),
      ],
    );
  }

  Widget _profileRow(Profile active) {
    final pickable = ref.watch(
      profilesControllerProvider.select((s) => s.profiles.length > 1),
    );
    final connecting = _status == VpnStatus.connecting;
    return DsCard(
      children: [
        DsRow(
          glyph: profileIcon(active.type),
          title: active.name,
          subtitle: profileKind(active),
          subtitleMaxLines: 1,
          trailing: [
            if (active.isRefreshable) RefreshButton(profile: active),
            DsAction(
              glyph: Glyph.settings,
              tooltip: context.l10n.homeConfigurationSettings,
              onPressed: () => _push(ConfigScreen(profileId: active.id)),
            ),
            if (pickable) DsChevron(down: true, locked: connecting),
          ],
          onTap: (!pickable || _locked) ? null : _pickProfile,
        ),
      ],
    );
  }

  Widget _locationRow(Profile active) {
    final l10n = context.l10n;
    final group = ref.watch(
      profilesControllerProvider.select((s) => s.selectedGroup),
    );
    final loc = ref.watch(
      profilesControllerProvider.select((s) => s.selectedLocation),
    );
    final pickable =
        !active.isSingleServer &&
        (active.locations.length > 1 || active.groups.isNotEmpty);
    final picked = group == null ? null : ref.watch(groupMemberProvider).value;
    final connecting = _status == VpnStatus.connecting;
    final card = DsCard(
      children: [
        DsRow(
          leading: group != null
              ? GlyphIcon(groupIcon(group.type))
              : flagOrIcon(loc),
          title:
              group?.name ??
              (loc != null ? stripLeadingFlag(loc.label) : l10n.homeNoServers),
          subtitle: group != null
              ? (picked == null || picked.isEmpty
                    ? l10n.homeGroupAuto
                    : l10n.homeGroupAutoPicked(picked))
              : loc?.subtitle,
          subtitleMaxLines: 1,
          trailing: [if (pickable) DsChevron(locked: connecting)],
          onTap: (!pickable || _locked) ? null : () => _pickLocation(active),
        ),
      ],
    );
    return connecting && pickable
        ? Opacity(opacity: kDisabledOpacity, child: card)
        : card;
  }

  Future<void> _pickProfile() async {
    final favorites = await ref.read(favoritesProvider.notifier).loaded();
    if (!mounted) return;
    final st = ref.read(profilesControllerProvider);
    final picked = await pickOption<String>(
      context,
      title: context.l10n.homeConfiguration,
      selected: st.activeId,
      itemNoun: context.l10n.uiNounConfiguration,
      favorites: favorites.profiles,
      onToggleFavorite: (id) =>
          ref.read(favoritesProvider.notifier).toggleProfile(id),
      onOpenSettings: (id) => _push(ConfigScreen(profileId: id)),
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
    if (picked != null) {
      ref.read(profilesControllerProvider.notifier).setActive(picked);
    }
  }

  Future<void> _pickLocation(Profile active) async {
    final favorites = await ref.read(favoritesProvider.notifier).loaded();
    if (!mounted) return;
    final st = ref.read(profilesControllerProvider);
    final picked = await pickOption<String>(
      context,
      title: context.l10n.homeServer,
      selected: st.selectionId,
      itemNoun: context.l10n.uiNounServer,
      pinnedHeader: context.l10n.homeChosenByEngine,
      pinned: active.groups
          .map(
            (g) => Option(
              g.id,
              g.name,
              subtitle: describeGroup(g, st.locations),
              leading: GlyphIcon(groupIcon(g.type)),
            ),
          )
          .toList(),
      favorites: favorites.locationsOf(active.id),
      onToggleFavorite: (id) =>
          ref.read(favoritesProvider.notifier).toggleLocation(active.id, id),
      options: st.locations
          .map(
            (l) => Option(
              l.id,
              stripLeadingFlag(l.label),
              subtitle: l.subtitle,
              leading: flagOrIcon(l),
            ),
          )
          .toList(),
    );
    if (picked != null) {
      ref.read(profilesControllerProvider.notifier).selectLocation(picked);
    }
  }
}
