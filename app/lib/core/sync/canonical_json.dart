import 'dart:convert';

/// Canonical JSON for signed sync bodies: object keys sorted by their UTF-16
/// code units, no whitespace, numbers only as integers or finite doubles.
///
/// Writers sign the canonical bytes, and readers accept a body only if
/// re-encoding what they parsed gives back exactly the bytes they verified.
/// That rejects duplicate keys, other spellings of the same value and
/// anything else a lenient parser would quietly accept (docs/sync-design.md
/// section 5, strict parsing).
String canonicalJson(Object? value) {
  final out = StringBuffer();
  _write(out, value, 0);
  return out.toString();
}

/// The UTF-8 bytes of [canonicalJson].
List<int> canonicalJsonBytes(Object? value) =>
    utf8.encode(canonicalJson(value));

/// Parses [bytes] strictly: valid UTF-8, at most [maxDepth] levels, and
/// canonical (see [canonicalJson]). Throws [FormatException] otherwise.
Object? parseCanonicalJson(List<int> bytes, {int maxDepth = 8}) {
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('body is not UTF-8');
  }
  final value = jsonDecode(text);
  if (canonicalJson(value) != text) {
    throw const FormatException('body is not canonical JSON');
  }
  if (_depth(value) > maxDepth) {
    throw const FormatException('body is nested too deeply');
  }
  return value;
}

int _depth(Object? value) => switch (value) {
  Map<String, dynamic>() =>
    1 + value.values.fold<int>(0, (d, v) => d > _depth(v) ? d : _depth(v)),
  List<dynamic>() =>
    1 + value.fold<int>(0, (d, v) => d > _depth(v) ? d : _depth(v)),
  _ => 0,
};

void _write(StringBuffer out, Object? value, int depth) {
  if (depth > 64) throw const FormatException('too deep');
  switch (value) {
    case null || bool() || String():
      out.write(jsonEncode(value));
    case int():
      out.write(value);
    case double():
      if (!value.isFinite) throw const FormatException('number not finite');
      // Whole doubles are written as integers so 1.0 and 1 agree.
      if (value == value.truncateToDouble() && value.abs() < 9007199254740992) {
        out.write(value.toInt());
      } else {
        out.write(jsonEncode(value));
      }
    case Map<String, Object?>():
      final keys = value.keys.toList()..sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        _write(out, value[keys[i]], depth + 1);
      }
      out.write('}');
    case List<Object?>():
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        _write(out, value[i], depth + 1);
      }
      out.write(']');
    default:
      throw FormatException('not a JSON value: ${value.runtimeType}');
  }
}
