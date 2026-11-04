import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';
import 'medicines_providers.dart' show todayOf;
import 'reminders.dart' show snoozeDuration;

/// A dose due (or snoozed until) up to this long ago still shows on the
/// widget, with Taken.
const widgetGrace = Duration(hours: 1);

/// Most doses kept in a snapshot; the widget shows three.
const widgetMaxDoses = 20;

/// One dose on the home-screen widget: only what the widget shows, and
/// the key to mark it taken. Health data, so nothing more: no full names,
/// strengths, amounts, instructions or conditions.
class WidgetDose {
  const WidgetDose({
    required this.at,
    required this.until,
    required this.time,
    required this.person,
    required this.medicine,
    required this.medicineId,
  });

  /// Local planned time.
  final DateTime at;

  /// When the widget stops showing it: [widgetGrace] after it's due, or
  /// after its snooze ends.
  final DateTime until;

  /// [at] as "٨:٠٠ م", in the app's language.
  final String time;

  /// First name only; empty in discreet mode.
  final String person;

  /// The medicine's name, without its strength; "Dose due" in discreet
  /// mode.
  final String medicine;
  final String medicineId;

  Map<String, Object> toJson() => {
    'at': at.toUtc().millisecondsSinceEpoch,
    'until': until.toUtc().millisecondsSinceEpoch,
    'time': time,
    'person': person,
    'medicine': medicine,
    'm': medicineId,
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
    this.discreet = false,
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

  /// Not yet taken or skipped, soonest first.
  final List<WidgetDose> doses;

  /// No names, and so no Taken button: rows that look alike could each
  /// mark someone else's dose. A tap opens the app instead.
  final bool discreet;

  static const version = 1;

  Map<String, Object> toJson() => {
    'v': version,
    'generatedAt': generatedAt.toUtc().millisecondsSinceEpoch,
    'validUntil': validUntil.toUtc().millisecondsSinceEpoch,
    'rtl': rtl,
    'title': title,
    'empty': empty,
    'stale': stale,
    'taken': taken,
    'discreet': discreet,
    'doses': [for (final d in doses) d.toJson()],
  };

  String encode() => jsonEncode(toJson());
}

/// "عمر" from "عمر محمد".
String firstName(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  return parts.first;
}

/// The widget's snapshot at [now]: doses from today to the end of
/// tomorrow that aren't marked taken or skipped and haven't been due (or
/// snoozed until) for over [widgetGrace], with text in [l]'s
/// language; [discreet] leaves out people's and medicines' names. Call
/// [ensureWidgetDateFormatting] first.
WidgetSnapshot buildWidgetSnapshot(
  List<Regimen> regimens,
  List<DoseLog> logs, {
  required DateTime now,
  required AppLocalizations l,
  bool discreet = false,
}) {
  final today = todayOf(now).from;
  final validUntil = DateTime(today.year, today.month, today.day + 2);
  final time = DateFormat.jm(_timeLocale(l.localeName));
  final doses = <WidgetDose>[];
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
    if (doses.length == widgetMaxDoses) break;
    doses.add(
      WidgetDose(
        at: d.at,
        until: until,
        time: time.format(d.at),
        person: discreet ? '' : firstName(d.regimen.person.displayName),
        medicine: discreet ? l.widgetDiscreetDose : d.regimen.medicine.name,
        medicineId: d.regimen.medicine.id,
      ),
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
    doses: doses,
    discreet: discreet,
  );
}

/// Egyptian Arabic, whose times read "٨:٠٠ م", big and familiar on the
/// widget; plain `ar` uses Western digits.
String _timeLocale(String localeName) =>
    localeName == 'ar' ? 'ar_EG' : localeName;

/// Date formats for [locale]; the snapshot may be built before the app's
/// localizations have loaded them.
Future<void> ensureWidgetDateFormatting(String locale) =>
    initializeDateFormatting(_timeLocale(locale));

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
