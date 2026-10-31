import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/profile.dart';
import '../../l10n/l10n.dart';
import '../../state/profiles_controller.dart';

Future<bool> askListConsent(BuildContext context, Profile p) async {
  final l10n = context.l10n;
  final lists = p.plan?.lists ?? const [];
  final hosts = {for (final l in lists) Uri.parse(l.url).host}.toList();
  final named = hosts.take(2).join(', ');
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => DsDialog(
      title: l10n.consentTitle,
      body: l10n.consentBody(
        p.name,
        lists.length,
        hosts.length > 2
            ? l10n.consentHostsMore(named, hosts.length - 2)
            : named,
      ),
      actions: [
        DsDialogAction(
          label: l10n.modeOwnRules,
          onPressed: () => Navigator.pop(context, false),
        ),
        DsDialogAction(
          label: l10n.consentUseRules,
          strong: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class SubscriptionModeGroup extends ConsumerWidget {
  const SubscriptionModeGroup({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rules = profile.usesSubscriptionRules;
    return DsGroup(
      caption: l10n.modeCaption,
      note: rules ? l10n.modeSubscriptionRulesNote : l10n.modeOwnRulesNote,
      child: DsSegmented<bool>(
        segments: [
          (true, l10n.modeSubscriptionRules),
          (false, l10n.modeOwnRules),
        ],
        value: rules,
        onChanged: (v) => ref
            .read(profilesControllerProvider.notifier)
            .setSubscriptionRules(
              profile.id,
              v,
              consent: (p) => askListConsent(context, p),
            ),
      ),
    );
  }
}
