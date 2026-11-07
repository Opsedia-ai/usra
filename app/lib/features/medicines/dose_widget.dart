import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';
import 'medicines_providers.dart' show todayOf;
import 'reminders.dart'
    show
        DoseCompany,
        doseCompanyLookback,
        doseCompanyOf,
        doseKey,
        doseTimeText,
        ensureDoseTimeFormatting,
        snoozeDuration;

/// A dose due (or snoozed until) up to this long ago still shows on the
/// widget, with Taken.
const widgetGrace = Duration(hours: 1);

/// Most rows kept in a snapshot; the widget shows three.
const widgetMaxRows = 20;

/// One row on the home-screen widget: a time and how many doses are due then,
/// and the key to mark it taken. Never a person's or a medicine's name, in any
/// mode: the snapshot sits outside the encrypted database, and on iOS in the App
/// Group, which may reach iCloud device backup (Apple 5.1.3).
class WidgetDose {
  const WidgetDose({
    required this.at,
    required this.until,
    required this.time,
    required this.label,
    required this.medicineId,
    required this.canMark,
  });

  /// Local planned time.
  final DateTime at;

  /// When the widget stops showing it: [widgetGrace] after it's due, or
  /// after its snooze ends.
  final DateTime until;

  /// [at] as "٨:٠٠ م", in the app's language.
  final String time;

  /// "Dose due", or how many are due at this time.
  final String label;

  /// Only on a row with Taken, so Taken can say which dose: empty otherwise. An
  /// id with no name in it, though a UUID v7 shows when the medicine was added.
  final String medicineId;

  /// Has a Taken button once due, only if this row can be told from others'
  /// ([DoseCompany.alone]); a tap opens the app otherwise.
  final bool canMark;

  Map<String, Object> toJson() => {
    'at': at.toUtc().millisecondsSinceEpoch,
    'until': until.toUtc().millisecondsSinceEpoch,
    'time': time,
    'label': label,
    'm': medicineId,
    't': canMark,
  };
}

/// What the home-screen widget shows, until the app next publishes one.
///
/// The database is encrypted and the widget can't open it, so the app
/// hands it the doses still due today and tomorrow; the widget picks the
/// next three itself as time passes, and rolls over at midnight without
/// the app.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.generatedAt,
    required this.validUntil,
    required this.rtl,
    required this.title,
    required this.empty,
    required this.stale,
    required this.taken,
    required this.doses,
  });

  /// When the doses were read; a Taken pressed on the widget after this
  /// isn't in them yet.
  final DateTime generatedAt;

  /// The end of tomorrow: after it the widget asks to open the app.
  final DateTime validUntil;
  final bool rtl;
  final String title;
  final String empty;
  final String stale;
  final String taken;

  /// Not yet taken or skipped, soonest first, one row per time. Rows that look
  /// alike could each mark someone else's dose, so each says for itself whether
  /// it has Taken: see [WidgetDose.canMark].
  final List<WidgetDose> doses;

  /// Version 1 held first names and medicine names. The widgets refuse it, and
  /// delete it: until the app runs after an update, it's still on the phone.
  static const version = 2;

  Map<String, Object> toJson() => {
    'v': version,
    'generatedAt': generatedAt.toUtc().millisecondsSinceEpoch,
    'validUntil': validUntil.toUtc().millisecondsSinceEpoch,
    'rtl': rtl,
    'title': title,
    'empty': empty,
    'stale': stale,
    'taken': taken,
    'doses': [for (final d in doses) d.toJson()],
  };

  String encode() => jsonEncode(toJson());
}

