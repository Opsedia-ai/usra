import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small per-device settings (not health data, so not in the database).
abstract class KeyValueStore {
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  int? getInt(String key);
  Future<void> setInt(String key, int value);
  String? getString(String key);
  Future<void> setString(String key, String value);
}

/// Kept only while the app runs; what tests use.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, Object>? values]) : _values = {...?values};

  final Map<String, Object> _values;

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}

/// Saved on the phone with shared_preferences.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore._(this._prefs);

  static Future<SharedPreferencesStore> open() async =>
      SharedPreferencesStore._(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: PrefKeys.all,
          ),
        ),
      );

  final SharedPreferencesWithCache _prefs;

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  /// Every saved setting, for "Delete all my data": this store's keys and
  /// anything else in shared preferences (account flags, plugins').
  Future<void> clearAll() async {
    await _prefs.clear();
    await SharedPreferencesAsync().clear();
  }
}

abstract final class PrefKeys {
  static const simpleMode = 'simple_mode';

  /// Light or dark look; missing follows the phone. See [ThemeModeController].
  static const themeMode = 'theme_mode';

  /// The first run is done: Welcome and About you, or, before those existed,
  /// the first-run tour. Missing means Welcome is still to come.
  static const tutorialSeen = 'tutorial_seen';
  static const elderTutorialSeen = 'tutorial_elder_seen';
  static const lastBackupAt = 'last_backup_at';

  /// Home's offer of the app lock was dismissed, or (older versions) the
  /// first-run offer was answered.
  static const appLockOffered = 'app_lock_offered';

  /// Set on first start. Missing means a fresh install, so a lock left in
  /// the iOS Keychain by a deleted copy of the app is dropped.
  static const installed = 'installed';

  static const discreetNotifications = 'discreet_notifications';
  static const blockScreenshots = 'block_screenshots';

  /// Vaccine visit reminders on (default) or off, and their time of day in
  /// minutes after midnight (default 10:00).
  static const vaccineReminders = 'vaccine_reminders';
  static const vaccineReminderMinutes = 'vaccine_reminder_minutes';

  /// The rooted / jailbroken phone warning was shown (once per install).
  static const rootWarningShown = 'root_warning_shown';

  /// "Don't ask again" on the warning before sharing outside the app.
  static const shareWarningOff = 'share_warning_off';

  /// The app's language, `ar` or `en`. Missing means Arabic.
  static const language = 'language';

  /// The chosen country, as an ISO code. Only `EG` for now.
  static const country = 'country';

  /// Which family profile is the person using this phone, from About you.
  /// Just the id, which says nothing about them. Not in a backup, so a
  /// restored phone has none until it's set again; a profile id that's gone
  /// is treated as none.
  static const meProfileId = 'me_profile_id';

  /// This install has checked for account secrets left by an earlier one.
  static const accountInstalled = 'usra.account.installed.v1';
  static const all = {
    accountInstalled,
    simpleMode,
    themeMode,
    tutorialSeen,
    elderTutorialSeen,
    lastBackupAt,
    appLockOffered,
    installed,
    discreetNotifications,
    blockScreenshots,
    vaccineReminders,
    vaccineReminderMinutes,
    rootWarningShown,
    shareWarningOff,
    language,
    country,
    meProfileId,
  };
}

/// Overridden in `main.dart` with [SharedPreferencesStore]. The default,
/// used by tests, starts with the tours already seen so they don't cover the
/// app; tests of the tours pass an empty [MemoryKeyValueStore].
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => MemoryKeyValueStore({
    PrefKeys.tutorialSeen: true,
    PrefKeys.elderTutorialSeen: true,
  }),
);

/// Simple Mode: bigger text and buttons, three tabs, a plain Home. For
/// grandparents using the phone on their own.
final simpleModeProvider = NotifierProvider<SimpleModeController, bool>(
  SimpleModeController.new,
);

class SimpleModeController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(keyValueStoreProvider).getBool(PrefKeys.simpleMode) ?? false;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(keyValueStoreProvider).setBool(PrefKeys.simpleMode, on);
  }
}

/// Follow the phone (default), or always light or dark.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  // Saved as fixed numbers, so reordering the enum can't change a choice.
  static const _saved = {
    ThemeMode.system: 0,
    ThemeMode.light: 1,
    ThemeMode.dark: 2,
  };

  @override
  ThemeMode build() {
    final saved = ref.watch(keyValueStoreProvider).getInt(PrefKeys.themeMode);
    return _saved.entries
        .firstWhere(
          (e) => e.value == saved,
          orElse: () => const MapEntry(ThemeMode.system, 0),
        )
        .key;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(keyValueStoreProvider)
        .setInt(PrefKeys.themeMode, _saved[mode]!);
  }
}

