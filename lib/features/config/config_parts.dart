import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/device_identity.dart';
import '../../core/dns_plan.dart';
import '../../core/app_error.dart';
import '../../core/log.dart';
import '../../core/mihomo_tun_config.dart';
import '../../core/norm_config.dart';
import '../../core/subscription_info.dart';
import '../../core/profile.dart';
import '../../core/rule_list_store.dart';
import '../../core/rule_set.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../state/profiles_controller.dart';
import '../../state/providers.dart';
import '../../state/routing_status.dart';
import '../dns_screen.dart';
import 'routing_config_screen.dart';
import '../routing_screen.dart';

/// Pieces every configuration screen shares. The three domains (ADR-005) differ in
/// what a configuration *is* — an account, a feed of servers, or a single
/// server — so they get a screen each; what they have in common lives here
/// rather than in a chain of conditionals none of the three reads cleanly.

IconData profileIcon(ProfileType t) => switch (t) {
      ProfileType.selfhosted => Icons.business_outlined,
      ProfileType.subscription => Icons.folder_outlined,
      ProfileType.link => Icons.link,
    };

String profileKind(Profile p) => switch (p.type) {
      ProfileType.selfhosted => 'Self-hosted · ${_servers(p)}',
      ProfileType.subscription => 'Subscription · ${_servers(p)}${_groups(p)}',
      ProfileType.link => 'Single server',
    };

/// "12 servers", or "294 of 306 servers" when the source offered protocols this
/// app cannot run. The second form exists so the number here matches what the
/// provider's own panel shows, minus an explanation the card below supplies.
String _servers(Profile p) {
  final offered = p.offeredServers;
  final ours = p.locations.length;
  final noun = offered == 1 ? 'server' : 'servers';
  return ours == offered ? '$ours $noun' : '$ours of $offered $noun';
}

/// "· 3 groups", when the subscription offered sets the engine picks from.
///
/// Counted where the servers are counted, because a section appearing in the
/// picker that was not there before otherwise reads as a new feature of the app
/// rather than as something the provider sent.
String _groups(Profile p) {
  final n = p.groups.length;
  if (n == 0) return '';
  return ' · $n group${n > 1 ? 's' : ''}';
}

/// Identity card at the top of every configuration screen. The check mark is
/// how "set active" reports itself: the button below disappears and the mark
/// appears here, so the result is visible without leaving the screen.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key, required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context) => Card(
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
      );
}

/// Where the configuration came from, and the one thing worth doing with it.
///
/// A subscription has a page meant for people — the panel even says which one
/// (`profile-web-page-url`) — so tapping opens it. A bare link has nothing to
/// open, so tapping copies it. The trailing icon names which of the two will
/// happen, so one row behaves differently without surprising anyone.
///
/// The value is shown elided in the middle: this is a credential, and the row
/// exists for recognition, not for reading it off the screen.
class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.value,
    this.openUrl,
    this.viaFallback = false,
  });

  final String value;

  /// The page to open on tap. Null → the value is copied instead.
  final String? openUrl;

  /// The last refresh came from the provider's backup address. The row keeps
  /// showing the address the user added — that is what they chose and what they
  /// would share — and says the backup carried it underneath. Swapping the line
  /// silently would hide that their provider's main address is unreachable.
  final bool viaFallback;

  @override
  Widget build(BuildContext context) {
    final opens = (openUrl ?? '').isNotEmpty;
    return Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.link),
        title: const Text('Source'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (viaFallback)
              Text('Last refresh used the subscription’s backup address',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        isThreeLine: viaFallback,
        trailing: Icon(opens ? Icons.open_in_new : Icons.copy_all_outlined, size: 18),
        onTap: () => opens ? _open(context, openUrl!) : _copy(context),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showToast(context, 'Couldn’t open that page.');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showToast(context, 'Link copied');
  }
}

/// Names the servers the source offered and this app cannot run.
///
/// Dropping them silently is the tempting option and the wrong one: the user
/// counted the locations in their provider's panel, and a smaller number here
/// with no reason given reads as the app losing them. A warning, not an error —
/// the rest of the servers work and connecting is available right now.
class UnsupportedServersCard extends StatelessWidget {
  const UnsupportedServersCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skipped = profile.offeredServers - profile.locations.length;
    final kinds = (profile.unsupportedServers.keys.toList()..sort()).join(', ');
    return Card(
      margin: kCardMargin,
      color: cs.tertiaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
        title: Text('$skipped of ${profile.offeredServers} servers unsupported'),
        subtitle: Text('They use $kinds, which this app cannot run yet. '
            'The other ${profile.locations.length} are available.'),
        isThreeLine: true,
      ),
    );
  }
}

