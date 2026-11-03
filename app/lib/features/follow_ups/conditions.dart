import '../../core/util/localized_numbers.dart';

/// Lower case, Western digits, no Arabic diacritics or tatweel, one form of
/// alef, yeh and teh marbuta, and single spaces, so typed text matches
/// keywords however it was spelled.
String normalizeText(String raw) =>
    toWesternDigits(raw)
        .toLowerCase()
        .replaceAll(RegExp('[ً-ْـ]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[-_/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

/// Whether [text] has a word starting with any of [keywords] (already
/// normalized). Arabic words may carry "ال", "و", "ب" or "لل" in front, so
/// "السكري" matches "سكر" while "معين" doesn't match "عين".
bool mentionsAny(String text, Iterable<String> keywords) =>
    _hasAny(normalizeText(text), keywords);

bool _hasAny(String normalized, Iterable<String> keywords) =>
    keywords.any((k) => _wordStart(k).hasMatch(normalized));

final _patterns = <String, RegExp>{};

RegExp _wordStart(String keyword) => _patterns.putIfAbsent(
  keyword,
  () => RegExp(
    '(^|[^\\p{L}\\p{N}])(ال|وال|بال|لل|و|ب)?${RegExp.escape(keyword)}',
    unicode: true,
  ),
);

/// Long-term conditions some follow-ups depend on.
enum Condition { diabetes, hypertension, heart, highCholesterol, kidney }

/// Words people write in a profile's conditions, Arabic and English,
/// normalized as [normalizeText] does.
const _conditionWords = <Condition, List<String>>{
  Condition.diabetes: [
    'سكر',
    'السكري',
    'diabet',
    'dm1',
    'dm2',
    't1dm',
    't2dm',
    'iddm',
    'niddm',
  ],
  Condition.hypertension: ['ضغط', 'hypertension', 'high blood pressure', 'htn'],
  Condition.heart: [
    'قلب',
    'ذبحه',
    'جلطه في القلب',
    'شرايين',
    'heart',
    'cardiac',
    'coronary',
    'angina',
  ],
  Condition.highCholesterol: [
    'كوليسترول',
    'كولسترول',
    'كولستيرول',
    'دهون',
    'cholesterol',
    'lipid',
    'hyperlipid',
    'dyslipid',
  ],
  Condition.kidney: ['كلي', 'كلوي', 'kidney', 'renal', 'ckd'],
};

/// "Low" blood pressure isn't hypertension.
const _lowPressureWords = [
  'واطي',
  'منخفض',
  'low blood pressure',
  'hypotension',
];

/// The known conditions in a profile's free-text conditions.
Set<Condition> conditionsIn(String? text) {
  if (text == null) return const {};
  // Heartburn is not heart disease.
  final n = normalizeText(text).replaceAll('heartburn', '');
  if (n.isEmpty) return const {};
  final found = <Condition>{};
  for (final MapEntry(key: condition, value: words)
      in _conditionWords.entries) {
    if (_hasAny(n, words)) found.add(condition);
  }
  // "ضغط واطي" alone mentions pressure but isn't hypertension.
  if (found.contains(Condition.hypertension) &&
      _lowPressureWords.any(n.contains) &&
      !['عالي', 'مرتفع', 'hypertension', 'high blood'].any(n.contains)) {
    found.remove(Condition.hypertension);
  }
  return found;
}
