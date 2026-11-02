import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules.dart';
import 'database/app_database.dart';
import 'modules/module_registry.dart';

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
  Locale build() => const Locale('ar');

  void change(Locale locale) => state = locale;
}
