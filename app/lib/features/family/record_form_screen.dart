import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/database/app_database.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/records/record_form.dart';
import '../../core/records/record_type.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../children/child_vaccines.dart' show checklistSourceKey;
import '../doctors/doctors_providers.dart';
import 'member_screen.dart';

/// Adds a record of [typeKey] for one person, or corrects record [eventId], using
/// the generic [RecordForm]. Correcting never changes whose record it is.
class RecordFormScreen extends ConsumerWidget {
  const RecordFormScreen({
    super.key,
    required this.profileId,
    required this.typeKey,
    this.eventId,
  });

  final String profileId;
  final String typeKey;
  final String? eventId;

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
    final editing = eventId != null;
    final MedicalEvent? saved;
    if (editing) {
      final event = ref.watch(eventProvider(eventId!));
      saved = event.value;
      if (saved == null || saved.type != typeKey) {
        return Scaffold(
          appBar: AppBar(),
          body: event.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(child: Text(l.recordNotFound)),
        );
      }
    } else {
      saved = null;
      if (type.screens.add case final add?) return add(profileId);
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
        initialDate: saved?.occurredAt,
        initialData: saved == null
            ? const {}
            : decodeRecordData(saved.dataJson),
        initialCostText: saved?.costMinor == null
            ? null
            : formatMoneyInput(saved!.costMinor!),
        initialDoctorId: saved?.doctorId,
        doctors: doctors,
        strings: recordFormStrings(l),
        // A vaccine record says what was given: it can't be in the future.
        lastOccurredAt: typeKey == 'vaccine' ? DateTime.now() : null,
        pickPhotos: (source) => pickRecordPhotos(context, ref, source),
        onSubmit: (result) async {
          if (!editing && !await ref.read(saveGateProvider).allow()) return;
          if (!context.mounted) return;
          final db = ref.read(databaseProvider);
          final store = result.photos.isEmpty
              ? null
              : ref.read(attachmentStoreProvider);
          try {
            // Copied in first; the form deletes the picked originals.
            final photos = [
              for (final path in result.photos) await store!.import(path),
            ];
            if (saved != null) {
              // Anything the form doesn't show stays as it was.
              final kept = {...decodeRecordData(saved.dataJson)}
                ..removeWhere((key, _) => type.fields.any((f) => f.key == key))
                // Corrected by hand, it's the family's own record now, and
                // unticking the dose warns before removing it.
                ..remove(checklistSourceKey);
              await db.updateEvent(
                saved.id,
                occurredAt: result.occurredAt,
                dataJson: jsonEncode({...kept, ...result.data}),
                costMinor: type.hasCost ? result.costMinor : saved.costMinor,
                currency: !type.hasCost
                    ? saved.currency
                    : result.costMinor == null
                    ? null
                    : saved.currency ?? 'EGP',
                doctorId: result.doctorId,
                photos: photos,
              );
              if (context.mounted) context.pop();
              return;
            }
            await db.addEvent(
              profileId: profileId,
              type: type.key,
              occurredAt: result.occurredAt,
              dataJson: jsonEncode(result.data),
              costMinor: result.costMinor,
              currency: result.costMinor == null ? null : 'EGP',
              doctorId: result.doctorId,
              photos: photos,
            );
          } catch (_) {
            // Copies of a record that wasn't saved.
            try {
              await store?.prune(await db.liveAttachmentPaths());
            } catch (_) {
              // Left for the next save or delete to clean up.
            }
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

/// The words of [RecordForm], in the app's language.
RecordFormStrings recordFormStrings(AppLocalizations l) => RecordFormStrings(
  date: l.recordDate,
  clearDate: l.recordClearDate,
  cost: l.recordCost,
  currency: l.currencyEgp,
  save: l.familySave,
  required: l.fieldRequired,
  invalid: l.fieldInvalid,
  pickDate: l.pickDate,
  chooseDoctor: l.chooseDoctor,
  photos: l.recordPhotos,
  photoCamera: l.photoCamera,
  photoGallery: l.photoGallery,
  photoRemove: l.photoRemove,
);

Future<List<String>> pickRecordPhotos(
  BuildContext context,
  WidgetRef ref,
  ImageSource source,
) async {
  final failed = AppLocalizations.of(context).photoFailed;
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (source == ImageSource.gallery) {
      return await ref.read(multiPhotoPickerProvider)();
    }
    final path = await ref.read(photoPickerProvider)(source);
    return [?path];
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return const [];
  }
}
