import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'episode_list_screen.dart';
import 'episode_screen.dart';
import 'fever_reading_start.dart';

/// Fever and sick days (C8): temperatures, symptoms, medicines given as
/// the family wrote them, and sourced warning signs. No dose advice.
class SickDaysModule extends FeatureModule {
  const SickDaysModule();

  @override
  String get id => 'sick_days';

  @override
  List<RouteBase> get routes => [
    // Opened from a person's page, so it lives under the family tab.
    GoRoute(
      path: '/family/:id/sick-days',
      builder: (_, s) => EpisodeListScreen(profileId: s.pathParameters['id']!),
    ),
  ];

  @override
  List<RouteBase> get fullScreenRoutes => [
    // Its own bottom actions take the tab bar's place.
    GoRoute(
      path: '/family/:id/sick-days/:episodeId',
      builder: (_, s) => EpisodeScreen(
        profileId: s.pathParameters['id']!,
        episodeId: s.pathParameters['episodeId']!,
        openReading: s.uri.queryParameters['reading'] == '1',
      ),
    ),
    // The Add sheet's temperature: a reading on the sick day going on.
    GoRoute(
      path: '/family/:id/fever',
      builder: (_, s) => FeverReadingStart(profileId: s.pathParameters['id']!),
    ),
  ];
}
