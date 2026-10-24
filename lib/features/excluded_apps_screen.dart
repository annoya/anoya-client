import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/android_apps.dart';
import '../core/ds.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../state/excluded_apps_controller.dart';
import 'app_picker.dart';

class ExcludedAppsScreen extends ConsumerStatefulWidget {
  const ExcludedAppsScreen({super.key});

  @override
  ConsumerState<ExcludedAppsScreen> createState() => _ExcludedAppsScreenState();
}

class _ExcludedAppsScreenState extends ConsumerState<ExcludedAppsScreen> {
  Map<String, AndroidApp> _apps = const {};
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    AndroidApps.installed(refresh: true).then((apps) {
      if (mounted) setState(() => _apps = appsByPackage(apps));
    });
  }

  Future<void> _add() async {
    final current = ref.read(excludedAppsProvider).packages.toSet();
    final picked = await pickApps(context, selected: current);
    if (picked == null) return;
    await ref.read(excludedAppsProvider.notifier).setApps(picked);
  }

  Future<void> _reconnect() async {
    setState(() => _restarting = true);
    await ref.read(excludedAppsProvider.notifier).applyNow();
    if (mounted) setState(() => _restarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(excludedAppsProvider);
    return DsPage(
      title: l10n.settingsExcludedApps,
      gap: kNoteGap,
      children: [
        DsNote(l10n.excludedAppsHint),
        if (state.packages.isNotEmpty)
          DsCard(
            children: [
              for (final p in state.packages)
                DsRow(
                  leading: AppIcon(_apps[p]),
                  title: _apps[p]?.label ?? p,
                  subtitle: p,
                  subtitleMaxLines: 1,
                  trailing: [
                    DsAction(
                      glyph: Glyph.x,
                      tooltip: l10n.commonRemove,
                      onPressed: () =>
                          ref.read(excludedAppsProvider.notifier).remove(p),
                    ),
                  ],
                ),
            ],
          ),
        DsButton.secondary(
          label: l10n.excludedAppsAdd,
          glyph: Glyph.plus,
          onPressed: _add,
        ),
        if (state.pending) ...[
          DsCard(
            children: [
              DsRow(
                glyph: Glyph.info,
                title: l10n.excludedAppsPending,
                subtitle: l10n.excludedAppsPendingDetail,
              ),
            ],
          ),
          DsButton.secondary(
            label: l10n.excludedAppsReconnect,
            glyph: Glyph.refreshCw,
            busy: _restarting,
            onPressed: _restarting ? null : _reconnect,
          ),
        ],
      ],
    );
  }
}
