import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_error.dart';

const double kGutter = 16;
const double kMaxContentWidth = 560;

const EdgeInsets kCardMargin = EdgeInsets.symmetric(
  horizontal: kGutter,
  vertical: 4,
);

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

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class SectionNote extends StatelessWidget {
  const SectionNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 0),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

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
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
            Icon(trailingIcon, size: 20, color: cs.onSurfaceVariant),
          ],
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

void showToast(BuildContext context, String message) =>
    showToastWith(ScaffoldMessenger.of(context), message);

void showToastWith(ScaffoldMessengerState messenger, String message) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: messenger.hideCurrentSnackBar,
        child: SizedBox(
          width: double.infinity,
          child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ),
    ),
  );
}

Future<void> showErrorDialog(
  BuildContext context,
  AppError error, {
  VoidCallback? onDismiss,
}) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    error.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: cs.onSurfaceVariant,
                  tooltip: context.l10n.commonDismiss,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (error.detail != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  error.detail!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    ),
  );
  onDismiss?.call();
}

// Flutter keeps a text field focused on an outside touch (mobile), leaving the keyboard up.
class DismissKeyboardOnTapOutside extends StatelessWidget {
  const DismissKeyboardOnTapOutside({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      EditableTextTapOutsideIntent:
          CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
    },
    child: child,
  );
}

// Disposing after `await showDialog` races the fade-out, whose TextField still listens.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String initial = '',
  String? hint,
  bool longValue = false,
  bool autocorrect = true,
  String? resetLabel,
  String? resetValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initial: initial,
      hint: hint,
      longValue: longValue,
      autocorrect: autocorrect,
      resetLabel: resetLabel,
      resetValue: resetValue,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initial,
    required this.hint,
    required this.longValue,
    required this.autocorrect,
    required this.resetLabel,
    required this.resetValue,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initial;
  final String? hint;

  final bool longValue;
  final bool autocorrect;
  final String? resetLabel;
  final String? resetValue;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: widget.autocorrect,
            maxLines: widget.longValue ? kLongValueMaxLines : 1,
            minLines: 1,
            style: widget.longValue
                ? Theme.of(context).textTheme.bodySmall
                : null,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          if (widget.resetLabel != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(widget.resetLabel!),
                onPressed: () => _controller.text = widget.resetValue ?? '',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

String formatBytes(int n) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (n >= gb) return '${(n / gb).toStringAsFixed(2)} GB';
  if (n >= mb) return '${(n / mb).toStringAsFixed(1)} MB';
  if (n >= 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
  return '$n B';
}

const int kSearchThreshold = 6;

const int kLongValueMaxLines = 4;

const kTextEditDebounce = Duration(milliseconds: 600);

const double kSheetMaxHeightFraction = 0.8;

const double kStatusChipHeight = 30;

Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required List<Option<T>> options,
  T? selected,
  Set<T> favorites = const {},
  ValueChanged<T>? onToggleFavorite,
  ValueChanged<T>? onOpenSettings,
  bool navigational = false,
  String? itemNoun,
  List<Option<T>> pinned = const [],
  String pinnedHeader = '',
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
      itemNoun: itemNoun ?? context.l10n.uiNounItem,
      pinned: pinned,
      pinnedHeader: pinnedHeader,
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
    required this.pinned,
    required this.pinnedHeader,
  });

  final String title;
  final List<Option<T>> options;
  final T? selected;
  final Set<T> favorites;
  final ValueChanged<T>? onToggleFavorite;
  final ValueChanged<T>? onOpenSettings;
  final bool navigational;
  final String itemNoun;

  final List<Option<T>> pinned;
  final String pinnedHeader;

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
    setState(
      () => _favorites.contains(value)
          ? _favorites.remove(value)
          : _favorites.add(value),
    );
    widget.onToggleFavorite!(value);
  }

  void _openSettings(T value) {
    Navigator.of(context).pop();
    widget.onOpenSettings!(value);
  }

  Widget _row(Option<T> o, {bool favouritable = true}) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final favorite = _favorites.contains(o.value);
    final selected = o.value == widget.selected;
    final actions = <Widget>[
      if (widget.onToggleFavorite != null && favouritable)
        IconButton(
          icon: Icon(favorite ? Icons.star : Icons.star_border, size: 20),
          color: favorite ? cs.primary : cs.onSurfaceVariant,
          tooltip: favorite
              ? l10n.uiRemoveFromFavorites
              : l10n.uiAddToFavorites,
          onPressed: () => _toggle(o.value),
        ),
      if (widget.onOpenSettings != null)
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          color: cs.onSurfaceVariant,
          tooltip: l10n.commonSettings,
          onPressed: () => _openSettings(o.value),
        ),
      if (widget.navigational)
        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
    ];
    return Opacity(
      opacity: o.enabled ? 1 : 0.45,
      child: ListTile(
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
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final shown = widget.options.where(_matches).toList();
    final pinnedShown = widget.pinned.where(_matches).toList();
    final favorites = shown.where((o) => _favorites.contains(o.value)).toList();
    final rest = shown.where((o) => !_favorites.contains(o.value)).toList();
    final searching = _query.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (widget.options.length >= kSearchThreshold)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: TextField(
                  autocorrect: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.commonSearch,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            // Transparent Material + ClipRect: list ink otherwise paints over the title on overscroll.
            Flexible(
              child: ClipRect(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (pinnedShown.isNotEmpty) ...[
                        SectionHeader(widget.pinnedHeader),
                        ...pinnedShown.map((o) => _row(o, favouritable: false)),
                      ],
                      if (!_grouped)
                        ...shown.map(_row)
                      else ...[
                        if (favorites.isNotEmpty) ...[
                          SectionHeader(l10n.commonFavorites),
                          ...favorites.map(_row),
                        ],
                        SectionHeader(
                          !searching
                              ? l10n.commonAll
                              : rest.isEmpty
                              ? l10n.uiAllNothingMatches
                              : l10n.uiAllMatchCount(
                                  rest.length,
                                  widget.options.length,
                                ),
                        ),
                        if (rest.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              kGutter,
                              0,
                              kGutter,
                              8,
                            ),
                            child: Text(
                              l10n.uiNoMatches(
                                widget.itemNoun,
                                _query.trim(),
                                widget.options.length,
                              ),
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
          ],
        ),
      ),
    );
  }
}
