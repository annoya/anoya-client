import 'package:flutter/material.dart';

/// Shared layout constants so every screen uses the same spacing.
const double kGutter = 16; // horizontal screen gutter (card margins, headers)
const double kMaxContentWidth = 560; // cap content width on wide/desktop windows

/// Standard card margin: the horizontal gutter + a small vertical gap.
const EdgeInsets kCardMargin = EdgeInsets.symmetric(horizontal: kGutter, vertical: 4);

/// Centers and width-caps page content so layouts stay readable when the
/// window is resized wide (macOS) instead of stretching edge to edge, and are
/// consistent across screens. Wrap a Scaffold body in it.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: child,
        ),
      );
}

/// A settings/list section label (uppercase, muted), aligned to [kGutter].
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 8),
        child: Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey)),
      );
}
