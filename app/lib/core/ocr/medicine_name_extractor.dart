import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ocr_service.dart';

/// A medicine name, and its strength when one was printed near it, read
/// off a box. Never a dose: how much to take is for the doctor and the
/// leaflet, not for a guess from a photo.
class MedicineSuggestion {
  const MedicineSuggestion({
    required this.name,
    this.strength,
    this.known = false,
    this.box,
  });

  final String name;

  /// As printed, tidied: "500mg", "1g", "875/125mg", "250mg/5ml".
  final String? strength;

  /// The name is in the bundled list, so it's more likely to be right.
  final bool known;

  /// Where the name was read, in the photo's pixels.
  final Rect? box;

  String get label => strength == null ? name : '$name $strength';

  @override
  bool operator ==(Object other) =>
      other is MedicineSuggestion &&
      other.name == name &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(name, strength);

  @override
  String toString() => 'MedicineSuggestion($label${known ? ', known' : ''})';
}

/// Suggests medicine names and strengths from the text on a box, using a
/// few heuristics and a list of names sold in Egypt.
class MedicineNameExtractor {
  MedicineNameExtractor(Iterable<String> names) {
    final seen = <String>{};
    for (final name in names) {
      final display = _tidy(name);
      final key = display.toLowerCase();
      if (display.isEmpty || !seen.add(key)) continue;
      _names.add(
        _KnownName(
          display,
          RegExp(
            '(?<![a-z0-9])'
            '${RegExp.escape(key).replaceAll(' ', r'\s+')}'
            '(?![a-z0-9])',
          ),
          key.contains(' ') ? null : key,
        ),
      );
    }
    // Longest first, so "Panadol Extra" wins over "Panadol".
    _names.sort((a, b) => b.display.length.compareTo(a.display.length));
  }

  /// Reads the bundled list: one name per line, `#` starts a comment.
  factory MedicineNameExtractor.fromList(String text) => MedicineNameExtractor(
    text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#')),
  );

  static const asset = 'assets/medicines/egypt_medicine_names.txt';

  final _names = <_KnownName>[];

