import 'package:flutter/material.dart';

const double kRadius = 12;
const double kSnackbarRadius = 10;
const double kFabRadius = 16;

const double kRowHeight = 56;
const double kRowPadding = 16;
const double kRowTextPadding = 10;
const double kRowGap = 12;
const double kRowIcon = 24;
const double kAppIconRadius = 6;
const double kActionButton = 40;
const double kFieldActionButton = 40;
const double kNavRowHeight = 56;
const double kNavButton = 48;
const double kNavIcon = 24;
const double kNavPadding = 4;
const double kNavGap = 8;
const double kDialogDismiss = 36;
const double kSmallIcon = 20;
const double kCardPadding = 12;
const double kTextFieldHeight = 56;
const double kSearchFieldHeight = 44;
const double kSegmentedHeight = 48;
const double kSegmentedCompactHeight = 30;
const double kButtonHeight = 48;
const double kChipHeight = 34;
const double kBadgeHeight = 22;
const double kToggleWidth = 50;
const double kToggleHeight = 30;
const double kToggleKnob = 20;
const double kRadioSize = 24;
const double kFabSize = 56;
const double kFabBottom = 48;
const double kConnectButtonWidth = 200;
const int kExpiryWarnDays = 3;
const double kExpiryWarnTraffic = 0.9;

const double kGroupGap = 24;
const double kCaptionGap = 12;
const double kStackGap = 12;
const double kNoteGap = 8;
const EdgeInsets kScrollPadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

const double kDisabledOpacity = 0.4;
const double kHoverLayer = 0.08;
const double kPressedLayer = 0.10;
const double kFocusRing = 2;
const double kCardBorder = 1;
const double kTextButtonHeight = 40;

@immutable
class DsColors extends ThemeExtension<DsColors> {
  const DsColors({
    required this.base,
    required this.surface,
    required this.surfaceAlt,
    required this.dialog,
    required this.panel,
    required this.overlay,
    required this.selected,
    required this.selectedStrong,
    required this.accentSubtle,
    required this.controlTrack,
    required this.inverse,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.textAccent,
    required this.textInverted,
    required this.icon1,
    required this.icon2,
    required this.icon3,
    required this.iconInverted,
    required this.accent,
    required this.accentDark,
    required this.accentLight,
    required this.accentAlpha,
    required this.buttonPrimary,
    required this.borderSoft,
    required this.borderFaint,
    required this.borderField,
    required this.borderFocus,
    required this.borderBold,
    required this.borderMedium,
    required this.borderBrand,
    required this.success,
    required this.warning,
    required this.destructive,
    required this.badgeSuccess,
    required this.badgeDestructive,
    required this.chroma,
    required this.catEye,
    required this.shadow1,
    required this.shadow2,
  });

  final Color base;
  final Color surface;
  final Color surfaceAlt;
  final Color dialog;
  final Color panel;
  final Color overlay;
  final Color selected;
  final Color selectedStrong;
  final Color accentSubtle;
  final Color controlTrack;
  final Color inverse;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color text4;
  final Color textAccent;
  final Color textInverted;
  final Color icon1;
  final Color icon2;
  final Color icon3;
  final Color iconInverted;
  final Color accent;
  final Color accentDark;
  final Color accentLight;
  final Color accentAlpha;
  final Color buttonPrimary;
  final Color borderSoft;
  final Color borderFaint;
  final Color borderField;
  final Color borderFocus;
  final Color borderBold;
  final Color borderMedium;
  final Color borderBrand;
  final Color success;
  final Color warning;
  final Color destructive;
  final Color badgeSuccess;
  final Color badgeDestructive;
  final Color chroma;
  final Color catEye;
  final List<BoxShadow> shadow1;
  final List<BoxShadow> shadow2;

