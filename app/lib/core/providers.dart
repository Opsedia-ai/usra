import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules.dart';
import 'database/app_database.dart';
import 'log.dart';
import 'modules/module_registry.dart';
import 'preferences.dart';

/// The current time, for everything that decides "today" or "now" on
/// screen: doses, ages, due and expiry dates, default dates and the last day
/// a picker allows. Overridden in tests to fix the date.
///
/// Database timestamps (`updatedAt`, `deletedAt`), backup file times and
/// reminder scheduling with the phone keep the phone's own clock.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// [clockProvider]'s time from the nearest `ProviderScope`, for widgets
/// without a `ref`; the phone's clock when there's no scope.
DateTime nowOf(BuildContext context) {
  final ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } on StateError {
    return DateTime.now();
  }
  return container.read(clockProvider)();
}

/// All feature modules. Override in tests to load a subset.
final moduleRegistryProvider = Provider<ModuleRegistry>(
  (ref) => ModuleRegistry(appModules),
);

/// The encrypted on-device database; provided in `main.dart`.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// True when the previous database couldn't be opened at start-up and was
/// kept aside; the home screen then explains it and points to restore.
final databaseRecoveredProvider = Provider<bool>((ref) => false);

/// App language. Arabic first.
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => Locale(
    ref.watch(keyValueStoreProvider).getString(PrefKeys.language) ?? 'ar',
  );

  void change(Locale locale) {
    state = locale;
    // Kept for the next start; if it can't be saved it only falls back to
    // Arabic then.
    unawaited(_save(locale));
  }

  Future<void> _save(Locale locale) async {
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(PrefKeys.language, locale.languageCode);
    } catch (e) {
      Log.error('Language save failed', e);
    }
  }
}
