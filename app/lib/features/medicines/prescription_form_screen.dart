import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctors_providers.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'medicines_providers.dart';

/// Times filled in by the "times a day" shortcut; the person can change
/// them. Spread over waking hours; this is about reminders, not doses. For
/// "every 8 hours" and the like there's [everyHours].
const presetTimes = <int, List<DoseTime>>{
  1: [DoseTime(8, 0)],
  2: [DoseTime(8, 0), DoseTime(20, 0)],
  3: [DoseTime(8, 0), DoseTime(14, 0), DoseTime(20, 0)],
  4: [DoseTime(8, 0), DoseTime(12, 0), DoseTime(16, 0), DoseTime(20, 0)],
};

/// Intervals offered for "every N hours".
const everyHoursChoices = [4, 6, 8, 12];

/// Reminder times for "every [hours] hours" starting at [first], within one
/// day: 08:00 every 8 hours is 08:00, 16:00 and 00:00. The interval is the
/// doctor's; this only lays it out on the clock.
List<DoseTime> everyHours(DoseTime first, int hours) {
  if (hours < 1 || hours > 24) throw ArgumentError.value(hours, 'hours');
  return [
    for (var m = 0; m < 24 * 60; m += hours * 60)
      DoseTime(
        (first.minutesOfDay + m) ~/ 60 % 24,
        (first.minutesOfDay + m) % 60,
      ),
  ]..sort();
}

/// A photo in the form: already saved, or just picked and only copied into
/// the app when the prescription is saved.
class _Photo {
  const _Photo(this.path, {required this.picked});

  final String path;
  final bool picked;
}

/// One medicine on the prescription, as typed.
class _Item {
  _Item({
    this.medicineId,
    String name = '',
    String strength = '',
    String dose = '',
    List<DoseTime> times = const [],
    this.startOn,
    this.ended = false,
    int? days,
  }) : name = TextEditingController(text: name),
       strength = TextEditingController(text: strength),
       dose = TextEditingController(text: dose),
       days = TextEditingController(text: days == null ? '' : '$days'),
       ongoing = days == null && medicineId != null,
       times = [...times];

  final String? medicineId;
  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController dose;
  final TextEditingController days;
  final List<DoseTime> times;

  /// Kept from the saved medicine; follows the prescription's date when
  /// that changes.
  DateTime? startOn;
  bool ongoing;

  /// Its course was already over when the form opened; moving the
  /// prescription's date never brings it back.
  final bool ended;

  /// A unique key for this row's widgets.
  final Key key = UniqueKey();

  int? get daysValue {
    final n = parseLocalizedNumber(days.text);
    return n is int && n >= 1 && n <= maxCourseDays ? n : null;
  }

  bool get valid =>
      name.text.trim().isNotEmpty && (ongoing || daysValue != null);

  void dispose() {
    for (final c in [name, strength, dose, days]) {
      c.dispose();
    }
  }
}

/// Adds a prescription for [profileId] with several medicines, or edits
/// [prescriptionId] when given. Saving creates or updates every medicine,
/// its reminder times and its course length at once.
///
/// Doses are typed exactly as the doctor wrote them; the app never
/// suggests or calculates one.
class PrescriptionFormScreen extends ConsumerStatefulWidget {
  const PrescriptionFormScreen({
    super.key,
    required this.profileId,
    this.prescriptionId,
  });

  final String profileId;
  final String? prescriptionId;

  @override
  ConsumerState<PrescriptionFormScreen> createState() =>
      _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState
    extends ConsumerState<PrescriptionFormScreen> {
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _date = DateUtils.dateOnly(ref.read(clockProvider)());
  String? _doctorId;
  final _items = <_Item>[];
  final _photos = <_Photo>[];
  bool _loaded = false;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    if (widget.prescriptionId == null) {
      _items.add(_Item());
      _loaded = true;
    } else {
      _load(widget.prescriptionId!);
    }
  }

