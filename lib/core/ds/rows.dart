import 'package:flutter/material.dart';

import '../theme.dart';
import 'glyph.dart';
import 'ink.dart';

// actionItem, as a ListTile: 56 for one line, 72 for two, 88 for three. Side padding 12, gap 12, text 4 after
// the gap; the 48 actions sit 4 from the edges, the text 8 (12 with a subtitle). Title 18/24, subtitle 14/18.
class DsRow extends StatelessWidget {
  const DsRow({
    super.key,
    this.glyph,
    this.leading,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.subtitleMaxLines = 2,
    this.badge,
    this.titleBadge,
    this.trailing = const [],
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.titleStyle,
    this.subtitleColor,
    this.tooltip,
  });

  final Glyph? glyph;
  final Widget? leading;
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? subtitleWidget;
  final int subtitleMaxLines;

  // Under the title, or right after it on the title line.
  final Widget? badge;
  final Widget? titleBadge;
  final List<Widget> trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool selected;
  final TextStyle? titleStyle;
  final Color? subtitleColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final lead =
        leading ??
        (glyph == null
            ? null
            : GlyphIcon(glyph!, color: selected ? ds.textAccent : null));
    final hasSubtitle =
        subtitleWidget != null || (subtitle != null && subtitle!.isNotEmpty);
    final titleText =
        titleWidget ??
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle ?? DsType.h3.copyWith(color: ds.text1),
        );
    final text = Padding(
      padding: EdgeInsets.only(
        left: lead == null ? 0 : 4,
        top: hasSubtitle || badge != null ? 8 : 4,
        bottom: hasSubtitle || badge != null ? 8 : 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleBadge == null)
            titleText
          else
            Row(
              children: [
                Flexible(child: titleText),
                const SizedBox(width: 8),
                titleBadge!,
              ],
            ),
          if (badge != null) ...[const SizedBox(height: 4), badge!],
          if (subtitleWidget != null) ...[
            const SizedBox(height: 4),
            subtitleWidget!,
          ] else if (hasSubtitle) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: subtitleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: DsType.small.copyWith(color: subtitleColor ?? ds.text3),
            ),
          ],
        ],
      ),
    );
    Widget row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: hasSubtitle || badge != null
            ? kRowHeightTwoLines
            : kRowHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kRowPadding,
          vertical: 4,
        ),
        child: Row(
          children: [
            if (lead != null)
              IconTheme.merge(
                data: const IconThemeData(size: kRowIcon),
                child: lead,
              ),
            if (lead != null) const SizedBox(width: kRowGap),
            Expanded(child: text),
            for (final t in trailing) ...[const SizedBox(width: kRowGap), t],
          ],
        ),
      ),
    );
    row = DsInk(
      color: selected ? ds.accentSubtle : Colors.transparent,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: row,
    );
    if (tooltip != null) row = Tooltip(message: tooltip!, child: row);
    return enabled
        ? Semantics(selected: selected, child: row)
        : Opacity(opacity: kDisabledOpacity, child: row);
  }
}

// actionButton 48: p8 around a 24 icon, r12.
class DsAction extends StatelessWidget {
  const DsAction({
    super.key,
    required this.glyph,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = kActionButton,
    this.iconSize = kRowIcon,
    this.busy = false,
  });

  final Glyph glyph;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  final double iconSize;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final icon = busy
        ? SizedBox.square(dimension: iconSize, child: const _RowSpinner())
        : GlyphIcon(glyph, size: iconSize, color: color);
    if (onPressed == null && !busy) {
      return SizedBox.square(
        dimension: size,
        child: Center(child: icon),
      );
    }
    return IconButton(
      onPressed: busy ? null : onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.square(size),
      ),
      icon: icon,
    );
  }
}

class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(2),
    child: CircularProgressIndicator(strokeWidth: 2, color: context.ds.icon1),
  );
}

// Trailing chevron: a 48 slot so the text column lines up with the rows that have actions.
class DsChevron extends StatelessWidget {
  const DsChevron({super.key, this.down = false, this.locked = false});

  final bool down;
  final bool locked;

  @override
  Widget build(BuildContext context) => DsAction(
    glyph: locked
        ? Glyph.lock
        : down
        ? Glyph.chevronDown
        : Glyph.chevronRight,
  );
}

class DsToggle extends StatelessWidget {
  const DsToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = onChanged != null;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final toggle = AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 150),
      width: kToggleWidth,
      height: kToggleHeight,
      padding: const EdgeInsets.all(5),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? ds.selected : ds.surfaceAlt,
        borderRadius: BorderRadius.circular(kToggleHeight / 2),
        border: Border.all(color: value ? ds.accentDark : ds.borderSoft),
      ),
      child: Container(
        width: kToggleKnob,
        height: kToggleKnob,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? ds.accentLight : ds.icon2,
          boxShadow: value
              ? [BoxShadow(color: ds.accentAlpha, blurRadius: 8)]
              : null,
        ),
      ),
    );
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : kDisabledOpacity,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: toggle,
          ),
        ),
      ),
    );
  }
}

class DsCheck extends StatelessWidget {
  const DsCheck({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => DsAction(
    glyph: checked ? Glyph.checkSquare : Glyph.square,
    color: checked ? context.ds.accent : null,
  );
}
