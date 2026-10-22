import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_error.dart';
import 'ds.dart';
import 'theme.dart';

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
    padding: const EdgeInsets.fromLTRB(
      kGutter,
      kGroupGap,
      kGutter,
      kCaptionGap,
    ),
    child: DsCaption(text),
  );
}

class SectionNote extends StatelessWidget {
  const SectionNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(kGutter, kNoteGap, kGutter, 0),
    child: DsNote(text),
  );
}

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
          side: BorderSide(color: ds.borderSoft),
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

void showToast(BuildContext context, String message) =>
    showToastWith(ScaffoldMessenger.of(context), message);

void showToastWith(ScaffoldMessengerState messenger, String message) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: messenger.hideCurrentSnackBar,
          child: SizedBox(
            width: double.infinity,
            child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    ),
  );
}

// AlertDialog of the DS: 16 from the screen edges, r12, title 18/24, body 14/18 scrolling within 80% of the screen,
// text actions 40 sharing the row.
class DsDialog extends StatelessWidget {
  const DsDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    this.actions = const [],
    this.glyph,
    this.onDismiss,
    this.dismissTooltip,
  });

  final String title;
  final String? body;
  final Widget? content;
  final List<Widget> actions;
  final Glyph? glyph;
  final VoidCallback? onDismiss;
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (glyph != null) ...[
          GlyphIcon(glyph!),
          const SizedBox(width: kRowGap),
        ],
        Expanded(
          child: Text(title, style: DsType.h3.copyWith(color: ds.text1)),
        ),
        if (onDismiss != null)
          Transform.translate(
            offset: const Offset(0, -6),
            child: DsAction(
              glyph: Glyph.x,
              size: kDialogDismiss,
              iconSize: kSmallIcon,
              tooltip: dismissTooltip,
              onPressed: onDismiss,
            ),
          ),
      ],
    );
    final scrolled = [
      if (body != null)
        Text(
          body!,
          style: DsType.small.copyWith(
            color: glyph != null ? ds.text2 : ds.text3,
          ),
        ),
      ?content,
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * kSheetMaxHeightFraction,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: glyph != null ? 28 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  onDismiss == null ? 16 : 10,
                  0,
                ),
                child: header,
              ),
              if (scrolled.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      actions.isEmpty ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: gapped(scrolled, 16),
                    ),
                  ),
                )
              else if (actions.isEmpty)
                const SizedBox(height: 16),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Row(
                    children: [for (final a in actions) Expanded(child: a)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// A text action of a DsDialog: accent, or destructive; the default one is semibold.
class DsDialogAction extends StatelessWidget {
  const DsDialogAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.strong = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final color = destructive ? ds.destructive : ds.textAccent;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: strong ? DsType.button : DsType.text,
      ),
      child: Text(label),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => DsDialog(
      title: title,
      body: body,
      actions: [
        DsDialogAction(
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.pop(context, false),
        ),
        DsDialogAction(
          label: confirmLabel,
          destructive: destructive,
          strong: !destructive,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<void> showErrorDialog(
  BuildContext context,
  AppError error, {
  VoidCallback? onDismiss,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DsDialog(
      glyph: Glyph.alertTriangle,
      title: error.title,
      body: error.detail,
      dismissTooltip: context.l10n.commonDismiss,
      onDismiss: () => Navigator.of(context).pop(),
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
  bool autocorrect = true,
  String? resetLabel,
  String? resetValue,
  String? Function(String value)? errorOf,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initial: initial,
      hint: hint,
      autocorrect: autocorrect,
      resetLabel: resetLabel,
      resetValue: resetValue,
      errorOf: errorOf,
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
    required this.autocorrect,
    required this.resetLabel,
    required this.resetValue,
    required this.errorOf,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initial;
  final String? hint;

  final bool autocorrect;
  final String? resetLabel;
  final String? resetValue;
  final String? Function(String value)? errorOf;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  )..addListener(() => setState(() {}));

  String? get _error => widget.errorOf?.call(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DsDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: widget.autocorrect,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              errorText: _error,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : DsAction(
                      glyph: Glyph.x,
                      size: kFieldActionButton,
                      iconSize: kSmallIcon,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: _controller.clear,
                    ),
            ),
            onSubmitted: (v) {
              if (_error == null) Navigator.of(context).pop(v);
            },
          ),
          if (widget.resetLabel != null) ...[
            const SizedBox(height: 4),
            DsButton.text(
              label: widget.resetLabel!,
              glyph: Glyph.rotateCcw,
              onPressed: () => _controller.text = widget.resetValue ?? '',
            ),
          ],
        ],
      ),
      actions: [
        DsDialogAction(
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DsDialogAction(
          label: widget.confirmLabel,
          strong: true,
          onPressed: _error == null
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
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

const kTextEditDebounce = Duration(milliseconds: 600);

const double kSheetMaxHeightFraction = 0.8;

const double kQrViewfinder = 294;

const double kQrViewfinderRadius = 12;

const double kQrViewfinderCorner = 78;

const double kQrViewfinderLift = 60;

const double kQrExportSize = 232;

const double kQrScrimOpacity = 0.3;

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

Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required List<Option<T>> options,
  T? selected,
  Set<T> favorites = const {},
  ValueChanged<T>? onToggleFavorite,
  ValueChanged<T>? onOpenSettings,
  bool navigational = false,
  bool radio = false,
  String? itemNoun,
  List<Option<T>> pinned = const [],
  String pinnedHeader = '',
}) {
  return showDsSheet<T>(
    context,
    (context) => _PickSheet<T>(
      title: title,
      options: options,
      selected: selected,
      favorites: favorites,
      onToggleFavorite: onToggleFavorite,
      onOpenSettings: onOpenSettings,
      navigational: navigational,
      radio: radio,
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
    required this.radio,
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
  final bool radio;
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
    final ds = context.ds;
    final favorite = _favorites.contains(o.value);
    final selected = o.value == widget.selected;
    return DsRow(
      leading: widget.radio ? DsRadio(selected: selected) : o.leading,
      title: o.title,
      subtitle: o.subtitle,
      selected: selected,
      enabled: o.enabled,
      onTap: () => Navigator.of(context).pop(o.value),
      trailing: [
        if (widget.onToggleFavorite != null && favouritable)
          DsAction(
            glyph: Glyph.star,
            color: favorite ? ds.textAccent : null,
            tooltip: favorite
                ? l10n.uiRemoveFromFavorites
                : l10n.uiAddToFavorites,
            onPressed: () => _toggle(o.value),
          ),
        if (widget.onOpenSettings != null)
          DsAction(
            glyph: Glyph.settings,
            tooltip: l10n.commonSettings,
            onPressed: () => _openSettings(o.value),
          ),
        if (widget.navigational) const DsChevron(),
      ],
    );
  }

  Widget _group(String? caption, Iterable<Widget> rows) =>
      DsGroup(caption: caption, children: rows.toList());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = widget.options.where(_matches).toList();
    final pinnedShown = widget.pinned.where(_matches).toList();
    final favorites = shown.where((o) => _favorites.contains(o.value)).toList();
    final rest = shown.where((o) => !_favorites.contains(o.value)).toList();
    final searching = _query.trim().isNotEmpty;

    return DsSheet(
      title: widget.title,
      header: widget.options.length >= kSearchThreshold
          ? DsSearchField(
              hint: l10n.commonSearch,
              onChanged: (v) => setState(() => _query = v),
            )
          : null,
      gap: kGroupGap,
      children: [
        if (pinnedShown.isNotEmpty)
          _group(
            widget.pinnedHeader,
            pinnedShown.map((o) => _row(o, favouritable: false)),
          ),
        if (!_grouped)
          if (shown.isEmpty) _nothing(l10n) else _group(null, shown.map(_row))
        else if (searching)
          if (shown.isEmpty)
            _nothing(l10n)
          else ...[
            if (favorites.isNotEmpty)
              _group(l10n.commonFavorites, favorites.map(_row)),
            if (rest.isNotEmpty)
              _group(
                l10n.uiAllMatchCount(rest.length, widget.options.length),
                rest.map(_row),
              ),
          ]
        else ...[
          if (favorites.isNotEmpty)
            _group(l10n.commonFavorites, favorites.map(_row)),
          if (rest.isNotEmpty) _group(l10n.commonAll, rest.map(_row)),
        ],
      ],
    );
  }

  Widget _nothing(AppLocalizations l10n) => _NothingMatches(
    text: l10n.uiNoMatches(
      widget.itemNoun,
      _query.trim(),
      widget.options.length,
    ),
  );
}

class _NothingMatches extends StatelessWidget {
  const _NothingMatches({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: DsType.small.copyWith(color: context.ds.text2),
    ),
  );
}

Future<Set<T>?> pickOptions<T>(
  BuildContext context, {
  required String title,
  required List<Option<T>> options,
  Set<T> selected = const {},
}) {
  return showDsSheet<Set<T>>(
    context,
    (context) =>
        _MultiPickSheet<T>(title: title, options: options, selected: selected),
  );
}

class _MultiPickSheet<T> extends StatefulWidget {
  const _MultiPickSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<Option<T>> options;
  final Set<T> selected;

  @override
  State<_MultiPickSheet<T>> createState() => _MultiPickSheetState<T>();
}

class _MultiPickSheetState<T> extends State<_MultiPickSheet<T>> {
  late final Set<T> _picked = {...widget.selected};
  String _query = '';

  bool _matches(Option<T> o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return o.title.toLowerCase().contains(q) ||
        (o.subtitle?.toLowerCase().contains(q) ?? false);
  }

  void _toggle(T value) => setState(
    () => _picked.contains(value) ? _picked.remove(value) : _picked.add(value),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = widget.options.where(_matches).toList();
    return DsSheet(
      title: widget.title,
      header: widget.options.length >= kSearchThreshold
          ? DsSearchField(
              hint: l10n.commonSearch,
              onChanged: (v) => setState(() => _query = v),
            )
          : null,
      footer: DsButton(
        label: l10n.uiDoneCount(_picked.length),
        onPressed: () => Navigator.of(context).pop(_picked),
      ),
      children: [
        if (shown.isEmpty)
          _NothingMatches(
            text: l10n.uiNoMatches(
              l10n.uiNounItem,
              _query.trim(),
              widget.options.length,
            ),
          )
        else
          DsCard(
            children: [
              for (final o in shown)
                DsRow(
                  leading: o.leading,
                  title: o.title,
                  subtitle: o.subtitle,
                  enabled: o.enabled,
                  onTap: () => _toggle(o.value),
                  trailing: [DsCheck(checked: _picked.contains(o.value))],
                ),
            ],
          ),
      ],
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      getPlatform(context) == TargetPlatform.linux
      ? const _NoFlingScrollPhysics()
      : super.getScrollPhysics(context);
}

class _NoFlingScrollPhysics extends ClampingScrollPhysics {
  const _NoFlingScrollPhysics({super.parent});

  @override
  _NoFlingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _NoFlingScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => super.createBallisticSimulation(position, 0);
}
