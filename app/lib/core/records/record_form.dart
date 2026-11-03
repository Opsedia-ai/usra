import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../files/photo_store.dart';
import '../util/localized_numbers.dart';
import 'record_type.dart';

/// Words the form needs, passed in so the core stays free of feature strings.
class RecordFormStrings {
  const RecordFormStrings({
    required this.date,
    required this.cost,
    required this.currency,
    required this.save,
    required this.required,
    required this.invalid,
    required this.pickDate,
    this.chooseDoctor = '',
    this.photos = '',
    this.photoCamera = '',
    this.photoGallery = '',
    this.photoRemove = '',
  });

  final String date;
  final String cost;
  final String currency;
  final String save;
  final String required;
  final String invalid;
  final String pickDate;

  /// Label of the "pick from your doctors" menu on types with a doctor field.
  final String chooseDoctor;

  /// The "Add photos" row, shown when the form is given a photo picker.
  final String photos;
  final String photoCamera;
  final String photoGallery;
  final String photoRemove;
}

/// A saved doctor offered in the form's doctor menu.
class DoctorChoice {
  const DoctorChoice({
    required this.id,
    required this.name,
    this.specialty,
    this.feeMinor,
  });

  final String id;
  final String name;
  final String? specialty;
  final int? feeMinor;

  // By id, so a rebuilt list still matches the picked doctor.
  @override
  bool operator ==(Object other) => other is DoctorChoice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// What the user entered, ready to store as a `MedicalEvent`.
class RecordFormResult {
  const RecordFormResult({
    required this.occurredAt,
    required this.data,
    this.costMinor,
    this.doctorId,
    this.photos = const [],
  });

  final DateTime occurredAt;
  final Map<String, Object?> data;

  /// Cost in the smallest currency unit (piasters for EGP).
  final int? costMinor;

  /// The saved doctor picked from the menu, if the name wasn't changed after.
  final String? doctorId;

  /// Temporary paths of the picked photos, in order. The caller copies them
  /// into the app; the form deletes them when it closes.
  final List<String> photos;
}

/// A form built from any [RecordTypeDefinition], so a new record type needs
/// no new screen. Dates are stored as `yyyy-MM-dd` strings.
class RecordForm extends StatefulWidget {
  const RecordForm({
    super.key,
    required this.type,
    required this.strings,
    required this.onSubmit,
    this.initialDate,
    this.doctors = const [],
    this.pickPhotos,
  });

  final RecordTypeDefinition type;
  final RecordFormStrings strings;

  /// Awaited; the Save button stays disabled until it completes.
  final Future<void> Function(RecordFormResult) onSubmit;
  final DateTime? initialDate;

  /// Saved doctors, offered when the type has a [RecordTypeDefinition.doctorField].
  final List<DoctorChoice> doctors;

  /// Returns the temporary paths of photos taken or picked (empty if
  /// cancelled). Without it the form has no photos row.
  final Future<List<String>> Function(ImageSource source)? pickPhotos;

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  static final _isoDate = DateFormat('yyyy-MM-dd');

  late DateTime _occurredAt =
      widget.initialDate ?? DateUtils.dateOnly(DateTime.now());
  final _text = <String, TextEditingController>{};
  final _values = <String, Object?>{};
  final _cost = TextEditingController();
  Set<String> _problems = {};
  bool _costInvalid = false;
  bool _submitting = false;
  DoctorChoice? _doctor;
  final _photos = <String>[];

  /// The fee text last filled in from a doctor, so switching doctors can
  /// replace it without overwriting a cost the user typed.
  String? _autoFee;

  @override
  void initState() {
    super.initState();
    for (final f in widget.type.fields) {
      if (_usesTextField(f.kind)) _text[f.key] = TextEditingController();
    }
    // Typing a different name unlinks the picked doctor.
    _doctorText?.addListener(() {
      if (_doctor != null && _doctorText!.text.trim() != _doctor!.name) {
        setState(() => _doctor = null);
      }
    });
  }

  TextEditingController? get _doctorText {
    final key = widget.type.doctorField;
    return key == null ? null : _text[key];
  }