/// The panel refused this device: its limit is full.
///
/// A warning rather than an error, and above everything else on the screen:
/// the configuration still exists and can be repaired, but every list below it
/// is now the provider's placeholder rather than servers, and reading them
/// without this card would be baffling.
class DeviceLimitCard extends StatelessWidget {
  const DeviceLimitCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: kCardMargin,
      color: cs.errorContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: cs.error),
        title: Text(kDeviceLimitReached.title),
        subtitle: Text(kDeviceLimitReached.detail!),
        isThreeLine: true,
      ),
    );
  }
}

/// Everything the subscription's panel reported, in its own voice.
///
/// The header is neutral because the rows already carry the attribution: the
/// provider's message stands without an icon of ours, and the plan's numbers
/// say "what the subscription reports, not verified here". Naming the section
/// after the source said it a third time, and in testing it read as the name of
/// some separate thing rather than as "details of this subscription". What must
/// not happen is the opposite — calling it ACCOUNT, which would claim an
/// authority a subscription does not have (ADR-005).
class ProviderSection extends StatelessWidget {
  const ProviderSection({super.key, required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('DETAILS'),
      if (info.announce.isNotEmpty)
        Card(
          margin: kCardMargin,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            // Their text, rendered as text: no links made clickable out of it,
            // and no warning icon lent to it. A provider's message is not a
            // state of the app.
            child: Text(info.announce, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      if (info.hasPlan) _PlanCard(info: info),
      if (info.supportUrl.isNotEmpty)
        Card(
          margin: kCardMargin,
          child: ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Get support'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.tryParse(info.supportUrl);
              if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) showToast(context, 'Couldn’t open that link.');
              }
            },
          ),
        ),
      if (!info.hasPlan && info.announce.isEmpty && info.supportUrl.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 0),
          child: Text('Your subscription reported no plan details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
        ),
    ]);
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.info});

  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final warn = Theme.of(context).colorScheme.error;
    return Card(
      margin: kCardMargin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            info.unlimited
                // A share of zero is not a number: a bar here would read as
                // "all used up" for a plan that has no ceiling at all.
                ? 'Used ${formatBytes(info.usedBytes)} · no limit'
                : 'Traffic: ${formatBytes(info.usedBytes)} of ${formatBytes(info.totalBytes)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!info.unlimited) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (info.usedBytes / info.totalBytes).clamp(0.0, 1.0),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _planLine(info),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: info.expired ? warn : muted),
          ),
        ]),
      ),
    );
  }

  String _planLine(SubscriptionInfo info) {
    final at = info.expiresAt;
    final when = at == null
        ? 'No expiry date given'
        : '${info.expired ? 'Expired' : 'Active until'} ${_date(at)}';
    return '$when · what the subscription reports, not verified here';
  }

  String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// Age of the cached servers plus a manual re-pull. Only for configurations
/// with an origin to ask — a link has none.
class RefreshCard extends StatelessWidget {
  const RefreshCard({
    super.key,
    required this.profile,
    required this.refreshing,
    required this.onRefresh,
  });

  final Profile profile;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Card(
        margin: kCardMargin,
        child: ListTile(
          title: const Text('Last refreshed'),
          subtitle: Text(refreshedAtLabel(profile)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _RefreshEveryButton(profile: profile),
            if (refreshing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh now',
                onPressed: onRefresh,
              ),
          ]),
        ),
      );
}

