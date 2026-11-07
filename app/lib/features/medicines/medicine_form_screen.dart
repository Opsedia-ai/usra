import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/buttons.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/files/photo_store.dart';
import '../../core/ocr/medicine_name_extractor.dart';
import '../../core/providers.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../doctors/doctors_providers.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/person_status.dart';
import '../scan/scan_medicine_screen.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'min_hours.dart';
import 'medicines_providers.dart';
import 'prescription_form_screen.dart' show EveryHoursDialog, presetTimes;

/// A photo in the form: already saved ([picked] false), or just picked and
/// only copied into the app when the medicine is saved.
class _Photo {
  const _Photo(this.path, {required this.picked});

  final String path;
  final bool picked;
}

enum _Repeat { daily, weekdays, everyN }

enum _Frequency { once, twice, thrice, everyHours, asNeeded }

/// Adds a medicine for [profileId], or edits [medicineId] when given. A new
/// medicine can be switched to someone else in the family before it's saved.
/// One already saved can't: it may belong to that person's prescription and
/// dose history, so it stays with them.
///
/// Everything is written as the doctor prescribed it; the app never
/// suggests a dose. A scan only fills in the name and strength, and nothing
/// is saved, and no reminder set, until the person says they've checked them
/// against the box.
class MedicineFormScreen extends ConsumerStatefulWidget {
  const MedicineFormScreen({
    super.key,
    required this.profileId,
    this.medicineId,
    this.startWithScan = false,
  });

  final String profileId;
  final String? medicineId;

  /// Opens the camera first, from "photograph a box" on the Add sheet. What it
  /// reads still only counts once the person has checked it.
  final bool startWithScan;

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _instructions = TextEditingController();

  /// Typed from the label or the doctor; the app only ever suggests a
  /// figure read from the instructions for the family to accept.
  final _minHours = TextEditingController();
  final _amount = TextEditingController();
  final _everyN = TextEditingController(text: '2');

  final _nameKey = GlobalKey();
  final _scanKey = GlobalKey();
  final _endKey = GlobalKey();
  final _detailsKey = GlobalKey();

  late String _personId = widget.profileId;
  String? _form;
  String? _doctorId;
  late DateTime _startOn = ref.read(clockProvider)();
  DateTime? _endOn;
  bool _active = true;
  final _times = <DoseTime>[];
  _Frequency? _frequency;
  _Repeat _repeat = _Repeat.daily;
  int _weekdays = 0;
  final _photos = <_Photo>[];
  bool _loaded = false;
  bool _saving = false;
  bool _showErrors = false;
  bool _showDetails = false;

  /// What a scan read off the box, and whether the person has checked it.
  MedicineSuggestion? _reading;
  bool _readingChecked = false;

