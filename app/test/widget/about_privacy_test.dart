import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/backup/backup_providers.dart';
import 'package:usra/features/settings/about_privacy_screen.dart';
import 'package:usra/features/account/account_providers.dart';
import 'package:usra/features/account/supabase_config.dart';

void main() {
  late AppDatabase db;
  late MemoryKeyValueStore prefs;
  late List<Uri> opened;
  late bool opens;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    prefs = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.elderTutorialSeen: true,
    });
    opened = [];
    opens = true;
  });
  tearDown(() => db.close());

  var cloud = SupabaseConfig.none;

  Widget app() => ProviderScope(
    overrides: [
      supabaseConfigProvider.overrideWithValue(cloud),
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(prefs),
      recoveryKeyStoreProvider.overrideWithValue(MemoryRecoveryKeyStore()),
      appVersionProvider.overrideWithValue('0.1.0+1'),
      openLinkProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return opens;
      }),
    ],
    child: const UsraApp(),
  );

  Future<void> openAbout(WidgetTester tester, {bool english = false}) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu).last);
    await tester.pumpAndSettle();
    if (english) {
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'More → About & privacy shows the summary, disclaimer and version',
    (tester) async {
      await openAbout(tester);

      expect(find.text('عن أسرة والخصوصية'), findsOneWidget);
      expect(find.text('خصوصيتك، بكلام بسيط'), findsOneWidget);
      expect(find.textContaining('قاعدة بيانات متشفرة'), findsOneWidget);
      expect(find.textContaining('مفيش حساب'), findsOneWidget);
      expect(find.text('تنبيه طبي'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('about-medical')),
          matching: find.textContaining('أسرة مش جهاز طبي'),
        ),
        findsOneWidget,
      );
      expect(find.text('النسخة 0.1.0+1'), findsOneWidget);
    },
  );

  testWidgets('Dr. Usra AI shows as coming soon and can\'t be opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey('settings-ai-soon')),
    );
    expect(tile.enabled, isFalse);
    expect(tile.onTap, isNull);
    expect(find.text('Dr. Usra AI'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('the back arrow returns to More', (tester) async {
    await openAbout(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-about')), findsOneWidget);
  });

  testWidgets('the placeholder site is only allowed outside store builds', (
    tester,
  ) async {
    // Store builds set USRA_RELEASE and USRA_WEBSITE; without USRA_WEBSITE
    // releaseWebsiteCheck stops the compile.
    expect(releaseWebsiteCheck, isNotNull);
    if (isStoreRelease) {
      expect(usraWebsite, isNot(placeholderWebsite));
      expect(Uri.parse(usraWebsite).scheme, 'https');
    }
  });

  testWidgets('policy and terms open in the browser, in the app language', (
    tester,
  ) async {
    await openAbout(tester);

    await tester.tap(find.byKey(const ValueKey('about-privacy-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('about-terms')));
    await tester.pumpAndSettle();

    expect(opened, [privacyPolicyUrl('ar'), termsUrl('ar')]);
    expect(opened.first.toString(), '$usraWebsite/ar/privacy');
  });

  testWidgets('a link that cannot open says so', (tester) async {
    opens = false;
    await openAbout(tester);

    await tester.tap(find.byKey(const ValueKey('about-privacy-policy')));
    await tester.pumpAndSettle();

    expect(find.text('مقدرناش نفتح الصفحة. اتأكد من النت.'), findsOneWidget);
  });

  testWidgets('a build with accounts doesn\'t say there are none', (
    tester,
  ) async {
    cloud = const SupabaseConfig(
      url: 'https://example.supabase.co',
      anonKey: 'anon',
    );
    addTearDown(() => cloud = SupabaseConfig.none);
    await openAbout(tester);
    expect(find.textContaining('مفيش حساب'), findsNothing);
    expect(find.textContaining('الحساب اختياري'), findsOneWidget);
  });

  testWidgets('in English', (tester) async {
    await openAbout(tester, english: true);

    expect(find.text('About & privacy'), findsOneWidget);
    expect(find.text('Medical disclaimer'), findsOneWidget);
    expect(find.text('Version 0.1.0+1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('about-privacy-policy')));
    await tester.pumpAndSettle();
    expect(opened, [privacyPolicyUrl('en')]);
  });
}