  /// The likeliest names first, at most [max].
  List<MedicineSuggestion> suggest(OcrResult result, {int max = 5}) {
    final lines = [
      for (final l in result.lines)
        if (_tidy(l.text).isNotEmpty) (text: _tidy(l.text), box: l.box),
    ];
    final strengths = [
      for (final l in lines) _isDoseLine(l.text) ? null : strengthIn(l.text),
    ];
    final known = [
      for (final l in lines)
        _isDetailLine(l.text) ? const <String>[] : _knownIn(l.text),
    ];
    final guessed = [
      for (final (i, l) in lines.indexed)
        known[i].isEmpty ? _guessName(l.text) : null,
    ];

    String? strengthNear(int i) {
      for (final d in const [0, 1, -1, 2, -2]) {
        final j = i + d;
        if (j < 0 || j >= lines.length || strengths[j] == null) continue;
        // A line with its own name has its own strength, unless it's the
        // smaller print under a brand ("Paracetamol 500mg" under "Panadol").
        final named = known[j].isNotEmpty || guessed[j] != null;
        if (d != 0 &&
            named &&
            lines[j].box.height > lines[i].box.height * 0.8) {
          continue;
        }
        return strengths[j];
      }
      return null;
    }

    final ranked = <(MedicineSuggestion, double)>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final name in known[i]) {
        ranked.add((
          MedicineSuggestion(
            name: name,
            strength: strengthNear(i),
            known: true,
            box: line.box,
          ),
          line.box.height,
        ));
      }
      final guess = guessed[i];
      if (guess != null) {
        ranked.add((
          MedicineSuggestion(
            name: guess,
            strength: strengthNear(i),
            box: line.box,
          ),
          // A listed name is more likely right than a guess the same size.
          line.box.height * 0.8,
        ));
      }
    }
    // Bigger print first: the brand is the largest text on a box.
    ranked.sort((a, b) => b.$2.compareTo(a.$2));

    final out = <MedicineSuggestion>[];
    final byName = <String, int>{};
    var keptGuesses = 0;
    for (final (s, _) in ranked) {
      if (!s.known && ++keptGuesses > 3) continue;
      final key = s.name.toLowerCase();
      final at = byName[key];
      if (at == null) {
        byName[key] = out.length;
        out.add(s);
      } else if (out[at].strength == null && s.strength != null) {
        out[at] = s;
      }
    }
    return out.take(max).toList();
  }

  /// The first strength in [text], tidied ("500 MG" -> "500mg"), or null.
  static String? strengthIn(String text) {
    for (final m in _strength.allMatches(_fixDigits(text))) {
      final unit = _unit(m.group(2)!);
      final per = m.group(4);
      // "120 ml" is how much is in the bottle, not how strong it is.
      if (unit == 'ml' && per == null) continue;
      final amount = _number(m.group(1)!);
      return per == null
          ? '$amount$unit'
          : '$amount$unit/${_number(m.group(3) ?? '')}${_unit(per)}';
    }
    return null;
  }

  /// "0,5" -> "0.5", but "200,000" and "200.000" -> "200000": three digits
  /// after the separator mean thousands.
  static String _number(String s) => s
      .replaceAll(RegExp(r'\s+'), '')
      .split('/')
      .map(
        (n) => RegExp(r'^[1-9]\d{0,2}([.,]\d{3})+$').hasMatch(n)
            ? n.replaceAll(RegExp('[.,]'), '')
            : n.replaceAll(',', '.'),
      )
      .join('/');

  List<String> _knownIn(String text) {
    var rest = text.toLowerCase();
    final found = <String>[];
    for (final n in _names) {
      final m = n.pattern.firstMatch(rest);
      if (m == null) continue;
      found.add(n.display);
      // Blank it out so "Panadol" isn't found again inside "Panadol Extra".
      rest = rest.replaceRange(m.start, m.end, ' ' * (m.end - m.start));
    }
    if (found.isNotEmpty) return found;
    // OCR slips: "Augrnentin", "Panad0l", "Concar".
    for (final token in rest.split(RegExp(r'[^a-z0-9]+'))) {
      if (RegExp('[a-z]').allMatches(token).length < 5) continue;
      final variants = {
        token.replaceAll('0', 'o').replaceAll('1', 'l'),
        token.replaceAll('0', 'o').replaceAll('1', 'l').replaceAll('rn', 'm'),
      };
      _KnownName? best;
      var bestDistance = 99;
      for (final n in _names) {
        final word = n.singleWord;
        if (word == null || word.length < 5) continue;
        final allowed = word.length >= 8 ? 2 : 1;
        for (final v in variants) {
          if ((v.length - word.length).abs() > allowed) continue;
          final d = _distance(v, word, allowed);
          if (d <= allowed && d < bestDistance) {
            best = n;
            bestDistance = d;
          }
        }
      }
      if (best != null) found.add(best.display);
    }
    return found;
  }

  /// A line that looks like a brand name not in the list: one to three
  /// Latin words, no company, storage or batch details.
  static String? _guessName(String text) {
    var rest = _fixDigits(text).replaceAll(_strength, ' ');
    final words = rest
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.any((w) => _rejectWords.contains(_bare(w)))) return null;
    // "Flotac capsules" -> "Flotac".
    while (words.isNotEmpty && _formWords.contains(_bare(words.last))) {
      words.removeLast();
    }
    if (words.isEmpty || words.length > 3) return null;
    rest = words.join(' ');
    if (!RegExp(r"^[A-Za-z][A-Za-z\-&+' ]*$").hasMatch(rest)) return null;
    if (_bare(words.first).length < 4) return null;
    if (_formWords.contains(_bare(words.first))) return null;
    // Labels on a box are capitalised; lowercase is usually small print.
    if (!RegExp('[A-Z]').hasMatch(words.first[0])) return null;
    final allCaps = rest == rest.toUpperCase();
    return allCaps
        ? words.map((w) => w[0] + w.substring(1).toLowerCase()).join(' ')
        : rest;
  }

  static bool _isDoseLine(String text) => _doseWords.hasMatch(text);

  /// Inactive ingredients and the maker's details: names there aren't the
  /// medicine ("magnesium stearate").
  static bool _isDetailLine(String text) => _detailWords.hasMatch(text);

  static String _unit(String raw) =>
      switch (raw.toLowerCase().replaceAll('.', '')) {
        'gm' || 'gram' || 'grams' => 'g',
        'µg' || 'ug' || 'mcg' => 'mcg',
        'iu' => 'IU',
        final u => u,
      };

  /// "5OO rng" -> "500 mg": letters OCR reads in place of digits next to a
  /// number.
  static String _fixDigits(String text) => text
      .replaceAllMapped(
        RegExp(r'(?<=\d)[oO]+|[oO]+(?=\d)'),
        (m) => '0' * m.group(0)!.length,
      )
      .replaceAllMapped(RegExp(r'(\d)\s*rng\b'), (m) => '${m[1]}mg');

  static String _tidy(String s) =>
      s.replaceAll(RegExp('[®™©]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _bare(String w) =>
      w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  static final _strength = RegExp(
    r'(?<![\d.,])(\d+(?:[.,]\d+)*(?:\s*/\s*\d+(?:[.,]\d+)*)?)\s*'
    r'(mg|mcg|µg|ug|grams?|gm|g|ml|i\.?u\.?|%)'
    r'(?:\s*/\s*(\d+(?:[.,]\d+)?)?\s*(ml|g|mg))?'
    r'(?![a-z])',
    caseSensitive: false,
  );

  /// Instructions for taking it ("1 tablet twice daily"): strengths there
  /// are doses, so they're never read.
  static final _doseWords = RegExp(
    r'\b(take|times|daily|every|hours?|hrs|twice|once|thrice|meals?|'
    r'bedtime|per\s+day|a\s+day)\b|\b\d\s*x\b|\bx\s*\d',
    caseSensitive: false,
  );

  static final _detailWords = RegExp(
    r'\b(excipients?|inactive|stearate|oxide|manufactured|marketed|'
    r'distributed|licen[cs]ed?|store|keep)\b',
    caseSensitive: false,
  );

  static const _formWords = {
    'tablet',
    'tablets',
    'tab',
    'tabs',
    'capsule',
    'capsules',
    'caps',
    'film',
    'coated',
    'fc',
    'syrup',
    'suspension',
    'susp',
    'cream',
    'ointment',
    'gel',
    'drops',
    'drop',
    'injection',
    'vial',
    'vials',
    'ampoule',
    'ampoules',
    'amp',
    'sachet',
    'sachets',
    'effervescent',
    'oral',
    'solution',
    'spray',
    'suppositories',
    'suppository',
    'lotion',
    'powder',
    'granules',
    'retard',
    'sr',
    'xr',
    'er',
    'mr',
    'forte',
    'chewable',
    'eye',
    'ear',
    'nasal',
    'inhaler',
  };

  static const _rejectWords = {
    'each',
    'contains',
    'contain',
    'keep',
    'store',
    'stored',
    'below',
    'above',
    'temperature',
    'exp',
    'expiry',
    'expires',
    'mfg',
    'mfd',
    'manufactured',
    'made',
    'batch',
    'lot',
    'bn',
    'reg',
    'price',
    'le',
    'egp',
    'pharma',
    'pharmaceutical',
    'pharmaceuticals',
    'company',
    'co',
    'ltd',
    'sae',
    'egypt',
    'cairo',
    'giza',
    'alexandria',
    'license',
    'licence',
    'under',
    'dosage',
    'leaflet',
    'read',
    'see',
    'children',
    'reach',
    'adults',
    'use',
    'only',
    'prescription',
    'rx',
    'pack',
    'box',
    'strip',
    'strips',
    'blister',
    'blisters',
    'net',
    'warning',
    'caution',
    'www',
    'com',
    'barcode',
    'the',
    'of',
    'and',
    'with',
    'for',
    'in',
    'to',
    'by',
    'from',
  };

  /// Edit distance, giving up past [max].
  static int _distance(String a, String b, int max) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      var rowMin = cur[0];
      for (var j = 1; j <= b.length; j++) {
        cur[j] = math.min(
          math.min(cur[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1),
        );
        rowMin = math.min(rowMin, cur[j]);
      }
      if (rowMin > max) return max + 1;
      prev = cur;
    }
    return prev[b.length];
  }
}

class _KnownName {
  const _KnownName(this.display, this.pattern, this.singleWord);

  final String display;
  final RegExp pattern;

  /// Lowercase, for near matches; null for names of several words.
  final String? singleWord;
}

/// The extractor with the bundled names. Overridden in tests.
final medicineNameExtractorProvider = FutureProvider<MedicineNameExtractor>(
  (ref) async => MedicineNameExtractor.fromList(
    await rootBundle.loadString(MedicineNameExtractor.asset),
  ),
);
