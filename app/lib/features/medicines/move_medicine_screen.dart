import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../core/log.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart';
import 'medicine_text.dart';
import 'medicines_providers.dart';

/// Moves [medicine] to [toProfileId]. Photos it shares with another record get a
/// copy of their own first, so the other person keeps theirs and neither sees
/// the other's: see [AppDatabase.moveMedicine].
Future<void> moveMedicineToPerson({
  required AppDatabase db,
  required PhotoStore photos,
  required Medicine medicine,
  required String toProfileId,
}) async {
  final shared = await db.medicinePhotosUsedElsewhere(medicine.id);
  final copies = <String>[];
  try {
    final list = <String>[];
    for (final path in decodeMedicinePhotos(medicine.photosJson)) {
      // A file that's gone has nothing to copy, and mustn't stop the move.
      if (shared.contains(path) && await photos.fileOf(path).exists()) {
        final copy = await photos.duplicate(path);
        copies.add(copy);
        list.add(copy);
      } else if (!shared.contains(path)) {
        list.add(path);
      }
    }
    await db.moveMedicine(
      id: medicine.id,
      fromProfileId: medicine.profileId,
      toProfileId: toProfileId,
      photos: shared.isEmpty ? null : list,
    );
  } catch (_) {
    // Only its own copies: another form may hold a photo not saved yet.
    for (final copy in copies) {
      try {
        await photos.fileOf(copy).delete();
      } catch (e) {
        Log.error('Unused medicine photo not cleared', e);
      }
    }
    rethrow;
  }
}

/// Who a medicine moves to, what goes with it and what stays. Nothing is picked
/// to start with, and the button names both people: a move is never by accident.
class MoveMedicineScreen extends ConsumerStatefulWidget {
  const MoveMedicineScreen({super.key, required this.medicineId});

  final String medicineId;

  @override
  ConsumerState<MoveMedicineScreen> createState() => _MoveMedicineScreenState();
}

class _MoveMedicineScreenState extends ConsumerState<MoveMedicineScreen> {
  String? _to;
  bool _moving = false;

  Future<void> _move(Medicine medicine, Profile to) async {
    if (_moving) return;
    setState(() => _moving = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await moveMedicineToPerson(
        db: ref.read(databaseProvider),
        photos: ref.read(medicinePhotoStoreProvider),
        medicine: medicine,
        toProfileId: to.id,
      );
    } catch (e) {
      Log.error('Medicine not moved', e);
      if (mounted) setState(() => _moving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l.medicineMoveDone(to.displayName))),
    );
    if (mounted) context.go('/family/${to.id}/medicines/${medicine.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final medicine = ref.watch(medicineProvider(widget.medicineId));
    final family = ref.watch(profilesProvider);
    final people = family.value ?? const <Profile>[];
    final m = medicine.value;
    final from = m == null
        ? null
        : people.where((p) => p.id == m.profileId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l.medicineMoveTitle)),
      body: switch ((medicine, family)) {
        (AsyncError(), _) ||
        (_, AsyncError()) => Center(child: Text(l.saveFailed)),
        _ when m == null || from == null =>
          medicine.isLoading || family.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(child: Text(l.medicineNotFound)),
        _ => _body(context, l, text, m, from, people),
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l,
    TextTheme text,
    Medicine m,
    Profile from,
    List<Profile> people,
  ) {
    final others = [
      for (final p in people)
        if (p.id != from.id) p,
    ];
    final picked = others.where((p) => p.id == _to).firstOrNull;
    final givenRows = ref.watch(_givenProvider(m.id));
    final given = givenRows.value ?? const <GivenMedicine>[];
    final stays = [
      if (m.prescriptionId != null) l.medicineMoveStaysPrescription,
      if (given.isNotEmpty) l.medicineMoveStaysSickDays,
      if (given.any((g) => g.remindNext)) l.medicineMoveStopsNextDose,
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(medicineTitle(m), style: text.titleLarge),
        const SizedBox(height: 4),
        Text(
          l.medicineMoveNow(from.displayName),
          key: const ValueKey('move-from'),
          style: text.bodyLarge?.copyWith(color: context.usra.inkMuted),
        ),
        const SizedBox(height: 24),
        Text(l.medicineMoveTo, style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in others)
              ChoiceChip(
                key: ValueKey('move-to-${p.id}'),
                label: Text(p.displayName),
                selected: _to == p.id,
                onSelected: _moving
                    ? null
                    : (on) => setState(() => _to = on ? p.id : null),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l.medicineMoveWhatTitle, style: text.titleSmall),
        const SizedBox(height: 4),
        Text(l.medicineMoveWhat, style: text.bodyMedium),
        if (stays.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l.medicineMoveStaysTitle(from.displayName),
            style: text.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final line in stays)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                key: const ValueKey('move-stays'),
                style: text.bodyMedium,
              ),
            ),
        ],
        if (picked != null) ...[
          const SizedBox(height: 16),
          // An amber dot and words instead of a tinted box.
          StatusDotText(
            key: const ValueKey('move-warning'),
            label: l.medicineMoveReminder(picked.displayName, from.displayName),
            color: context.usra.ink,
            style: text.bodyMedium,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('move-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
          // Not before it's known what stays, which the person must get to read.
          onPressed: picked == null || _moving || !givenRows.hasValue
              ? null
              : () => _move(m, picked),
          child: Text(
            picked == null
                ? l.medicineMoveChoose
                : l.medicineMoveConfirm(picked.displayName),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('move-cancel'),
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _moving ? null : () => Navigator.of(context).maybePop(),
          child: Text(l.medicineMoveKeep(from.displayName)),
        ),
      ],
    );
  }
}

/// Doses of this medicine recorded in sick days, which stay where they were.
final _givenProvider = StreamProvider.autoDispose
    .family<List<GivenMedicine>, String>(
      (ref, medicineId) => ref.watch(databaseProvider).watchGivenOf(medicineId),
    );
