import 'package:flutter/material.dart';

import '../theme.dart';
import '../ui.dart';
import 'glyph.dart';

enum DsLeading { back, close, none }

class DsNavButton extends StatelessWidget {
  const DsNavButton({
    super.key,
    required this.glyph,
    required this.onPressed,
    this.tooltip,
    this.busy = false,
    this.filled = false,
  });

  final Glyph glyph;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool busy;

  final bool filled;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: busy ? null : onPressed,
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(
      width: kNavButton,
      height: kNavButton,
    ),
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size.square(kNavButton),
      backgroundColor: filled ? context.ds.accentAlpha : null,
      disabledForegroundColor: context.ds.icon1.withValues(
        alpha: busy ? 1 : kDisabledOpacity,
      ),
    ),
    icon: busy
        ? const DsSpinner(size: kNavIcon)
        : GlyphIcon(
            glyph,
            size: kNavIcon,
            color: onPressed == null
                ? context.ds.icon1.withValues(alpha: kDisabledOpacity)
                : null,
          ),
  );
}

class DsNavBar extends StatelessWidget implements PreferredSizeWidget {
  const DsNavBar({
    super.key,
    this.leading = DsLeading.back,
    this.onLeading,
    this.actions = const [],
    this.title,
    this.lead,
  });

  final Widget? lead;
  final DsLeading leading;
  final VoidCallback? onLeading;
  final List<Widget> actions;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(kNavRowHeight);

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final lead =
        this.lead ??
        switch (leading) {
          DsLeading.back when canPop || onLeading != null => DsNavButton(
            glyph: Glyph.arrowLeft,
            tooltip: material.backButtonTooltip,
            onPressed: onLeading ?? () => Navigator.of(context).maybePop(),
          ),
          DsLeading.close => DsNavButton(
            glyph: Glyph.x,
            tooltip: material.closeButtonTooltip,
            onPressed: onLeading ?? () => Navigator.of(context).maybePop(),
          ),
          _ => null,
        };
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: kNavRowHeight,
      titleSpacing: kNavGap,
      leadingWidth: kNavPadding + kNavButton,
      leading: lead == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: kNavPadding),
              child: Center(child: lead),
            ),
      actionsPadding: const EdgeInsets.only(right: kNavPadding),
      title: title == null
          ? null
          : Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge!.merge(
                DsType.navTitle.copyWith(color: context.ds.text1),
              ),
            ),
      actions: actions,
    );
  }
}

class DsSubtitle extends StatelessWidget {
  const DsSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: DsType.text.copyWith(color: context.ds.text2));
}

class DsLargeTitle extends StatelessWidget {
  const DsLargeTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final String title;
  final String? subtitle;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsType.h1.copyWith(color: color ?? ds.text1),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: DsType.text.copyWith(color: ds.text2)),
          ],
        ],
      ),
    );
  }
}

// Large-title screen: nav row 48 · title 30/44 · content 16/16/24/16 with groups 24 apart.
class DsPage extends StatelessWidget {
  const DsPage({
    super.key,
    this.title,
    this.subtitle,
    this.leading = DsLeading.back,
    this.onLeading,
    this.actions = const [],
    this.children = const [],
    this.body,
    this.dock = const [],
    this.fab,
    this.gap = kGroupGap,
  });

  final String? title;
  final String? subtitle;
  final DsLeading leading;
  final VoidCallback? onLeading;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? body;
  final List<Widget> dock;
  final Widget? fab;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final content =
        body ??
        ListView(
          padding: kScrollPadding,
          children: gapped([
            if (subtitle != null) DsSubtitle(subtitle!),
            ...children,
          ], gap),
        );
    return Scaffold(
      appBar: DsNavBar(
        leading: leading,
        onLeading: onLeading,
        actions: actions,
        title: title,
      ),
      floatingActionButton: fab,
      body: PageBody(
        child: dock.isEmpty
            ? content
            : Column(
                children: [
                  Expanded(child: content),
                  DsDock(children: dock),
                ],
              ),
      ),
    );
  }
}

class DsDock extends StatelessWidget {
  const DsDock({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: gapped(children, kStackGap),
      ),
    ),
  );
}

List<Widget> gapped(Iterable<Widget> children, double gap) => [
  for (final (i, w) in children.indexed) ...[
    if (i > 0) SizedBox(height: gap),
    w,
  ],
];

class DsStack extends StatelessWidget {
  const DsStack({super.key, required this.children, this.gap = kStackGap});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: gapped(children, gap),
  );
}

class DsCaption extends StatelessWidget {
  const DsCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: DsType.text.copyWith(color: context.ds.text3)),
  );
}

