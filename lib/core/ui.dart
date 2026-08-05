import 'package:flutter/material.dart';

import 'app_error.dart';

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

/// A toast: three seconds, dismissed by tapping it. No close button — there is
/// nothing to close by hand about a message that leaves on its own. Use it for
/// what is already over (a refresh that failed, a copy that succeeded); if the
/// user has to decide something, they need [showErrorDialog] instead.
void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 3),
    content: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: messenger.hideCurrentSnackBar,
      child: SizedBox(
        width: double.infinity,
        child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    ),
  ));
}

/// An error the user has to acknowledge: centred, with the scrim swallowing
/// taps so Connect and the pickers stay out of reach until it is read. What
/// happened in the title, what to do about it below, and a cross as the only
/// way out — a tap on the scrim would wipe out the reason for the failure by
/// accident. Nothing here occupies space in the layout, so no screen jumps.
///
/// Ordinary dialog surface, not the error palette: being modal is what marks
/// this as a problem, and a red sheet the size of the dialog only fights the
/// rest of the app. Red stays where it points at a spot — the outline of a
/// field with bad input.
///
/// [onDismiss] runs after it closes, so the caller can clear the error it holds;
/// otherwise the next rebuild would raise the dialog again.
Future<void> showErrorDialog(BuildContext context, AppError error,
    {VoidCallback? onDismiss}) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(error.title,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w500, color: cs.onSurface)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: cs.onSurfaceVariant,
              tooltip: 'Dismiss',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        ),
        if (error.detail != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: Text(error.detail!,
                  style: TextStyle(fontSize: 14, height: 1.45, color: cs.onSurfaceVariant)),
            ),
          )
        else
          const SizedBox(height: 20),
      ]),
    ),
  );
  onDismiss?.call();
}

/// Search only earns its place once the list is long enough to scan — the same
/// threshold the on-demand value lists use.
const int kSearchThreshold = 6;

/// A sheet never covers the whole screen: the strip of scrim left above it is
/// what makes it dismissable by a tap, not only by a swipe.
const double kSheetMaxHeightFraction = 0.8;

/// The app's single way to choose from a list: a bottom sheet with a title,
/// the current value marked by a filled row, and disabled rows kept visible
/// (greyed, with their reason in the subtitle) rather than hidden.
///
/// The current value is filled rather than check-marked, which keeps the
/// trailing slot free for actions: [onToggleFavorite] adds a star and splits
/// the list into FAVORITES / ALL, [onOpenSettings] adds a gear that closes the
/// sheet and hands the value back to the caller. Long lists also get a search
/// field; favourites stay on top while filtering.
///
/// With [navigational] the rows carry a chevron instead of promising a choice:
/// the caller treats the returned value as "open this", not "select this". The
/// fill still marks whichever value is current.
Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required List<Option<T>> options,
  T? selected,
  Set<T> favorites = const {},
  ValueChanged<T>? onToggleFavorite,
  ValueChanged<T>? onOpenSettings,
  bool navigational = false,
  String itemNoun = 'item',
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * kSheetMaxHeightFraction,
    ),
    builder: (context) => _PickSheet<T>(
      title: title,
      options: options,
      selected: selected,
      favorites: favorites,
      onToggleFavorite: onToggleFavorite,
      onOpenSettings: onOpenSettings,
      navigational: navigational,
      itemNoun: itemNoun,
    ),
  );
}

class _PickSheet<T> extends StatefulWidget {
  const _PickSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.favorites,
    required this.onToggleFavorite,
    required this.onOpenSettings,
    required this.navigational,
    required this.itemNoun,
  });

  final String title;
  final List<Option<T>> options;
  final T? selected;
  final Set<T> favorites;
  final ValueChanged<T>? onToggleFavorite;
  final ValueChanged<T>? onOpenSettings;
  final bool navigational;
  final String itemNoun;

  @override
  State<_PickSheet<T>> createState() => _PickSheetState<T>();
}

class _PickSheetState<T> extends State<_PickSheet<T>> {
  late final Set<T> _favorites = {...widget.favorites};
  String _query = '';

  bool get _grouped => widget.onToggleFavorite != null || _favorites.isNotEmpty;

  bool _matches(Option<T> o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return o.title.toLowerCase().contains(q) ||
        (o.subtitle?.toLowerCase().contains(q) ?? false);
  }

  void _toggle(T value) {
    setState(() => _favorites.contains(value)
        ? _favorites.remove(value)
        : _favorites.add(value));
    widget.onToggleFavorite!(value);
  }

  /// The gear leaves the sheet first: its screen would otherwise open behind
  /// the sheet, which stays up until the user picks something.
  void _openSettings(T value) {
    Navigator.of(context).pop();
    widget.onOpenSettings!(value);
  }

  Widget _row(Option<T> o) {
    final cs = Theme.of(context).colorScheme;
    final favorite = _favorites.contains(o.value);
    final selected = o.value == widget.selected;
    final actions = <Widget>[
      if (widget.onToggleFavorite != null)
        IconButton(
          icon: Icon(favorite ? Icons.star : Icons.star_border, size: 20),
          color: favorite ? cs.primary : cs.onSurfaceVariant,
          tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () => _toggle(o.value),
        ),
      if (widget.onOpenSettings != null)
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          color: cs.onSurfaceVariant,
          tooltip: 'Settings',
          onPressed: () => _openSettings(o.value),
        ),
      if (widget.navigational) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
    ];
    return Opacity(
      opacity: o.enabled ? 1 : 0.45,
      child: ListTile(
        // Selection is a fill, so the colour is not the only carrier: the tile
        // also reports itself as selected to assistive technology.
        selected: selected,
        selectedTileColor: cs.primaryContainer.withValues(alpha: 0.55),
        leading: o.leading == null
            ? null
            : IconTheme.merge(
                data: IconThemeData(color: selected ? cs.primary : null),
                child: o.leading!,
              ),
        title: Text(o.title),
        subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
        trailing: actions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
        onTap: o.enabled ? () => Navigator.of(context).pop(o.value) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = widget.options.where(_matches).toList();
    final favorites = shown.where((o) => _favorites.contains(o.value)).toList();
    final rest = shown.where((o) => !_favorites.contains(o.value)).toList();
    final searching = _query.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (widget.options.length >= kSearchThreshold)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: TextField(
                autocorrect: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          // Row fills and highlights are Ink, which paints on the nearest
          // Material — the sheet's own, outside the list — so an overscrolled
          // row used to be drawn over the title. A transparent Material here
          // makes the list host its own ink, and the ClipRect bounds it (a
          // shrink-wrapping viewport clips only once its content overflows).
          Flexible(
            child: ClipRect(
              child: Material(
                type: MaterialType.transparency,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (!_grouped)
                      ...shown.map(_row)
                    else ...[
                      if (favorites.isNotEmpty) ...[
                        const SectionHeader('FAVORITES'),
                        ...favorites.map(_row),
                      ],
                      SectionHeader(searching
                          ? 'ALL · ${rest.isEmpty ? 'NOTHING MATCHES' : '${rest.length} OF ${widget.options.length} MATCH'}'
                          : 'ALL'),
                      if (rest.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 8),
                          child: Text(
                            'No ${widget.itemNoun} matches “${_query.trim()}”. '
                            'Clear the search to see all ${widget.options.length}.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      else
                        ...rest.map(_row),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
