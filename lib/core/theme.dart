import 'package:flutter/material.dart';

const _seed = Color(0xFF4F7CFF);

const _rCard = 16.0;
const _rControl = 12.0;
const _rOverlay = 20.0;

const _kLeading = 56.0;
const _kIconButton = 48.0;

@immutable
class VpnColors extends ThemeExtension<VpnColors> {
  const VpnColors({
    required this.connected,
    required this.connecting,
    required this.onStatusContainer,
    required this.direct,
  });

  final Color connected;

  final Color connecting;

  final Color onStatusContainer;

  final Color direct;

  static const light = VpnColors(
    connected: Color(0xFF1E9E50),
    connecting: Color(0xFFB57E00),
    onStatusContainer: Color(0xFF0B5227),
    direct: Color(0xFF5B6470),
  );

  static const dark = VpnColors(
    connected: Color(0xFF4CC97B),
    connecting: Color(0xFFE0A93E),
    onStatusContainer: Color(0xFFB9EFCB),
    direct: Color(0xFF98A1AD),
  );

  @override
  VpnColors copyWith({
    Color? connected,
    Color? connecting,
    Color? onStatusContainer,
    Color? direct,
  }) => VpnColors(
    connected: connected ?? this.connected,
    connecting: connecting ?? this.connecting,
    onStatusContainer: onStatusContainer ?? this.onStatusContainer,
    direct: direct ?? this.direct,
  );

  @override
  VpnColors lerp(VpnColors? other, double t) {
    if (other == null) return this;
    return VpnColors(
      connected: Color.lerp(connected, other.connected, t)!,
      connecting: Color.lerp(connecting, other.connecting, t)!,
      onStatusContainer: Color.lerp(
        onStatusContainer,
        other.onStatusContainer,
        t,
      )!,
      direct: Color.lerp(direct, other.direct, t)!,
    );
  }
}

extension VpnColorsX on BuildContext {
  VpnColors get vpnColors => Theme.of(this).extension<VpnColors>()!;
}

ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final dark = brightness == Brightness.dark;
  final hairline = scheme.outlineVariant.withValues(alpha: dark ? 0.4 : 0.7);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [dark ? VpnColors.dark : VpnColors.light],

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // Leading slot centres its 48pt button at 28 from the edge, actions sit at
      // 24; this padding makes both 28.
      leadingWidth: _kLeading,
      actionsPadding: const EdgeInsets.only(
        right: (_kLeading - _kIconButton) / 2,
      ),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rCard),
        side: BorderSide(color: hairline),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 12.5,
        color: scheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rControl),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 10,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rControl),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rControl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rControl),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        side: BorderSide(color: hairline),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(
        alpha: dark ? 0.35 : 0.6,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rControl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rControl),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    ),

    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rOverlay),
      ),
      backgroundColor: scheme.surfaceContainerLow,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_rOverlay)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rControl),
      ),
    ),
    dividerTheme: DividerThemeData(color: hairline, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}
