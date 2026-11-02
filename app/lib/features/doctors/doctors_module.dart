import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../l10n/app_localizations.dart';
import 'doctor_form_screen.dart';
import 'doctor_screen.dart';
import 'doctors_screen.dart';

/// The family's doctors: phone numbers, fees, and visits with each one.
class DoctorsModule extends FeatureModule {
  const DoctorsModule();

  @override
  String get id => 'doctors';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/doctors',
      icon: Icons.contacts_outlined,
      label: (c) => AppLocalizations.of(c).navDoctors,
      order: 20,
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/doctors',
      builder: (_, _) => const DoctorsScreen(),
      routes: [
        GoRoute(path: 'new', builder: (_, _) => const DoctorFormScreen()),
        GoRoute(
          path: ':id',
          builder: (_, s) => DoctorScreen(doctorId: s.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, s) =>
                  DoctorFormScreen(doctorId: s.pathParameters['id']),
            ),
          ],
        ),
      ],
    ),
  ];
}
