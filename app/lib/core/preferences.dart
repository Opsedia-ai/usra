import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small per-device settings (not health data, so not in the database).
abstract class KeyValueStore {
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
}

/// Kept only while the app runs; what tests use.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, bool>? values]) : _values = {...?values};

  final Map<String, bool> _values;

  @override
  bool? getBool(String key) => _values[key];

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
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
}

abstract final class PrefKeys {
  static const simpleMode = 'simple_mode';
  static const tutorialSeen = 'tutorial_seen';
  static const elderTutorialSeen = 'tutorial_elder_seen';
  static const all = {simpleMode, tutorialSeen, elderTutorialSeen};
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
