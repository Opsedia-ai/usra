import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../core/records/record_type.dart';
import '../../l10n/app_localizations.dart';
import 'lab_report.dart';
import 'lab_report_form_screen.dart';
import 'lab_results_screen.dart';
import 'lab_widgets.dart';

/// Lab reports: several results per report with the lab's printed range,
/// a flag from that range only, trends per test, and reading a report
/// from a photo on the phone. Informational: never a diagnosis.
class LabsModule extends FeatureModule {
  const LabsModule();

  @override
  String get id => 'labs';

  @override
  List<RouteBase> get routes => [
    // Opened from a person's page, so they live under the family tab.
    GoRoute(
      path: '/family/:id/labs',
      builder: (_, s) => LabResultsScreen(profileId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/family/:id/labs/test/:test',
      builder: (_, s) => LabTrendScreen(
        profileId: s.pathParameters['id']!,
        routeId: s.pathParameters['test']!,
      ),
    ),
    GoRoute(
      path: '/family/:id/labs/:eventId/edit',
      builder: (_, s) => LabReportFormScreen(
        key: ValueKey(s.uri.path),
        profileId: s.pathParameters['id']!,
        eventId: s.pathParameters['eventId'],
      ),
    ),
  ];

  @override
  List<RecordTypeDefinition> get recordTypes => [
    RecordTypeDefinition(
      key: LabFields.type,
      icon: Icons.science_outlined,
      label: (c) => _l(c).recordLab,
      // Old single-test records were saved with these; reports keep the
      // test names in `test` too (see LabFields).
      fields: [
        FieldSpec(
          key: LabFields.test,
          kind: FieldKind.text,
          required: true,
          label: (c) => _l(c).fieldTests,
        ),
        FieldSpec(
          key: LabFields.value,
          kind: FieldKind.number,
          keepsLatinDigits: true,
          label: (c) => _l(c).fieldValue,
        ),
        FieldSpec(
          key: LabFields.unit,
          kind: FieldKind.text,
          label: (c) => _l(c).fieldUnit,
        ),
        FieldSpec(
          key: LabFields.lab,
          kind: FieldKind.text,
          label: (c) => _l(c).fieldLab,
        ),
        FieldSpec(
          key: LabFields.orderedBy,
          kind: FieldKind.text,
          label: (c) => _l(c).fieldOrderedBy,
        ),
      ],
      screens: RecordTypeScreens(
        add: (profileId) => LabReportFormScreen(profileId: profileId),
        editPath: LabReportFormScreen.editPath,
        details: (_, event) => LabReportDetails(event: event),
        shareLines: labShareLines,
      ),
    ),
  ];
}

AppLocalizations _l(BuildContext c) => AppLocalizations.of(c);