/// Sets how often this configuration re-reads itself, in the same unit the
/// panel asks in.
///
/// A period is a request from the source, and the app honours it by default —
/// but it is spent out of the user's data and battery, so it has to be movable.
/// The gear sits beside the refresh button because it is the setting for what
/// that button does on its own.
class _RefreshEveryButton extends ConsumerWidget {
  const _RefreshEveryButton({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        icon: const Icon(Icons.settings_outlined, size: 20),
        tooltip: 'Refresh every',
        onPressed: () => _edit(context, ref),
      );

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final asked = profile.providerInfo?.updateInterval;
    final typed = await promptText(
      context,
      title: 'Refresh every',
      label: 'Hours',
      confirmLabel: 'Save',
      initial: profile.refreshHours?.toString() ?? '',
      hint: asked != null && asked > 0 ? '$asked' : '',
      autocorrect: false,
      // Getting back to the source's own period has to be an action, not an
      // empty field: a cleared box reads as a mistake, not as a decision.
      resetLabel: 'As the subscription asks',
      resetValue: '',
    );
    if (typed == null) return;
    final trimmed = typed.trim();
    final hours = trimmed.isEmpty ? null : int.tryParse(trimmed);
    if (trimmed.isNotEmpty && (hours == null || hours <= 0)) {
      if (context.mounted) showToast(context, 'Enter a whole number of hours.');
      return;
    }
    await ref
        .read(profilesControllerProvider.notifier)
        .setRefreshHours(profile.id, hours);
  }
}


String refreshedAtLabel(Profile p) {
  final at = p.refreshedAt;
  final every = _cadence(p);
  if (at == null) return 'never · $every';
  final d = DateTime.now().difference(at);
  final ago = d.inDays > 0
      ? '${d.inDays} day${d.inDays > 1 ? 's' : ''} ago'
      : d.inHours > 0
          ? '${d.inHours} hour${d.inHours > 1 ? 's' : ''} ago'
          : d.inMinutes > 0
              ? '${d.inMinutes} min ago'
              : 'just now';
  return '$ago · $every';
}

/// How often this configuration re-pulls — what the app actually does, which is
/// the user's period where they set one, the panel's `profile-update-interval`
/// (in **hours**) otherwise, and our polling floor when neither says.
String _cadence(Profile p) {
  final gap = refreshGapFor(p);
  if (gap.inMinutes < 60) return 'auto every ${gap.inMinutes} min';
  if (gap.inHours < 24) return 'auto every ${gap.inHours} h';
  final days = gap.inDays;
  return 'auto every ${days == 1 ? 'day' : '$days days'}';
}


/// The routing section for a subscription whose panel sent rules of its own.
///
/// Applied by default — a provider that sent rules meant them — but with a
/// switch, which is the whole difference from a self-hosted policy: an
/// organization's server both sets and enforces its policy, while a panel can
/// only stop returning servers (ADR-005). It cannot decide where this device's
/// traffic goes, so the decision is stated in words rather than implied.
class ProviderRoutingCard extends ConsumerStatefulWidget {
  const ProviderRoutingCard({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<ProviderRoutingCard> createState() => _ProviderRoutingCardState();
}

class _ProviderRoutingCardState extends ConsumerState<ProviderRoutingCard> {
  /// A dozen files from someone else's hosts is seconds, and more on a phone.
  /// The switch cannot move until they are here — a rule whose list is missing
  /// matches nothing, so an early "on" would be a lie — so the row carries the
  /// state instead of leaving the tap unanswered.
  bool _downloading = false;

  Future<void> _setLists(bool enabled) async {
    if (enabled) setState(() => _downloading = true);
    try {
      await ref
          .read(profilesControllerProvider.notifier)
          .setProviderRuleListsEnabled(widget.profile.id, enabled);
      ref.invalidate(providerRuleListsProvider(widget.profile.id));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final cs = Theme.of(context).colorScheme;
    final routing = profile.providerRouting!;
    final on = profile.providerRoutingEnabled;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    final lists = ref.watch(providerRuleListsProvider(profile.id)).value;
    final needLists = routing.rules.where((r) => r.needsRuleList).length;
    return Card(
      margin: kCardMargin,
      color: cs.primaryContainer.withValues(alpha: 0.35),
      child: Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.alt_route),
          // Named like the device's own controls below it. Whose policy this
          // is comes from the section header, once, instead of from every row —
          // the width a repeated "from your provider" costs is width the
          // subtitle needs for facts.
          title: const Text('Routing'),
          subtitle: Text(providerRoutingSummary(profile, lists)),
          value: on,
          onChanged: (v) => ctrl.setProviderRoutingEnabled(profile.id, v),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        // Readable with the switch off: deciding whether to accept someone
        // else's rules requires seeing them first.
        ListTile(
          leading: const Icon(Icons.layers_outlined),
          title: const Text('Rule set'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RoutingScreen.managed(
              routing,
              origin: PolicyOrigin.provider(
                profile.name,
                skipped: profile.providerRoutingSkipped,
              ),
              // Null while the lists are refused, so the rules that need them
              // can say "off" rather than "not downloaded" — the user's own
              // decision reads differently from a failure.
              listsAvailable: profile.providerRuleListsEnabled
                  ? (lists ?? const [])
                      .where((s) => s.available)
                      .map((s) => s.list.name)
                      .toSet()
                  : null,
            ),
          )),
        ),
        // Only when there is something to decide: a policy with no external
        // lists would get a switch that governs nothing.
        if (needLists > 0) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            // The spinner takes the icon's place rather than the switch's, so
            // the row does not change width and it stays clear which operation
            // is running — the same shape as the refresh card.
            secondary: _downloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Icon(Icons.description_outlined),
            title: const Text('Rule lists'),
            subtitle: Text(_downloading
                ? 'Downloading ${needLists == 1 ? 'one list' : '$needLists lists'}…'
                : _listSummary(profile, needLists, lists)),
            value: profile.providerRuleListsEnabled,
            // A second tap would not hurry the first, and two writers on the
            // same files is how half a list ends up on disk.
            onChanged: _downloading ? null : _setLists,
          ),
        ],
      ]),
    );
  }
}

