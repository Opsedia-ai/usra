import 'package:flutter/painting.dart';

/// The two bundled faces. Baloo is variable, so its weight is set on the
/// `wght` axis as well as [TextStyle.fontWeight].
abstract final class UsraFonts {
  static const display = 'Baloo Bhaijaan 2';
  static const body = 'IBM Plex Sans Arabic';
}

/// Type styles from the design file, without colour: the theme adds it.
abstract final class UsraType {
  static TextStyle _display(double size, double line, int weight) => TextStyle(
    fontFamily: UsraFonts.display,
    fontFamilyFallback: const [UsraFonts.body],
    fontSize: size,
    height: line / size,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );

  static TextStyle _body(double size, double line, FontWeight weight) =>
      TextStyle(
        fontFamily: UsraFonts.body,
        fontSize: size,
        height: line / size,
        fontWeight: weight,
      );

  // Lighter headings since the November 2026 polish: size carries the
  // hierarchy, not weight.
  static final display = _display(32, 44, 600);
  static final title = _display(24, 34, 600);
  static final heading = _display(20, 30, 600);

  static final bodySimple = _body(20, 32, FontWeight.w500);
  static final bodyLg = _body(18, 30, FontWeight.w400);
  static final body = _body(16, 26, FontWeight.w400);
  static final label = _body(14, 22, FontWeight.w500);

  /// Sources, timestamps, helper text. Never for doses or warnings.
  static final caption = _body(12, 18, FontWeight.w400);

  /// Times, temperatures, doses and amounts, in tabular figures.
  static final numeral = _body(
    16,
    24,
    FontWeight.w600,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
