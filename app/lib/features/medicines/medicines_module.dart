import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../l10n/app_localizations.dart';
import 'medicine_form_screen.dart';
import 'medicine_list_screen.dart';
import 'medicine_screen.dart';
import 'move_medicine_screen.dart';
import 'prescription_form_screen.dart';
import 'prescription_screen.dart';
import 'today_screen.dart';

/// Medicines and prescriptions as the doctor wrote them, today's doses for
/// the family, and reminders at dose times.
class MedicinesModule extends FeatureModule {
  const MedicinesModule();

  @override
  String get id => 'medicines';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/medicines',
      icon: Icons.medication_outlined,
      label: (c) => AppLocalizations.of(c).navMedicines,
      order: 15,
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/medicines',
      builder: (_, _) => const TodayScreen(),
      routes: [
        GoRoute(path: 'all', builder: (_, _) => const AllMedicinesScreen()),
      ],
    ),
    // A person's medicines, opened from their page, under the family tab.
    GoRoute(
      path: '/family/:id/medicines',
      builder: (_, s) => MedicineListScreen(profileId: s.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, s) => MedicineFormScreen(
            key: ValueKey(s.uri.path),
            profileId: s.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: ':medicineId',
          builder: (_, s) => MedicineScreen(
            profileId: s.pathParameters['id']!,
            medicineId: s.pathParameters['medicineId']!,
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, s) => MedicineFormScreen(
                key: ValueKey(s.uri.path),
                profileId: s.pathParameters['id']!,
                medicineId: s.pathParameters['medicineId'],
              ),
            ),
            GoRoute(
              path: 'move',
              builder: (_, s) => MoveMedicineScreen(
                key: ValueKey(s.uri.path),
                medicineId: s.pathParameters['medicineId']!,
              ),
            ),
          ],
        ),
      ],
    ),
    // A prescription with several medicines, entered in one go (C5).
    GoRoute(
      path: '/family/:id/prescriptions',
      redirect: (_, s) => s.uri.pathSegments.length == 3
          ? '/family/${s.pathParameters['id']}/medicines'
          : null,
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, s) => PrescriptionFormScreen(
            key: ValueKey(s.uri.path),
            profileId: s.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: ':prescriptionId',
          builder: (_, s) => PrescriptionScreen(
            profileId: s.pathParameters['id']!,
            prescriptionId: s.pathParameters['prescriptionId']!,
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, s) => PrescriptionFormScreen(
                key: ValueKey(s.uri.path),
                profileId: s.pathParameters['id']!,
                prescriptionId: s.pathParameters['prescriptionId'],
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}