/// The line under the switch. Says what is in force, and — when something is
/// missing — says that too, because a summary that reads as complete is the
/// one place this could mislead.
String providerRoutingSummary(Profile profile, List<RuleListStatus>? lists) {
  final routing = profile.providerRouting!;
  final mode = routing.mode == 'split' ? 'Split' : 'Full tunnel';
  final applied = routing.rules
      .where((r) => !r.needsRuleList || _isAvailable(profile, r.value, lists))
      .length;
  final rules = applied == 0 ? 'no exceptions' : '$applied rule${applied > 1 ? 's' : ''}';
  final parts = ['$mode · $rules'];
  final skipped = profile.providerRoutingSkipped;
  if (skipped > 0) parts.add('$skipped not supported');
  final missing = routing.rules.length - applied;
  if (missing > 0) {
    parts.add(profile.providerRuleListsEnabled
        ? '$missing list${missing > 1 ? 's' : ''} unavailable'
        : '$missing need${missing > 1 ? '' : 's'} their lists');
  }
  return parts.join(' · ');
}

bool _isAvailable(Profile p, String name, List<RuleListStatus>? lists) {
  if (!p.providerRuleListsEnabled) return false;
  // Unknown status is not the same as absent: while the read is in flight,
  // assume what the user asked for rather than flashing a failure.
  if (lists == null) return true;
  return lists.any((s) => s.list.name == name && s.available);
}

String _listSummary(Profile p, int needed, List<RuleListStatus>? lists) {
  if (!p.providerRuleListsEnabled) {
    return 'Off · $needed rule${needed > 1 ? 's' : ''} need${needed > 1 ? '' : 's'} them';
  }
  if (lists == null) return 'Checking…';
  final have = lists.where((s) => s.available).toList();
  if (have.isEmpty) return 'None downloaded yet';
  final kb = have.fold<int>(0, (a, s) => a + s.bytes) ~/ 1024;
  final count = have.length == lists.length
      ? '${have.length} list${have.length > 1 ? 's' : ''}'
      : '${have.length} of ${lists.length} downloaded';
  return '$count · $kb KB';
}

/// Shown when the provider named a list we could not fetch.
///
/// The engine would say nothing here: a rule whose list is missing matches
/// nothing, traffic falls through to the next rule, and the policy quietly
/// changes. So this is the same choice as for geo rules — the rule is not
/// applied and the fact is stated, with the one action that can fix it.

class RuleListFailureCard extends ConsumerStatefulWidget {
  const RuleListFailureCard({super.key, required this.profile, required this.failed});

  final Profile profile;
  final List<RuleListStatus> failed;

  @override
  ConsumerState<RuleListFailureCard> createState() => _RuleListFailureCardState();
}

