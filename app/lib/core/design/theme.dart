import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildUsraTheme() {
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
    appBarTheme: const AppBarTheme(
      backgroundColor: UsraColors.background,
      foregroundColor: UsraColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: UsraColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: UsraColors.surface,
      indicatorColor: UsraColors.primaryTint,
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
