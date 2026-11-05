import '../follow_ups/conditions.dart' show normalizeText;

/// A test labs commonly print, with the names it goes by in Arabic and
/// English. Used to suggest names while typing and to put the same test
/// from different labs on one trend chart. Any other name can be typed.
class KnownLabTest {
  const KnownLabTest(this.id, this.en, this.ar, this.aliases);

  /// Stable key, used in links to a test's trend page.
  final String id;
  final String en;
  final String ar;

  /// Other ways reports and people write it (matched after [labTestKey]'s
  /// normalising, so case, dashes and "serum" in front don't matter).
  final List<String> aliases;

  String nameIn(String languageCode) => languageCode == 'ar' ? ar : en;
}

/// Common tests on Egyptian lab reports. Not a list of what anyone should
/// have done: only names, so the same test reads the same everywhere.
const knownLabTests = <KnownLabTest>[
  KnownLabTest('cbc', 'CBC', 'صورة دم كاملة', [
    'complete blood count',
    'complete blood picture',
    'cbp',
    'صوره دم',
    'صوره دم كامله',
  ]),
  KnownLabTest('hb', 'Hemoglobin', 'هيموجلوبين', [
    'hb',
    'hgb',
    'haemoglobin',
    'hemoglobin hb',
    'هيموجلوبين',
    'الهيموجلوبين',
  ]),
  KnownLabTest('rbc', 'RBCs', 'كرات الدم الحمراء', [
    'rbc',
    'rbc count',
    'red blood cells',
    'red cell count',
    'كرات الدم الحمرا',
  ]),
  KnownLabTest('hct', 'Hematocrit', 'الهيماتوكريت', [
    'hct',
    'pcv',
    'haematocrit',
    'hematocrit hct',
    'هيماتوكريت',
  ]),
  KnownLabTest('mcv', 'MCV', 'MCV', []),
  KnownLabTest('mch', 'MCH', 'MCH', []),
  KnownLabTest('mchc', 'MCHC', 'MCHC', []),
  KnownLabTest('rdw', 'RDW', 'RDW', ['rdw cv']),
  KnownLabTest('wbc', 'WBCs', 'كرات الدم البيضاء', [
    'wbc',
    'tlc',
    'total leucocytic count',
    'total leukocyte count',
    'white blood cells',
    'wbc count',
    'كرات الدم البيضا',
  ]),
  KnownLabTest('neutrophils', 'Neutrophils', 'النيوتروفيل', [
    'neutrophil',
    'segmented neutrophils',
  ]),
  KnownLabTest('lymphocytes', 'Lymphocytes', 'الخلايا الليمفاوية', [
    'lymphocyte',
  ]),
  KnownLabTest('monocytes', 'Monocytes', 'المونوسيت', ['monocyte']),
  KnownLabTest('eosinophils', 'Eosinophils', 'الإيوسينوفيل', ['eosinophil']),
  KnownLabTest('platelets', 'Platelets', 'الصفائح الدموية', [
    'plt',
    'platelet count',
    'platelets count',
    'صفايح',
    'الصفايح',
    'صفائح',
  ]),
  KnownLabTest('esr', 'ESR', 'سرعة الترسيب', [
    'esr 1st hour',
    'esr 1st hr',
    'erythrocyte sedimentation rate',
    'سرعه الترسيب',
    'سرعه ترسيب',
  ]),
  KnownLabTest('crp', 'CRP', 'CRP', ['c reactive protein', 'crp quantitative']),
  KnownLabTest('ferritin', 'Ferritin', 'مخزون الحديد (فيريتين)', [
    'فيريتين',
    'مخزون الحديد',
  ]),
  KnownLabTest('iron', 'Serum iron', 'الحديد', ['iron', 'fe', 'حديد']),
  KnownLabTest('tibc', 'TIBC', 'TIBC', ['total iron binding capacity']),
  KnownLabTest('hba1c', 'HbA1c', 'السكر التراكمي', [
    'hb a1c',
    'a1c',
    'glycated hemoglobin',
    'glycosylated hemoglobin',
    'glycated haemoglobin',
    'سكر تراكمي',
    'التراكمي',
  ]),
  KnownLabTest('fbs', 'Fasting blood sugar', 'سكر صائم', [
    'fbs',
    'fasting glucose',
    'fasting blood glucose',
    'fasting plasma glucose',
    'glucose fasting',
    'السكر الصايم',
    'سكر صايم',
  ]),
  KnownLabTest('pp', 'Blood sugar 2h after meal', 'سكر فاطر', [
    'pp',
    '2h pp',
    '2 hours post prandial',
    'post prandial blood glucose',
    'ppbs',
    'سكر بعد الاكل',
    'السكر الفاطر',
  ]),
  KnownLabTest('rbs', 'Random blood sugar', 'سكر عشوائي', [
    'rbs',
    'random glucose',
    'random blood glucose',
  ]),
  KnownLabTest('cholesterol', 'Total cholesterol', 'الكوليسترول', [
    'cholesterol',
    'cholesterol total',
    'total cholesterol',
    'كوليسترول',
    'كوليسترول كلي',
  ]),
  KnownLabTest('ldl', 'LDL cholesterol', 'الكوليسترول الضار (LDL)', [
    'ldl',
    'ldl c',
    'ldl cholesterol',
    'ldl cholesterol calculated',
    'الكوليسترول الضار',
  ]),
  KnownLabTest('hdl', 'HDL cholesterol', 'الكوليسترول النافع (HDL)', [
    'hdl',
    'hdl c',
    'hdl cholesterol',
    'الكوليسترول النافع',
  ]),
  KnownLabTest('triglycerides', 'Triglycerides', 'الدهون الثلاثية', [
    'tg',
    'triglyceride',
    'دهون ثلاثيه',
  ]),
  KnownLabTest('lipids', 'Lipid profile', 'دهون الدم', [
    'lipid profile',
    'lipogram',
    'صوره دهون',
  ]),
  KnownLabTest('tsh', 'TSH', 'هرمون الغدة (TSH)', [
    'thyroid stimulating hormone',
    'tsh ultra sensitive',
    'tsh3',
    'هرمون الغده',
  ]),
  KnownLabTest('ft4', 'Free T4', 'Free T4', ['ft4', 'free thyroxine']),
  KnownLabTest('ft3', 'Free T3', 'Free T3', ['ft3']),
  KnownLabTest('vitd', 'Vitamin D', 'فيتامين د', [
    'vitamin d3',
    'vitamin d total',
    'total vitamin d',
    '25 oh vitamin d',
    '25 oh vit d',
    '25 hydroxy vitamin d',
    'vit d',
    'vit d3',
    'فيتامين د3',
    'فيتامين دال',
  ]),
  KnownLabTest('b12', 'Vitamin B12', 'فيتامين ب12', [
    'vit b12',
    'vitamin b 12',
    'cobalamin',
    'فيتامين ب 12',
  ]),
  KnownLabTest('creatinine', 'Creatinine', 'الكرياتينين', [
    'creat',
    'creatinine serum',
    'كرياتينين',
  ]),
  KnownLabTest('urea', 'Urea', 'اليوريا', ['blood urea', 'bun', 'يوريا']),
  KnownLabTest('uric', 'Uric acid', 'حمض اليوريك', [
    'uric acid serum',
    'حمض اليوريك',
    'الاملاح',
  ]),
  KnownLabTest('alt', 'ALT (SGPT)', 'إنزيم الكبد ALT', [
    'alt',
    'sgpt',
    'alt sgpt',
    'sgpt alt',
  ]),
  KnownLabTest('ast', 'AST (SGOT)', 'إنزيم الكبد AST', [
    'ast',
    'sgot',
    'ast sgot',
    'sgot ast',
  ]),
  KnownLabTest('albumin', 'Albumin', 'الألبيومين', ['albumin serum']),
  KnownLabTest('bilirubin', 'Total bilirubin', 'الصفراء الكلية', [
    'bilirubin total',
    'total bilirubin',
    't bil',
  ]),
  KnownLabTest('calcium', 'Calcium', 'الكالسيوم', [
    'ca',
    'total calcium',
    'كالسيوم',
  ]),
  KnownLabTest('potassium', 'Potassium', 'البوتاسيوم', ['k', 'بوتاسيوم']),
  KnownLabTest('sodium', 'Sodium', 'الصوديوم', ['na', 'صوديوم']),
  KnownLabTest('psa', 'PSA', 'PSA', ['total psa', 'psa total']),
];

