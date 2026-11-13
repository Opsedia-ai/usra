import 'package:flutter/material.dart';

// Usra's design tokens. Colour values come from the design file
// ds/usra/tokens.json, with the light values, radii, hairlines and quiet
// status colours of the November 2026 polish (docs/design/polish-2026-11/).
// Screens never hard-code a colour: they read `context.usra`.

/// Every colour token, for one theme. Read it with `context.usra`.
@immutable
class UsraColors extends ThemeExtension<UsraColors> {
  const UsraColors({
    required this.bg,
    required this.surface,
    required this.surfaceSoft,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.heading,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.orchid,
    required this.onOrchid,
    required this.orchidSoft,
    required this.orchidInk,
    required this.sky,
    required this.skySoft,
    required this.skyInk,
    required this.info,
    required this.infoSoft,
    required this.good,
    required this.goodSoft,
    required this.headsUp,
    required this.headsUpSoft,
    required this.actSoon,
    required this.actSoonSoft,
    required this.urgent,
    required this.onUrgent,
    required this.urgentSoft,
    required this.attention,
    required this.attentionDot,
    required this.shadowCard,
    required this.shadowFloat,
    required this.shadowControl,
  });

  /// Screen background behind every page and the tab bar's surroundings.
  final Color bg;

  /// Cards, bottom sheets, the tab bar, text fields. In dark it sits close to bg, so cards also take a line border.
  final Color surface;

  /// Grouped rows inside a card, the person switcher pill, neutral chips.
  final Color surfaceSoft;

  /// Dividers and card borders. Decorative only, never the only edge of a control.
  final Color line;

  /// Borders of text fields, unselected checkboxes and optional (dashed) chips: 3:1 or more on bg and surface in both themes.
  final Color lineStrong;

  /// Body text on bg, surface and surface-soft (14:1 or more in both themes).
  final Color ink;

  /// Secondary text (times, hints, captions) on bg, surface and surface-soft (5:1 or more in both themes).
  final Color inkMuted;

  /// Screen titles and card titles set in Baloo Bhaijaan 2, on bg and surface.
  final Color heading;

  /// Primary buttons, links, the selected tab, progress. Text in primary reads on bg and surface (6:1 or more).
  final Color primary;

  /// Text and icons on a primary fill (10.5:1 light, 6.8:1 dark). Never literal white in dark.
  final Color onPrimary;

  /// Background of the selected tab and of secondary buttons; primary text on it.
  final Color primarySoft;

  /// The accent: the + button, Dr. Usra's heart, female avatars, one highlight per screen. A fill only; text on it is on-orchid. Too light for text on bg (2.5:1).
  final Color orchid;

  /// Text and icons on an orchid fill (6.4:1).
  final Color onOrchid;

  /// Blush tint behind highlights (next-vaccine countdown, founding-member badge); ink or orchid-ink text on it.
  final Color orchidSoft;

  /// Orchid-family text and icons (female labels, accent links) on bg, surface and orchid-soft.
  final Color orchidInk;

  /// Male avatars and the second chart series. A fill only; text on it is on-orchid (6.8:1).
  final Color sky;

  /// Tint behind male-profile headers and chart backgrounds.
  final Color skySoft;

  /// Sky-family text and icons on bg and surface.
  final Color skyInk;

  /// Severity 1, information: icon, title and border of an info notice, on bg, surface and info-soft.
  final Color info;

  /// Background of an info notice.
  final Color infoSoft;

  /// Severity 2, on track: growth on track, dose taken, vaccine done. Always with a check icon and words.
  final Color good;

  /// Background of a good notice and of done chips.
  final Color goodSoft;

  /// Severity 3, watch: re-measure, due soon. Dark amber so text passes 4.5:1.
  final Color headsUp;

  /// Background of a heads-up notice.
  final Color headsUpSoft;

  /// Severity 4, act soon: overdue vaccine, contact a doctor now.
  final Color actSoon;

  /// Background of an act-soon notice.
  final Color actSoonSoft;

  /// Severity 5, urgent: call 123 now, pregnancy danger signs. Also the fill of the SOS and Call my doctor buttons.
  final Color urgent;

  /// Text on an urgent fill (6.4:1 light, 7.3:1 dark).
  final Color onUrgent;

  /// Background of an urgent notice.
  final Color urgentSoft;

  /// Text of a quiet "needs attention" status, beside an [attentionDot]: a
  /// late vaccine, no backup yet, a person who's unwell. Passes 4.5:1 on bg
  /// and surface in both themes. Emergencies use [urgent] instead.
  final Color attention;

  /// The small dot in front of a quiet status. Never the only sign: the
  /// words beside it carry the meaning.
  final Color attentionDot;

  /// Soft shadow under cards. Empty since the November 2026 polish: cards
  /// take a hairline [line] border in both themes.
  final List<BoxShadow> shadowCard;

  /// The + button, primary pills and bottom sheets.
  final List<BoxShadow> shadowFloat;

