import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../refresh_button.dart';

class RefreshCard extends StatelessWidget {
  const RefreshCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => Card(
    margin: kCardMargin,
    child: ListTile(
      title: Text(context.l10n.configLastRefreshed),
      subtitle: Text(refreshedAtLabel(profile)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RefreshEveryButton(profile: profile),
          RefreshButton(profile: profile),
        ],
      ),
    ),
  );
}

class _RefreshEveryButton extends ConsumerWidget {
  const _RefreshEveryButton({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    icon: const Icon(Icons.settings_outlined, size: 20),
    tooltip: context.l10n.configRefreshEvery,
    onPressed: () => _edit(context, ref),
  );

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final asked = profile.providerInfo?.updateInterval;
    final l10n = context.l10n;
    final typed = await promptText(
      context,
      title: l10n.configRefreshEvery,
      label: l10n.configHours,
      confirmLabel: l10n.commonSave,
      initial: profile.refreshHours?.toString() ?? '',
      hint: asked != null && asked > 0 ? '$asked' : '',
      autocorrect: false,
      resetLabel: l10n.configRefreshAsSubscriptionAsks,
      resetValue: '',
    );
    if (typed == null) return;
    final trimmed = typed.trim();
    final hours = trimmed.isEmpty ? null : int.tryParse(trimmed);
    if (trimmed.isNotEmpty && (hours == null || hours <= 0)) {
      if (context.mounted) {
        showToast(context, l10n.configRefreshEnterWholeHours);
      }
      return;
    }
    await ref
        .read(profilesControllerProvider.notifier)
        .setRefreshHours(profile.id, hours);
  }
}

String refreshedAtLabel(Profile p) {
  final l10n = L10n.current;
  final at = p.refreshedAt;
  final every = _cadence(l10n, p);
  if (at == null) return l10n.configRefreshNever(every);
  final d = DateTime.now().difference(at);
  final ago = d.inDays > 0
      ? l10n.commonDaysAgo(d.inDays)
      : d.inHours > 0
      ? l10n.commonHoursAgo(d.inHours)
      : d.inMinutes > 0
      ? l10n.commonMinutesAgo(d.inMinutes)
      : l10n.commonJustNow;
  return l10n.configRefreshAgo(ago, every);
}

String _cadence(AppLocalizations l10n, Profile p) {
  final gap = refreshGapFor(p);
  if (gap.inMinutes < 60) return l10n.configAutoEveryMinutes(gap.inMinutes);
  if (gap.inHours < 24) return l10n.configAutoEveryHours(gap.inHours);
  return l10n.configAutoEveryDays(gap.inDays);
}
