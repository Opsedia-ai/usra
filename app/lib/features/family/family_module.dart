import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/records/record_type.dart';
import '../../l10n/app_localizations.dart';
import '../insurance/insurance_card_screen.dart';
import '../insurance/insurance_form_screen.dart';
import 'emergency_card_screen.dart';
import 'family_screen.dart';
import 'member_screen.dart';
import 'profile_form_screen.dart';
import 'record_form_screen.dart';

export 'family_screen.dart' show initialOf;

class FamilyModule extends FeatureModule {
  const FamilyModule();

  @override
  String get id => 'family';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/family',
      icon: Icons.groups_outlined,
      label: (c) => AppLocalizations.of(c).navFamily,
      order: 10,
      simple: true,
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/family',
      builder: (_, _) => const FamilyScreen(),
      routes: [
        GoRoute(path: 'new', builder: (_, _) => const ProfileFormScreen()),
        GoRoute(
          path: ':id',
          builder: (_, s) => MemberScreen(profileId: s.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, s) =>
                  ProfileFormScreen(profileId: s.pathParameters['id']),
            ),
            GoRoute(
              path: 'emergency',
              builder: (_, s) =>
                  EmergencyCardScreen(profileId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'add/:type',
              builder: (_, s) => RecordFormScreen(
                profileId: s.pathParameters['id']!,
                typeKey: s.pathParameters['type']!,
              ),
            ),
            GoRoute(
              path: 'insurance/new',
              builder: (_, s) =>
                  InsuranceFormScreen(profileId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: 'insurance/:cardId',
              builder: (_, s) => InsuranceCardScreen(
                profileId: s.pathParameters['id']!,
                cardId: s.pathParameters['cardId']!,
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, s) => InsuranceFormScreen(
                    profileId: s.pathParameters['id']!,
                    cardId: s.pathParameters['cardId'],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  /// The core record types; later modules add their own (pregnancy, growth...).
  @override
  List<RecordTypeDefinition> get recordTypes => [
    RecordTypeDefinition(
      key: 'visit',
      icon: Icons.medical_services_outlined,
      label: (c) => _l(c).recordVisit,
      doctorField: 'doctorName',
      fields: [
        FieldSpec(
          key: 'doctorName',
          kind: FieldKind.text,
          required: true,
          label: (c) => _l(c).fieldDoctorName,
        ),
        FieldSpec(
          key: 'reason',
          kind: FieldKind.text,
          label: (c) => _l(c).fieldReason,
        ),
        FieldSpec(
          key: 'diagnosis',
          kind: FieldKind.text,
          label: (c) => _l(c).fieldDiagnosis,
        ),
        FieldSpec(
          key: 'nextVisit',
          kind: FieldKind.date,
          label: (c) => _l(c).fieldNextVisit,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: 'scan',
      icon: Icons.image_outlined,
      label: (c) => _l(c).recordScan,
      fields: [
        FieldSpec(
          key: 'kind',
          kind: FieldKind.choice,
          required: true,
          choices: const ['xray', 'ct', 'mri', 'ultrasound', 'other'],
          label: (c) => _l(c).fieldScanKind,
          choiceLabel: _scanKind,
        ),
        FieldSpec(
          key: 'center',
          kind: FieldKind.text,
          label: (c) => _l(c).fieldCenter,
        ),
        FieldSpec(
          key: 'result',
          kind: FieldKind.text,
          label: (c) => _l(c).fieldResult,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: 'lab',
      icon: Icons.science_outlined,
      label: (c) => _l(c).recordLab,
      fields: [
        FieldSpec(
          key: 'test',
          kind: FieldKind.text,
          required: true,
          label: (c) => _l(c).fieldTest,
        ),
        FieldSpec(
          key: 'value',
          kind: FieldKind.number,
          label: (c) => _l(c).fieldValue,
        ),
        FieldSpec(
          key: 'unit',
          kind: FieldKind.text,
          label: (c) => _l(c).fieldUnit,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: 'vaccine',
      icon: Icons.vaccines_outlined,
      label: (c) => _l(c).recordVaccine,
      fields: [
        FieldSpec(
          key: 'vaccine',
          kind: FieldKind.text,
          required: true,
          label: (c) => _l(c).fieldVaccine,
        ),
        FieldSpec(
          key: 'dose',
          kind: FieldKind.number,
          label: (c) => _l(c).fieldDose,
        ),
        FieldSpec(
          key: 'nextDue',
          kind: FieldKind.date,
          label: (c) => _l(c).fieldNextDue,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: 'surgery',
      icon: Icons.local_hospital_outlined,
      label: (c) => _l(c).recordSurgery,
      fields: [
        FieldSpec(
          key: 'procedure',
          kind: FieldKind.text,
          required: true,
          label: (c) => _l(c).fieldProcedure,
        ),
        FieldSpec(
          key: 'hospital',
          kind: FieldKind.text,
          label: (c) => _l(c).fieldHospital,
        ),
        FieldSpec(
          key: 'filmed',
          kind: FieldKind.boolean,
          label: (c) => _l(c).fieldFilmed,
        ),
        FieldSpec(
          key: 'daysInHospital',
          kind: FieldKind.number,
          label: (c) => _l(c).fieldDaysInHospital,
        ),
      ],
    ),
  ];
}

AppLocalizations _l(BuildContext c) => AppLocalizations.of(c);

String _scanKind(BuildContext c, String kind) => switch (kind) {
  'xray' => _l(c).scanXray,
  'ct' => _l(c).scanCt,
  'mri' => _l(c).scanMri,
  'ultrasound' => _l(c).scanUltrasound,
  _ => _l(c).scanOther,
};
