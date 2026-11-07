import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small per-device settings (not health data, so not in the database).
abstract class KeyValueStore {
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  int? getInt(String key);
  Future<void> setInt(String key, int value);
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
  static const tutorialSeen = 'tutorial_seen';
  static const elderTutorialSeen = 'tutorial_elder_seen';
  static const lastBackupAt = 'last_backup_at';

  /// The first-run offer to turn on the app lock was answered.
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

/// Discreet notifications: reminders and the home-screen widget say "Your
/// medicine time" without anyone's or any medicine's name, since both show
/// on a phone others can see. On unless switched off.
final discreetNotificationsProvider = NotifierProvider<BoolPreference, bool>(
  () => BoolPreference(PrefKeys.discreetNotifications, fallback: true),
);

/// Block screenshots and screen recording in the whole app. Off by default
/// so families can screenshot the emergency card; the recovery key is
/// always blocked.
final blockScreenshotsProvider = NotifierProvider<BoolPreference, bool>(
  () => BoolPreference(PrefKeys.blockScreenshots, fallback: false),
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

/// Whether the Dr. Usra walkthrough is on screen. It shows once on first
/// run (the short elder version when Simple Mode is on, itself once), and
/// again whenever it's reopened from Settings.
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
    ref.watch(simpleModeProvider);
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
