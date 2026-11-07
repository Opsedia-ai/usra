import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../backup/backup_screen.dart';
import 'about_you_screen.dart';
import 'country_screen.dart';
import 'welcome_screen.dart';

/// The first run: Welcome, country, About you, then Home. Family, vaccines,
/// reminders, backup and the emergency card wait until someone wants them,
/// and permissions are asked for when they're needed.
class OnboardingModule extends FeatureModule {
  const OnboardingModule();

  @override
  String get id => 'onboarding';

  @override
  List<RouteBase> get fullScreenRoutes => [
    GoRoute(
      path: welcomePath,
      builder: (_, _) => const WelcomeScreen(),
      routes: [
        GoRoute(
          path: 'country',
          builder: (_, _) => const CountryScreen(),
          routes: [
            GoRoute(path: 'about', builder: (_, _) => const AboutYouScreen()),
          ],
        ),
        // The same restore as in Backup; the router would send its usual
        // address back here while the first run is pending.
        GoRoute(path: 'restore', builder: (_, _) => const RestoreScreen()),
      ],
    ),
  ];
}

const welcomeCountryPath = '$welcomePath/country';
const welcomeAboutPath = '$welcomeCountryPath/about';
const welcomeRestorePath = '$welcomePath/restore';