class _RuleListFailureCardState extends ConsumerState<RuleListFailureCard> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(profilesControllerProvider.notifier)
          .syncRuleLists(widget.profile.id);
      ref.invalidate(providerRuleListsProvider(widget.profile.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warn = context.vpnColors.connecting;
    final n = widget.failed.length;
    final names = widget.failed.map((s) => '«${s.list.name}»').join(', ');
    final hosts = widget.failed
        .map((s) => Uri.parse(s.list.url).host)
        .toSet()
        .join(', ');
    return Card(
      margin: kCardMargin,
      color: warn.withValues(alpha: 0.12),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.warning_amber_outlined, color: warn),
          title: Text(n == 1
              ? 'One list could not be downloaded'
              : '$n lists could not be downloaded'),
          subtitle: Text('$names from $hosts — '
              'the rule${n > 1 ? 's' : ''} using ${n > 1 ? 'them' : 'it'} '
              '${n > 1 ? 'are' : 'is'} not applied.'),
          isThreeLine: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
            child: FilledButton.tonal(
              onPressed: _busy ? null : _retry,
              child: _busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Try again'),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Disk state of the lists a profile's provider policy names. Read from the
/// store, not from the profile: the files are the truth here, and a profile
/// that says "enabled" tells us nothing about what actually arrived.
final providerRuleListsProvider =
    FutureProvider.family<List<RuleListStatus>, String>((ref, profileId) async {
  final profile = ref.watch(profilesControllerProvider
      .select((s) => s.profiles.where((p) => p.id == profileId).firstOrNull));
  final lists = profile?.providerRouting?.lists ?? const <RuleList>[];
  if (lists.isEmpty) return const [];
  try {
    return await RuleListStore.status(lists);
  } catch (e) {
    // A container we cannot read means we hold nothing, which is a fact worth
    // reporting rather than an error to hide behind: null is reserved for "not
    // known yet", and callers treat that optimistically.
    Log.e('rule list status unavailable', '$e');
    return [for (final l in lists) RuleListStatus(list: l, error: '$e')];
  }
});

/// The routing section for a configuration whose rules are the device's own:
/// an opt-in switch plus the rule set in force.
class LocalRoutingCard extends ConsumerWidget {
  const LocalRoutingCard({super.key, required this.profile, this.overriddenBy});

  final Profile profile;

  /// Names the policy standing in for this one, when something else is in
  /// force. Dimming alone would say "unavailable"; the row has to say why, and
  /// stay usable, because switching back is how the user takes it over again.
  final String? overriddenBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(ruleSetsProvider).value ?? const <RuleSet>[];
    final ruleSet =
        sets.where((s) => s.id == (profile.ruleSetId ?? RuleSet.defaultId)).firstOrNull;
    final ctrl = ref.read(profilesControllerProvider.notifier);

    return Card(
      margin: kCardMargin,
      child: Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.alt_route),
          title: const Text('Routing'),
          // The subtitle is the policy in force, not a description of the
          // switch: the set itself is named in the row below, and repeating it
          // here would say nothing new.
          subtitle: Text(overriddenBy != null
              ? 'Replaced by $overriddenBy'
              : localRoutingSummary(profile, ruleSet)),
          value: profile.routingEnabled,
          onChanged: (v) => ctrl.setRoutingEnabled(profile.id, v),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        // Kept visible while off — hiding it would make the switch look like it
        // controls nothing, and the chosen set is remembered for when routing
        // comes back on.
        Opacity(
          opacity: profile.routingEnabled ? 1 : 0.38,
          child: ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: const Text('Rule set'),
            subtitle: Text(ruleSet?.name ?? 'Default'),
            trailing: const Icon(Icons.expand_more),
            // Reachable with routing off: picking a set is how it gets turned on.
            onTap: () => _pick(context, ref, sets),
          ),
        ),
      ]),
    );
  }


  Future<void> _pick(BuildContext context, WidgetRef ref, List<RuleSet> sets) async {
    final picked = await pickOption<String>(
      context,
      title: 'Rule set',
      selected: profile.ruleSetId ?? RuleSet.defaultId,
      options: sets
          .map((s) => Option(
                s.id,
                s.name,
                subtitle:
                    '${s.mode == 'split' ? 'Split' : 'Full tunnel'} · ${s.rules.isEmpty ? 'no rules' : '${s.rules.length} rules'}',
                leading: const Icon(Icons.layers_outlined),
              ))
          .toList(),
    );
    if (picked != null) {
      await ref.read(profilesControllerProvider.notifier).setRuleSet(profile.id, picked);
    }
  }
}