  Future<void> _load(String id) async {
    final db = ref.read(databaseProvider);
    final p = await db.watchPrescription(id).first;
    final medicines = await db.watchPrescriptionMedicines(id).first;
    final schedules = [
      for (final m in medicines) await db.watchDoseSchedule(m.id).first,
    ];
    if (!mounted) return;
    setState(() {
      if (p != null) {
        _date = storedDay(p.prescribedOn);
        _doctorId = p.doctorId;
        _diagnosis.text = p.diagnosis ?? '';
        _notes.text = p.notes ?? '';
        _photos.addAll([
          for (final path in decodeMedicinePhotos(p.photosJson))
            _Photo(path, picked: false),
        ]);
      }
      for (final (i, m) in medicines.indexed) {
        final start = storedDay(m.startOn);
        _items.add(
          _Item(
            medicineId: m.id,
            name: m.name,
            strength: m.strength ?? '',
            dose: m.instructions ?? '',
            times: schedules[i] == null
                ? const []
                : DoseTime.parseList(schedules[i]!.times),
            startOn: start,
            ended: medicineEnded(m, ref.read(clockProvider)()),
            days: courseDays(m),
          ),
        );
      }
      if (_items.isEmpty) _items.add(_Item());
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _notes.dispose();
    for (final item in _items) {
      item.dispose();
    }
    for (final p in _photos) {
      if (p.picked) discardPicked(p.path);
    }
    super.dispose();
  }

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 30);
    final last = DateTime(now.year + 10, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(first) ? _date : first,
      lastDate: _date.isAfter(last) ? _date : last,
    );
    if (picked == null || picked == _date || !mounted) return;
    // Courses already saved and not over yet can move with the date; the
    // person decides. Ended ones keep their dates, so no reminders return.
    final movable = [
      for (final item in _items)
        if (item.startOn != null && !item.ended) item,
    ];
    var move = false;
    if (movable.isNotEmpty) {
      final l = AppLocalizations.of(context);
      final answer = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l.prescriptionMoveTitle),
          content: Text(l.prescriptionMoveBody),
          actions: [
            TextButton(
              key: const ValueKey('rx-move-keep'),
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.prescriptionMoveKeep),
            ),
            FilledButton(
              key: const ValueKey('rx-move-courses'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.prescriptionMoveYes),
            ),
          ],
        ),
      );
      if (answer == null) return;
      move = answer;
    }
    setState(() {
      _date = picked;
      if (move) {
        for (final item in movable) {
          item.startOn = null;
        }
      }
    });
  }

  /// Takes an item off the form; a saved medicine is stopped and unlinked
  /// on save, keeping its history, so ask first.
  Future<void> _remove(_Item item) async {
    if (item.medicineId != null) {
      final l = AppLocalizations.of(context);
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(
            l.prescriptionRemoveConfirm(
              item.name.text.trim().isEmpty ? '' : item.name.text.trim(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.familyCancel),
            ),
            FilledButton(
              key: const ValueKey('rx-remove-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.prescriptionRemoveMedicine),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      _items.remove(item);
      item.dispose();
    });
  }

  Future<void> _everyHours(_Item item) async {
    final picked = await showDialog<List<DoseTime>>(
      context: context,
      builder: (_) => const _EveryHoursDialog(),
    );
    if (picked == null || !mounted) return;
    setState(
      () => item.times
        ..clear()
        ..addAll(picked),
    );
  }

  Future<void> _addTime(_Item item) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    final t = DoseTime(picked.hour, picked.minute);
    if (item.times.contains(t)) return;
    setState(
      () => item.times
        ..add(t)
        ..sort(),
    );
  }

  Future<void> _save() async {
    final invalid = _items.isEmpty || _items.any((i) => !i.valid);
    setState(() => _showErrors = invalid);
    if (invalid) return;

    setState(() => _saving = true);
    final l = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    final store = ref.read(medicinePhotoStoreProvider);
    final String id;
    try {
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (!p.picked) continue;
        _photos[i] = _Photo(await store.import(p.path), picked: false);
        discardPicked(p.path);
      }
      id = await db.savePrescription(
        id: widget.prescriptionId,
        profileId: widget.profileId,
        doctorId: _doctorId,
        prescribedOn: _date,
        diagnosis: _diagnosis.text,
        notes: _notes.text,
        photos: [for (final p in _photos) p.path],
        items: [
          for (final item in _items)
            PrescriptionItemInput(
              medicineId: item.medicineId,
              name: item.name.text,
              strength: item.strength.text,
              dose: item.dose.text,
              times: [for (final t in item.times) t.key],
              startOn: item.startOn,
              days: item.ongoing ? null : item.daysValue,
            ),
        ],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    try {
      await store.prune(await db.liveMedicinePhotos());
    } catch (_) {
      // Left for the next save or delete to clean up.
    }
    if (_items.any((i) => i.times.isNotEmpty)) await _askForNotifications();
    if (mounted) context.go('/family/${widget.profileId}/prescriptions/$id');
  }

  /// Asks to show notifications the first time; the Medicines tab's banner
  /// handles exact alarms.
  Future<void> _askForNotifications() async {
    try {
      final scheduler = ref.read(reminderSchedulerProvider);
      if (!(await scheduler.access()).notifications) {
        await scheduler.requestAccess(exactAlarms: false);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.prescriptionId == null
              ? l.prescriptionNew
              : l.prescriptionEdit,
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: UsraColors.primaryTint,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l.prescriptionNoDoseAdvice,
                      key: const ValueKey('rx-no-dose-advice'),
                      style: text.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    key: const ValueKey('rx-date'),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.prescriptionDate,
                        suffixIcon: const Icon(Icons.event_outlined),
                      ),
                      child: Text(DateFormat.yMMMd(locale).format(_date)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey('rx-doctor'),
                    initialValue: doctors.any((d) => d.id == _doctorId)
                        ? _doctorId
                        : null,
                    isExpanded: true,
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    key: const ValueKey('rx-diagnosis'),
                    controller: _diagnosis,
                    decoration: InputDecoration(
                      labelText: l.prescriptionDiagnosis,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.prescriptionMedicines, style: text.titleLarge),
                const SizedBox(height: 8),
                for (final (i, item) in _items.indexed)
                  _ItemCard(
                    key: item.key,
                    index: i,
                    item: item,
                    showErrors: _showErrors,
                    removable: _items.length > 1,
                    onChanged: () => setState(() {}),
                    onAddTime: () => _addTime(item),
                    onEveryHours: () => _everyHours(item),
                    onRemove: () => _remove(item),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('rx-add-medicine'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                  ),
                  onPressed: () => setState(() => _items.add(_Item())),
                  icon: const Icon(Icons.add),
                  label: Text(l.prescriptionAddMedicine),
                ),
                const SizedBox(height: 24),
                Text(l.prescriptionPhotos, style: text.titleSmall),
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
                                key: ValueKey('rx-photo-preview-$i'),
                                image: p.picked
                                    ? FileImage(File(p.path))
                                    : store.image(p.path),
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
                                key: ValueKey('rx-photo-remove-$i'),
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
                        key: const ValueKey('rx-photo-camera'),
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
                        key: const ValueKey('rx-photo-gallery'),
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
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('rx-notes'),
                  controller: _notes,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l.prescriptionNotes),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('rx-save'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed: _saving ? null : _save,
                  child: Text(l.familySave),
                ),
              ],
            ),
    );
  }
}

