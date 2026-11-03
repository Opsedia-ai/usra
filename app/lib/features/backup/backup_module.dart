import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'backup_screen.dart';
import 'recovery_key_screen.dart';

/// Encrypted backups the family keeps (Drive, Files, WhatsApp to self),
/// the recovery key that opens them, and restoring on a new phone.
class BackupModule extends FeatureModule {
  const BackupModule();

  @override
  String get id => 'backup';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: backupPath,
      builder: (_, _) => const BackupScreen(),
      routes: [
        GoRoute(path: 'key', builder: (_, _) => const RecoveryKeyScreen()),
        GoRoute(path: 'restore', builder: (_, _) => const RestoreScreen()),
      ],
    ),
  ];
}