  static const light = DsColors(
    base: Color(0xFFF3F4F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE3E4E9),
    dialog: Color(0xFFF3F4F8),
    panel: Color(0xFFDFE0E5),
    overlay: Color(0x4D08090E),
    selected: Color(0xFFEEF2FF),
    selectedStrong: Color(0xFF4F46E5),
    accentSubtle: Color(0x4D6366F1),
    controlTrack: Color(0xFFE3E4E9),
    inverse: Color(0xFF17181E),
    text1: Color(0xFF17181E),
    text2: Color(0xFF3E3F46),
    text3: Color(0xFF575960),
    text4: Color(0xFF6B6D74),
    textAccent: Color(0xFF4338CA),
    textInverted: Color(0xFFF3F4F8),
    icon1: Color(0xFF17181E),
    icon2: Color(0xFF3E3F46),
    icon3: Color(0xFF51535A),
    iconInverted: Color(0xFFF3F4F8),
    accent: Color(0xFF4F46E5),
    accentDark: Color(0xFF4338CA),
    accentLight: Color(0xFF7881F6),
    accentAlpha: Color(0x806366F1),
    buttonPrimary: Color(0xFF4F46E5),
    borderSoft: Color(0xFFD3D4D9),
    borderFaint: Color(0xFFE3E4E9),
    borderField: Color(0xFF85878D),
    borderFocus: Color(0xFF4F46E5),
    borderBold: Color(0xFF797B82),
    borderMedium: Color(0xFF85878D),
    borderBrand: Color(0xFF7881F6),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    destructive: Color(0xFFB91C1C),
    badgeSuccess: Color(0xFF065F46),
    badgeDestructive: Color(0xFFBE123C),
    chroma: Color(0xFFA5B4FC),
    catEye: Color(0xFFA5B4FC),
    shadow1: [
      BoxShadow(color: Color(0x14000000), offset: Offset(0, 4), blurRadius: 12),
    ],
    shadow2: [
      BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 2),
    ],
  );

  static const dark = DsColors(
    base: Color(0xFF0F1016),
    surface: Color(0xFF17181E),
    surfaceAlt: Color(0xFF1E1F25),
    dialog: Color(0xFF1E1F25),
    panel: Color(0xFF3E3F46),
    overlay: Color(0x8008090E),
    selected: Color(0x4D6366F1),
    selectedStrong: Color(0xFFA5B4FC),
    accentSubtle: Color(0x4D818CF8),
    controlTrack: Color(0xFF1E1F25),
    inverse: Color(0xFFE3E4E9),
    text1: Color(0xFFF3F4F8),
    text2: Color(0xFFE3E4E9),
    text3: Color(0xFFA0A2A8),
    text4: Color(0xFF85878D),
    textAccent: Color(0xFFC7D2FE),
    textInverted: Color(0xFF08090E),
    icon1: Color(0xFFE3E4E9),
    icon2: Color(0xFFA0A2A8),
    icon3: Color(0xFF3E3F46),
    iconInverted: Color(0xFF08090E),
    accent: Color(0xFFA5B4FC),
    accentDark: Color(0xFF7881F6),
    accentLight: Color(0xFFC7D2FE),
    accentAlpha: Color(0x80818CF8),
    buttonPrimary: Color(0xFFA5B4FC),
    borderSoft: Color(0xFF3E3F46),
    borderFaint: Color(0xFF303138),
    borderField: Color(0xFF51535A),
    borderFocus: Color(0xFFC7D2FE),
    borderBold: Color(0xFFA0A2A8),
    borderMedium: Color(0xFF51535A),
    borderBrand: Color(0xFFC7D2FE),
    success: Color(0xFF6EE7B7),
    warning: Color(0xFFFDBA74),
    destructive: Color(0xFFF87171),
    badgeSuccess: Color(0xFF6EE7B7),
    badgeDestructive: Color(0xFFFB7185),
    chroma: Color(0xFFA5B4FC),
    catEye: Color(0xFFA5B4FC),
    shadow1: [
      BoxShadow(
        color: Color(0x26000000),
        offset: Offset(0, 4),
        blurRadius: 8,
        spreadRadius: 3,
      ),
    ],
    shadow2: [
      BoxShadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 3),
    ],
  );

  @override
  DsColors copyWith() => this;

  // Light and dark swap whole; nothing animates between them.
  @override
  DsColors lerp(DsColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

abstract final class DsType {
  static const h1 = TextStyle(
    fontSize: 30,
    height: 44 / 30,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );
  static const h2 = TextStyle(
    fontSize: 24,
    height: 36 / 24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
  static const h3 = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
  );
  static const navTitle = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const h4 = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );
  static const text = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
  );
  static const button = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );
  static const small = TextStyle(
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const subtitle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 14 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}

