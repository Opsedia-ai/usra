import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'insurance_info.dart';

/// A card photo in the form: already saved ([stored]), or just picked and
/// only copied into the app when the card is saved.
class _PhotoValue {
  const _PhotoValue.stored(this.path) : picked = false;
  const _PhotoValue.picked(this.path) : picked = true;

  final String path;
  final bool picked;
}

/// Adds an insurance card for [profileId], or edits [cardId] when given.
class InsuranceFormScreen extends ConsumerStatefulWidget {
  const InsuranceFormScreen({super.key, required this.profileId, this.cardId});

  final String profileId;
  final String? cardId;

  @override
  ConsumerState<InsuranceFormScreen> createState() =>
      _InsuranceFormScreenState();
}

class _InsuranceFormScreenState extends ConsumerState<InsuranceFormScreen> {
  final _label = TextEditingController();
  final _insurer = TextEditingController();
  final _memberNumber = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _expiresOn;
  _PhotoValue? _front;
  _PhotoValue? _back;
  bool _loaded = false;
  bool _labelMissing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.cardId == null) {
      _loaded = true;
    } else {
      _load(widget.cardId!);
    }
  }

  Future<void> _load(String id) async {
    final c = await ref.read(databaseProvider).watchInsuranceCard(id).first;
    if (!mounted) return;
    setState(() {
      if (c != null) {
        _label.text = c.label;
        _insurer.text = c.insurer ?? '';
        _memberNumber.text = c.memberNumber ?? '';
        _notes.text = c.notes ?? '';
        _expiresOn = expiryDay(c.expiresOn);
        if (c.frontPhoto != null) _front = _PhotoValue.stored(c.frontPhoto!);
        if (c.backPhoto != null) _back = _PhotoValue.stored(c.backPhoto!);
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_label, _insurer, _memberNumber, _notes]) {
      c.dispose();
    }
    // Picked but never saved: don't leave copies of the card in the cache.
    _discard(_front);
    _discard(_back);
    super.dispose();
  }

  /// Deletes a picked photo's temporary file. Saved photos are left to
  /// [PhotoStore.prune], which knows whether a card still uses them.
  static void _discard(_PhotoValue? v) {
    if (v != null && v.picked) discardPicked(v.path);
  }

  /// Copies a picked photo into the app and forgets the temporary file, so
  /// retrying a failed save doesn't copy it again.
  static Future<_PhotoValue?> _keep(_PhotoValue? v, PhotoStore photos) async {
    if (v == null || !v.picked) return v;
    final stored = _PhotoValue.stored(await photos.import(v.path));
    _discard(v);
    return stored;
  }

  Future<_PhotoValue?> _pick(ImageSource source) async {
    try {
      final path = await ref.read(photoPickerProvider)(source);
      return path == null ? null : _PhotoValue.picked(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photoFailed)),
        );
      }
      return null;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _expiresOn ?? now;
    final first = DateTime(1990);
    final last = DateTime(now.year + 20, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // Widen the range so an unusual saved date still opens the picker.
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
    );
    if (picked != null) setState(() => _expiresOn = picked);
  }

  Future<void> _save() async {
    final labelMissing = _label.text.trim().isEmpty;
    setState(() => _labelMissing = labelMissing);
    if (labelMissing) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final photos = ref.read(cardPhotoStoreProvider);
    final String id;
    try {
      _front = await _keep(_front, photos);
      _back = await _keep(_back, photos);
      id = await db.saveInsuranceCard(
        id: widget.cardId,
        profileId: widget.profileId,
        label: _label.text,
        insurer: _insurer.text,
        memberNumber: _memberNumber.text,
        expiresOn: _expiresOn,
        notes: _notes.text,
        frontPhoto: _front?.path,
        backPhoto: _back?.path,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
      return;
    }
    // Replaced or removed photos are no longer needed.
    try {
      await photos.prune(await db.liveInsurancePhotos());
    } catch (_) {
      // Left for the next save or delete to clean up.
    }
    if (mounted) context.go('/family/${widget.profileId}/insurance/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    Widget field(
      String key,
      TextEditingController c,
      String label, {
      String? error,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        key: ValueKey('insurance-$key'),
        controller: c,
        decoration: InputDecoration(labelText: label, errorText: error),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId == null ? l.insuranceNew : l.insuranceEdit),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                field(
                  'label',
                  _label,
                  '${l.insuranceLabel} *',
                  error: _labelMissing ? l.fieldRequired : null,
                ),
                field('insurer', _insurer, l.insuranceInsurer),
                field('member', _memberNumber, l.insuranceMemberNumber),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    key: const ValueKey('insurance-expiry'),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.insuranceExpiry,
                        suffixIcon: _expiresOn == null
                            ? const Icon(Icons.event_outlined)
                            : IconButton(
                                tooltip: l.clearDate,
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _expiresOn = null),
                              ),
                      ),
                      child: Text(
                        _expiresOn == null
                            ? ''
                            : DateFormat.yMMMd(locale).format(_expiresOn!),
                      ),
                    ),
                  ),
                ),
                field('notes', _notes, l.insuranceNotes),
                _PhotoSlot(
                  slot: 'front',
                  label: l.insuranceFront,
                  value: _front,
                  onPick: (source) async {
                    final v = await _pick(source);
                    if (v == null || !mounted) return;
                    _discard(_front);
                    setState(() => _front = v);
                  },
                  onRemove: () {
                    _discard(_front);
                    setState(() => _front = null);
                  },
                ),
                const SizedBox(height: 16),
                _PhotoSlot(
                  slot: 'back',
                  label: l.insuranceBack,
                  value: _back,
                  onPick: (source) async {
                    final v = await _pick(source);
                    if (v == null || !mounted) return;
                    _discard(_back);
                    setState(() => _back = v);
                  },
                  onRemove: () {
                    _discard(_back);
                    setState(() => _back = null);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('insurance-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l.familySave),
                ),
              ],
            ),
    );
  }
}

/// One side of the card: a preview, and big buttons to take or pick a photo.
class _PhotoSlot extends ConsumerWidget {
  const _PhotoSlot({
    required this.slot,
    required this.label,
    required this.value,
    required this.onPick,
    required this.onRemove,
  });

  final String slot;
  final String label;
  final _PhotoValue? value;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final v = value;
    final ImageProvider? image = v == null
        ? null
        : v.picked
        ? FileImage(File(v.path))
        : ref.watch(cardPhotoStoreProvider).image(v.path);
    const tall = Size(0, 56);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PhotoImage(
              key: ValueKey('insurance-$slot-preview'),
              image: image,
              height: 180,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: ValueKey('insurance-$slot-camera'),
                style: OutlinedButton.styleFrom(minimumSize: tall),
                onPressed: () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l.photoCamera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: ValueKey('insurance-$slot-gallery'),
                style: OutlinedButton.styleFrom(minimumSize: tall),
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l.photoGallery),
              ),
            ),
            if (image != null) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                key: ValueKey('insurance-$slot-remove'),
                tooltip: l.photoRemove,
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
