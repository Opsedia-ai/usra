import 'package:flutter/widgets.dart';

/// The kind of value a record field holds; drives the form and validation.
enum FieldKind { text, number, date, money, choice, boolean }

/// One field of a record type (for example "fee" on a doctor visit).
class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.kind,
    this.required = false,
    this.choices = const [],
  });

  final String key;
  final FieldKind kind;
  final bool required;
  final List<String> choices;
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
  });

  final String key;
  final IconData icon;
  final List<FieldSpec> fields;
  final bool hasCost;

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
