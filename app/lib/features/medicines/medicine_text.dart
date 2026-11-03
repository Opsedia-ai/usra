import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';

/// Medicine forms, as stored in `Medicines.form`.
const medicineForms = [
  'tablet',
  'capsule',
  'syrup',
  'drops',
  'injection',
  'cream',
  'inhaler',
  'other',
];

String medicineFormLabel(AppLocalizations l, String form) => switch (form) {
  'tablet' => l.formTablet,
  'capsule' => l.formCapsule,
  'syrup' => l.formSyrup,
  'drops' => l.formDrops,
  'injection' => l.formInjection,
  'cream' => l.formCream,
  'inhaler' => l.formInhaler,
  _ => l.formOther,
};

IconData medicineFormIcon(String? form) => switch (form) {
  'syrup' => Icons.local_drink_outlined,
  'drops' => Icons.water_drop_outlined,
  'injection' => Icons.vaccines_outlined,
  'cream' => Icons.back_hand_outlined,
  'inhaler' => Icons.air,
  _ => Icons.medication_outlined,
};

/// "Panadol 500 mg".
String medicineTitle(Medicine m) => [m.name, ?m.strength].join(' ');

/// "8:00 AM" in the app's language.
String formatDoseTime(BuildContext context, DateTime at) =>
    DateFormat.jm(Localizations.localeOf(context).toLanguageTag()).format(at);

String formatDoseClock(BuildContext context, DoseTime t) =>
    formatDoseTime(context, t.on(DateTime(2000)));

/// Weekday names Monday to Sunday, short, in the app's language.
List<String> weekdayNames(BuildContext context) {
  final format = DateFormat.E(Localizations.localeOf(context).toLanguageTag());
  // 2024-01-01 was a Monday.
  return [for (var i = 0; i < 7; i++) format.format(DateTime(2024, 1, 1 + i))];
}

/// "Every day · 8:00 AM, 8:00 PM · 1 tablet".
String scheduleSummary(BuildContext context, DoseSchedule s) {
  final l = AppLocalizations.of(context);
  final days = switch ((s.everyNDays, s.weekdays)) {
    (final n?, _) when n > 1 => l.scheduleEveryNDays(n),
    (_, final mask?) => [
      for (final (i, name) in weekdayNames(context).indexed)
        if (mask & (1 << i) != 0) name,
    ].join(_comma(context)),
    _ => l.scheduleEveryDay,
  };
  final times = DoseTime.parseList(s.times)
      .map((t) => formatDoseClock(context, t))
      .join(_comma(context));
  return [days, times, ?s.amount].join(' · ');
}

String _comma(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar' ? '، ' : ', ';

/// Past its last day.
bool medicineEnded(Medicine m, DateTime now) {
  final end = m.endOn;
  return end != null && DateTime.utc(now.year, now.month, now.day).isAfter(end);
}

/// A stored date (UTC midnight) as a local date, for display and pickers.
DateTime localDay(DateTime stored) =>
    DateTime(stored.year, stored.month, stored.day);
