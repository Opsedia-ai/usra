import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctors_providers.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'medicines_providers.dart';

/// A photo in the form: already saved ([picked] false), or just picked and
/// only copied into the app when the medicine is saved.
class _Photo {
  const _Photo(this.path, {required this.picked});

  final String path;
  final bool picked;
}

enum _Repeat { daily, weekdays, everyN }

/// Adds a medicine for [profileId], or edits [medicineId] when given.
///
/// Everything is written as the doctor prescribed it; the app never
/// suggests a dose.
class MedicineFormScreen extends ConsumerStatefulWidget {
  const MedicineFormScreen({
    super.key,
    required this.profileId,
    this.medicineId,
  });

  final String profileId;
  final String? medicineId;

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _instructions = TextEditingController();
  final _amount = TextEditingController();
  final _everyN = TextEditingController(text: '2');
  String? _form;
  String? _doctorId;
  DateTime _startOn = DateTime.now();
  DateTime? _endOn;
  bool _active = true;
  final _times = <DoseTime>[];
  _Repeat _repeat = _Repeat.daily;
  int _weekdays = 0;
  final _photos = <_Photo>[];
  bool _loaded = false;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    if (widget.medicineId == null) {
      _loaded = true;
    } else {
      _load(widget.medicineId!);
    }
  }

  Future<void> _load(String id) async {
    final db = ref.read(databaseProvider);
    final m = await db.watchMedicine(id).first;
    final s = await db.watchDoseSchedule(id).first;
    if (!mounted) return;
    setState(() {
      if (m != null) {
        _name.text = m.name;
        _strength.text = m.strength ?? '';
        _instructions.text = m.instructions ?? '';
        _form = m.form;
        _doctorId = m.doctorId;
        _startOn = storedDay(m.startOn);
        _endOn = m.endOn == null ? null : storedDay(m.endOn!);
        _active = m.active;
        _photos.addAll([
          for (final p in decodeMedicinePhotos(m.photosJson))
            _Photo(p, picked: false),
        ]);
      }
      if (s != null) {
        _times.addAll(DoseTime.parseList(s.times));
        _amount.text = s.amount ?? '';
        if (s.everyNDays != null) {
          _repeat = _Repeat.everyN;
          _everyN.text = '${s.everyNDays}';
        } else if (s.weekdays != null) {
          _repeat = _Repeat.weekdays;
          _weekdays = s.weekdays!;
        }
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _strength, _instructions, _amount, _everyN]) {
      c.dispose();
    }
    // Picked but never saved: don't leave copies in the cache.
    for (final p in _photos) {
      if (p.picked) discardPicked(p.path);
    }
    super.dispose();
  }

  int? get _everyNValue {
    final n = parseLocalizedNumber(_everyN.text);
    return n is int && n >= 2 && n <= 60 ? n : null;
  }

  bool get _endBeforeStart =>
      _endOn != null &&
      DateUtils.dateOnly(_endOn!).isBefore(DateUtils.dateOnly(_startOn));

  Future<void> _pickPhotos(ImageSource source) async {
    try {
      final paths = source == ImageSource.camera
          ? [?await ref.read(photoPickerProvider)(source)]
          : await ref.read(multiPhotoPickerProvider)();
      if (!mounted) {
        paths.forEach(discardPicked);
        return;
      }
      setState(
        () => _photos.addAll([for (final p in paths) _Photo(p, picked: true)]),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photoFailed)),
        );
      }
    }
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    final now = DateTime.now();
    final initial = current ?? now;
    final first = DateTime(now.year - 30);
    final last = DateTime(now.year + 10, 12, 31);
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
    );
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final t = DoseTime(picked.hour, picked.minute);
    if (_times.contains(t)) return;
    setState(
      () => _times
        ..add(t)
        ..sort(),
    );
  }

  Future<void> _save() async {
    final invalid =
        _name.text.trim().isEmpty ||
        _endBeforeStart ||
        (_times.isNotEmpty && _repeat == _Repeat.weekdays && _weekdays == 0) ||
        (_times.isNotEmpty &&
            _repeat == _Repeat.everyN &&
            _everyNValue == null);
    setState(() => _showErrors = invalid);
    if (invalid) return;

    setState(() => _saving = true);
    final l = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    final store = ref.read(medicinePhotoStoreProvider);
    final String id;
    try {
      // Copy picked photos in, one at a time, so a retry after a failure
      // doesn't copy the same one twice.
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (!p.picked) continue;
        _photos[i] = _Photo(await store.import(p.path), picked: false);
        discardPicked(p.path);
      }
      id = await db.saveMedicine(
        id: widget.medicineId,
        profileId: widget.profileId,
        name: _name.text,
        strength: _strength.text,
        form: _form,
        instructions: _instructions.text,
        doctorId: _doctorId,
        startOn: _startOn,
        endOn: _endOn,
        photos: [for (final p in _photos) p.path],
        active: _active,
        schedule: _times.isEmpty
            ? null
            : DoseScheduleInput(
                times: [for (final t in _times) t.key],
                weekdays: _repeat == _Repeat.weekdays ? _weekdays : null,
                everyNDays: _repeat == _Repeat.everyN ? _everyNValue : null,
                amount: _amount.text,
              ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    // Replaced or removed photos are no longer needed.
    try {
      await store.prune(await db.liveMedicinePhotos());
    } catch (_) {
      // Left for the next save or delete to clean up.
    }
    if (_times.isNotEmpty) await _askForNotifications();
    if (mounted) context.go('/family/${widget.profileId}/medicines/$id');
  }

  /// The first time a medicine has times, ask to show notifications. The
  /// exact-alarm screen is left to the Medicines tab's banner.
  Future<void> _askForNotifications() async {
    try {
      final scheduler = ref.read(reminderSchedulerProvider);
      if (!(await scheduler.access()).notifications) {
        await scheduler.requestAccess();
      }
      ref.invalidate(reminderAccessProvider);
    } catch (_) {
      // The banner on the Medicines tab asks again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final doctors = ref.watch(doctorsProvider).value ?? const <Doctor>[];
    final store = ref.watch(medicinePhotoStoreProvider);

    Widget field(
      String key,
      TextEditingController c,
      String label, {
      String? hint,
      String? error,
      int maxLines = 1,
      TextInputType? keyboard,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        key: ValueKey('medicine-$key'),
        controller: c,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
        ),
      ),
    );

    Widget dateField(
      String key,
      String label,
      DateTime? value,
      ValueChanged<DateTime?> onChanged, {
      bool clearable = false,
      String? error,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        key: ValueKey('medicine-$key'),
        onTap: () async {
          final picked = await _pickDate(value);
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            suffixIcon: clearable && value != null
                ? IconButton(
                    tooltip: l.clearDate,
                    icon: const Icon(Icons.close),
                    onPressed: () => onChanged(null),
                  )
                : const Icon(Icons.event_outlined),
          ),
          child: Text(
            value == null ? '' : DateFormat.yMMMd(locale).format(value),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicineId == null ? l.medicineNew : l.medicineEdit),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                field(
                  'name',
                  _name,
                  '${l.medicineName} *',
                  error: _showErrors && _name.text.trim().isEmpty
                      ? l.fieldRequired
                      : null,
                ),
                field('strength', _strength, l.medicineStrength),
                Text(l.medicineForm, style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in medicineForms)
                      ChoiceChip(
                        key: ValueKey('medicine-form-$f'),
                        label: Text(medicineFormLabel(l, f)),
                        avatar: Icon(medicineFormIcon(f), size: 18),
                        selected: _form == f,
                        onSelected: (on) =>
                            setState(() => _form = on ? f : null),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                field(
                  'instructions',
                  _instructions,
                  l.medicineInstructions,
                  hint: l.medicineInstructionsHint,
                  maxLines: 4,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey('medicine-doctor'),
                    initialValue: doctors.any((d) => d.id == _doctorId)
                        ? _doctorId
                        : null,
                    decoration: InputDecoration(labelText: l.medicineDoctor),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l.medicineNoDoctor),
                      ),
                      for (final d in doctors)
                        DropdownMenuItem(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() => _doctorId = v),
                  ),
                ),
                dateField(
                  'start',
                  l.medicineStart,
                  _startOn,
                  (v) => setState(() => _startOn = v ?? _startOn),
                ),
                dateField(
                  'end',
                  l.medicineEnd,
                  _endOn,
                  (v) => setState(() => _endOn = v),
                  clearable: true,
                  error: _showErrors && _endBeforeStart
                      ? l.medicineEndBeforeStart
                      : null,
                ),
                const SizedBox(height: 8),
                Text(l.medicineSchedule, style: text.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _times)
                      InputChip(
                        key: ValueKey('medicine-time-${t.key}'),
                        label: Text(
                          formatDoseClock(context, t),
                          style: text.titleMedium,
                        ),
                        deleteButtonTooltipMessage: l.medicineRemoveTime(
                          formatDoseClock(context, t),
                        ),
                        onDeleted: () => setState(() => _times.remove(t)),
                      ),
                    ActionChip(
                      key: const ValueKey('medicine-add-time'),
                      avatar: const Icon(Icons.alarm_add_outlined),
                      label: Text(l.medicineAddTime),
                      onPressed: _addTime,
                    ),
                  ],
                ),
                if (_times.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.medicineNoTimes, style: text.bodyMedium),
                  )
                else ...[
                  const SizedBox(height: 16),
                  field(
                    'amount',
                    _amount,
                    l.medicineAmount,
                    hint: l.medicineAmountHint,
                  ),
                  Text(l.medicineRepeat, style: text.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<_Repeat>(
                    key: const ValueKey('medicine-repeat'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: _Repeat.daily,
                        label: Text(l.repeatDaily),
                      ),
                      ButtonSegment(
                        value: _Repeat.weekdays,
                        label: Text(l.repeatWeekdays),
                      ),
                      ButtonSegment(
                        value: _Repeat.everyN,
                        label: Text(l.repeatEveryN),
                      ),
                    ],
                    selected: {_repeat},
                    onSelectionChanged: (s) =>
                        setState(() => _repeat = s.single),
                  ),
                  const SizedBox(height: 12),
                  if (_repeat == _Repeat.weekdays) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (i, name) in weekdayNames(context).indexed)
                          FilterChip(
                            key: ValueKey('medicine-weekday-$i'),
                            label: Text(name),
                            selected: _weekdays & (1 << i) != 0,
                            onSelected: (_) =>
                                setState(() => _weekdays ^= 1 << i),
                          ),
                      ],
                    ),
                    if (_showErrors && _weekdays == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l.medicineWeekdaysEmpty,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                  if (_repeat == _Repeat.everyN)
                    field(
                      'every-n',
                      _everyN,
                      l.medicineEveryN,
                      keyboard: TextInputType.number,
                      error: _showErrors && _everyNValue == null
                          ? l.medicineEveryNInvalid
                          : null,
                    ),
                ],
                const SizedBox(height: 16),
                Text(l.medicinePhotos, style: text.titleSmall),
                const SizedBox(height: 8),
                if (_photos.isNotEmpty)
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final p = _photos[i];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: PhotoImage(
                                key: ValueKey('medicine-photo-preview-$i'),
                                file: p.picked
                                    ? File(p.path)
                                    : store.fileOf(p.path),
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                cacheWidth: 330,
                              ),
                            ),
                            PositionedDirectional(
                              top: 0,
                              end: 0,
                              child: IconButton.filledTonal(
                                key: ValueKey('medicine-photo-remove-$i'),
                                tooltip: l.photoRemove,
                                onPressed: () => setState(() {
                                  final removed = _photos.removeAt(i);
                                  if (removed.picked) {
                                    discardPicked(removed.path);
                                  }
                                }),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('medicine-photo-camera'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                        ),
                        onPressed: () => _pickPhotos(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l.photoCamera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('medicine-photo-gallery'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                        ),
                        onPressed: () => _pickPhotos(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l.photoGallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('medicine-save'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed: _saving ? null : _save,
                  child: Text(l.familySave),
                ),
              ],
            ),
    );
  }
}