/// One medicine's fields: name, strength, dose as written, times and how
/// many days.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.showErrors,
    required this.removable,
    required this.onChanged,
    required this.onAddTime,
    required this.onEveryHours,
    required this.onRemove,
  });

  final int index;
  final _Item item;
  final bool showErrors;
  final bool removable;
  final VoidCallback onChanged;
  final VoidCallback onAddTime;
  final VoidCallback onEveryHours;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final k = 'rx-item-$index';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.prescriptionMedicineN(index + 1),
                    style: text.titleMedium,
                  ),
                ),
                if (removable)
                  IconButton(
                    key: ValueKey('$k-remove'),
                    tooltip: l.prescriptionRemoveMedicine,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            TextField(
              key: ValueKey('$k-name'),
              controller: item.name,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: '${l.medicineName} *',
                errorText: showErrors && item.name.text.trim().isEmpty
                    ? l.fieldRequired
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('$k-strength'),
              controller: item.strength,
              decoration: InputDecoration(labelText: l.medicineStrength),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('$k-dose'),
              controller: item.dose,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l.prescriptionDose,
                hintText: l.prescriptionDoseHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(l.prescriptionTimesPerDay, style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: n, value: times)
                    in presetTimes.entries)
                  ChoiceChip(
                    key: ValueKey('$k-per-day-$n'),
                    label: Text(l.prescriptionTimesN(n)),
                    selected: _sameTimes(item.times, times),
                    onSelected: (_) {
                      item.times
                        ..clear()
                        ..addAll(times);
                      onChanged();
                    },
                  ),
                ActionChip(
                  key: ValueKey('$k-every-hours'),
                  avatar: const Icon(Icons.schedule),
                  label: Text(l.prescriptionEveryHours),
                  onPressed: onEveryHours,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.prescriptionTimesHint, style: text.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in item.times)
                  InputChip(
                    key: ValueKey('$k-time-${t.key}'),
                    label: Text(
                      formatDoseClock(context, t),
                      style: text.titleMedium,
                    ),
                    deleteButtonTooltipMessage: l.medicineRemoveTime(
                      formatDoseClock(context, t),
                    ),
                    onDeleted: () {
                      item.times.remove(t);
                      onChanged();
                    },
                  ),
                ActionChip(
                  key: ValueKey('$k-add-time'),
                  avatar: const Icon(Icons.alarm_add_outlined),
                  label: Text(l.medicineAddTime),
                  onPressed: onAddTime,
                ),
              ],
            ),
            if (item.times.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.medicineNoTimes, style: text.bodyMedium),
              ),
            const SizedBox(height: 16),
            Text(l.prescriptionDuration, style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: ValueKey('$k-ongoing'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l.prescriptionForDays)),
                ButtonSegment(value: true, label: Text(l.prescriptionOngoing)),
              ],
              selected: {item.ongoing},
              onSelectionChanged: (s) {
                item.ongoing = s.single;
                onChanged();
              },
            ),
            if (!item.ongoing) ...[
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('$k-days'),
                controller: item.days,
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  labelText: l.prescriptionDays,
                  errorText: showErrors && item.daysValue == null
                      ? l.prescriptionDaysInvalid
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _sameTimes(List<DoseTime> a, List<DoseTime> b) =>
      a.length == b.length && a.every(b.contains);
}

