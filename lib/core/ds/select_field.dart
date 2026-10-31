import 'package:flutter/material.dart';

import '../theme.dart';
import 'glyph.dart';
import 'rows.dart';

// A text-field-shaped chooser: label 12/14 over the value 16/24, a 40 action on the right.
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing = Glyph.chevronDown,
    this.enabled = true,
  });

  final String label;

  final String value;
  final VoidCallback onTap;
  final Glyph trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Opacity(
      opacity: enabled ? 1 : kDisabledOpacity,
      child: Material(
        color: ds.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
          side: BorderSide(color: ds.borderInput),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: kTextFieldHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: DsType.caption.copyWith(color: ds.text3),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsType.text.copyWith(color: ds.text1),
                        ),
                      ],
                    ),
                  ),
                  DsAction(glyph: trailing, size: kFieldActionButton),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Option<T> {
  const Option(
    this.value,
    this.title, {
    this.subtitle,
    this.enabled = true,
    this.leading,
  });

  final T value;
  final String title;
  final String? subtitle;
  final bool enabled;
  final Widget? leading;
}
