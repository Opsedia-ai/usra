import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/files/photo_store.dart';
import 'core/preferences.dart';
import 'core/providers.dart';
import 'features/follow_ups/dismissals.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final key = await DatabaseKeyStore().readOrCreate();
  final file = await defaultDatabaseFile();
  final outcome = prepareDatabaseFile(file, key);
  final database = AppDatabase(openEncryptedDatabase(file, key));
  final (preferences, cardPhotos, attachments, dismissals) = await (
    SharedPreferencesStore.open(),
    PhotoStore.open(PhotoStore.cardsFolder),
    PhotoStore.open(PhotoStore.attachmentsFolder),
    FileDismissalStore.open(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        keyValueStoreProvider.overrideWithValue(preferences),
        cardPhotoStoreProvider.overrideWithValue(cardPhotos),
        attachmentStoreProvider.overrideWithValue(attachments),
        dismissalStoreProvider.overrideWithValue(dismissals),
        databaseRecoveredProvider.overrideWithValue(
          outcome == DatabaseOpenOutcome.recoveredFromUnreadableFile,
        ),
      ],
      child: const UsraApp(),
    ),
  );
}
