import 'package:flutter/material.dart';

import '../theme.dart';
import 'controls.dart';
import 'glyph.dart';

// notification (inline): r12 on background/surface.
// regular — p16, icon 24, gap 12, title 14/18 (or 16/24 bold), body 14/18 text/secondary, action 16 below;
// small — p12, icon 18, gap 8, text 14/18.
class DsNotification extends StatelessWidget {
  const DsNotification({
    super.key,
    required this.title,
    this.body,
    this.glyph = Glyph.info,
    this.tone = DsTone.neutral,
    this.boldTitle = false,
    this.small = false,
    this.action,
    this.onTap,
  });

  final String title;
  final String? body;
  final Glyph glyph;
  final DsTone tone;
  final bool boldTitle;
  final bool small;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final iconColor = switch (tone) {
      DsTone.warning => ds.warning,
      DsTone.destructive => ds.destructive,
      DsTone.success => ds.success,
      DsTone.accent => ds.accent,
      DsTone.neutral => ds.icon1,
    };
    final iconSize = small ? 18.0 : kRowIcon;
    final titleStyle = boldTitle
        ? DsType.h4.copyWith(color: ds.text1)
        : DsType.small.copyWith(color: ds.text1);
    return Material(
      color: ds.surface,
      borderRadius: BorderRadius.circular(kRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(small ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlyphIcon(glyph, size: iconSize, color: iconColor),
                  SizedBox(width: small ? 8 : kRowGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: titleStyle),
                        if (body != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            body!,
                            style: DsType.small.copyWith(color: ds.text2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

// sticky alert state=info: a state, not an event — background/selected, 1 pt border/brand, no buttons.
class DsStickyAlert extends StatelessWidget {
  const DsStickyAlert({
    super.key,
    required this.title,
    this.body,
    this.glyph = Glyph.zap,
    this.onTap,
  });

  final String title;
  final String? body;
  final Glyph glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Material(
      color: ds.selected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: ds.borderBrand),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              GlyphIcon(glyph, color: ds.accent),
              const SizedBox(width: kRowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: DsType.small.copyWith(color: ds.text1)),
                    if (body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        body!,
                        style: DsType.small.copyWith(color: ds.text2),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Empty state: centred title 16/24 text/secondary (or 18/24 primary as a heading), body and hint below.
class DsEmptyState extends StatelessWidget {
  const DsEmptyState({
    super.key,
    this.heading,
    required this.title,
    this.hint,
    this.glyph,
  });

  final String? heading;
  final String title;
  final String? hint;
  final Glyph? glyph;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            GlyphIcon(glyph!, size: 48),
            const SizedBox(height: 12),
          ],
          if (heading != null) ...[
            Text(
              heading!,
              textAlign: TextAlign.center,
              style: DsType.h3.copyWith(color: ds.text1),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: DsType.text.copyWith(color: ds.text2),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: DsType.small.copyWith(color: ds.text3),
            ),
          ],
        ],
      ),
    );
  }
}

// Progress line: 4 pt, r2, track background/panel, fill accent/light (warning when spent).
class DsProgress extends StatelessWidget {
  const DsProgress({super.key, required this.value, this.warning = false});

  final double value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 4,
        backgroundColor: ds.panel,
        color: warning ? ds.warning : ds.accentLight,
      ),
    );
  }
}