/// Set active / remove, in that order, at the bottom of every screen.
class ConfigActions extends ConsumerWidget {
  const ConfigActions({super.key, required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(profilesControllerProvider.notifier);
    // stretch, not the default centre: a Column hands its children their
    // intrinsic width, which made these buttons hug their labels instead of
    // spanning the content width the way every other screen's do.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      if (!isActive)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kGutter),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Set active'),
            onPressed: () => ctrl.setActive(profile.id),
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
          onPressed: () => _remove(context, ref),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${profile.name}?'),
        content: const Text('This configuration will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    final ctrl = ref.read(profilesControllerProvider.notifier);
    if (ref.read(profilesControllerProvider).activeId == profile.id) {
      try {
        // Through the controller, not the raw core: it records the on-demand
        // pause first, so the home chips explain why auto-connect is off.
        await ctrl.disconnect();
      } catch (_) {/* ignore */}
    }
    await ctrl.removeProfile(profile.id);
    if (!context.mounted) return;
    // Only close ourselves while other configurations remain. When that was the
    // last one, the app shell unwinds to the add screen on its own — popping
    // here as well would race it and take the root route down too (leaving an
    // empty navigator, i.e. a black screen).
    if (ref.read(profilesControllerProvider).hasProfiles) Navigator.of(context).pop();
  }
}

/// Opens the read-only view of a policy the configuration did not choose.
void openManagedRouting(BuildContext context, Routing routing) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoutingScreen.managed(routing)));
}

/// Shown only for a configuration whose panel said it counts devices.
///
/// The panel reports *that* it counts and *that* it is full — never how many of
/// how many — so this says what we know and stops. What it must say is that
/// this installation occupies a slot: that is a consequence of using the app,
/// and learning it by hitting the limit somewhere else would be a surprise.
class ThisDeviceSection extends StatelessWidget {
  const ThisDeviceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceIdentity>(
      future: DeviceIdentityStore.load(),
      builder: (context, snap) {
        final id = snap.data;
        if (id == null) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader('THIS DEVICE'),
          Card(
            margin: kCardMargin,
            child: ListTile(
              leading: const Icon(Icons.smartphone_outlined),
              title: Text(id.label),
              subtitle: const Text('Identified to your subscription, which counts devices'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
            child: Text(
              'Your subscription counts devices by an id this app generates once and '
              'keeps. Reinstalling makes a new one, which takes another slot.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ]);
      },
    );
  }
}

/// Which resolvers this configuration uses, and a way to see why some of them
/// are not being used.
///
/// A section of its own rather than a line inside `ROUTING`: routing decides
/// where a connection goes, this decides who is asked for the address, and the
/// two are answered by different halves of the engine config. The subtitle
/// names the resolver and how it is reached, because "1 resolver" answers
/// neither of the questions a person opens this for.
class NamesSection extends ConsumerWidget {
  const NamesSection({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesControllerProvider);
    final active = state.active?.id == profile.id;
    final group = active ? state.selectedGroup : null;
    final members = active ? state.selectedGroupMembers : const <Location>[];
    final location = (active ? state.selectedLocation : null) ??
        (profile.locations.isEmpty ? null : profile.locations.first);
    final shape = location == null
        ? (outbounds: const <String>{}, carriesUdp: false)
        : engineShape(location, group: group, members: members);
    final plan = dnsPlanFor(
      dns: profile.dns,
      outbounds: shape.outbounds,
      carriesUdp: shape.carriesUdp,
      fallback: ref.watch(routingPrefsProvider).value?.defaultDns ?? kFallbackNameserver,
    );
    final first = plan.resolvers.first;

    return Column(
      // Without this a Column hands its children their intrinsic width and
      // centres them — which is exactly what happened to this header while
      // every other one on the page stayed flush left.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      const SectionHeader('DNS'),
      Card(
        margin: kCardMargin,
        child: ListTile(
          leading: const Icon(Icons.language_outlined),
          title: const Text('DNS'),
          // Host and routing, not a count: the first is what the user came to
          // check, the second is the one that decides who else sees the query.
          subtitle: Text('${_host(first.address)} · ${first.routing}'
              '${plan.resolvers.length > 1 ? ' · +${plan.resolvers.length - 1} more' : ''}'),
          // Refusals are the reason this row leads anywhere at all, so they are
          // announced before the screen is opened.
          trailing: plan.dropped.isEmpty
              ? const Icon(Icons.chevron_right)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${plan.dropped.length} dropped',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error)),
                  const Icon(Icons.chevron_right),
                ]),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DnsScreen(profile: profile))),
        ),
      ),
    ]);
  }

  /// The host alone. A DoH resolver's path (`/dns-query`) is the same on every
  /// server that has one and only costs the row the width it needs for the name.
  String _host(String address) {
    final at = address.indexOf('://');
    if (at < 0) return address;
    return Uri.tryParse(address)?.host ?? address.substring(at + 3);
  }
}