/// The widget's snapshot at [now]: doses from today to the end of tomorrow that
/// aren't marked taken or skipped and haven't been due (or snoozed until) for
/// over [widgetGrace], one row per time, with text in [l]'s language. Call
/// [ensureWidgetDateFormatting] first.
WidgetSnapshot buildWidgetSnapshot(
  List<Regimen> regimens,
  List<DoseLog> logs, {
  required DateTime now,
  required AppLocalizations l,
}) {
  final today = todayOf(now).from;
  final validUntil = DateTime(today.year, today.month, today.day + 2);
  final company = doseCompanyOf(
    regimens,
    logs,
    from: now.subtract(doseCompanyLookback),
    to: validUntil,
  );
  // Doses that also leave together: a shared row can't lose one and keep a
  // right count.
  final rows = <(DateTime, DateTime), _WidgetRow>{};
  for (final d in plannedDoses(regimens, logs, from: today, to: validUntil)) {
    if (d.isDone) continue;
    final log = d.log;
    final snoozedUntil = log?.status == DoseOutcome.snoozed
        ? log!.at.toLocal().add(snoozeDuration)
        : d.at;
    final until = (snoozedUntil.isAfter(d.at) ? snoozedUntil : d.at).add(
      widgetGrace,
    );
    if (until.isBefore(now)) continue;
    final row = rows[(d.at, until)];
    if (row != null) {
      row.count++;
      continue;
    }
    if (rows.length == widgetMaxRows) break;
    rows[(d.at, until)] = _WidgetRow(
      medicineId: d.regimen.medicine.id,
      // A snoozed dose still has its reminder coming, which Taken here can't
      // cancel: it would ring for a dose already given.
      markable:
          log?.status != DoseOutcome.snoozed &&
          company[doseKey(d.regimen.medicine.id, d.at)] == DoseCompany.alone,
    );
  }
  return WidgetSnapshot(
    generatedAt: now,
    validUntil: validUntil,
    rtl: Bidi.isRtlLanguage(l.localeName),
    title: l.medicinesTodayTitle,
    empty: l.widgetEmpty,
    stale: l.widgetStale,
    taken: l.doseTaken,
    doses: [
      for (final MapEntry(key: (at, until), value: row) in rows.entries)
        WidgetDose(
          at: at,
          until: until,
          time: doseTimeText(at, l.localeName),
          label: row.count == 1
              ? l.widgetDoseDue
              : l.widgetDoseCount(
                  row.count,
                  digitsIn(l.localeName, '${row.count}'),
                ),
          medicineId: row.canMark ? row.medicineId : '',
          canMark: row.canMark,
        ),
    ],
  );
}

/// The doses due at one time, while a snapshot is built.
class _WidgetRow {
  _WidgetRow({required this.medicineId, required this.markable});

  final String medicineId;
  final bool markable;
  var count = 1;

  bool get canMark => count == 1 && markable;
}

/// Date formats for [locale]; the snapshot may be built before the app's
/// localizations have loaded them.
Future<void> ensureWidgetDateFormatting(String locale) =>
    ensureDoseTimeFormatting(locale);

/// Hands the snapshot to the home-screen widget. Tests use a fake.
abstract interface class WidgetSnapshotPublisher {
  Future<void> publish(WidgetSnapshot snapshot);
}

/// [WidgetSnapshotPublisher] on the home_widget plugin: app-private
/// SharedPreferences on Android, the App Group's UserDefaults on iOS.
class HomeWidgetSnapshotPublisher implements WidgetSnapshotPublisher {
  const HomeWidgetSnapshotPublisher();

  /// Shared with the WidgetKit extension; see `ios/DoseWidget/README.md`.
  static const appGroup = 'group.com.opsedia.usra';
  static const dataKey = 'dose_widget_snapshot';
  static const androidProvider = 'com.opsedia.usra.DoseWidgetProvider';
  static const iOSKind = 'DoseWidget';

  /// Doses marked Taken on the iOS widget and not yet in a snapshot; only
  /// the widget reads it.
  static const iosPendingKey = 'dose_widget_taken';

  static Future<void> init() => HomeWidget.setAppGroupId(appGroup);

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    try {
      await HomeWidget.saveWidgetData<String>(dataKey, snapshot.encode());
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iOSKind,
      );
    } on MissingPluginException {
      // No widget on this platform.
    }
  }

  /// Calls [open] when the widget is tapped, including the tap that
  /// launched the app.
  static Future<void> onTap(void Function() open) async {
    try {
      HomeWidget.widgetClicked.listen(
        (uri) {
          if (uri != null) open();
        },
        // The widget can't be reached; it still opens the app.
        onError: (Object _) {},
      );
      if (await HomeWidget.initiallyLaunchedFromHomeWidget() != null) open();
    } on MissingPluginException {
      // No widget on this platform.
    } on PlatformException {
      // The widget can't be reached; it still opens the app.
    }
  }
}
