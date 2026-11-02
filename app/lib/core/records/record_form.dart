import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  });

  final String date;
  final String cost;
  final String currency;
  final String save;
  final String required;
  final String invalid;
  final String pickDate;
}

/// What the user entered, ready to store as a `MedicalEvent`.
class RecordFormResult {
  const RecordFormResult({
    required this.occurredAt,
    required this.data,
    this.costMinor,
  });

  final DateTime occurredAt;
  final Map<String, Object?> data;

  /// Cost in the smallest currency unit (piasters for EGP).
  final int? costMinor;
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
  });

  final RecordTypeDefinition type;
  final RecordFormStrings strings;

  /// Awaited; the Save button stays disabled until it completes.
  final Future<void> Function(RecordFormResult) onSubmit;
  final DateTime? initialDate;

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

  @override
  void initState() {
    super.initState();
    for (final f in widget.type.fields) {
      if (_usesTextField(f.kind)) _text[f.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    _cost.dispose();
    super.dispose();
  }

  static bool _usesTextField(FieldKind kind) =>
      kind == FieldKind.text ||
      kind == FieldKind.number ||
      kind == FieldKind.money;

  static num? _parseNumber(String raw) {
    // Accept Arabic-Indic digits and the Arabic decimal separator.
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final western = raw.trim().split('').map((ch) {
      final i = arabic.indexOf(ch);
      if (i >= 0) return '$i';
      return ch == '٫' ? '.' : ch;
    }).join();
    return western.isEmpty ? null : num.tryParse(western);
  }

  Map<String, Object?> _collect() {
    final data = <String, Object?>{};
    for (final f in widget.type.fields) {
      switch (f.kind) {
        case FieldKind.text:
          final v = _text[f.key]!.text.trim();
          if (v.isNotEmpty) data[f.key] = v;
        case FieldKind.number || FieldKind.money:
          final raw = _text[f.key]!.text;
          if (raw.trim().isNotEmpty) data[f.key] = _parseNumber(raw) ?? raw;
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
      final amount = _parseNumber(_cost.text);
      if (amount == null || amount < 0) {
        costInvalid = true;
      } else {
        costMinor = (amount * 100).round();
      }
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
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
