import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/log.dart';
import '../core/profile.dart';
import '../core/ui.dart';
import '../l10n/l10n.dart';
import '../state/profiles_controller.dart';

class RefreshButton extends ConsumerStatefulWidget {
  const RefreshButton({
    super.key,
    required this.profile,
    this.iconSize,
    this.spinnerPadding = 12,
  });

  final Profile profile;

  final double? iconSize;

  final double spinnerPadding;

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
  Widget build(BuildContext context) {
    if (_busy) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.spinnerPadding),
        child: const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: Icon(Icons.refresh, size: widget.iconSize),
      tooltip: context.l10n.configRefreshNow,
      onPressed: _refresh,
    );
  }
}
