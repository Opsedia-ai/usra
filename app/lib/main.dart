import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/preferences.dart';
import 'core/providers.dart';
import 'features/insurance/card_photos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final key = await DatabaseKeyStore().readOrCreate();
  final file = await defaultDatabaseFile();
  final outcome = prepareDatabaseFile(file, key);
  final database = AppDatabase(openEncryptedDatabase(file, key));
  final preferences = await SharedPreferencesStore.open();
  final cardPhotos = await CardPhotoStore.open();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        keyValueStoreProvider.overrideWithValue(preferences),
        cardPhotoStoreProvider.overrideWithValue(cardPhotos),
        databaseRecoveredProvider.overrideWithValue(
          outcome == DatabaseOpenOutcome.recoveredFromUnreadableFile,
        ),
      ],
      child: const UsraApp(),
    ),
  );
}
