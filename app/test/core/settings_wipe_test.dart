import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:usra/core/preferences.dart';

/// "Delete all my data" clears settings through the real store
/// (`SharedPreferencesStore.clearAll`, wired in `main.dart`). `data_wipe_test`
/// checks the wipe calls it; this checks the store itself leaves nothing.
void main() {
  late InMemorySharedPreferencesAsync platform;

  setUp(() {
    platform = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = platform;
  });

  test(
    'clears every setting the app writes, and anything a plugin left',
    () async {
      final store = await SharedPreferencesStore.open();
      for (final key in PrefKeys.all) {
        await store.setString(key, 'x');
      }
      // A key outside the app's list, as a plugin or an older version might
      // leave (the legacy API prefixes "flutter.").
      await SharedPreferencesAsync().setString('flutter.leftover', 'x');
      await SharedPreferencesAsync().setBool('some_plugin_flag', true);
      expect(await SharedPreferencesAsync().getKeys(), isNotEmpty);

      await store.clearAll();

      expect(await SharedPreferencesAsync().getKeys(), isEmpty);
      final reopened = await SharedPreferencesStore.open();
      for (final key in PrefKeys.all) {
        expect(reopened.getString(key), isNull, reason: key);
      }
    },
  );

  test('settings hold no health data: only flags, choices, times and ids', () {
    // A new key needs a look here before it's added: names, conditions,
    // medicines and readings belong in the encrypted database, never in
    // settings, which are a plain file on the phone.
    expect(PrefKeys.all, {
      PrefKeys.accountInstalled,
      PrefKeys.simpleMode,
      PrefKeys.themeMode,
      PrefKeys.tutorialSeen,
      PrefKeys.elderTutorialSeen,
      PrefKeys.lastBackupAt,
      PrefKeys.appLockOffered,
      PrefKeys.installed,
      PrefKeys.discreetNotifications,
      PrefKeys.blockScreenshots,
      PrefKeys.vaccineReminders,
      PrefKeys.vaccineReminderMinutes,
      PrefKeys.rootWarningShown,
      PrefKeys.shareWarningOff,
      PrefKeys.language,
      PrefKeys.country,
      PrefKeys.meProfileId,
      PrefKeys.consentVersion,
      PrefKeys.consentAt,
      PrefKeys.homeSetupHidden,
    });
  });
}