/// Asks for "every N hours" and the first time; returns the times.
class _EveryHoursDialog extends StatefulWidget {
  const _EveryHoursDialog();

  @override
  State<_EveryHoursDialog> createState() => _EveryHoursDialogState();
}

class _EveryHoursDialogState extends State<_EveryHoursDialog> {
  int _hours = 8;
  DoseTime _first = const DoseTime(8, 0);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.prescriptionEveryHours),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            key: const ValueKey('rx-hours'),
            initialValue: _hours,
            decoration: InputDecoration(labelText: l.prescriptionInterval),
            items: [
              for (final h in everyHoursChoices)
                DropdownMenuItem(
                  value: h,
                  child: Text(l.prescriptionEveryNHours(h)),
                ),
            ],
            onChanged: (v) => setState(() => _hours = v ?? _hours),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('rx-first-time'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: _first.hour,
                  minute: _first.minute,
                ),
              );
              if (t != null) {
                setState(() => _first = DoseTime(t.hour, t.minute));
              }
            },
            icon: const Icon(Icons.alarm),
            label: Text(
              l.prescriptionFirstDose(formatDoseClock(context, _first)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            everyHours(
              _first,
              _hours,
            ).map((t) => formatDoseClock(context, t)).join(' · '),
            key: const ValueKey('rx-hours-preview'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.familyCancel),
        ),
        FilledButton(
          key: const ValueKey('rx-hours-ok'),
          onPressed: () => Navigator.pop(context, everyHours(_first, _hours)),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
