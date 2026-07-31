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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                )),
      );
}

/// A choice field that looks like the text fields next to it (same fill,
/// radius and floating label) and opens a bottom sheet instead of a native
/// dropdown menu — a popup menu would land over the dialog title with its own
/// surface, highlight and radii, which reads as a different design language.
/// Use [pickOption] for the sheet.
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailingIcon = Icons.expand_more,
    this.enabled = true,
  });

  final String label;

  /// Rendered as-is, so callers can pass "🇷🇺  Russia (RU)".
  final String value;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: enabled),
        child: Row(children: [
          Expanded(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    color: enabled ? cs.onSurface : cs.onSurfaceVariant)),
          ),
          Icon(trailingIcon, size: 20, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// One row of a [pickOption] sheet.
class Option<T> {
  const Option(this.value, this.title, {this.subtitle, this.enabled = true, this.leading});

  final T value;
  final String title;
  final String? subtitle;
  final bool enabled;
  final Widget? leading;
}

/// The app's single way to choose from a list: a bottom sheet with a title,
/// the current value checked, and disabled rows kept visible (greyed, with
/// their reason in the subtitle) rather than hidden.
Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required List<Option<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map((o) => Opacity(
                        opacity: o.enabled ? 1 : 0.45,
                        child: ListTile(
                          leading: o.leading,
                          title: Text(o.title),
                          subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
                          trailing: o.value == selected
                              ? Icon(Icons.check, color: cs.primary)
                              : null,
                          onTap: o.enabled ? () => Navigator.of(context).pop(o.value) : null,
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      );
    },
  );
}
