import 'package:flutter/material.dart';

import '../theme.dart';

// A pressable DS surface: hover and pressed are state layers over it, keyboard focus is a border/focus ring.
class DsInk extends StatefulWidget {
  const DsInk({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color = Colors.transparent,
    this.radius = kRadius,
    this.side = BorderSide.none,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final double radius;
  final BorderSide side;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<DsInk> createState() => _DsInkState();
}

class _DsInkState extends State<DsInk> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    return Material(
      color: widget.color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: _focused
            ? BorderSide(color: context.ds.borderFocus, width: kFocusRing)
            : widget.side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        borderRadius: radius,
        onFocusChange: (f) {
          final shown =
              f &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional;
          if (shown != _focused) setState(() => _focused = shown);
        },
        child: widget.child,
      ),
    );
  }
}
