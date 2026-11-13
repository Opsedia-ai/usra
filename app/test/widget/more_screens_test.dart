import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/status_dot.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/account/account_providers.dart';
import 'package:usra/features/account/device_identity.dart';
import 'package:usra/features/account/login_config.dart';
import 'package:usra/features/account/supabase_config.dart';
import 'package:usra/features/app_lock/app_lock_module.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_auth_gateway.dart';
import '../support/fits.dart';

void main() {
  late AppDatabase db;
  late MemoryKeyValueStore prefs;
  late FakeAuthGateway gateway;
  var theme = ThemeMode.light;

  const cloud = SupabaseConfig(
    url: 'https://example.supabase.co',
    anonKey: 'anon',
  );

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
    gateway = FakeAuthGateway(signedIn: FakeAuthGateway.googleUser);
    theme = ThemeMode.light;
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    String path, {
    bool login = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(prefs),
          themeModeProvider.overrideWith(() => _FixedTheme(theme)),
          supabaseConfigProvider.overrideWithValue(
            login ? cloud : SupabaseConfig.none,
          ),
          if (login) authGatewayProvider.overrideWithValue(gateway),
          loginConfigProvider.overrideWithValue(
            const LoginConfig(googleWebClientId: 'web'),
          ),
          devicePlatformProvider.overrideWithValue('android'),
          deviceIdentityStoreProvider.overrideWithValue(
            MemoryDeviceIdentityStore(),
          ),
          accountReinstallCheckProvider.overrideWithValue(() async {}),
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await settle(tester);
  }

  void tall(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 8000);
    addTearDown(tester.view.reset);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('pages opened from More have a way back (QA M5)', (tester) async {
    tall(tester);
    for (final link in [
      'more-family',
      'more-doctors',
      'more-money',
      'settings-backup',
      'settings-about',
    ]) {
      await open(tester, '/settings');
      await tester.tap(key(link));
      await settle(tester);
      expect(find.byType(BackButton), findsOneWidget, reason: link);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(key('more-doctors'), findsOneWidget, reason: link);
    }
  });

  testWidgets('More has its groups in order, with chevrons on links', (
    tester,
  ) async {
    tall(tester);
    await open(tester, '/settings');
    final family = tester.getTopLeft(find.text('العيلة').first).dy;
    final safety = tester.getTopLeft(find.text('الأمان')).dy;
    final app = tester.getTopLeft(find.text('التطبيق')).dy;
    expect(family, lessThan(safety));
    expect(safety, lessThan(app));
    for (final link in [
      'more-family',
      'more-doctors',
      'more-money',
      'settings-backup',
      'settings-app-lock',
      'settings-about',
    ]) {
      expect(
        find.descendant(
          of: key(link),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
        reason: link,
      );
    }
    // Not built, so not offered.
    expect(find.textContaining('كود'), findsNothing);
    expect(key('settings-account'), findsNothing);
    // One-line rows: no backup is an amber status, the lock just says off.
    expect(
      find.descendant(
        of: key('settings-backup'),
        matching: find.byType(StatusDot),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: key('settings-backup'),
        matching: find.text('لسه مفيش نسخة'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: key('settings-app-lock'),
        matching: find.text('مش شغّال'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: key('more-money'), matching: find.text('المصاريف')),
      findsOneWidget,
    );
  });

  testWidgets('Dr. Usra says "soon" and nothing about what it will do', (
    tester,
  ) async {
    tall(tester);
    await open(tester, '/settings');
    final tile = tester.widget<ListTile>(key('settings-ai-soon'));
    expect(tile.enabled, isFalse);
    expect((tile.subtitle! as Text).data, 'قريب');
    expect(find.textContaining('تحليل'), findsNothing);
  });

  testWidgets('with login on, More leads to the account, which says what it '
      'keeps and promises nothing about later', (tester) async {
    tall(tester);
    await open(tester, '/settings', login: true);
    expect(key('settings-account'), findsOneWidget);
    await tester.tap(key('settings-account'));
    await settle(tester);
    expect(key('account-keeps'), findsOneWidget);
    expect(key('account-delete-note'), findsOneWidget);
    expect(find.textContaining('مزامنة'), findsNothing);
    expect(find.textContaining('الذكاء'), findsNothing);
    final deleteButton = tester.widget<TextButton>(key('account-delete'));
    final color = deleteButton.style!.foregroundColor!.resolve({});
    expect(
      color,
      Severity.actSoon.foregroundOf(tester.element(key('account-delete'))),
    );
  });

  test(
    'the account text no longer mentions sync or AI, in either language',
    () {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        final l = lookupAppLocalizations(locale);
        expect(l.accountPrivacy, isNot(contains('مزامنة')));
        expect(l.accountPrivacy, isNot(contains('AI')));
        expect(l.accountPrivacy, isNot(contains('sync')));
      }
    },
  );

  testWidgets('Privacy answers the five questions and leads to delete', (
    tester,
  ) async {
    tall(tester);
    await open(tester, '/settings/about');
    expect(key('privacy-answers'), findsOneWidget);
    expect(find.text('إيه اللي متشفر؟'), findsOneWidget);
    expect(find.text('لأ. السجلات والصور بتفضل على موبايلك.'), findsOneWidget);
    expect(find.textContaining('من غير نسخة، السجلات بتضيع'), findsOneWidget);
    expect(find.textContaining('بتفضل لحد ما تتمسح'), findsOneWidget);
    // The full policy and terms stay linked.
    expect(key('about-privacy-policy'), findsOneWidget);
    expect(key('about-terms'), findsOneWidget);
    await tester.ensureVisible(key('privacy-delete-all'));
    await settle(tester);
    await tester.tap(key('privacy-delete-all'));
    await settle(tester);
    expect(key('privacy-answers'), findsNothing);
  });

  testWidgets('choosing a PIN says the backup is what makes it safe', (
    tester,
  ) async {
    tall(tester);
    await prefs.setInt(
      PrefKeys.lastBackupAt,
      DateTime(2026, 11, 3).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PinSetupScreen(),
        ),
      ),
    );
    await settle(tester);
    expect(key('setup-backup-ready'), findsOneWidget);
    expect(key('setup-step'), findsOneWidget);
    expect(find.textContaining('احفظ الرقم السري'), findsOneWidget);
  });

  testWidgets('choosing a PIN fits a small phone at double text', (
    tester,
  ) async {
    smallPhoneDoubleText(tester);
    await prefs.setInt(
      PrefKeys.lastBackupAt,
      DateTime(2026, 11, 3).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PinSetupScreen(),
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.textContaining('احفظ الرقم السري'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  group('fits a small phone at double text', () {
    for (final locale in const ['ar', 'en']) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('$locale, ${mode.name}', (tester) async {
          smallPhoneDoubleText(tester);
          theme = mode;
          await prefs.setString(PrefKeys.language, locale);
          await open(tester, '/settings', login: true);
          await walkScreen(tester);
          for (final path in const [
            '/settings/account',
            '/settings/about',
            '/settings/app-lock',
          ]) {
            GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
            await settle(tester);
            await walkScreen(tester);
          }
        });
      }
    }
  });
}

class _FixedTheme extends ThemeModeController {
  _FixedTheme(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}
