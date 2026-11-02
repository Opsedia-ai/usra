import 'package:flutter/widgets.dart';

/// The kind of value a record field holds; drives the form and validation.
enum FieldKind { text, number, date, money, choice, boolean }

/// Translates a label in the current language. Modules pass these so the
/// core never depends on a feature's strings.
typedef LabelBuilder = String Function(BuildContext context);
typedef ChoiceLabelBuilder = String Function(
  BuildContext context,
  String choice,
);

/// One field of a record type (for example "doctor" on a visit).
class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.kind,
    this.required = false,
    this.choices = const [],
    this.label,
    this.choiceLabel,
  });

  final String key;
  final FieldKind kind;
  final bool required;
  final List<String> choices;
  final LabelBuilder? label;
  final ChoiceLabelBuilder? choiceLabel;

  String labelOf(BuildContext context) => label?.call(context) ?? key;
  String choiceLabelOf(BuildContext context, String choice) =>
      choiceLabel?.call(context, choice) ?? choice;
}

/// A kind of medical record: visit, scan, lab, vaccine, surgery...
///
/// Every record is stored as one generic `MedicalEvent`; the type only
/// describes its extra fields, so adding a type never needs a new table.
class RecordTypeDefinition {
  const RecordTypeDefinition({
    required this.key,
    required this.icon,
    this.fields = const [],
    this.hasCost = true,
    this.label,
    this.doctorField,
  });

  final String key;
  final IconData icon;
  final List<FieldSpec> fields;

  /// Whether the record has a cost (stored in the event's money columns and
  /// counted in spending), so types don't each add their own "fee" field.
  final bool hasCost;
  final LabelBuilder? label;

  /// Key of the text field holding the doctor's name. When set, the form
  /// offers saved doctors and links the record to the one picked.
  final String? doctorField;

  String labelOf(BuildContext context) => label?.call(context) ?? key;

  /// The field shown as the record's title in lists: the first required one.
  FieldSpec? get titleField {
    for (final f in fields) {
      if (f.required) return f;
    }
    return fields.isEmpty ? null : fields.first;
  }

  /// Returns the keys of fields that are missing or have the wrong kind.
  List<String> validate(Map<String, Object?> data) {
    final problems = <String>[];
    for (final field in fields) {
      final value = data[field.key];
      final isEmpty =
          value == null || (value is String && value.trim().isEmpty);
      if (isEmpty) {
        if (field.required) problems.add(field.key);
        continue;
      }
      final ok = switch (field.kind) {
        FieldKind.text => value is String,
        FieldKind.number || FieldKind.money => value is num,
        FieldKind.date =>
          value is DateTime ||
              (value is String && DateTime.tryParse(value) != null),
        FieldKind.boolean => value is bool,
        FieldKind.choice => value is String && field.choices.contains(value),
      };
      if (!ok) problems.add(field.key);
    }
    return problems;
  }
}

/// All record types contributed by the registered feature modules.
class RecordTypeRegistry {
  RecordTypeRegistry(Iterable<RecordTypeDefinition> types) {
    for (final type in types) {
      if (_types.containsKey(type.key)) {
        throw ArgumentError('Duplicate record type: ${type.key}');
      }
      _types[type.key] = type;
    }
  }

  final Map<String, RecordTypeDefinition> _types = {};

  RecordTypeDefinition? operator [](String key) => _types[key];

  List<RecordTypeDefinition> get all => List.unmodifiable(_types.values);
}
