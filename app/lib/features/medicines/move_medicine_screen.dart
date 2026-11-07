import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
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
  final kept = decodeMedicinePhotos(medicine.photosJson);
  final copies = [
    for (final path in kept)
      shared.contains(path) ? await photos.duplicate(path) : path,
  ];
  try {
    await db.moveMedicine(
      id: medicine.id,
      fromProfileId: medicine.profileId,
      toProfileId: toProfileId,
      photos: shared.isEmpty ? null : copies,
    );
  } catch (_) {
    if (shared.isNotEmpty) {
      try {
        await photos.prune(await db.liveMedicinePhotos());
      } catch (e) {
        Log.error('Unused medicine photos not cleared', e);
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
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final m = medicine.value;
    final from = m == null
        ? null
        : people.where((p) => p.id == m.profileId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l.medicineMoveTitle)),
      body: m == null || from == null
          ? Center(
              child: medicine.isLoading
                  ? const CircularProgressIndicator()
                  : Text(l.medicineNotFound),
            )
          : _body(context, l, text, m, from, people),
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
    final given = ref.watch(_givenCountProvider(m.id)).value ?? 0;
    final stays = [
      if (m.prescriptionId != null) l.medicineMoveStaysPrescription,
      if (given > 0) l.medicineMoveStaysSickDays,
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
          Container(
            key: const ValueKey('move-warning'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Severity.headsUp.backgroundOf(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l.medicineMoveReminder(picked.displayName, from.displayName),
              style: text.bodyMedium?.copyWith(
                color: Severity.headsUp.foregroundOf(context),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('move-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: picked == null || _moving ? null : () => _move(m, picked),
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
final _givenCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, medicineId) =>
      ref.watch(databaseProvider).watchGivenCountOf(medicineId),
);
