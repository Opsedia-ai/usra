import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/theme.dart';
import 'package:usra/core/design/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  const themes = {'light': UsraColors.light, 'dark': UsraColors.dark};

  // Every pair the app draws. Text needs 4.5:1, icons and field edges 3:1.
  final text = <String, (Color, Color) Function(UsraColors)>{
    'ink on bg': (c) => (c.ink, c.bg),
    'ink on surface': (c) => (c.ink, c.surface),
    'ink on surface-soft': (c) => (c.ink, c.surfaceSoft),
    'ink on orchid-soft': (c) => (c.ink, c.orchidSoft),
    'ink on sky-soft': (c) => (c.ink, c.skySoft),
    'muted on bg': (c) => (c.inkMuted, c.bg),
    'muted on surface': (c) => (c.inkMuted, c.surface),
    'muted on surface-soft': (c) => (c.inkMuted, c.surfaceSoft),
    'heading on bg': (c) => (c.heading, c.bg),
    'heading on surface': (c) => (c.heading, c.surface),
    'primary on bg': (c) => (c.primary, c.bg),
    'primary on surface': (c) => (c.primary, c.surface),
    'primary on primary-soft': (c) => (c.primary, c.primarySoft),
    'on-primary on primary': (c) => (c.onPrimary, c.primary),
    'on-orchid on orchid': (c) => (c.onOrchid, c.orchid),
    'on-orchid on sky': (c) => (c.onOrchid, c.sky),
    'orchid-ink on orchid-soft': (c) => (c.orchidInk, c.orchidSoft),
    'orchid-ink on surface': (c) => (c.orchidInk, c.surface),
    'sky-ink on surface': (c) => (c.skyInk, c.surface),
    'on-urgent on urgent': (c) => (c.onUrgent, c.urgent),
    'attention on bg': (c) => (c.attention, c.bg),
    'attention on surface': (c) => (c.attention, c.surface),
    'attention on surface-soft': (c) => (c.attention, c.surfaceSoft),
    'urgent on bg': (c) => (c.urgent, c.bg),
  };

  for (final MapEntry(key: theme, value: colors) in themes.entries) {
    group('$theme contrast', () {
      for (final MapEntry(key: name, value: pair) in text.entries) {
        test(name, () {
          final (fg, bg) = pair(colors);
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      }

      for (final s in Severity.values) {
        test('${s.name} chip, and as text on bg and surface', () {
          final fg = s.foregroundIn(colors);
          expect(
            contrast(fg, s.backgroundIn(colors)),
            greaterThanOrEqualTo(4.5),
          );
          expect(contrast(fg, colors.bg), greaterThanOrEqualTo(4.5));
          expect(contrast(fg, colors.surface), greaterThanOrEqualTo(4.5));
        });
      }

      test('field edges and pregnancy chart lines reach 3:1', () {
        expect(contrast(colors.lineStrong, colors.bg), greaterThanOrEqualTo(3));
        expect(
          contrast(colors.lineStrong, colors.surface),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrast(colors.orchidInk, colors.surface),
          greaterThanOrEqualTo(3),
        );
      });

      test('the pregnancy card icon reaches 3:1 on orchid-soft', () {
        expect(
          contrast(colors.primary, colors.orchidSoft),
          greaterThanOrEqualTo(3),
        );
      });
    });
  }

  test('good text reaches 4.5:1 on the polished light surface-soft', () {
    // Was 4.40:1 on the old pink surface-soft; the November 2026 polish's
    // cooler grey lifts it. Pinned so a token change makes someone re-check.
    expect(
      contrast(UsraColors.light.good, UsraColors.light.surfaceSoft),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('severity backgrounds are all different', () {
    for (final colors in themes.values) {
      final backgrounds = Severity.values
          .map((s) => s.backgroundIn(colors))
          .toSet();
      expect(backgrounds, hasLength(Severity.values.length));
    }
  });

  test('the theme carries the tokens for its brightness', () {
    expect(buildUsraTheme().extension<UsraColors>()!.bg, UsraColors.light.bg);
    final dark = buildUsraTheme(brightness: Brightness.dark);
    expect(dark.extension<UsraColors>()!.bg, UsraColors.dark.bg);
    expect(dark.colorScheme.brightness, Brightness.dark);
  });

  test('Simple Mode keeps its tap sizes in both themes', () {
    for (final b in Brightness.values) {
      final theme = buildUsraTheme(simple: true, brightness: b);
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        simpleTapTarget,
      );
      expect(
        theme.iconButtonTheme.style!.minimumSize!.resolve({})!.height,
        simpleTapTarget,
      );
      expect(theme.listTileTheme.minTileHeight, 72);
    }
  });

  test('tokens interpolate between themes', () {
    final mid = UsraColors.light.lerp(UsraColors.dark, 0.5);
    expect(mid.bg, Color.lerp(UsraColors.light.bg, UsraColors.dark.bg, 0.5));
    expect(UsraColors.light.lerp(UsraColors.dark, 1).ink, UsraColors.dark.ink);
  });
}
