import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../core/ui.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';
import '../refresh_button.dart';

class RefreshRow extends StatelessWidget {
  const RefreshRow({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => DsRow(
    glyph: Glyph.clock,
    title: context.l10n.configLastRefreshed,
    subtitle: refreshedAtLabel(profile),
    trailing: [
      _RefreshEveryButton(profile: profile),
      RefreshButton(profile: profile),
    ],
  );
}

class _RefreshEveryButton extends ConsumerWidget {
  const _RefreshEveryButton({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DsAction(
    glyph: Glyph.settings,
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
      errorOf: (value) {
        final v = value.trim();
        return v.isEmpty || (int.tryParse(v) ?? 0) > 0
            ? null
            : l10n.configRefreshEnterWholeHours;
      },
    );
    if (typed == null) return;
    final hours = int.tryParse(typed.trim());
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
  return l10n.configRefreshAgo(agoLabel(l10n, at), every);
}

String _cadence(AppLocalizations l10n, Profile p) {
  final gap = refreshGapFor(p);
  if (gap.inMinutes < 60) return l10n.configAutoEveryMinutes(gap.inMinutes);
  if (gap.inHours < 24) return l10n.configAutoEveryHours(gap.inHours);
  return l10n.configAutoEveryDays(gap.inDays);
}