/// Discreet notifications: reminders say "Your medicine time" without anyone's
/// or any medicine's name, since they show on a phone others can see. On unless
/// switched off. The home-screen widget never has names, whatever this says.
final discreetNotificationsProvider = NotifierProvider<BoolPreference, bool>(
  () => BoolPreference(PrefKeys.discreetNotifications, fallback: true),
);

/// Block screenshots and screen recording in the whole app. Off by default
/// so families can screenshot the emergency card; the recovery key is
/// always blocked.
final blockScreenshotsProvider = NotifierProvider<BoolPreference, bool>(
  () => BoolPreference(PrefKeys.blockScreenshots, fallback: false),
);

/// Home's offer of the app lock was dismissed, so it stays away. The lock is
/// still in More.
final appLockOfferAnsweredProvider = NotifierProvider<BoolPreference, bool>(
  () => BoolPreference(PrefKeys.appLockOffered, fallback: false),
);

/// Vaccine visit reminders, a week before and on the day. On unless
/// switched off.
final vaccineRemindersProvider = NotifierProvider<BoolPreference, bool>(
  () => BoolPreference(PrefKeys.vaccineReminders, fallback: true),
);

/// When vaccine reminders ring, in minutes after midnight: 10:00 unless
/// changed.
final vaccineReminderMinutesProvider = NotifierProvider<IntPreference, int>(
  () => IntPreference(PrefKeys.vaccineReminderMinutes, fallback: 600),
);

/// A number saved under [key].
class IntPreference extends Notifier<int> {
  IntPreference(this.key, {required this.fallback});

  final String key;
  final int fallback;

  @override
  int build() => ref.watch(keyValueStoreProvider).getInt(key) ?? fallback;

  Future<void> set(int value) async {
    state = value;
    await ref.read(keyValueStoreProvider).setInt(key, value);
  }
}

/// An on/off setting saved under [key].
class BoolPreference extends Notifier<bool> {
  BoolPreference(this.key, {required this.fallback});

  final String key;
  final bool fallback;

  @override
  bool build() => ref.watch(keyValueStoreProvider).getBool(key) ?? fallback;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(keyValueStoreProvider).setBool(key, on);
  }
}

/// Where the tutorial module shows the walkthrough.
const tutorialPath = '/tutorial';

/// Where the first run starts.
const welcomePath = '/welcome';

/// Whether the first run is still to do: Welcome, country, About you. Every
/// page leads there until it's done. Simple Mode has its own short tour
/// instead (see [tutorialProvider]).
final onboardingProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);

class OnboardingController extends Notifier<bool> {
  @override
  bool build() {
    if (ref.watch(simpleModeProvider)) return false;
    return ref.read(keyValueStoreProvider).getBool(PrefKeys.tutorialSeen) !=
        true;
  }

  /// Saved first: if that fails the first run stays pending and says so.
  Future<void> finish() async {
    await ref.read(keyValueStoreProvider).setBool(PrefKeys.tutorialSeen, true);
    state = false;
  }
}

/// After a restore the family is already here, so the first run is skipped,
/// and the backup just restored counts as the last one. Runs in `main.dart`.
Future<void> rememberRestore(
  KeyValueStore store,
  DateTime backupCreatedAt,
) async {
  await store.setBool(PrefKeys.tutorialSeen, true);
  await store.setInt(
    PrefKeys.lastBackupAt,
    backupCreatedAt.millisecondsSinceEpoch,
  );
}

/// Which family profile is "me", from About you. See [PrefKeys.meProfileId].
final meProfileIdProvider = NotifierProvider<MeProfileController, String?>(
  MeProfileController.new,
);

class MeProfileController extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(keyValueStoreProvider).getString(PrefKeys.meProfileId);

  Future<void> set(String id) async {
    await ref.read(keyValueStoreProvider).setString(PrefKeys.meProfileId, id);
    state = id;
  }
}

/// Whether the Dr. Usra walkthrough is on screen: the elder version once in
/// Simple Mode, and either version whenever it's reopened from Settings.
final tutorialProvider = NotifierProvider<TutorialController, bool>(
  TutorialController.new,
);

class TutorialController extends Notifier<bool> {
  bool _reopened = false;

  String get _key => ref.read(simpleModeProvider)
      ? PrefKeys.elderTutorialSeen
      : PrefKeys.tutorialSeen;

  @override
  bool build() {
    // The regular first run is Welcome and About you, not the tour.
    if (!ref.watch(simpleModeProvider)) return _reopened;
    final seen = ref.read(keyValueStoreProvider).getBool(_key) ?? false;
    return _reopened || !seen;
  }

  /// Opened again from Settings, rather than the first-run tour.
  bool get reopened => _reopened;

  void reopen() {
    _reopened = true;
    state = true;
  }

  Future<void> finish() async {
    _reopened = false;
    state = false;
    final store = ref.read(keyValueStoreProvider);
    await store.setBool(_key, true);
    // Finishing either tour means the basics were seen.
    await store.setBool(PrefKeys.tutorialSeen, true);
  }
}
