import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/files/photo_store.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final key = await DatabaseKeyStore().readOrCreate();
  final file = await defaultDatabaseFile();
  final outcome = prepareDatabaseFile(file, key);
  final database = AppDatabase(openEncryptedDatabase(file, key));
  final cardPhotos = await PhotoStore.open(PhotoStore.cardsFolder);
  final attachments = await PhotoStore.open(PhotoStore.attachmentsFolder);
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        cardPhotoStoreProvider.overrideWithValue(cardPhotos),
        attachmentStoreProvider.overrideWithValue(attachments),
        databaseRecoveredProvider.overrideWithValue(
          outcome == DatabaseOpenOutcome.recoveredFromUnreadableFile,
        ),
      ],
      child: const UsraApp(),
    ),
  );
}
