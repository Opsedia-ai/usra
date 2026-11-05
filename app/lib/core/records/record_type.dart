import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../database/app_database.dart';

/// The kind of value a record field holds; drives the form and validation.
enum FieldKind { text, number, date, money, choice, boolean }

/// Translates a label in the current language. Modules pass these so the
/// core never depends on a feature's strings.
typedef LabelBuilder = String Function(BuildContext context);

/// Whether a record type fits a person on a given day.
typedef RecordTypeFilter = bool Function(Profile profile, DateTime today);
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
    this.requireOneOf = const [],
    this.appliesTo,
    this.inTimeline = true,
    this.screens = const RecordTypeScreens(),
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

  /// Keys of fields of which at least one must be filled (for example a
  /// measurement needs a weight or a height, not necessarily both).
  final List<String> requireOneOf;

  /// Who the "add record" list offers this type to (pregnancy for women,
  /// a feed for babies); null means everyone. A module's own screens can
  /// still add it.
  final RecordTypeFilter? appliesTo;

  /// False for quick logs (feeds, diapers, ticked milestones) that would
  /// flood a person's timeline; their module's screen lists them instead.
  final bool inTimeline;

  /// The type's own pages, where the generic form and field list don't fit.
  final RecordTypeScreens screens;

  String labelOf(BuildContext context) => label?.call(context) ?? key;

  bool offeredFor(Profile profile, DateTime today) =>
      appliesTo?.call(profile, today) ?? true;

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
    final noneFilled = requireOneOf.every((k) {
      final v = data[k];
      return v == null || (v is String && v.trim().isEmpty);
    });
    if (requireOneOf.isNotEmpty && noneFilled) problems.addAll(requireOneOf);
    return problems;
  }
}

/// Pages a record type brings when the generic ones don't fit it (a lab
/// report holds a list of results, which the generic form can't edit).
class RecordTypeScreens {
  const RecordTypeScreens({
    this.add,
    this.editPath,
    this.details,
    this.shareLines,
  });

  /// Shown at `/family/<profileId>/add/<type>` instead of the generic form.
  final Widget Function(String profileId)? add;

  /// Where a saved record is changed; the record page offers Edit when set.
  final String Function(String profileId, String eventId)? editPath;

  /// Shown on the record page instead of the field list (the date and cost
  /// stay).
  final Widget Function(BuildContext context, MedicalEvent event)? details;

  /// The shared text's lines instead of the field list.
  final List<String> Function(BuildContext context, MedicalEvent event)?
  shareLines;
}

/// A record's `dataJson` as a map; empty when missing or malformed.
Map<String, Object?> decodeRecordData(String json) {
  try {
    final v = jsonDecode(json);
    return v is Map<String, Object?> ? v : const {};
  } catch (_) {
    return const {};
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