extension DsColorsX on BuildContext {
  DsColors get ds => Theme.of(this).extension<DsColors>()!;
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? DsColors.dark : DsColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.textInverted,
    primaryContainer: c.selected,
    onPrimaryContainer: c.text1,
    secondary: c.accentDark,
    onSecondary: c.textInverted,
    secondaryContainer: c.selected,
    onSecondaryContainer: c.text2,
    tertiary: c.accentLight,
    onTertiary: c.textInverted,
    error: c.destructive,
    onError: c.textInverted,
    surface: c.base,
    onSurface: c.text1,
    onSurfaceVariant: c.text3,
    surfaceContainerLowest: c.base,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surfaceAlt,
    surfaceContainerHighest: c.surfaceAlt,
    outline: c.borderBold,
    outlineVariant: c.borderSoft,
    inverseSurface: c.inverse,
    onInverseSurface: c.textInverted,
    inversePrimary: c.accentLight,
    scrim: c.overlay,
    shadow: Colors.black,
  );
  final text = TextTheme(
    headlineMedium: DsType.h1.copyWith(color: c.text1),
    headlineSmall: DsType.h2.copyWith(color: c.text1),
    titleLarge: DsType.h3.copyWith(color: c.text1),
    titleMedium: DsType.text.copyWith(color: c.text1),
    titleSmall: DsType.small.copyWith(color: c.text1),
    bodyLarge: DsType.text.copyWith(color: c.text1),
    bodyMedium: DsType.small.copyWith(color: c.text1),
    bodySmall: DsType.caption.copyWith(color: c.text3),
    labelLarge: DsType.button.copyWith(color: c.text1),
    labelMedium: DsType.small.copyWith(color: c.text3),
    labelSmall: DsType.caption.copyWith(color: c.text3),
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kRadius),
  );
  DsFieldBorder field(Color color) => DsFieldBorder(color);
  WidgetStateProperty<Color?> stateLayer(Color on) =>
      WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed)
            ? on.withValues(alpha: kPressedLayer)
            : s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
            ? on.withValues(alpha: kHoverLayer)
            : Colors.transparent,
      );
  final focusRing = WidgetStateProperty.resolveWith<BorderSide?>(
    (s) => s.contains(WidgetState.focused)
        ? BorderSide(color: c.borderFocus, width: kFocusRing)
        : null,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: c.base,
    canvasColor: c.base,
    extensions: [c],
    iconTheme: IconThemeData(color: c.icon1, size: kRowIcon),
    hoverColor: c.text1.withValues(alpha: kHoverLayer),
    highlightColor: c.text1.withValues(alpha: kPressedLayer),
    focusColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.icon1,
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: rounded,
      ).copyWith(overlayColor: stateLayer(c.text1), side: focusRing),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.base,
      foregroundColor: c.icon1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: kNavRowHeight,
      titleTextStyle: DsType.navTitle.copyWith(color: c.text1),
      iconTheme: IconThemeData(color: c.icon1, size: kNavIcon),
      actionsIconTheme: IconThemeData(color: c.icon1, size: kNavIcon),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, kTextButtonHeight)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        shape: WidgetStatePropertyAll(rounded),
        textStyle: const WidgetStatePropertyAll(DsType.text),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? c.textAccent.withValues(alpha: kDisabledOpacity)
              : c.textAccent,
        ),
        overlayColor: stateLayer(c.text1),
        side: focusRing,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.textInverted,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kFabRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      // The filled decorator adds 4 on each side: 12 here puts the text 16 from the frame.
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      // The floating label is drawn at 75%: 16 here is the 12/14 caption of the DS.
      labelStyle: DsType.caption.copyWith(
        color: c.text3,
        fontSize: 16,
        height: 14 / 12,
      ),
      floatingLabelStyle: DsType.caption.copyWith(
        color: c.text3,
        fontSize: 16,
        height: 14 / 12,
      ),
      hintStyle: DsType.text.copyWith(color: c.text4),
      helperStyle: DsType.small.copyWith(color: c.text3),
      errorStyle: DsType.small.copyWith(color: c.destructive),
      prefixIconColor: c.icon1,
      suffixIconColor: c.icon1,
      border: field(c.borderSoft),
      enabledBorder: field(c.borderSoft),
      disabledBorder: field(c.borderSoft.withValues(alpha: kDisabledOpacity)),
      focusedBorder: field(c.borderFocus),
      errorBorder: field(c.destructive),
      focusedErrorBorder: field(c.destructive),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.text1,
      selectionColor: c.accentAlpha,
      selectionHandleColor: c.accent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.dialog,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: rounded,
      barrierColor: c.overlay,
      titleTextStyle: DsType.navTitle.copyWith(color: c.text1),
      contentTextStyle: DsType.small.copyWith(color: c.text3),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceAlt,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.overlay,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: c.icon3,
      dragHandleSize: const Size(36, 5),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kRadius),
        ),
        side: BorderSide(color: c.borderFaint),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverse,
      contentTextStyle: DsType.small.copyWith(color: c.textInverted),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSnackbarRadius),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.borderSoft, space: 1, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.panel,
      circularTrackColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.inverse,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: DsType.caption.copyWith(color: c.textInverted),
    ),
  );
}

// textField of the DS: a rounded 1 pt frame with the label inside it, above the value.
// An outline border would notch the label into the frame; an "underline" one keeps it in the fill.
class DsFieldBorder extends InputBorder {
  const DsFieldBorder(this.color) : super(borderSide: BorderSide.none);

  final Color color;

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  DsFieldBorder copyWith({BorderSide? borderSide}) =>
      DsFieldBorder(borderSide?.color ?? color);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(BorderRadius.circular(kRadius).toRRect(rect));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      getInnerPath(rect, textDirection: textDirection);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    canvas.drawRRect(
      BorderRadius.circular(kRadius).toRRect(rect).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
