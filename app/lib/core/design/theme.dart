import 'package:flutter/material.dart';

import 'tokens.dart';

/// Height of buttons and rows in Simple Mode: big enough for shaky hands.
const simpleTapTarget = 64.0;

/// Text grows by this much in Simple Mode, on top of the phone's own size.
const simpleTextScale = 1.3;

/// The app theme. [simple] makes every button and row at least
/// [simpleTapTarget] tall for Simple Mode.
ThemeData buildUsraTheme({bool simple = false}) {
  final tap = simple ? const Size(simpleTapTarget, simpleTapTarget) : null;
  final scheme = ColorScheme.fromSeed(
    seedColor: UsraColors.primary,
    primary: UsraColors.primary,
    onPrimary: Colors.white,
    surface: UsraColors.surface,
    onSurface: UsraColors.text,
    error: UsraColors.emergency,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: UsraColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: UsraColors.background,
      foregroundColor: UsraColors.text,
      elevation: 0,
      centerTitle: false,
      // Room for the bigger back and action buttons.
      toolbarHeight: simple ? simpleTapTarget + 8 : null,
      leadingWidth: simple ? simpleTapTarget + 8 : null,
    ),
    cardTheme: CardThemeData(
      color: UsraColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(simple ? simpleTapTarget : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: tap),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: tap),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: tap),
    ),
    listTileTheme: ListTileThemeData(minTileHeight: simple ? 72 : null),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: UsraColors.surface,
      indicatorColor: UsraColors.primaryTint,
      height: simple ? 88 : null,
      iconTheme: simple
          ? const WidgetStatePropertyAll(IconThemeData(size: 32))
          : null,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: UsraColors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: UsraColors.text,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: UsraColors.text),
      bodyMedium: TextStyle(fontSize: 15, color: UsraColors.text),
      bodySmall: TextStyle(fontSize: 13, color: UsraColors.textMuted),
    ),
  );
}
