import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/country_flag.dart';
import '../core/norm_config.dart';
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
  /// Status and session start are owned by [sessionProvider] — the menu bar
  /// shows the same clock, and two owners print two durations for one tunnel.
  /// The once-a-second repaint for the clock is [StatusLabel]'s own business.
  VpnStatus get _status => ref.watch(sessionProvider.select((s) => s.status));

  /// When the pickers refuse taps. A connected tunnel is NOT locked: switching
  /// is a hot reload under the live session. Locked only while the initial
  /// connect is in flight, or during the (brief) hot switch itself.
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
    // Watched by the piece that needs it, never the whole state: a notice or a
    // flag flipping used to rebuild every card on this screen.
    final active = ref.watch(
      profilesControllerProvider.select((s) => s.active),
    );

    // A connect failure floats above the screen until dismissed: the layout
    // must not jump, and a cause that vanished on its own tells the user
    // nothing about what to fix.
    ref.listen(profilesControllerProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        showErrorDialog(
          context,
          error,
          onDismiss: ref.read(profilesControllerProvider.notifier).clearError,
        );
      }
    });

    // What happened, changed nothing, and needs no decision — a toast, in the
    // same form the configuration screens use for the same class of event
    // (spec §9). The dialog above is for what blocks the user.
    ref.listen(profilesControllerProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showToast(context, notice.line);
      ref.read(profilesControllerProvider.notifier).clearNotice();
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.homeAddConfiguration,
          onPressed: () => _push(const StartScreen()),
        ),
        title: Text(l10n.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.commonSettings,
            onPressed: () => _push(const SettingsScreen()),
          ),
        ],
      ),
      // The ring owns the free space and stays centred in it; the pickers are
      // pinned to the bottom edge, within thumb reach and steady when a banner
      // appears above them.
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const StatusLabel(),
                            const SizedBox(height: 28),
                            ConnectButton(status: _status, onTap: _toggle),
                          ],
                        ),
                      ),
                    ),
                    ?_checkBanner(),
                    ?_onDemandBanner(),
                    if (active != null) _profileRow(active),
                    if (active != null) _locationRow(active),
                    if (active?.account != null) ...[
                      const SizedBox(height: 12),
                      _accountRow(active!.account!),
                    ],
                    const SizedBox(height: kGutter),
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

  /// The three things that change how the tunnel behaves and otherwise live on
  /// three separate settings screens: whether the system connects on its own,
  /// whether any traffic is routed around the tunnel, and whether anything is
  /// written to the log. Each chip opens the screen that owns it — the off ones
  /// too, since that is where they get turned on.
  Widget _statusStrip(Profile? active) {
    final l10n = context.l10n;
    final onDemand = ref.watch(onDemandProvider);
    final collectLogs = ref.watch(
      appPrefsProvider.select((p) => p.collectLogs),
    );
    final routing = ref.watch(routingStatusProvider).value;

    // "Enabled but not currently working" is its own state: showing it as off
    // would send the user to a screen where the switch is already on. Only the
    // last case means the OS confirmed it is auto-connecting.
    final (autoLabel, autoTone) = switch (onDemand) {
      OnDemandPrefs(enabled: false) => (l10n.homeStateOff, ChipTone.off),
      OnDemandPrefs(paused: true) => (l10n.homeAutoPaused, ChipTone.pending),
      OnDemandPrefs(rules: []) => (l10n.ruleSetNoRules, ChipTone.pending),
      OnDemandPrefs(systemArmed: false) => (
        l10n.homeAutoNotArmed,
        ChipTone.pending,
      ),
      _ => (l10n.homeStateOn, ChipTone.on),
    };

    return Padding(
      padding: const EdgeInsets.only(
        left: kGutter,
        right: kGutter,
        top: 8,
        bottom: 4,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          // Only where the label can be true: on Android auto-connect is the
          // system's Always-on switch, whose state the app cannot read while
          // the tunnel is down — a chip would show a guess.
          if (supportsOnDemand)
            StatusChip(
              icon: Icons.bolt_outlined,
              label: l10n.homeChipAuto(autoLabel),
              tone: autoTone,
              onTap: () => _push(const OnDemandScreen()),
            ),
          StatusChip(
            icon: Icons.alt_route,
            // The value is unknown only until the rule set is read off disk, so
            // it holds its place with an ellipsis instead of the chip appearing
            // a frame late and shifting the row.
            label: l10n.homeChipRouting(routing?.label ?? '…'),
            tone: routing == null || routing == RoutingStatus.off
                ? ChipTone.off
                : ChipTone.on,
            // Routing is a per-configuration setting, so the chip leads to the
            // active configuration; with none added yet, to the sets themselves.
            onTap: () => _push(
              active == null
                  ? const RuleSetsScreen()
                  : ConfigScreen(profileId: active.id),
            ),
          ),
          StatusChip(
            icon: Icons.description_outlined,
            label: l10n.homeChipLogs(
              collectLogs ? l10n.homeStateOn : l10n.homeStateOff,
            ),
            tone: collectLogs ? ChipTone.on : ChipTone.off,
            onTap: () => _push(const LogsScreen()),
          ),
        ],
      ),
    );
  }

  /// The one thing a green ring cannot say: the tunnel is up and nothing is
  /// getting through it.
  ///
  /// A banner rather than a toast — the state holds until the user changes
  /// something, and a message that leaves on its own is a way of both telling
  /// them and not telling them. The ring stays green on purpose: the tunnel
  /// really is up, and recolouring it would misreport the system's state to
  /// deliver a warning about the server.
  Widget? _checkBanner() {
    final check = ref.watch(connectionCheckProvider.select((s) => s.last));
    if (check == null || check.passed) return null;
    final l10n = context.l10n;
    final warn = context.vpnColors.connecting;
    return Card(
      margin: kCardMargin,
      color: warn.withValues(alpha: 0.12),
      child: ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: warn),
        title: Text(l10n.homeCheckFailedTitle),
        subtitle: Text(l10n.homeCheckFailedDetail),
        isThreeLine: true,
      ),
    );
  }

  /// Explains why the system is not auto-connecting: either the user paused it
  /// with a manual disconnect, or it is enabled but has no tunnel config to
  /// start from yet (the system only accepts on-demand after one connect).
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
    return Card(
      margin: kCardMargin,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: const Icon(Icons.bolt_outlined),
        title: Text(title),
        subtitle: Text(subtitle!),
      ),
    );
  }

  /// The active configuration is always on screen, even when it is the only
  /// one: the gear jumps straight into its settings, while the chevron (and the
  /// row tap) only offer a choice when there is something to choose between.
  Widget _profileRow(Profile active) {
    final pickable = ref.watch(
      profilesControllerProvider.select((s) => s.profiles.length > 1),
    );
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: Icon(profileIcon(active.type)),
        title: Text(active.name),
        subtitle: Text(profileKind(active)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A duplicate of the button on the configuration screen, not a move:
            // that is where it belongs, next to "last refreshed", but it is
            // pressed from here — the servers ran out or the provider changed
            // something, and the user is already looking at this screen.
            if (active.isRefreshable)
              RefreshButton(profile: active, iconSize: 20, spinnerPadding: 14),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: context.l10n.homeConfigurationSettings,
              onPressed: () => _push(ConfigScreen(profileId: active.id)),
            ),
            if (pickable)
              _status == VpnStatus.connecting
                  ? const Icon(Icons.lock_outline, size: 18)
                  : const Icon(Icons.expand_more),
          ],
        ),
        onTap: (!pickable || _locked) ? null : _pickProfile,
      ),
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
    // A single-server profile (a plain link) has nothing to pick between: show
    // the server but no dropdown affordance or picker.
    final pickable =
        !active.isSingleServer &&
        (active.locations.length > 1 || active.groups.isNotEmpty);
    final picked = group == null ? null : ref.watch(groupMemberProvider).value;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: group != null
            ? Icon(groupIcon(group.type))
            : flagOrIcon(loc?.label),
        title: Text(
          group?.name ??
              (loc != null ? stripLeadingFlag(loc.label) : l10n.homeNoServers),
        ),
        // With a group, the name alone is a claim the user cannot check — they
        // do not know where their traffic goes. So the line names the method
        // and the result; until the engine has picked, it names only the method
        // rather than a server from a previous session.
        subtitle: group != null
            ? Text(
                picked == null || picked.isEmpty
                    ? l10n.homeGroupAuto
                    : l10n.homeGroupAutoPicked(picked),
              )
            : loc != null && loc.subtitle.isNotEmpty
            ? Text(loc.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: !pickable
            ? null
            : _status == VpnStatus.connecting
            ? const Icon(Icons.lock_outline, size: 18)
            : const Icon(Icons.chevron_right),
        onTap: (!pickable || _locked) ? null : () => _pickLocation(active),
      ),
    );
  }

  Widget _accountRow(Account account) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Text(
        account.expiresAt != null
            ? context.l10n.homeAccountUntil(
                account.status,
                account.expiresAt!.toLocal().toString().split('.').first,
              )
            : account.status,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
      ),
    );
  }

  Future<void> _pickProfile() async {
    final st = ref.read(profilesControllerProvider);
    final favorites = ref.read(favoritesProvider);
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
              leading: Icon(profileIcon(p.type)),
            ),
          )
          .toList(),
    );
    if (picked != null) {
      ref.read(profilesControllerProvider.notifier).setActive(picked);
    }
  }

  Future<void> _pickLocation(Profile active) async {
    final st = ref.read(profilesControllerProvider);
    final favorites = ref.read(favoritesProvider);
    final picked = await pickOption<String>(
      context,
      title: context.l10n.homeServer,
      selected: st.selectionId,
      itemNoun: context.l10n.uiNounServer,
      // Groups first: for most people "the fastest one" is the answer they
      // came for, and it is an answer to the same question as a country.
      pinnedHeader: context.l10n.homeChosenByEngine,
      pinned: active.groups
          .map(
            (g) => Option(
              g.id,
              g.name,
              subtitle: describeGroup(g, st.locations),
              leading: Icon(groupIcon(g.type)),
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
              leading: flagOrIcon(l.label),
            ),
          )
          .toList(),
    );
    if (picked != null) {
      ref.read(profilesControllerProvider.notifier).selectLocation(picked);
    }
  }
}
