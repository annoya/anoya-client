import 'package:flutter/material.dart';

import '../theme.dart';
import 'glyph.dart';
import 'layout.dart';
import 'rows.dart';
import 'sheet.dart';

// AlertDialog of the DS: 16 from the screen edges, r12, title 18/24, body 14/18 scrolling within 80% of the screen,
// text actions 40 sharing the row.
class DsDialog extends StatelessWidget {
  const DsDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    this.actions = const [],
    this.glyph,
    this.onDismiss,
    this.dismissTooltip,
  });

  final String title;
  final String? body;
  final Widget? content;
  final List<Widget> actions;
  final Glyph? glyph;
  final VoidCallback? onDismiss;
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (glyph != null) ...[
          GlyphIcon(glyph!),
          const SizedBox(width: kRowGap),
        ],
        Expanded(
          child: Text(title, style: DsType.h3.copyWith(color: ds.text1)),
        ),
        if (onDismiss != null)
          Transform.translate(
            offset: const Offset(0, -6),
            child: DsAction(
              glyph: Glyph.x,
              size: kDialogDismiss,
              iconSize: kSmallIcon,
              tooltip: dismissTooltip,
              onPressed: onDismiss,
            ),
          ),
      ],
    );
    final scrolled = [
      if (body != null)
        Text(
          body!,
          style: DsType.small.copyWith(
            color: glyph != null ? ds.text2 : ds.text3,
          ),
        ),
      ?content,
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * kSheetMaxHeightFraction,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: glyph != null ? 28 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  onDismiss == null ? 16 : 10,
                  0,
                ),
                child: header,
              ),
              if (scrolled.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      actions.isEmpty ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: gapped(scrolled, 16),
                    ),
                  ),
                )
              else if (actions.isEmpty)
                const SizedBox(height: 16),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Row(
                    children: [for (final a in actions) Expanded(child: a)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// A text action of a DsDialog: accent, or destructive; the default one is semibold.
class DsDialogAction extends StatelessWidget {
  const DsDialogAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.strong = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final color = destructive ? ds.destructive : ds.textAccent;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: strong ? DsType.button : DsType.text,
      ),
      child: Text(label),
    );
  }
}
