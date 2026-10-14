import 'package:flutter/material.dart';

import '../theme.dart';
import 'glyph.dart';
import 'layout.dart';

enum DsButtonKind { primary, tonal, destructive, text }

// DS button size=large: 48, r12, p8/12, gap 4, label 16/24.
class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    this.kind = DsButtonKind.primary,
    this.glyph,
    this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
    this.focusNode,
    this.autofocus = false,
  });

  const DsButton.tonal({
    super.key,
    required this.label,
    this.glyph,
    this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
    this.focusNode,
    this.autofocus = false,
  }) : kind = DsButtonKind.tonal;

  const DsButton.destructive({
    super.key,
    required this.label,
    this.glyph,
    this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.expand = true,
    this.focusNode,
    this.autofocus = false,
  }) : kind = DsButtonKind.destructive;

  const DsButton.text({
    super.key,
    required this.label,
    this.glyph,
    this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
  }) : kind = DsButtonKind.text;

  final String label;
  final DsButtonKind kind;
  final Glyph? glyph;
  final VoidCallback? onPressed;

  // The spinner replaces the icon (or the label when there is no busy label).
  final bool busy;
  final String? busyLabel;
  final bool expand;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = onPressed != null && !busy;
    // A muted tonal or text button keeps its fill and greys the label (DS state=muted).
    final muted = !enabled && !busy;
    final (bg, fg, iconColor, side, style) = switch (kind) {
      DsButtonKind.primary => (
        ds.buttonPrimary,
        ds.textInverted,
        ds.textInverted,
        null,
        DsType.button,
      ),
      DsButtonKind.tonal => (
        ds.selected,
        muted ? ds.text4 : ds.text2,
        muted ? ds.icon3 : ds.icon1,
        null,
        DsType.button,
      ),
      DsButtonKind.destructive => (
        ds.surface,
        ds.destructive,
        ds.destructive,
        BorderSide(color: ds.borderSoft),
        DsType.button,
      ),
      DsButtonKind.text => (
        Colors.transparent,
        muted ? ds.text4 : ds.textAccent,
        muted ? ds.icon3 : ds.icon2,
        null,
        DsType.text,
      ),
    };
    final showLabel = !busy || busyLabel != null || glyph != null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          DsSpinner(color: iconColor)
        else if (glyph != null)
          GlyphIcon(glyph!, color: iconColor),
        if (showLabel) ...[
          if (busy || glyph != null) const SizedBox(width: 4),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Text(
                busy ? busyLabel ?? label : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(color: fg),
              ),
            ),
          ),
        ],
      ],
    );
    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: side ?? BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        focusNode: focusNode,
        autofocus: autofocus,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kButtonHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
    final dimmed = kind == DsButtonKind.primary && muted;
    final sized = expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? busyLabel ?? label : null,
      child: Opacity(opacity: dimmed ? kDisabledOpacity : 1, child: sized),
    );
  }
}

// Segmented Control: large 48 / compact 30; the selected item is background/selected with a 1 pt accent/light ring.
class DsSegmented<T> extends StatelessWidget {
  const DsSegmented({
    super.key,
    required this.segments,
    required this.value,
    this.onChanged,
    this.compact = false,
  });

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = onChanged != null;
    final radius = BorderRadius.circular(kRadius);
    return Opacity(
      opacity: enabled ? 1 : kDisabledOpacity,
      child: Container(
        height: compact ? kSegmentedCompactHeight : kSegmentedHeight,
        decoration: BoxDecoration(color: ds.controlTrack, borderRadius: radius),
        child: Row(
          children: [
            for (final (v, label) in segments)
              Expanded(
                child: Semantics(
                  selected: v == value,
                  button: true,
                  child: Material(
                    color: v == value ? ds.selected : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: radius,
                      side: v == value
                          ? BorderSide(color: ds.accentLight)
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled && v != value ? () => onChanged!(v) : null,
                      child: Center(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (compact ? DsType.small : DsType.text)
                              .copyWith(color: ds.text1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Chips size=S: 34, r12, p8/14; selected = background/selected with a 2 pt accent ring.
class DsChip extends StatelessWidget {
  const DsChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.removeTooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? ds.selected : ds.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
          side: selected
              ? BorderSide(color: ds.accent, width: 2)
              : BorderSide(color: ds.borderBold),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: kChipHeight,
            child: Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: onRemove == null ? 14 : 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsType.small.copyWith(
                        color: selected ? ds.text1 : ds.text2,
                      ),
                    ),
                  ),
                  if (onRemove != null) ...[
                    const SizedBox(width: 4),
                    InkResponse(
                      onTap: onRemove,
                      radius: 14,
                      child: Tooltip(
                        message: removeTooltip ?? '',
                        child: GlyphIcon(Glyph.x, size: 18, color: ds.icon2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Chips size=M selected: a removable value — filled background/selected-strong, text inverted.
class DsValueChip extends StatelessWidget {
  const DsValueChip({
    super.key,
    required this.label,
    this.onRemove,
    this.removeTooltip,
  });

  final String label;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Container(
      height: 36,
      padding: EdgeInsets.only(left: 12, right: onRemove == null ? 12 : 6),
      decoration: BoxDecoration(
        color: ds.selectedStrong,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsType.text.copyWith(color: ds.textInverted),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: removeTooltip ?? '',
              child: Semantics(
                button: true,
                label: removeTooltip,
                child: InkResponse(
                  onTap: onRemove,
                  radius: 16,
                  child: GlyphIcon(Glyph.x, size: 20, color: ds.iconInverted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum DsTone { neutral, success, destructive, accent, warning }

// Badge: 22, p4/8, r8, a 1 pt ring in the status colour, label 12/14.
class DsBadge extends StatelessWidget {
  const DsBadge(this.label, {super.key, this.tone = DsTone.neutral});

  final String label;
  final DsTone tone;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final (fg, ring) = switch (tone) {
      DsTone.success => (ds.badgeSuccess, ds.success),
      DsTone.destructive => (ds.badgeDestructive, ds.destructive),
      DsTone.accent => (ds.textAccent, ds.borderBrand),
      DsTone.warning => (ds.warning, ds.warning),
      DsTone.neutral => (ds.text2, ds.borderMedium),
    };
    return Container(
      height: kBadgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ring),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: DsType.caption.copyWith(color: fg)),
      ),
    );
  }
}

// searchField: 56, p16, gap 12, r12, surface-alt, 1 pt border/field.
class DsSearchField extends StatefulWidget {
  const DsSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
    this.clearTooltip,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final String? clearTooltip;

  @override
  State<DsSearchField> createState() => _DsSearchFieldState();
}

class _DsSearchFieldState extends State<DsSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadius),
      borderSide: BorderSide(color: ds.borderField),
    );
    return SizedBox(
      height: kSearchFieldHeight,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        autocorrect: false,
        textAlignVertical: TextAlignVertical.center,
        style: DsType.text.copyWith(color: ds.text1),
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v);
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: DsType.text.copyWith(color: ds.text3),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: ds.borderFocus),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: GlyphIcon(Glyph.search),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 52),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: widget.clearTooltip,
                  icon: const GlyphIcon(Glyph.xCircle),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
