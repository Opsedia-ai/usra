import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/demo/demo_family.dart';
import 'package:usra/features/medicines/medicines_providers.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/sync_photo_store.dart';

/// The fixed moment every UI check runs at, so ages, due dates and
/// "today" never change between runs.
final demoNow = DateTime(2026, 11, 5, 10, 30);

/// A phone the size of an iPhone 15/16 (logical pixels).
const phoneSize = Size(393, 852);

/// One screen the UI checks open, with the demo family loaded.
class UiScreen {
  const UiScreen(this.name, this.route, {this.simple = false});

  /// File-name friendly, e.g. `home`, `child-vaccines`.
  final String name;
  final String Function(DemoFamily f) route;

  /// Opened with Simple Mode on (bigger text and buttons).
  final bool simple;

  @override
  String toString() => name;
}

/// The main screens: what a family opens most, one of each kind of page.
final mainScreens = <UiScreen>[
  UiScreen('home', (_) => '/home'),
  UiScreen('family', (_) => '/family'),
  UiScreen('member-toddler', (f) => '/family/${f.youssef}'),
  UiScreen('emergency-card', (f) => '/family/${f.fatma}/emergency'),
  UiScreen('child-vaccines', (f) => '/family/${f.youssef}/vaccines'),
  UiScreen('growth', (f) => '/family/${f.layla}/growth'),
  UiScreen('baby-log', (f) => '/family/${f.layla}/baby-log'),
  UiScreen('pregnancy', (f) => '/family/${f.mona}/pregnancy'),
  UiScreen('labs', (f) => '/family/${f.mona}/labs'),
  UiScreen('fever', (f) => '/family/${f.youssef}/sick-days/${f.youssefFever}'),
  UiScreen('medicines-today', (_) => '/medicines'),
  UiScreen(
    'prescription-form',
    (f) => '/family/${f.youssef}/prescriptions/new',
  ),
  UiScreen('doctors', (_) => '/doctors'),
  UiScreen('money', (_) => '/money'),
  UiScreen('more', (_) => '/settings'),
  UiScreen('simple-home', (_) => '/home', simple: true),
  UiScreen('simple-medicines', (_) => '/medicines', simple: true),
];

/// Opens the app on [screen] with the demo family, in [locale], at the
/// phone text size [textScale], on a [size] phone (null: the device's). Run the test body in
/// [atDemoTime] so dates match.
Future<DemoFamily> pumpDemoScreen(
  WidgetTester tester,
  UiScreen screen, {
  Locale locale = const Locale('ar'),
  double textScale = 1.0,
  Size? size = phoneSize,
  double pixelRatio = 3,
  DateTime? now,
}) async {
  // On a device the screens read the real clock, so the family is made
  // relative to it; tests pin both to [demoNow].
  final today = now ?? demoNow;
  // On a real phone or simulator (null) the screen is what it is.
  if (size != null) {
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  final family = (await tester.runAsync(() => seedDemoFamily(db, now: today)))!;

  final dir = Directory.systemTemp.createTempSync('usra_ui');
  addTearDown(() => dir.deleteSync(recursive: true));
  // The camera and gallery hand back a tiny picture (a fresh file each
  // time: forms delete the picker's copy).
  var picks = 0;
  Future<String?> pick(ImageSource _) async {
    final file = File('${dir.path}/pick-${picks++}.png')
      ..writeAsBytesSync(tinyPng);
    return file.path;
  }

  PhotoStore photos(String folder) =>
      SyncPhotoStore(Directory('${dir.path}/support'), folder);

  // Owned by the widget tree, so its timers go when the test ends.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        keyValueStoreProvider.overrideWithValue(
          MemoryKeyValueStore({
            PrefKeys.tutorialSeen: true,
            PrefKeys.elderTutorialSeen: true,
            PrefKeys.appLockOffered: true,
            PrefKeys.simpleMode: screen.simple,
          }),
        ),
        cardPhotoStoreProvider.overrideWithValue(
          photos(PhotoStore.cardsFolder),
        ),
        attachmentStoreProvider.overrideWithValue(
          photos(PhotoStore.attachmentsFolder),
        ),
        medicinePhotoStoreProvider.overrideWithValue(
          photos(PhotoStore.medicinesFolder),
        ),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        photoPickerProvider.overrideWithValue(pick),
        clockProvider.overrideWithValue(
          () => now == null ? demoNow : clock.now(),
        ),
      ],
      child: const UsraApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(UsraApp)),
  );
  container.read(localeProvider.notifier).change(locale);
  await settle(tester);
  container.read(routerProvider).go(screen.route(family));
  await settle(tester);
  // Runs before the database closes, even when the test failed half way:
  // closing it under a live screen hangs the next test.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  return family;
}

/// Runs [body] with the app's clock at [demoNow].
Future<void> atDemoTime(Future<void> Function() body) =>
    withClock(Clock.fixed(demoNow), body);

/// Every error Flutter reported while [body] ran (overflow stripes, failed
/// builds), instead of failing on the first.
Future<List<FlutterErrorDetails>> collectFlutterErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// Like `pumpAndSettle`, but gives up after [max] instead of ten minutes
/// when something keeps animating (a spinner that never stops shows as a
/// screenshot, not a hang).
Future<void> settle(
  WidgetTester tester, {
  Duration max = const Duration(seconds: 5),
}) async {
  final end = tester.binding.clock.now().add(max);
  do {
    await tester.pump(const Duration(milliseconds: 100));
  } while (tester.binding.hasScheduledFrame &&
      tester.binding.clock.now().isBefore(end));
}

/// A 1×1 PNG, standing in for a photo.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// The page's own vertical list: the tallest one (text fields and chips
/// rows have small Scrollables of their own).
Finder pageScrollable() {
  final all = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  final elements = all.evaluate();
  if (elements.isEmpty) return all;
  final page = elements.reduce(
    (a, b) => a.size!.height >= b.size!.height ? a : b,
  );
  return find.byElementPredicate((e) => e == page);
}