/// A test name compared loosely: normalised like other typed text, with
/// brackets, dots and colons gone and a leading "serum" or "S." dropped.
String labTestKey(String name) {
  var n = normalizeText(name.replaceAll(RegExp(r'[().,:;*\[\]]'), ' '))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  for (final prefix in ['serum ', 's ', 'blood ']) {
    if (n.startsWith(prefix) && n.length > prefix.length + 1) {
      n = n.substring(prefix.length);
    }
  }
  return n;
}

final Map<String, KnownLabTest> _byKey = {
  for (final t in knownLabTests)
    for (final name in [t.id, t.en, t.ar, ...t.aliases]) labTestKey(name): t,
};

/// Every name a known test goes by, compared loosely, for suggestions.
final List<(String, KnownLabTest)> labTestNames = [
  for (final MapEntry(:key, :value) in _byKey.entries) (key, value),
];

/// The known test a typed or printed name is, if any.
KnownLabTest? matchLabTest(String name) => _byKey[labTestKey(name)];

/// Groups the same test together: the known test's id, or the loosely
/// compared name.
String labSeriesKey(String name) => matchLabTest(name)?.id ?? labTestKey(name);

/// A unit compared loosely ("mg/dL" and "mg/dl", "µIU/mL" and "uIU/ml"), so
/// only really different units are kept apart.
String labUnitKey(String? unit) => (unit ?? '')
    .toLowerCase()
    .replaceAll(RegExp('[µμ]'), 'u')
    .replaceAll('mcg', 'ug')
    .replaceAll(RegExp(r'\s+'), '');