class DsNote extends StatelessWidget {
  const DsNote(this.text, {super.key, this.color, this.align});

  final String text;
  final Color? color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: DsType.small.copyWith(color: color ?? context.ds.text3),
  );
}

// The card surface of the DS: background/surface, r12, a 1 pt border/soft inside (border-width/card).
class DsSurface extends StatelessWidget {
  const DsSurface({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding,
    this.elevation = 0,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets? padding;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Material(
      color: color ?? ds.surface,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(
          color: borderColor ?? ds.borderSoft,
          width: kCardBorder,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

// Card of rows: r12 surface, 1 pt dividers inside the rows, none under the last.
class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.children,
    this.color,
    this.divided = true,
  });

  final List<Widget> children;
  final Color? color;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final line = BoxDecoration(
      border: Border(bottom: BorderSide(color: ds.borderSoft)),
    );
    return DsSurface(
      color: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed)
            divided && i < children.length - 1
                ? DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: line,
                    child: child,
                  )
                : child,
        ],
      ),
    );
  }
}

// Group: caption 16/24 tertiary · 12 · card · 8 · note.
class DsGroup extends StatelessWidget {
  const DsGroup({
    super.key,
    this.caption,
    this.children = const [],
    this.child,
    this.note,
    this.color,
    this.captionGap = kCaptionGap,
  });

  final String? caption;
  final List<Widget> children;
  final Widget? child;
  final String? note;
  final Color? color;
  final double captionGap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (caption != null) ...[
        DsCaption(caption!),
        SizedBox(height: captionGap),
      ],
      child ?? DsCard(color: color, children: children),
      if (note != null) ...[const SizedBox(height: kNoteGap), DsNote(note!)],
    ],
  );
}

class DsSpinner extends StatefulWidget {
  const DsSpinner({super.key, this.size = kRowIcon, this.color});

  final double size;
  final Color? color;

  @override
  State<DsSpinner> createState() => _DsSpinnerState();
}

class _DsSpinnerState extends State<DsSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _spin,
    child: GlyphIcon(Glyph.loader2, size: widget.size, color: widget.color),
  );
}

// DsCard whose rows are dragged by a ReorderableDragStartListener in each row.
class DsReorderableCard<T> extends StatelessWidget {
  const DsReorderableCard({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    required this.onReorder,
  });

  final List<T> items;
  final Key Function(T item) keyOf;
  final Widget Function(int index, T item) itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final line = BoxDecoration(
      border: Border(bottom: BorderSide(color: ds.borderSoft)),
    );
    Widget card(Widget child, {double elevation = 0}) =>
        DsSurface(elevation: elevation, child: child);
    return card(
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorderItem: onReorder,
        proxyDecorator: (child, _, _) => card(child, elevation: 4),
        children: [
          for (final (i, item) in items.indexed)
            DecoratedBox(
              key: keyOf(item),
              position: DecorationPosition.foreground,
              decoration: i < items.length - 1 ? line : const BoxDecoration(),
              child: itemBuilder(i, item),
            ),
        ],
      ),
    );
  }
}

// One row of a DsCard built lazily: rounds its top when first, its bottom when last, a divider in between.
class DsCardSlice extends StatelessWidget {
  const DsCardSlice({
    super.key,
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    const r = Radius.circular(kRadius);
    return Material(
      color: ds.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.vertical(
        top: first ? r : Radius.zero,
        bottom: last ? r : Radius.zero,
      ),
      child: CustomPaint(
        foregroundPainter: _SliceBorder(
          first: first,
          last: last,
          color: ds.borderSoft,
        ),
        child: child,
      ),
    );
  }
}

class _SliceBorder extends CustomPainter {
  _SliceBorder({required this.first, required this.last, required this.color});

  final bool first;
  final bool last;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const h = kCardBorder / 2;
    const r = Radius.circular(kRadius - h);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kCardBorder
      ..color = color;
    // The open ends run past the clip, so only the sides and the rounded ends of the card are stroked.
    final outline = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        h,
        first ? h : -kRadius,
        size.width - h,
        last ? size.height - h : size.height + kRadius,
      ),
      topLeft: first ? r : Radius.zero,
      topRight: first ? r : Radius.zero,
      bottomLeft: last ? r : Radius.zero,
      bottomRight: last ? r : Radius.zero,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRRect(outline, paint);
    canvas.restore();
    if (!last) {
      canvas.drawLine(
        Offset(0, size.height - h),
        Offset(size.width, size.height - h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SliceBorder old) =>
      old.first != first || old.last != last || old.color != color;
}
