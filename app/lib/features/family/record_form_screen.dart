import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/records/record_form.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
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
    if (type.screens.add case final add?) return add(profileId);
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
          photos: l.recordPhotos,
          photoCamera: l.photoCamera,
          photoGallery: l.photoGallery,
          photoRemove: l.photoRemove,
        ),
        pickPhotos: (source) => _pickPhotos(context, ref, source),
        onSubmit: (result) async {
          if (!await ref.read(saveGateProvider).allow()) return;
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

  Future<List<String>> _pickPhotos(
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
}