  @override
  void initState() {
    super.initState();
    // The suggestion follows the instructions as they're typed, and a scan's
    // highlight goes away once the value is corrected.
    for (final c in [_name, _strength, _instructions, _minHours]) {
      c.addListener(_rebuild);
    }
    if (widget.medicineId == null) {
      _loaded = true;
      if (widget.startWithScan) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scan();
        });
      }
    } else {
      // Nothing is tucked away when changing what's already there.
      _showDetails = true;
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
        if (m.minHoursBetweenDoses case final h?) {
          _minHours.text = formatHours(h, 'en');
        }
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
      _frequency = _frequencyOfTimes();
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _strength,
      _instructions,
      _minHours,
      _amount,
      _everyN,
    ]) {
      c.dispose();
    }
    // Picked but never saved: don't leave copies in the cache.
    for (final p in _photos) {
      if (p.picked) discardPicked(p.path);
    }
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool get _minHoursInvalid =>
      _minHours.text.trim().isNotEmpty && parseMinHours(_minHours.text) == null;

  int? get _everyNValue {
    final n = parseLocalizedNumber(_everyN.text);
    return n is int && n >= 2 && n <= 60 ? n : null;
  }

  bool get _endBeforeStart =>
      _endOn != null &&
      DateUtils.dateOnly(_endOn!).isBefore(DateUtils.dateOnly(_startOn));

  bool get _nameUnsure =>
      _reading != null &&
      !_reading!.nameSure &&
      _name.text.trim() == _reading!.name;

  bool get _strengthUnsure =>
      _reading != null &&
      !_reading!.strengthSure &&
      _strength.text.trim() == (_reading!.strength ?? '');

  bool get _scanUnchecked => _reading != null && !_readingChecked;

  bool get _detailsInvalid =>
      _minHoursInvalid ||
      (_times.isNotEmpty && _repeat == _Repeat.weekdays && _weekdays == 0) ||
      (_times.isNotEmpty && _repeat == _Repeat.everyN && _everyNValue == null);

  /// Which chip the times match, if any.
  _Frequency? _frequencyOfTimes() => switch (_times.length) {
    0 => _Frequency.asNeeded,
    1 => _Frequency.once,
    2 => _Frequency.twice,
    3 => _Frequency.thrice,
    _ => null,
  };

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

  /// Reads the name and strength off the box (on the phone). They only count
  /// once the person ticks that they've checked them: see [_scanUnchecked].
  Future<void> _scan() async {
    final found = await context.push<MedicineSuggestion>(
      ScanMedicineScreen.path,
    );
    if (found == null || !mounted) return;
    setState(() {
      _reading = found;
      _readingChecked = false;
      _name.text = found.name;
      // Both come from this box: never leave an old strength beside a new name.
      _strength.text = found.strength ?? '';
    });
  }

  Future<DateTime?> _pickDate(DateTime? current, {DateTime? first}) {
    final now = ref.read(clockProvider)();
    final earliest = first ?? DateTime(now.year - 30);
    var initial = current ?? now;
    if (initial.isBefore(earliest)) initial = earliest;
    final last = DateTime(now.year + 10, 12, 31);
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: initial.isAfter(last) ? initial : last,
    );
  }

  Future<void> _setStart() async {
    final picked = await _pickDate(_startOn);
    if (picked != null && mounted) setState(() => _startOn = picked);
  }

  /// The picker doesn't offer days before the first day, so the only way to
  /// [_endBeforeStart] is moving the first day later afterwards.
  Future<void> _setEnd() async {
    final picked = await _pickDate(_endOn ?? _startOn, first: _startOn);
    if (picked != null && mounted) setState(() => _endOn = picked);
  }

  Future<DoseTime?> _askTime(DoseTime initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    return picked == null ? null : DoseTime(picked.hour, picked.minute);
  }

  Future<void> _addTime() async {
    final t = await _askTime(const DoseTime(8, 0));
    if (t == null || _times.contains(t) || !mounted) return;
    setState(() {
      _times
        ..add(t)
        ..sort();
      _frequency = _frequencyOfTimes();
    });
  }

  Future<void> _changeTime(DoseTime old) async {
    final t = await _askTime(old);
    if (t == null || _times.contains(t) || !mounted) return;
    setState(() {
      _times
        ..remove(old)
        ..add(t)
        ..sort();
      _frequency = _frequencyOfTimes();
    });
  }

  void _removeTime(DoseTime t) => setState(() {
    _times.remove(t);
    _frequency = _frequencyOfTimes();
  });

  /// Lays the times out on the clock; every one can be changed afterwards.
  /// Picking the count it already has keeps the times the family set.
  void _setCount(_Frequency frequency, int count) => setState(() {
    _frequency = frequency;
    if (_times.length == count) return;
    _times
      ..clear()
      ..addAll(presetTimes[count]!);
  });

  Future<void> _setEveryHours() async {
    final picked = await showDialog<List<DoseTime>>(
      context: context,
      builder: (_) => const EveryHoursDialog(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _times
        ..clear()
        ..addAll(picked);
      _frequency = _Frequency.everyHours;
    });
  }

  void _setAsNeeded() => setState(() {
    _times.clear();
    _frequency = _Frequency.asNeeded;
  });

  Future<void> _changePerson(List<Profile> people) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PersonSheet(people: people, selected: _personId),
    );
    if (picked != null && mounted) setState(() => _personId = picked);
  }

  /// Shows the first thing that stops the save: it can be off screen, far
  /// from the Save button.
  void _showFirstError() {
    final GlobalKey? key = _name.text.trim().isEmpty
        ? _nameKey
        : _scanUnchecked
        ? _scanKey
        : _endBeforeStart
        ? _endKey
        : _detailsInvalid
        ? _detailsKey
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.1);
      }
    });
  }

  Future<void> _save(Profile? person) async {
    final invalid =
        _name.text.trim().isEmpty ||
        _scanUnchecked ||
        _endBeforeStart ||
        _detailsInvalid;
    setState(() {
      _showErrors = invalid;
      if (_detailsInvalid) _showDetails = true;
    });
    if (invalid) {
      _showFirstError();
      return;
    }

    setState(() => _saving = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    final store = ref.read(medicinePhotoStoreProvider);
    if (widget.medicineId == null &&
        !await ref.read(saveGateProvider).allow()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
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
        profileId: _personId,
        name: _name.text,
        strength: _strength.text,
        form: _form,
        instructions: _instructions.text,
        minHoursBetweenDoses: Value(parseMinHours(_minHours.text)),
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
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    // Replaced or removed photos are no longer needed.
    try {
      await store.prune(await db.liveMedicinePhotos());
    } catch (_) {
      // Left for the next save or delete to clean up.
    }
    if (_times.isNotEmpty) await _askForNotifications();
    if (person != null) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          content: Text(
            l.medicineSavedFor(
              [
                _name.text.trim(),
                _strength.text.trim(),
              ].where((part) => part.isNotEmpty).join(' '),
              person.displayName,
            ),
          ),
        ),
      );
    }
    if (mounted) context.go('/family/$_personId/medicines/$id');
  }

  /// The first time a medicine has times, ask to show notifications. The
  /// exact-alarm screen is left to the Medicines tab's banner.
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

  void _close() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/family/${widget.profileId}/medicines');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final doctors = ref.watch(doctorsProvider).value ?? const <Doctor>[];
    final store = ref.watch(medicinePhotoStoreProvider);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final person = people.where((p) => p.id == _personId).firstOrNull;
    final labelStyle = text.titleSmall;
    final inputStyle = UsraType.body.copyWith(
      color: c.ink,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    );
    final unsureColor = Severity.headsUp.foregroundOf(context);
    final unsureBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(UsraRadius.md),
      borderSide: BorderSide(color: unsureColor, width: 2),
    );

    /// A field with its label above it, as one thing to a screen reader.
    Widget field(
      String key,
      TextEditingController controller,
      String label, {
      String? hint,
      String? error,
      int maxLines = 1,
      TextInputType? keyboard,
      bool unsure = false,
      Key? scrollKey,
    }) => Padding(
      key: scrollKey,
      padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: UsraSpacing.s1),
            TextField(
              key: ValueKey('medicine-$key'),
              controller: controller,
              maxLines: maxLines,
              minLines: 1,
              keyboardType: keyboard,
              style: inputStyle,
              decoration: InputDecoration(
                hintText: hint,
                hintMaxLines: 2,
                errorText: error,
                errorMaxLines: 3,
                enabledBorder: unsure ? unsureBorder : null,
                focusedBorder: unsure ? unsureBorder : null,
              ),
            ),
            if (unsure)
              Padding(
                padding: const EdgeInsets.only(top: UsraSpacing.s1),
                child: Row(
                  key: ValueKey('medicine-$key-unsure'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: unsureColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: UsraSpacing.s1),
                    Expanded(
                      child: Text(
                        l.medicineUnsureValue,
                        style: UsraType.body.copyWith(
                          color: unsureColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    Widget dateField(
      String key,
      String label,
      DateTime value,
      VoidCallback onTap, {
      String? error,
      Key? scrollKey,
    }) => Padding(
      key: scrollKey,
      padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: UsraSpacing.s1),
            InkWell(
              key: ValueKey('medicine-$key'),
              borderRadius: BorderRadius.circular(UsraRadius.md),
              onTap: onTap,
              child: InputDecorator(
                decoration: InputDecoration(
                  errorText: error,
                  errorMaxLines: 3,
                  suffixIcon: const Icon(Icons.event_outlined),
                ),
                child: Text(
                  DateFormat.yMMMd(locale).format(value),
                  style: inputStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final hasTimes = _times.isNotEmpty;
    // Only promise a reminder that will ring.
    final now = ref.watch(clockProvider)();
    final remind =
        hasTimes &&
        _active &&
        (_endOn == null ||
            !DateUtils.dateOnly(_endOn!).isBefore(DateUtils.dateOnly(now)));
    final save = UsraPillButton(
      key: const ValueKey('medicine-save'),
      label: person == null
          ? l.familySave
          : remind
          ? l.medicineSaveForRemind(person.displayName)
          : l.medicineSaveFor(person.displayName),
      onPressed: _saving ? null : () => _save(person),
    );
    // At very large text the pinned button would take up too much of a small
    // screen, more so with the keyboard open, so it scrolls with the form.
    final pinSave =
        MediaQuery.textScalerOf(context).scale(16) <= 24 &&
        MediaQuery.sizeOf(context).height >= 560;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.medicineId == null ? l.medicineNew : l.medicineEdit),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: UsraSpacing.s4),
            child: UsraRoundIconButton(
              key: const ValueKey('medicine-close'),
              icon: Icons.close,
              semanticLabel: l.medicineClose,
              onPressed: _close,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _loaded && pinSave
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: save,
              ),
            )
          : null,
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          // Not lazy: Save can scroll back to an error anywhere in the form.
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (person != null) ...[
                    _PersonBanner(
                      person: person,
                      // Only a new medicine moves: see [MedicineFormScreen].
                      onChange: widget.medicineId == null && people.length > 1
                          ? () => _changePerson(people)
                          : null,
                    ),
                    const SizedBox(height: UsraSpacing.s3),
                  ],
                  _ScanCard(
                    key: _scanKey,
                    read: _reading != null,
                    checked: _readingChecked,
                    showError: _showErrors && _scanUnchecked,
                    onScan: _scan,
                    onChecked: (v) => setState(() => _readingChecked = v),
                  ),
                  const SizedBox(height: UsraSpacing.s3),
                  field(
                    'name',
                    _name,
                    '${l.medicineName} *',
                    scrollKey: _nameKey,
                    unsure: _nameUnsure,
                    error: _showErrors && _name.text.trim().isEmpty
                        ? l.fieldRequired
                        : null,
                  ),
                  field(
                    'strength',
                    _strength,
                    l.medicineStrength,
                    unsure: _strengthUnsure,
                  ),
                  field(
                    'instructions',
                    _instructions,
                    l.prescriptionDose,
                    maxLines: 4,
                  ),
                  Text(l.medicineSchedule, style: labelStyle),
                  const SizedBox(height: UsraSpacing.s1),
                  Wrap(
                    spacing: UsraSpacing.s2,
                    runSpacing: UsraSpacing.s2,
                    children: [
                      for (final (key, label, frequency, onTap) in [
                        (
                          'once',
                          l.medicineFreqOnce,
                          _Frequency.once,
                          () => _setCount(_Frequency.once, 1),
                        ),
                        (
                          'twice',
                          l.medicineFreqTwice,
                          _Frequency.twice,
                          () => _setCount(_Frequency.twice, 2),
                        ),
                        (
                          'thrice',
                          l.medicineFreqThrice,
                          _Frequency.thrice,
                          () => _setCount(_Frequency.thrice, 3),
                        ),
                        (
                          'every-hours',
                          l.prescriptionEveryHours,
                          _Frequency.everyHours,
                          _setEveryHours,
                        ),
                        (
                          'as-needed',
                          l.medicineFreqAsNeeded,
                          _Frequency.asNeeded,
                          _setAsNeeded,
                        ),
                      ])
                        UsraPill(
                          key: ValueKey('medicine-frequency-$key'),
                          label: label,
                          selected: _frequency == frequency,
                          onTap: onTap,
                        ),
                    ],
                  ),
                  const SizedBox(height: UsraSpacing.s3),
                  // Dose times, on their own row.
                  Wrap(
                    spacing: UsraSpacing.s2,
                    runSpacing: UsraSpacing.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final t in _times)
                        _TimePill(
                          key: ValueKey('medicine-time-${t.key}'),
                          time: t,
                          onChange: () => _changeTime(t),
                          onRemove: () => _removeTime(t),
                        ),
                      UsraPill(
                        key: const ValueKey('medicine-add-time'),
                        label: hasTimes
                            ? l.medicineAddAnotherTime
                            : l.medicineAddTime,
                        dashed: true,
                        icon: Icons.add,
                        onTap: _addTime,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: UsraSpacing.s2),
                    child: Text(
                      hasTimes ? l.prescriptionTimesHint : l.medicineNoTimes,
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(height: UsraSpacing.s4),
                  Text(l.prescriptionDuration, style: labelStyle),
                  const SizedBox(height: UsraSpacing.s1),
                  Wrap(
                    spacing: UsraSpacing.s2,
                    runSpacing: UsraSpacing.s2,
                    children: [
                      UsraPill(
                        key: const ValueKey('medicine-duration-ongoing'),
                        label: l.medicineOngoing,
                        selected: _endOn == null,
                        onTap: () => setState(() => _endOn = null),
                      ),
                      UsraPill(
                        key: const ValueKey('medicine-duration-until'),
                        label: l.medicineUntilDate,
                        selected: _endOn != null,
                        onTap: _setEnd,
                      ),
                    ],
                  ),
                  const SizedBox(height: UsraSpacing.s3),
                  dateField('start', l.medicineStart, _startOn, _setStart),
                  if (_endOn case final end?)
                    dateField(
                      'end',
                      l.medicineLastDay,
                      end,
                      _setEnd,
                      scrollKey: _endKey,
                      error: _endBeforeStart ? l.medicineEndBeforeStart : null,
                    ),
                  KeyedSubtree(
                    key: _detailsKey,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const ValueKey('medicine-more'),
                        onPressed: () =>
                            setState(() => _showDetails = !_showDetails),
                        icon: Icon(
                          _showDetails ? Icons.expand_less : Icons.expand_more,
                        ),
                        label: Text(
                          _showDetails
                              ? l.medicineLessDetails
                              : l.medicineMoreDetails,
                        ),
                      ),
                    ),
                  ),
                  if (_showDetails) ...[
                    const SizedBox(height: UsraSpacing.s2),
                    Text(l.medicineForm, style: labelStyle),
                    const SizedBox(height: UsraSpacing.s2),
                    Wrap(
                      spacing: UsraSpacing.s2,
                      runSpacing: UsraSpacing.s2,
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
                    const SizedBox(height: UsraSpacing.s4),
                    if (hasTimes) ...[
                      field(
                        'amount',
                        _amount,
                        l.medicineAmount,
                        hint: l.medicineAmountHint,
                      ),
                      Text(l.medicineRepeat, style: labelStyle),
                      const SizedBox(height: UsraSpacing.s2),
                      Wrap(
                        spacing: UsraSpacing.s2,
                        runSpacing: UsraSpacing.s2,
                        children: [
                          for (final (repeat, label) in [
                            (_Repeat.daily, l.repeatDaily),
                            (_Repeat.weekdays, l.repeatWeekdays),
                            (_Repeat.everyN, l.repeatEveryN),
                          ])
                            UsraPill(
                              key: ValueKey('medicine-repeat-${repeat.name}'),
                              label: label,
                              selected: _repeat == repeat,
                              onTap: () => setState(() => _repeat = repeat),
                            ),
                        ],
                      ),
                      const SizedBox(height: UsraSpacing.s3),
                      if (_repeat == _Repeat.weekdays) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final (i, name) in weekdayNames(
                              context,
                            ).indexed)
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
                              style: UsraType.body.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: UsraSpacing.s3),
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
                    _MinHoursField(
                      controller: _minHours,
                      instructions: _instructions.text,
                      error: _showErrors && _minHoursInvalid
                          ? l.medicineMinHoursInvalid
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('medicine-doctor'),
                        isExpanded: true,
                        initialValue: doctors.any((d) => d.id == _doctorId)
                            ? _doctorId
                            : null,
                        decoration: InputDecoration(
                          labelText: l.medicineDoctor,
                        ),
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
                    Text(l.medicinePhotos, style: labelStyle),
                    const SizedBox(height: UsraSpacing.s2),
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
                  ],
                  if (!pinSave) ...[
                    const SizedBox(height: UsraSpacing.s5),
                    save,
                  ],
                ],
              ),
            ),
    );
  }
}

