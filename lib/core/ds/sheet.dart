import 'package:flutter/material.dart';

import '../theme.dart';
import 'layout.dart';

const double kSheetMaxHeightFraction = 0.8;

Future<T?> showDsSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * kSheetMaxHeightFraction,
      ),
      builder: builder,
    );

class DsSheet extends StatelessWidget {
  const DsSheet({
    super.key,
    this.title,
    this.header,
    required this.children,
    this.footer,
    this.gap = 16,
  });

  final String? title;
  final Widget? header;
  final List<Widget> children;
  final Widget? footer;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  title!,
                  style: DsType.h2.copyWith(color: context.ds.text1),
                ),
              ),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: header!,
              ),
            // Transparent Material + ClipRect: list ink otherwise paints over the title on overscroll.
            Flexible(
              child: ClipRect(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: gapped(children, gap),
                  ),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}
