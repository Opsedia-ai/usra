import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';
import '../../core/util/separator.dart';

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

/// "Every day – 8:00 AM, 8:00 PM – 1 tablet".
String scheduleSummary(BuildContext context, DoseSchedule s) =>
    scheduleSummaryIn(AppLocalizations.of(context), s);

/// [scheduleSummary] in [l]'s language, without a [BuildContext] (for a
/// PDF made in a language other than the app's). [withAmount] false leaves
/// out the amount, for callers that place it themselves.
String scheduleSummaryIn(
  AppLocalizations l,
  DoseSchedule s, {
  bool withAmount = true,
}) {
  final locale = l.localeName;
  final comma = l.localeName.startsWith('ar') ? '، ' : ', ';
  final weekday = DateFormat.E(locale);
  final days = switch ((s.everyNDays, s.weekdays)) {
    (final n?, _) when n > 1 => l.scheduleEveryNDays(n),
    (_, final mask?) => [
      // 2024-01-01 was a Monday.
      for (var i = 0; i < 7; i++)
        if (mask & (1 << i) != 0) weekday.format(DateTime(2024, 1, 1 + i)),
    ].join(comma),
    _ => l.scheduleEveryDay,
  };
  final clock = DateFormat.jm(locale);
  final times = DoseTime.parseList(s.times)
      .map((t) => clock.format(t.on(DateTime(2000))))
      .join(comma);
  return [days, times, if (withAmount) ?s.amount].join(partSeparator);
}

/// Past its last day.
bool medicineEnded(Medicine m, DateTime now) {
  final end = m.endOn;
  return end != null &&
      DateTime(now.year, now.month, now.day).isAfter(storedDay(end));
}

/// A calendar date as UTC midnight, so clock changes can't shorten a day.
DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// How many days a course with a last day lasts, counting both ends; null
/// when it goes on.
int? courseDays(Medicine m) => m.endOn == null
    ? null
    : _utcDay(storedDay(m.endOn!))
              .difference(_utcDay(storedDay(m.startOn)))
              .inDays +
          1;

/// Where a course with a last day stands on [now]: day [day] of [total],
/// both counting the first day. Null for a medicine that goes on, or when
/// [now] is before the first day or after the last. Calendar arithmetic
/// only; nothing about doses.
({int day, int total})? courseProgress(Medicine m, DateTime now) {
  final total = courseDays(m);
  if (total == null) return null;
  final day = _utcDay(now).difference(_utcDay(storedDay(m.startOn))).inDays + 1;
  if (day < 1 || day > total) return null;
  return (day: day, total: total);
}
