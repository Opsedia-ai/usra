import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'reports_screens.dart';

/// PDFs made on the phone from the family's records: the vaccination
/// record (C4) and the summary for the doctor (C10). Shared through the
/// share sheet after the usual warning; the file is deleted afterwards.
class ReportsModule extends FeatureModule {
  const ReportsModule();

  @override
  String get id => 'reports';

  @override
  List<RouteBase> get routes => [
    // Opened from a person's page, so it lives under the family tab.
    GoRoute(
      path: '/family/:id/doctor-summary',
      builder: (_, s) =>
          DoctorSummaryScreen(profileId: s.pathParameters['id']!),
    ),
  ];
}