  /// Round icon buttons and other small controls.
  final List<BoxShadow> shadowControl;

  /// Keyboard and switch-access focus ring.
  Color get focus => primary;

  static const light = UsraColors(
    bg: Color(0xFFF4F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFEEF2F8),
    line: Color(0xFFE3E6EC),
    lineStrong: Color(0xFF8C8299),
    ink: Color(0xFF14263D),
    inkMuted: Color(0xFF55657A),
    heading: Color(0xFF14263D),
    primary: Color(0xFF24405F),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE3EAF3),
    orchid: Color(0xFFC48CB3),
    onOrchid: Color(0xFF0B1B32),
    orchidSoft: Color(0xFFE5C9D7),
    orchidInk: Color(0xFF77405F),
    sky: Color(0xFF83A6CE),
    skySoft: Color(0xFFDCE6F2),
    skyInk: Color(0xFF335C8C),
    info: Color(0xFF2457B8),
    infoSoft: Color(0xFFE4ECFA),
    good: Color(0xFF1F7A45),
    goodSoft: Color(0xFFE2F3E8),
    headsUp: Color(0xFF8A6100),
    headsUpSoft: Color(0xFFFBF1D6),
    actSoon: Color(0xFF9E4409),
    actSoonSoft: Color(0xFFFCE9DC),
    urgent: Color(0xFFB42318),
    onUrgent: Color(0xFFFFFFFF),
    urgentSoft: Color(0xFFFBE3E3),
    attention: Color(0xFF9A6200),
    attentionDot: Color(0xFFD49A2A),
    shadowCard: [],
    shadowFloat: [
      BoxShadow(
        color: Color(0x380B1B32),
        offset: Offset(0, 10),
        blurRadius: 28,
      ),
    ],
    shadowControl: [
      BoxShadow(color: Color(0x140B1B32), offset: Offset(0, 4), blurRadius: 14),
    ],
  );

  static const dark = UsraColors(
    bg: Color(0xFF0B1B32),
    surface: Color(0xFF10234A),
    surfaceSoft: Color(0xFF1B3156),
    line: Color(0xFF26415E),
    lineStrong: Color(0xFF6E86A6),
    ink: Color(0xFFEAF0F7),
    inkMuted: Color(0xFFA9B7CB),
    heading: Color(0xFFEAF0F7),
    primary: Color(0xFF83A6CE),
    onPrimary: Color(0xFF0B1B32),
    primarySoft: Color(0xFF1E3555),
    orchid: Color(0xFFC48CB3),
    onOrchid: Color(0xFF0B1B32),
    orchidSoft: Color(0xFF4A3552),
    orchidInk: Color(0xFFDDB1CF),
    sky: Color(0xFF83A6CE),
    skySoft: Color(0xFF1E3555),
    skyInk: Color(0xFFA9C3E2),
    info: Color(0xFF7FA8F5),
    infoSoft: Color(0xFF16294D),
    good: Color(0xFF6CCB91),
    goodSoft: Color(0xFF12302A),
    headsUp: Color(0xFFF2CC5B),
    headsUpSoft: Color(0xFF33301C),
    actSoon: Color(0xFFF4A066),
    actSoonSoft: Color(0xFF3A2A22),
    urgent: Color(0xFFF28B8B),
    onUrgent: Color(0xFF0B1B32),
    urgentSoft: Color(0xFF3D2028),
    attention: Color(0xFFE2AE55),
    attentionDot: Color(0xFFE2AE55),
    shadowCard: [],
    shadowFloat: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 8), blurRadius: 24),
    ],
    shadowControl: [],
  );

  @override
  UsraColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSoft,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? inkMuted,
    Color? heading,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? orchid,
    Color? onOrchid,
    Color? orchidSoft,
    Color? orchidInk,
    Color? sky,
    Color? skySoft,
    Color? skyInk,
    Color? info,
    Color? infoSoft,
    Color? good,
    Color? goodSoft,
    Color? headsUp,
    Color? headsUpSoft,
    Color? actSoon,
    Color? actSoonSoft,
    Color? urgent,
    Color? onUrgent,
    Color? urgentSoft,
    Color? attention,
    Color? attentionDot,
    List<BoxShadow>? shadowCard,
    List<BoxShadow>? shadowFloat,
    List<BoxShadow>? shadowControl,
  }) => UsraColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceSoft: surfaceSoft ?? this.surfaceSoft,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    heading: heading ?? this.heading,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primarySoft: primarySoft ?? this.primarySoft,
    orchid: orchid ?? this.orchid,
    onOrchid: onOrchid ?? this.onOrchid,
    orchidSoft: orchidSoft ?? this.orchidSoft,
    orchidInk: orchidInk ?? this.orchidInk,
    sky: sky ?? this.sky,
    skySoft: skySoft ?? this.skySoft,
    skyInk: skyInk ?? this.skyInk,
    info: info ?? this.info,
    infoSoft: infoSoft ?? this.infoSoft,
    good: good ?? this.good,
    goodSoft: goodSoft ?? this.goodSoft,
    headsUp: headsUp ?? this.headsUp,
    headsUpSoft: headsUpSoft ?? this.headsUpSoft,
    actSoon: actSoon ?? this.actSoon,
    actSoonSoft: actSoonSoft ?? this.actSoonSoft,
    urgent: urgent ?? this.urgent,
    onUrgent: onUrgent ?? this.onUrgent,
    urgentSoft: urgentSoft ?? this.urgentSoft,
    attention: attention ?? this.attention,
    attentionDot: attentionDot ?? this.attentionDot,
    shadowCard: shadowCard ?? this.shadowCard,
    shadowFloat: shadowFloat ?? this.shadowFloat,
    shadowControl: shadowControl ?? this.shadowControl,
  );

  @override
  UsraColors lerp(UsraColors? other, double t) {
    if (other == null) return this;
    return UsraColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      orchid: Color.lerp(orchid, other.orchid, t)!,
      onOrchid: Color.lerp(onOrchid, other.onOrchid, t)!,
      orchidSoft: Color.lerp(orchidSoft, other.orchidSoft, t)!,
      orchidInk: Color.lerp(orchidInk, other.orchidInk, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      skySoft: Color.lerp(skySoft, other.skySoft, t)!,
      skyInk: Color.lerp(skyInk, other.skyInk, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      good: Color.lerp(good, other.good, t)!,
      goodSoft: Color.lerp(goodSoft, other.goodSoft, t)!,
      headsUp: Color.lerp(headsUp, other.headsUp, t)!,
      headsUpSoft: Color.lerp(headsUpSoft, other.headsUpSoft, t)!,
      actSoon: Color.lerp(actSoon, other.actSoon, t)!,
      actSoonSoft: Color.lerp(actSoonSoft, other.actSoonSoft, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      onUrgent: Color.lerp(onUrgent, other.onUrgent, t)!,
      urgentSoft: Color.lerp(urgentSoft, other.urgentSoft, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      attentionDot: Color.lerp(attentionDot, other.attentionDot, t)!,
      shadowCard: BoxShadow.lerpList(shadowCard, other.shadowCard, t)!,
      shadowFloat: BoxShadow.lerpList(shadowFloat, other.shadowFloat, t)!,
      shadowControl: BoxShadow.lerpList(shadowControl, other.shadowControl, t)!,
    );
  }
}

extension UsraColorsOfContext on BuildContext {
  /// The colour tokens of the current theme.
  UsraColors get usra {
    final theme = Theme.of(this);
    // The app's themes always carry the tokens; a bare Theme still draws.
    return theme.extension<UsraColors>() ??
        (theme.brightness == Brightness.dark
            ? UsraColors.dark
            : UsraColors.light);
  }
}

/// How urgent or important something is. Always shown with a word too.
enum Severity { info, good, headsUp, actSoon, urgent }

extension SeverityColors on Severity {
  /// Icon, title and border colour, in [colors]' theme.
  Color foregroundIn(UsraColors colors) => switch (this) {
    Severity.info => colors.info,
    Severity.good => colors.good,
    Severity.headsUp => colors.headsUp,
    Severity.actSoon => colors.actSoon,
    Severity.urgent => colors.urgent,
  };

  /// Soft notice background, in [colors]' theme.
  Color backgroundIn(UsraColors colors) => switch (this) {
    Severity.info => colors.infoSoft,
    Severity.good => colors.goodSoft,
    Severity.headsUp => colors.headsUpSoft,
    Severity.actSoon => colors.actSoonSoft,
    Severity.urgent => colors.urgentSoft,
  };

  Color foregroundOf(BuildContext context) => foregroundIn(context.usra);

  Color backgroundOf(BuildContext context) => backgroundIn(context.usra);
}

/// Colours that stay the same in both themes on purpose.
abstract final class UsraFixedColors {
  /// Photos are viewed on black, with white controls, in light and dark.
  static const photoBackdrop = Color(0xFF000000);
  static const onPhotoBackdrop = Color(0xFFFFFFFF);
}

/// Spacing steps from the design file.
abstract final class UsraSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
}

/// Corner radii, sized to the element (November 2026 polish): cards 16,
/// buttons and tiles 14, sheets 20, fields and icon boxes 12 or 10, and
/// chips stay round.
abstract final class UsraRadius {
  static const sm = 8.0;
  static const iconBox = 10.0;
  static const md = 12.0;
  static const button = 14.0;
  static const card = 16.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

/// How long things stay on screen.
abstract final class UsraDurations {
  /// A message with Undo: long enough to read and tap, then it goes, so it
  /// never sits over the screen's own buttons.
  static const undo = Duration(seconds: 6);
}

/// Minimum sizes from the design file.
abstract final class UsraSizes {
  static const touchTarget = 48.0;
  static const roundIcon = 48.0;
  static const roundIconLarge = 60.0;
  static const tabBarHeight = 64.0;
}