  void _pickDoctor(DoctorChoice? d) {
    setState(() => _doctor = d);
    if (d == null) return;
    _doctorText?.text = d.name;
    final current = _cost.text.trim();
    final untouched = current.isEmpty || current == _autoFee;
    if (widget.type.hasCost && untouched) {
      _autoFee = d.feeMinor == null ? null : formatMoneyInput(d.feeMinor!);
      _cost.text = _autoFee ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    _cost.dispose();
    // Picked photos are temporary copies: never leave them in the cache.
    for (final path in _photos) {
      discardPicked(path);
    }
    super.dispose();
  }

  static bool _usesTextField(FieldKind kind) =>
      kind == FieldKind.text ||
      kind == FieldKind.number ||
      kind == FieldKind.money;

  Map<String, Object?> _collect() {
    final data = <String, Object?>{};
    for (final f in widget.type.fields) {
      switch (f.kind) {
        case FieldKind.text:
          final v = _text[f.key]!.text.trim();
          if (v.isNotEmpty) data[f.key] = v;
        case FieldKind.number || FieldKind.money:
          final raw = _text[f.key]!.text;
          if (raw.trim().isNotEmpty) {
            data[f.key] = parseLocalizedNumber(raw) ?? raw;
          }
        case FieldKind.date || FieldKind.choice || FieldKind.boolean:
          if (_values[f.key] != null) data[f.key] = _values[f.key];
      }
    }
    return data;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final data = _collect();
    final problems = widget.type.validate(data).toSet();

    int? costMinor;
    var costInvalid = false;
    if (widget.type.hasCost && _cost.text.trim().isNotEmpty) {
      costMinor = parseMoneyMinor(_cost.text);
      costInvalid = costMinor == null;
    }

    setState(() {
      _problems = problems;
      _costInvalid = costInvalid;
    });
    if (problems.isNotEmpty || costInvalid) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        RecordFormResult(
          occurredAt: _occurredAt,
          data: data,
          costMinor: costMinor,
          doctorId: _doctor?.id,
          photos: List.unmodifiable(_photos),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addPhotos(ImageSource source) async {
    final picked = await widget.pickPhotos!(source);
    if (!mounted) {
      picked.forEach(discardPicked);
      return;
    }
    if (picked.isNotEmpty) setState(() => _photos.addAll(picked));
  }

  void _removePhoto(int index) {
    discardPicked(_photos[index]);
    setState(() => _photos.removeAt(index));
  }

  String? _errorFor(FieldSpec f) {
    if (!_problems.contains(f.key)) return null;
    final empty = !_collect().containsKey(f.key);
    return empty ? widget.strings.required : widget.strings.invalid;
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(DateTime.now().year + 5, 12, 31),
  );

  Widget _field(FieldSpec f) {
    final label = f.labelOf(context) + (f.required ? ' *' : '');
    final error = _errorFor(f);
    switch (f.kind) {
      case FieldKind.text:
        return TextFormField(
          key: ValueKey('field-${f.key}'),
          controller: _text[f.key],
          decoration: InputDecoration(labelText: label, errorText: error),
        );
      case FieldKind.number || FieldKind.money:
        return TextFormField(
          key: ValueKey('field-${f.key}'),
          controller: _text[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, errorText: error),
        );
      case FieldKind.choice:
        return DropdownButtonFormField<String>(
          key: ValueKey('field-${f.key}'),
          initialValue: _values[f.key] as String?,
          decoration: InputDecoration(labelText: label, errorText: error),
          items: [
            for (final c in f.choices)
              DropdownMenuItem(
                value: c,
                child: Text(f.choiceLabelOf(context, c)),
              ),
          ],
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldKind.boolean:
        return SwitchListTile(
          key: ValueKey('field-${f.key}'),
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _values[f.key] as bool? ?? false,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case FieldKind.date:
        final value = _values[f.key] as String?;
        return InkWell(
          key: ValueKey('field-${f.key}'),
          onTap: () async {
            final picked = await _pickDate(
              value == null ? DateTime.now() : DateTime.parse(value),
            );
            if (picked != null) {
              setState(() => _values[f.key] = _isoDate.format(picked));
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, errorText: error),
            child: Text(value ?? widget.strings.pickDate),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InkWell(
          key: const ValueKey('field-occurredAt'),
          onTap: () async {
            final picked = await _pickDate(_occurredAt);
            if (picked != null) setState(() => _occurredAt = picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: widget.strings.date),
            child: Text(DateFormat.yMMMd(locale).format(_occurredAt)),
          ),
        ),
        for (final f in widget.type.fields) ...[
          const SizedBox(height: 16),
          if (f.key == widget.type.doctorField &&
              widget.doctors.isNotEmpty) ...[
            DropdownButtonFormField<DoctorChoice>(
              key: const ValueKey('field-doctorPick'),
              initialValue: _doctor,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: widget.strings.chooseDoctor,
                prefixIcon: const Icon(Icons.contacts_outlined),
              ),
              items: [
                for (final d in widget.doctors)
                  DropdownMenuItem(
                    value: d,
                    child: Text(
                      [d.name, ?d.specialty].join(' · '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _pickDoctor,
            ),
            const SizedBox(height: 12),
          ],
          _field(f),
        ],
        if (widget.type.hasCost) ...[
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('field-cost'),
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.strings.cost,
              suffixText: widget.strings.currency,
              errorText: _costInvalid ? widget.strings.invalid : null,
            ),
          ),
        ],
        if (widget.pickPhotos != null) ...[
          const SizedBox(height: 20),
          _PhotosRow(
            strings: widget.strings,
            photos: _photos,
            onAdd: _submitting ? null : _addPhotos,
            onRemove: _submitting ? null : _removePhoto,
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(
          key: const ValueKey('record-save'),
          onPressed: _submitting ? null : _submit,
          child: Text(widget.strings.save),
        ),
      ],
    );
  }
}

/// Picked photos as thumbnails, with big buttons to take or pick more.
class _PhotosRow extends StatelessWidget {
  const _PhotosRow({
    required this.strings,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final RecordFormStrings strings;
  final List<String> photos;
  final ValueChanged<ImageSource>? onAdd;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    const tall = Size(0, 56);
    const thumb = 88.0;
    final pixels = (thumb * MediaQuery.devicePixelRatioOf(context)).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.photos, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (photos.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, path) in photos.indexed)
                Stack(
                  key: ValueKey('record-photo-$i'),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: PhotoImage(
                        file: File(path),
                        width: thumb,
                        height: thumb,
                        fit: BoxFit.cover,
                        cacheWidth: pixels,
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: IconButton.filledTonal(
                        key: ValueKey('record-photo-remove-$i'),
                        tooltip: strings.photoRemove,
                        visualDensity: VisualDensity.compact,
                        onPressed: onRemove == null ? null : () => onRemove!(i),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('record-photo-camera'),
                style: OutlinedButton.styleFrom(minimumSize: tall),
                onPressed: onAdd == null
                    ? null
                    : () => onAdd!(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(strings.photoCamera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('record-photo-gallery'),
                style: OutlinedButton.styleFrom(minimumSize: tall),
                onPressed: onAdd == null
                    ? null
                    : () => onAdd!(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(strings.photoGallery),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
