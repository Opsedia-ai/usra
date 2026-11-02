# Usra mobile app (Flutter)

Android + iOS from one codebase. Arabic first (right to left), English second. Records stay on the phone in an encrypted database.

## Run it

Requirements: Flutter (stable), plus Android Studio (Android SDK) and/or Xcode for devices.

```bash
flutter pub get
flutter run            # on a connected phone or simulator
flutter test           # unit + widget tests
flutter analyze
```

After changing database tables or ARB strings:

```bash
dart run build_runner build --delete-conflicting-outputs   # Drift
flutter gen-l10n                                           # translations
```

## Structure

```
lib/
  main.dart                 opens the encrypted database, starts the app
  app.dart                  MaterialApp: theme, locale, router
  modules.dart              the list of feature modules
  core/
    modules/                FeatureModule contract + ModuleRegistry
    records/                RecordTypeDefinition / FieldSpec / registry
    routing/                router + bottom navigation built from modules
    database/               Drift tables, AppDatabase, encrypted connection, key store
    design/                 colours, severity scale, theme, SeverityChip, Dr. Usra
    providers.dart          Riverpod providers (registry, database, locale)
  features/
    home/  family/  settings/
  l10n/                     app_ar.arb, app_en.arb (+ generated classes)
test/
  core/                     severity contrast, registry, record types, database
  widget/                   app starts in Arabic RTL, language switch, add a person
```

## Adding a feature

1. Create `lib/features/<name>/<name>_module.dart` with a class that extends `FeatureModule`.
2. Give it routes, an optional tab, and any record types it adds.
3. Add it to `appModules` in `lib/modules.dart`.
4. Add strings to both ARB files and tests under `test/`.

The core never imports a feature.

## Encryption

`package:sqlite3` is built with SQLite3 Multiple Ciphers (`hooks.user_defines.sqlite3.source: sqlite3mc` in `pubspec.yaml`). A random 256-bit key is created on first launch and kept in Android Keystore / iOS Keychain (`flutter_secure_storage`); `PRAGMA key` is the first statement on every connection.
