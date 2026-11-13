import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// Height of buttons and rows in Simple Mode: big enough for shaky hands.
const simpleTapTarget = 64.0;

/// Text grows by this much in Simple Mode, on top of the phone's own size.
const simpleTextScale = 1.3;

/// The app theme, light or dark. [simple] makes every button and row at
/// least [simpleTapTarget] tall for Simple Mode.
ThemeData buildUsraTheme({
  bool simple = false,
  Brightness brightness = Brightness.light,
}) {
  final dark = brightness == Brightness.dark;
  final c = dark ? UsraColors.dark : UsraColors.light;
  final tap = simple ? const Size(simpleTapTarget, simpleTapTarget) : null;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.primary,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    secondaryContainer: c.primarySoft,
    onSecondaryContainer: c.primary,
    tertiary: c.orchid,
    onTertiary: c.onOrchid,
    tertiaryContainer: c.orchidSoft,
    onTertiaryContainer: c.ink,
    error: c.urgent,
    onError: c.onUrgent,
    errorContainer: c.urgentSoft,
    onErrorContainer: c.urgent,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.surfaceSoft,
    surfaceTint: Colors.transparent,
    outline: c.lineStrong,
    outlineVariant: c.line,
    inverseSurface: c.ink,
    onInverseSurface: c.bg,
    inversePrimary: dark ? UsraColors.light.primary : UsraColors.dark.primary,
    shadow: dark ? const Color(0xFF000000) : c.ink,
    scrim: const Color(0x99000000),
  );

  // Every style names its face, so the base can't be set with
  // ThemeData.fontFamily: that would turn the Baloo titles into Plex too.
  final base =
      (dark ? Typography.material2021().white : Typography.material2021().black)
          .apply(
            fontFamily: UsraFonts.body,
            bodyColor: c.ink,
            displayColor: c.heading,
          );
  final textTheme = base.merge(
    TextTheme(
      headlineLarge: UsraType.display.copyWith(color: c.heading),
      headlineMedium: UsraType.title.copyWith(color: c.heading),
      headlineSmall: UsraType.title.copyWith(color: c.heading),
      titleLarge: UsraType.title.copyWith(color: c.heading),
      titleMedium: UsraType.heading.copyWith(color: c.heading),
      titleSmall: UsraType.label.copyWith(color: c.ink),
      bodyLarge: UsraType.body.copyWith(color: c.ink),
      bodyMedium: UsraType.body.copyWith(color: c.ink),
      // Existing screens use bodySmall for hints and for warning lines, and
      // the design's 12 px caption is never for warnings, so this stays at
      // the label size. New screens use UsraType.caption where it fits.
      bodySmall: UsraType.label.copyWith(
        color: c.inkMuted,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: UsraType.label.copyWith(color: c.ink),
    ),
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    extensions: [c],
    textTheme: textTheme,
    scaffoldBackgroundColor: c.bg,
    dividerColor: c.line,
    dividerTheme: DividerThemeData(color: c.line),
    focusColor: c.focus.withValues(alpha: 0.16),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.heading,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: UsraType.title.copyWith(color: c.heading),
      // Room for the bigger back and action buttons.
      toolbarHeight: simple ? simpleTapTarget + 8 : null,
      leadingWidth: simple ? simpleTapTarget + 8 : null,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      // Hairline border, no shadow, in both themes.
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UsraRadius.card),
        side: BorderSide(color: c.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(
          simple ? simpleTapTarget : UsraSizes.touchTarget,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(UsraRadius.button)),
        ),
        textStyle: UsraType.body.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize:
            tap ?? const Size(UsraSizes.touchTarget, UsraSizes.touchTarget),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(UsraRadius.button)),
        ),
        foregroundColor: c.primary,
        side: BorderSide(color: c.lineStrong),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize:
            tap ?? const Size(UsraSizes.touchTarget, UsraSizes.touchTarget),
        shape: const StadiumBorder(),
        foregroundColor: c.primary,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: tap),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.orchid,
      foregroundColor: c.onOrchid,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UsraRadius.md),
        borderSide: BorderSide(color: c.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UsraRadius.md),
        borderSide: BorderSide(color: c.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UsraRadius.md),
        borderSide: BorderSide(color: c.focus, width: 2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UsraRadius.lg),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(UsraRadius.card)),
      ),
    ),
    // One look for every message: a floating pill above the bottom bar.
    // Ones with Undo also pass [UsraDurations.undo] and persist: false.
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: StadiumBorder(),
    ),
    // Dropdown and popup menus: rounded, a hairline, no shadow.
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UsraRadius.md),
        side: BorderSide(color: c.line),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: simple ? 72 : null,
      iconColor: c.inkMuted,
      textColor: c.ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.primarySoft,
      height: simple ? 88 : null,
      // The default is 12, under the 14 every text has to reach.
      labelTextStyle: WidgetStatePropertyAll(
        UsraType.label.copyWith(fontSize: simple ? 16 : 14),
      ),
      iconTheme: simple
          ? const WidgetStatePropertyAll(IconThemeData(size: 32))
          : null,
    ),
  );
}
