import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/consent.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/bottom_bar.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/features/backup/backup_providers.dart';
import 'package:usra/features/backup/backup_screen.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/onboarding/consent_screen.dart';
import 'package:usra/features/settings/about_privacy_screen.dart';
import 'package:usra/features/settings/delete_data_screen.dart';

/// Explicit consent before any health data is saved (Egypt PDPL 151/2020),
/// asked again when the policy version changes.
void main() {
  late AppDatabase db;
  late MemoryKeyValueStore store;
  late List<Uri> opened;
  final now = DateTime.utc(2026, 11, 13, 9, 30);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = MemoryKeyValueStore();
    opened = [];
  });
  tearDown(() => db.close());

  Widget app({double scale = 1}) => MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      textScaler: TextScaler.linear(scale),
    ),
    child: ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        keyValueStoreProvider.overrideWithValue(store),
        consentStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
        backupServiceProvider.overrideWithValue(_NoBackupService()),
        openLinkProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: const UsraApp(),
    ),
  );

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tapKey(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await settle(tester);
  }

  void go(WidgetTester tester, String path) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
          .read(routerProvider)
          .go(path);

  bool agreeEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(
            find.descendant(
              of: key('consent-agree'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed !=
      null;

  testWidgets('first run: Welcome, then consent before the country, with '
      'nothing saved until the box is ticked and I agree is pressed', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('welcome-headline'), findsOneWidget);

    await tapKey(tester, 'welcome-start');
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(find.byType(UsraBottomBar), findsNothing);
    expect(find.text('قبل ما نبدأ'), findsOneWidget);
    expect(
      find.text(
        'بيانات عيلتك الصحية بتفضل على الموبايل ده ومتشفرة، وإحنا مش بنشوفها.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('معلومات أفراد العيلة بتتضاف بصفتك وليّ أمرهم، أو بموافقتهم.'),
      findsOneWidget,
    );
    expect(
      find.text('أسرة مش بتشخّص ولا بتعالج. الرأي دايماً للدكتور.'),
      findsOneWidget,
    );
    expect(find.text('سياسة الخصوصية، إصدار ١٫٠'), findsOneWidget);
    // An update notice and a way to delete are for later, not a first run.
    expect(key('consent-delete'), findsNothing);

    // Unticked to start; the button does nothing until it's ticked.
    expect(tester.widget<CheckboxListTile>(key('consent-tick')).value, isFalse);
    expect(agreeEnabled(tester), isFalse);
    expect(store.getString(PrefKeys.consentVersion), isNull);

    // No way round it: the country and About you lead back here.
    go(tester, '/welcome/country/about');
    await settle(tester);
    expect(find.byType(ConsentScreen), findsOneWidget);

    await tapKey(tester, 'consent-tick');
    expect(agreeEnabled(tester), isTrue);
    await tapKey(tester, 'consent-tick');
    expect(agreeEnabled(tester), isFalse);
    await tapKey(tester, 'consent-tick');
    await tapKey(tester, 'consent-agree');

    expect(store.getString(PrefKeys.consentVersion), consentPolicyVersion);
    expect(store.getString(PrefKeys.consentAt), '2026-11-13T09:30:00.000Z');
    // Back to where it was going.
    expect(key('about-name'), findsOneWidget);
    expect((await tester.runAsync(() => db.watchProfiles().first))!, isEmpty);
  });

  testWidgets('back from consent returns to Welcome', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await tapKey(tester, 'welcome-start');
    await tapKey(tester, 'consent-back');
    expect(key('welcome-headline'), findsOneWidget);
    expect(store.getString(PrefKeys.consentVersion), isNull);
  });

  testWidgets('in English, then on to the country', (tester) async {
    phone(tester);
    store = MemoryKeyValueStore({PrefKeys.language: 'en'});
    await tester.pumpWidget(app());
    await settle(tester);
    await tapKey(tester, 'welcome-start');
    expect(find.text('Before you start'), findsOneWidget);
    expect(
      find.text(
        "Your family's health data stays on this phone, encrypted. We can't "
        'see it.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "You add family members' information as their parent or guardian, or "
        'with their agreement.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Usra doesn\'t diagnose or treat. Always check with a doctor.'),
      findsOneWidget,
    );
    expect(find.text('Privacy policy version 1.0'), findsOneWidget);
    await tapKey(tester, 'consent-privacy');
    await tapKey(tester, 'consent-terms');
    expect(opened, [privacyPolicyUrl('en'), termsUrl('en')]);
    expect(store.getString(PrefKeys.consentVersion), isNull);

    await tapKey(tester, 'consent-tick');
    await tapKey(tester, 'consent-agree');
    expect(key('country-egypt'), findsOneWidget);
    expect(store.getString(PrefKeys.consentVersion), consentPolicyVersion);
  });

  testWidgets('restoring a backup needs consent too', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await tapKey(tester, 'welcome-restore');
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(find.byType(RestoreScreen), findsNothing);
    await tapKey(tester, 'consent-tick');
    await tapKey(tester, 'consent-agree');
    expect(find.byType(RestoreScreen), findsOneWidget);
  });

  testWidgets('a new policy version asks again, before any page opens', (
    tester,
  ) async {
    phone(tester);
    store = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.consentVersion: '0.9',
      PrefKeys.consentAt: '2026-10-01T00:00:00.000Z',
    });
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(
      find.text('سياسة الخصوصية اتغيّرت. محتاجين موافقتك تاني قبل ما نكمّل.'),
      findsOneWidget,
    );
    expect(key('consent-back'), findsNothing);

    go(tester, '/settings');
    await settle(tester);
    expect(find.byType(ConsentScreen), findsOneWidget);

    // Not agreeing still leaves deleting everything.
    await tapKey(tester, 'consent-delete');
    expect(find.byType(DeleteDataScreen), findsOneWidget);
    go(tester, '/home');
    await settle(tester);
    expect(find.byType(ConsentScreen), findsOneWidget);

    await tapKey(tester, 'consent-tick');
    await tapKey(tester, 'consent-agree');
    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.byType(UsraBottomBar), findsOneWidget);
    expect(store.getString(PrefKeys.consentVersion), consentPolicyVersion);
    expect(store.getString(PrefKeys.consentAt), '2026-11-13T09:30:00.000Z');
  });

  testWidgets('someone who already agreed to this version isn\'t asked', (
    tester,
  ) async {
    phone(tester);
    store = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.consentVersion: consentPolicyVersion,
    });
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.byType(UsraBottomBar), findsOneWidget);
  });

  testWidgets('a failed save says so and stays', (tester) async {
    phone(tester);
    store = _FailingStore();
    await tester.pumpWidget(app());
    await settle(tester);
    await tapKey(tester, 'welcome-start');
    await tapKey(tester, 'consent-tick');
    await tapKey(tester, 'consent-agree');
    expect(key('consent-failed'), findsOneWidget);
    expect(find.byType(ConsentScreen), findsOneWidget);
  });

  testWidgets('a screen reader hears the box, its state and the disabled '
      'button', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await settle(tester);
    await tapKey(tester, 'welcome-start');
    final box = tester.getSemantics(key('consent-tick'));
    expect(box.label, contains('قريت سياسة الخصوصية والشروط'));
    expect(box, containsSemantics(hasCheckedState: true, isChecked: false));
    final button = find.byType(FilledButton);
    expect(
      tester.getSemantics(button),
      containsSemantics(hasEnabledState: true, isEnabled: false),
    );
    await tapKey(tester, 'consent-tick');
    expect(
      tester.getSemantics(key('consent-tick')),
      containsSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(button),
      containsSemantics(hasEnabledState: true, isEnabled: true),
    );
    for (final k in ['consent-back', 'consent-privacy', 'consent-terms']) {
      expect(tester.getSize(key(k)).height, greaterThanOrEqualTo(48));
    }
    semantics.dispose();
  });

  for (final (language, dark) in [
    ('ar', false),
    ('ar', true),
    ('en', false),
    ('en', true),
  ]) {
    testWidgets('large text (2x), $language, ${dark ? 'dark' : 'light'}: '
        'fits, and agreeing still works', (tester) async {
      phone(tester);
      store = MemoryKeyValueStore({
        PrefKeys.language: language,
        PrefKeys.themeMode: dark ? 2 : 1,
      });
      await tester.pumpWidget(app(scale: 2));
      await settle(tester);
      await tapKey(tester, 'welcome-start');
      expect(tester.takeException(), isNull);
      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(key('consent-title'))).scale(10),
        20,
      );
      expect(
        Directionality.of(tester.element(key('consent-title'))),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      await tapKey(tester, 'consent-tick');
      await tapKey(tester, 'consent-agree');
      expect(tester.takeException(), isNull);
      expect(key('country-egypt'), findsOneWidget);
    });
  }

  test('declining reaches the real delete page, and consent is a setting '
      'that "Delete all my data" clears', () {
    expect(consentDeletePath, deleteDataPath);
    expect(
      PrefKeys.all,
      containsAll([PrefKeys.consentVersion, PrefKeys.consentAt]),
    );
  });
}

class _NoBackupService extends Fake implements BackupService {}

class _FailingStore extends MemoryKeyValueStore {
  @override
  Future<void> setString(String key, String value) async {
    if (key.startsWith('consent')) throw StateError('disk full');
    return super.setString(key, value);
  }
}