/// The policy a device's own rule set puts in force, in one line.
String localRoutingSummary(Profile p, RuleSet? set) {
  if (!p.routingEnabled) return 'Off · everything through the VPN';
  final mode = (set?.mode ?? 'full') == 'split' ? 'Split' : 'Full tunnel';
  final rules = set?.rules.length ?? 0;
  return '$mode · ${rules == 0 ? 'no rules' : '$rules rule${rules > 1 ? 's' : ''}'}';
}

/// A policy the organization owns: shown, never switched.
class ManagedRoutingCard extends StatelessWidget {
  const ManagedRoutingCard({super.key, required this.routing});

  final Routing routing;

  @override
  Widget build(BuildContext context) => Card(
        margin: kCardMargin,
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: ListTile(
          leading: const Icon(Icons.business_outlined),
          title: const Text('Managed by your organization'),
          subtitle: Text(
              '${routing.mode == 'split' ? 'Split' : 'Full tunnel'} · ${routing.rules.length} rules, set on the server'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openManagedRouting(context, routing),
        ),
      );
}

/// The one row that stands in for everything about where traffic goes and who
/// names the addresses.
///
/// Both used to sit on the configuration screen and were the largest thing on
/// it, while being the part almost nobody opens. The subtitle carries the two
/// facts a passer-by would have read off those sections — the policy in force
/// and whose resolvers — so moving them costs no one an answer they used to
/// get for free.
class RoutingRow extends ConsumerWidget {
  const RoutingRow({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final plan = dnsPlanForProfile(ref, profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('ROUTING'),
        Card(
      margin: kCardMargin,
      child: ListTile(
        leading: const Icon(Icons.alt_route),
        title: const Text('Routing'),
        subtitle: Text.rich(TextSpan(children: [
          TextSpan(text: '${_routing(ref)} · '),
          // The refusals were just taken out of a log file nobody reads.
          // Leaving them two taps away would put them back — in words, and in
          // the one place a passer-by looks.
          if (plan.dropped.isEmpty)
            // "DNS app default" reads as a typo; the app is the one origin
            // that needs a preposition of its own.
            TextSpan(
                text: plan.usingFallback
                    ? 'DNS by the app'
                    : 'DNS ${dnsOriginLabel(profile, plan)}')
          else
            TextSpan(
              text: 'DNS: ${plan.dropped.length} refused',
              style: TextStyle(color: cs.error),
            ),
        ])),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RoutingConfigScreen(profileId: profile.id))),
      ),
        ),
      ],
    );
  }

  /// Whichever of the three policies is actually in force.
  String _routing(WidgetRef ref) {
    // Named rather than summarised: a row that leads to something the user
    // cannot change should say so before it is tapped.
    if (profile.routing != null) {
      final mode = profile.routing!.mode == 'split' ? 'Split' : 'Full tunnel';
      return '$mode · set by your organization';
    }
    if (profile.providerRouting != null && profile.providerRoutingEnabled) {
      return providerRoutingSummary(
          profile, ref.watch(providerRuleListsProvider(profile.id)).value);
    }
    final sets = ref.watch(ruleSetsProvider).value ?? const <RuleSet>[];
    final set =
        sets.where((s) => s.id == (profile.ruleSetId ?? RuleSet.defaultId)).firstOrNull;
    return localRoutingSummary(profile, set);
  }
}
