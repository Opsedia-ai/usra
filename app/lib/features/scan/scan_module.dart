import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'scan_medicine_screen.dart';

/// Reading things from photos, on the phone. No tab: other features open
/// its screens and get the result back.
class ScanModule extends FeatureModule {
  const ScanModule();

  @override
  String get id => 'scan';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: ScanMedicineScreen.path,
      builder: (_, _) => const ScanMedicineScreen(),
    ),
  ];
}
