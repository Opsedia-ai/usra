import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/bottom_bar.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/core/security/app_lock.dart';
import 'package:usra/core/security/data_wipe.dart';
import 'package:usra/core/security/device_integrity.dart';

import '../support/fake_lock.dart';

class _FakeIntegrity implements DeviceIntegrity {
  _FakeIntegrity(this.found);

  final List<String> found;
  int asked = 0;

  @override
  Future<List<String>> signs() async {
    asked++;
    return found;
  }
}

void main() {
  late AppDatabase db;
  late MemoryLockStore store;
  late FakeClocks clocks;
  late MemoryKeyValueStore prefs;
  late int wipes;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = MemoryLockStore();
    clocks = FakeClocks();
    prefs = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.elderTutorialSeen: true,
    });
    wipes = 0;
  });
  tearDown(() => db.close());

  Future<AppLock> openLock(WidgetTester tester) async => (await tester.runAsync(
    () => AppLock.open(
      store: store,
      hasher: fastHasher,
      clock: clocks.wall,
      ticks: clocks.ticks,
      uptime: clocks,
    ),
  ))!;

  Future<AppLock> lockedWith(
    WidgetTester tester,
    String pin, {
    bool wipe = false,
  }) async {
    final first = await openLock(tester);
    await tester.runAsync(() async {
      await first.enable(pin);
      if (wipe) await first.setWipeOnFailures(true);
    });
    return openLock(tester);
  }

  Widget app(
    AppLock lock, {
    DeviceIntegrity? integrity,
    WipeOutcome? outcome,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appLockProvider.overrideWithValue(lock),
      keyValueStoreProvider.overrideWithValue(prefs),
      wipeAndRestartProvider.overrideWithValue(() async => wipes++),
      wipeOutcomeProvider.overrideWithValue(outcome),
      if (integrity != null)
        deviceIntegrityProvider.overrideWithValue(integrity),
    ],
    child: const UsraApp(),
  );

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$d')));
      await tester.pump();
    }
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String path) async {
    ProviderScope.containerOf(tester.element(find.byType(UsraApp)))
        .read(routerProvider)
        .go(path);
    await tester.pumpAndSettle();
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('delete all my data (S10)', () {
    testWidgets('needs the word typed before anything is deleted', (
      tester,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(app(await openLock(tester)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المزيد').last);
      await tester.pumpAndSettle();
      final tile = find.byKey(const ValueKey('settings-delete-all'));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // The list's bullets stand apart from the words, not "•كل الصور".
      expect(find.text('كل الصور'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\s*•\S')), findsNothing);

      final button = find.byKey(const ValueKey('wipe-confirm'));
      ButtonStyleButton widget() => tester.widget<ButtonStyleButton>(button);
      expect(widget().onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('wipe-confirm-word')),
        'امسحه',
      );
      await tester.pump();
      expect(widget().onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('wipe-confirm-word')),
        ' امسح ',
      );
      await tester.pump();
      expect(widget().onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(wipes, 1);
    });

    testWidgets('with the app lock on, the PIN is asked too', (tester) async {
      tallScreen(tester);
      final lock = await lockedWith(tester, '258046');
      await tester.pumpWidget(app(lock));
      await tester.pumpAndSettle();
      await typePin(tester, '258046');
      await go(tester, '/settings/delete-all');

      await tester.enterText(
        find.byKey(const ValueKey('wipe-confirm-word')),
        'delete',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wipe-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('أكّد إنه إنت'), findsOneWidget);
      expect(wipes, 0);
      await typePin(tester, '111111');
      expect(wipes, 0);
      await typePin(tester, '258046');
      expect(wipes, 1);
    });

    testWidgets('Home says it was done, or that it will try again', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(await openLock(tester), outcome: WipeOutcome.incomplete),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wipe-outcome')), findsOneWidget);
      expect(find.textContaining('هتحاول تاني'), findsOneWidget);
    });
  });

  group('erase after 10 wrong PINs', () {
    testWidgets('turning it on warns first; off needs the PIN', (tester) async {
      tallScreen(tester);
      final lock = await lockedWith(tester, '258046');
      await tester.pumpWidget(app(lock));
      await tester.pumpAndSettle();
      await typePin(tester, '258046');
      await go(tester, appLockSettingsPath);

      final toggle = find.byKey(const ValueKey('app-lock-wipe'));
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('تمسح بعد ١٠ أرقام سرية غلط؟'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(lock.wipeOnFailures, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-lock-wipe-yes')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(lock.wipeOnFailures, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('أكّد إنه إنت'), findsOneWidget);
      await typePin(tester, '258046');
      expect(lock.wipeOnFailures, isFalse);
    });

    testWidgets('the lock screen counts down, and the 10th wrong PIN wipes', (
      tester,
    ) async {
      final lock = await lockedWith(tester, '258046', wipe: true);
      var erased = 0;
      lock.onTooManyFailures = () async => erased++;
      await tester.pumpWidget(app(lock));
      await tester.pumpAndSettle();

      await typePin(tester, '000000');
      expect(
        find.textContaining('٩ أرقام سرية غلط كمان تمسح كل حاجة'),
        findsOneWidget,
      );
      for (var i = 0; i < 8; i++) {
        clocks.pass(lock.waitRemaining);
        await tester.pump(const Duration(seconds: 1));
        await typePin(tester, '000000');
      }
      expect(
        find.textContaining('رقم سري غلط كمان واحد يمسح كل حاجة'),
        findsOneWidget,
      );
      expect(erased, 0);
      clocks.pass(lock.waitRemaining);
      await tester.pump(const Duration(seconds: 1));
      await typePin(tester, '000000');
      expect(erased, 1);
    });
  });

  group('rooted or jailbroken phone (S8)', () {
    testWidgets('warned once, in plain words, and the app carries on', (
      tester,
    ) async {
      final integrity = _FakeIntegrity(['su']);
      await tester.pumpWidget(
        app(await openLock(tester), integrity: integrity),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('root-warning')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('root-warning-ok')));
      await tester.pumpAndSettle();
      expect(find.byType(UsraBottomBar), findsOneWidget);
      expect(prefs.getBool(PrefKeys.rootWarningShown), isTrue);

      // Next start: not again.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(await openLock(tester), integrity: integrity),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('root-warning')), findsNothing);
    });

    testWidgets('waits for the lock, and says nothing on a normal phone', (
      tester,
    ) async {
      final lock = await lockedWith(tester, '258046');
      await tester.pumpWidget(app(lock, integrity: _FakeIntegrity(['su'])));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('root-warning')), findsNothing);
      await typePin(tester, '258046');
      expect(find.byKey(const ValueKey('root-warning')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('root-warning-ok')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      prefs = MemoryKeyValueStore({PrefKeys.tutorialSeen: true});
      store = MemoryLockStore();
      final clean = _FakeIntegrity(const []);
      await tester.pumpWidget(app(await openLock(tester), integrity: clean));
      await tester.pumpAndSettle();
      expect(clean.asked, 1);
      expect(find.byKey(const ValueKey('root-warning')), findsNothing);
    });
  });
}
