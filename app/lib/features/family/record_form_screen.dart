import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/records/record_form.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctors_providers.dart';

/// Adds a record of [typeKey] for one person, using the generic [RecordForm].
class RecordFormScreen extends ConsumerWidget {
  const RecordFormScreen({
    super.key,
    required this.profileId,
    required this.typeKey,
  });

  final String profileId;
  final String typeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final type = ref.watch(moduleRegistryProvider).recordTypes[typeKey];
    if (type == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.profileNotFound)),
      );
    }
    final doctors = type.doctorField == null
        ? const <DoctorChoice>[]
        : [
            for (final d in ref.watch(doctorsProvider).value ?? const [])
              DoctorChoice(
                id: d.id,
                name: d.name,
                specialty: d.specialty,
                feeMinor: d.feeMinor,
              ),
          ];
    return Scaffold(
      appBar: AppBar(title: Text(type.labelOf(context))),
      body: RecordForm(
        type: type,
        doctors: doctors,
        strings: RecordFormStrings(
          date: l.recordDate,
          cost: l.recordCost,
          currency: l.currencyEgp,
          save: l.familySave,
          required: l.fieldRequired,
          invalid: l.fieldInvalid,
          pickDate: l.pickDate,
          chooseDoctor: l.chooseDoctor,
        ),
        onSubmit: (result) async {
          try {
            await ref
                .read(databaseProvider)
                .addEvent(
                  profileId: profileId,
                  type: type.key,
                  occurredAt: result.occurredAt,
                  dataJson: jsonEncode(result.data),
                  costMinor: result.costMinor,
                  currency: result.costMinor == null ? null : 'EGP',
                  doctorId: result.doctorId,
                );
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.saveFailed)));
            }
            return;
          }
          if (context.mounted) context.go('/family/$profileId');
        },
      ),
    );
  }
}
