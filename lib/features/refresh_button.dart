import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_error.dart';
import '../core/log.dart';
import '../core/profile.dart';
import '../core/ui.dart';
import '../state/profiles_controller.dart';

/// The manual re-pull of one configuration: the button, its spinner, and the
/// two things it says when the pull did not end in a new server list.
///
/// One widget for the home screen's configuration row and the configuration
/// screen's "Last refreshed" card, so a refresh reads the same wherever it was
/// pressed — four copies of this had already drifted in wording. The busy
/// state lives here rather than in the controller because it is about this
/// button's own appearance: the poll timer refreshes without anyone watching.
class RefreshButton extends ConsumerStatefulWidget {
  const RefreshButton({
    super.key,
    required this.profile,
    this.iconSize,
    this.spinnerPadding = 12,
  });

  final Profile profile;

  /// Null for the toolbar default; the home row uses the smaller trailing size.
  final double? iconSize;

  /// Horizontal inset of the spinner, chosen so it holds the button's width and
  /// the row does not shift while the pull is in flight.
  final double spinnerPadding;

  @override
  ConsumerState<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<RefreshButton> {
  bool _busy = false;

  /// Silent when it worked — the new list of servers is the answer. A toast
  /// when the panel refused the device, a toast when the pull failed: in both
  /// the servers we hold still work, so this is news, not a decision (spec §9).
  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final updated =
          await ref.read(profilesControllerProvider.notifier).refreshProfile(widget.profile.id);
      // The fetch itself succeeded — the panel simply answered with a refusal
      // and placeholders. Nothing threw, so without this the refresh would look
      // like it worked while the server list quietly turned into a message.
      if (updated.deviceLimitReached && mounted) {
        showToast(context, kDeviceLimitReached.line);
      }
    } catch (e) {
      Log.e('manual refresh failed', '$e');
      if (mounted) {
        showToast(context,
            'Couldn’t refresh — ${describeError(e).detail ?? 'showing the servers we already have.'}');
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
            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      icon: Icon(Icons.refresh, size: widget.iconSize),
      tooltip: 'Refresh now',
      onPressed: _refresh,
    );
  }
}
