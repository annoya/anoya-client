import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/ds.dart';
import '../core/log.dart';
import '../core/profile.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';

class RefreshButton extends ConsumerStatefulWidget {
  const RefreshButton({
    super.key,
    required this.profile,
    this.iconSize = kRowIcon,
  });

  final Profile profile;
  final double iconSize;

  @override
  ConsumerState<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<RefreshButton> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(profilesControllerProvider.notifier)
          .refreshProfile(widget.profile.id);
      if (updated.deviceLimitReached && mounted) {
        showToast(context, kDeviceLimitReached.line);
      }
    } catch (e) {
      Log.e('manual refresh failed', '$e');
      if (mounted) {
        final l10n = context.l10n;
        showToast(
          context,
          l10n.configRefreshFailed(
            describeError(e).detail ?? l10n.configRefreshFailedFallback,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DsAction(
    glyph: Glyph.refreshCw,
    iconSize: widget.iconSize,
    busy: _busy,
    tooltip: context.l10n.configRefreshNow,
    onPressed: _refresh,
  );
}
