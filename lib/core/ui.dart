import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_error.dart';
import 'ds.dart';
import 'theme.dart';

const double kGutter = 16;

const EdgeInsets kTvSafeArea = EdgeInsets.symmetric(
  horizontal: 48,
  vertical: 27,
);

const double kWideMinWidth = 720;
const double kWideMaxHeight = 600;
const double kWideColumnGap = 48;
const double kWideHeroColumn = 360;
const double kWideSideColumn = 340;

bool isWideLandscape(Size size) =>
    size.width >= kWideMinWidth && size.height < kWideMaxHeight;

const double kTransferTile = 300;
const double kTransferCode = 276;
const double kTransferTileSmall = 232;
const double kTransferCodeSmall = 208;
const double kTransferStepBadge = 28;

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

const double kQrViewfinder = 294;

const double kQrViewfinderRadius = 12;

const double kQrViewfinderCorner = 78;

const double kQrViewfinderLift = 60;

const double kQrScrimOpacity = 0.3;

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
            glyph: favorite ? Glyph.starFilled : Glyph.star,
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