/// Who the medicine is for, and a way to change it where that's possible.
class _PersonBanner extends StatelessWidget {
  const _PersonBanner({required this.person, required this.onChange});

  final Profile person;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    return Semantics(
      button: onChange != null,
      container: true,
      child: Material(
        color: c.surface,
        shape: StadiumBorder(side: BorderSide(color: c.primary, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('medicine-person'),
          onTap: onChange,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 16, 4),
            child: Row(
              children: [
                MiniPersonPebble(
                  person: person,
                  initialOnly: nameGoesBesidePebble(context, person),
                ),
                const SizedBox(width: UsraSpacing.s3),
                // Change drops below at large text rather than squeezing.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: UsraSpacing.s2,
                    children: [
                      Text(
                        l.medicineFor(person.displayName),
                        style: UsraType.body.copyWith(
                          color: c.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (onChange != null)
                        Text(
                          l.medicineForChange,
                          key: const ValueKey('medicine-person-change'),
                          style: UsraType.body.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Everyone in the family, to give the new medicine to.
class _PersonSheet extends StatelessWidget {
  const _PersonSheet({required this.people, required this.selected});

  final List<Profile> people;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.medicineForPick,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: UsraSpacing.s3),
            for (final p in people)
              Semantics(
                button: true,
                selected: p.id == selected,
                child: InkWell(
                  key: ValueKey('medicine-person-pick-${p.id}'),
                  borderRadius: BorderRadius.circular(UsraRadius.md),
                  onTap: () => Navigator.of(context).pop(p.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: UsraSpacing.s2,
                    ),
                    child: Row(
                      children: [
                        MiniPersonPebble(
                          person: p,
                          initialOnly: nameGoesBesidePebble(context, p),
                        ),
                        const SizedBox(width: UsraSpacing.s3),
                        Expanded(
                          child: Text(
                            p.displayName,
                            style: UsraType.body.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (p.id == selected)
                          ExcludeSemantics(
                            child: Icon(Icons.check, color: c.primary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The way in to scanning a box, then, once it's read, the person's check of
/// what was read, which saving waits for.
class _ScanCard extends StatelessWidget {
  const _ScanCard({
    super.key,
    required this.read,
    required this.checked,
    required this.showError,
    required this.onScan,
    required this.onChecked,
  });

  final bool read;
  final bool checked;
  final bool showError;
  final VoidCallback onScan;
  final ValueChanged<bool> onChecked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    return Material(
      color: c.infoSoft,
      borderRadius: BorderRadius.circular(UsraRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('medicine-scan'),
            onTap: onScan,
            child: Padding(
              padding: const EdgeInsets.all(UsraSpacing.s3),
              child: Row(
                children: [
                  Container(
                    width: UsraSizes.touchTarget,
                    height: UsraSizes.touchTarget,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(UsraRadius.md),
                    ),
                    child: ExcludeSemantics(
                      child: Icon(
                        read ? Icons.refresh : Icons.photo_camera_outlined,
                        color: c.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: UsraSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          read ? l.medicineScanRead : l.medicineScanOption,
                          style: UsraType.body.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          read
                              ? l.medicineScanReview
                              : l.medicineScanOptionBody,
                          style: UsraType.label.copyWith(color: c.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (read) ...[
            CheckboxListTile(
              key: const ValueKey('medicine-scan-confirm'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: UsraSpacing.s2,
              ),
              value: checked,
              onChanged: (v) => onChecked(v ?? false),
              title: Text(
                l.medicineScanConfirm,
                style: UsraType.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (showError)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  UsraSpacing.s3,
                  0,
                  UsraSpacing.s3,
                  UsraSpacing.s3,
                ),
                child: Text(
                  l.medicineScanConfirmNeeded,
                  key: const ValueKey('medicine-scan-confirm-needed'),
                  style: UsraType.body.copyWith(
                    color: Severity.actSoon.foregroundOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A dose time: tap it to change it, or remove it.
class _TimePill extends StatelessWidget {
  const _TimePill({
    super.key,
    required this.time,
    required this.onChange,
    required this.onRemove,
  });

  final DoseTime time;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final clock = formatDoseClock(context, time);
    return Material(
      color: c.surface,
      shape: StadiumBorder(side: BorderSide(color: c.lineStrong)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: l.medicineChangeTime(clock),
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('medicine-time-change-${time.key}'),
              onTap: onChange,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: UsraSizes.touchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: UsraSpacing.s4,
                    end: UsraSpacing.s1,
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      clock,
                      style: UsraType.numeral.copyWith(color: c.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('medicine-time-remove-${time.key}'),
            tooltip: l.medicineRemoveTime(clock),
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

/// "Minimum hours between doses": typed by the family. A figure read from
/// the instructions is only offered, with the words it came from, and
/// fills the field only when the family taps Use.
class _MinHoursField extends StatelessWidget {
  const _MinHoursField({
    required this.controller,
    required this.instructions,
    this.error,
  });

  final TextEditingController controller;
  final String instructions;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final suggestion = controller.text.trim().isEmpty
        ? suggestMinHours(instructions)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('medicine-min-hours'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.medicineMinHours,
              helperText: l.medicineMinHoursHint,
              helperMaxLines: 3,
              errorText: error,
            ),
          ),
          if (suggestion != null)
            Card(
              key: const ValueKey('medicine-min-hours-suggestion'),
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                title: Text(
                  l.medicineMinHoursSuggest(
                    suggestion.phrase,
                    formatHours(suggestion.hours, locale),
                  ),
                ),
                trailing: TextButton(
                  key: const ValueKey('medicine-min-hours-use'),
                  onPressed: () =>
                      controller.text = formatHours(suggestion.hours, 'en'),
                  child: Text(l.medicineMinHoursUse),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
