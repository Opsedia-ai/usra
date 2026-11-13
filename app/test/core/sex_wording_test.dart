import 'package:flutter_test/flutter_test.dart';
import 'package:usra/features/children/milestones.dart';
import 'package:usra/features/sick_days/fever.dart';
import 'package:usra/l10n/app_localizations_ar.dart';
import 'package:usra/l10n/app_localizations_en.dart';

/// Danger signs, symptoms and milestones follow the person's sex in Arabic
/// (item I of the two-year-old report): a girl reads "سنها" and "بتضحك",
/// a boy reads the wording the doctor reviewed, and a person whose sex
/// isn't recorded reads a neutral form (milestones: the boy's wording).
/// Whether [word] is in [text] as a whole word.
bool hasWord(String text, String word) =>
    RegExp('(^|[\\s،(])$word(\$|[\\s،.)])').hasMatch(text);

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();
  final signs = {
    for (final age in AgeGroup.values)
      for (final s in warningSignsFor(age)) s.key,
  };

  test('a girl reads feminine danger signs', () {
    expect(
      ar.warnSign('female', 'under3Months'),
      'سنها أقل من ٣ شهور وحرارتها ٣٨ °م (١٠٠٫٤ °ف) أو أكتر',
    );
    expect(
      ar.warnSign('female', 'drowsy'),
      'نعسانة جدًا أو صعب تصحى، أو مش بترد زي عادتها',
    );
    // Not about the person: the same for everyone.
    expect(ar.warnSign('female', 'seizure'), ar.warnSign('male', 'seizure'));
  });

  test('a boy reads the wording as before', () {
    expect(
      ar.warnSign('male', 'under3Months'),
      'سنه أقل من ٣ شهور وحرارته ٣٨ °م (١٠٠٫٤ °ف) أو أكتر',
    );
    expect(ar.symptomName('male', Symptom.drowsy), 'نعسان جدًا أو صعب يصحى');
    expect(ar.milestone('male', 'm2_social'), 'بيضحك لما تكلمه أو تضحكله');
  });

  test('sex not recorded: neutral signs, never masculine pronouns', () {
    expect(
      ar.warnSign('other', 'under3Months'),
      'السن أقل من ٣ شهور والحرارة ٣٨ °م (١٠٠٫٤ °ف) أو أكتر',
    );
    for (final key in signs) {
      final text = ar.warnSign('other', key);
      for (final masculine in ['سنه', 'حرارته', 'عينه', 'عادته', 'نفسه']) {
        expect(hasWord(text, masculine), isFalse, reason: key);
      }
    }
  });

  test('no feminine danger sign or symptom keeps a masculine form', () {
    const masculine = [
      'سنه',
      'حرارته',
      'عينه',
      'عادته',
      'نفسه',
      'نعسان',
      'بيرد',
      'بيشرب',
      'بيرضع',
      'بيرجّع',
      'بيتنفس',
      'بياكل',
      'بيعمل',
      'مركز',
    ];
    // The check finds a masculine word where there is one.
    expect(hasWord(ar.warnSign('male', 'under3Months'), 'سنه'), isTrue);
    expect(hasWord(ar.warnSign('male', 'drowsy'), 'نعسان'), isTrue);
    for (final key in signs) {
      for (final m in masculine) {
        expect(hasWord(ar.warnSign('female', key), m), isFalse, reason: key);
      }
    }
    for (final s in Symptom.all) {
      for (final m in masculine) {
        expect(hasWord(ar.symptomName('female', s), m), isFalse, reason: s);
      }
    }
  });

  test('every milestone has a feminine form for a girl', () {
    for (final m in cdcMilestones) {
      final girl = ar.milestone('female', m.id);
      expect(girl, isNotEmpty, reason: m.id);
      expect(girl, isNot(ar.milestone('male', m.id)), reason: m.id);
      expect(girl, startsWith('بت'), reason: m.id);
      // Unknown sex keeps the reviewed wording.
      expect(ar.milestone('other', m.id), ar.milestone('male', m.id));
    }
  });

  test('English is the same whatever the sex', () {
    for (final key in signs) {
      expect(en.warnSign('female', key), en.warnSign('male', key));
    }
    for (final m in cdcMilestones) {
      expect(en.milestone('female', m.id), en.milestone('other', m.id));
    }
  });

  test(
    "Home, dose counts and the milestones intro follow sex (e2e #10, #11)",
    () {
      expect(ar.homeNeedsAttentionOne('female'), 'محتاجة انتباهك');
      expect(ar.homeNeedsAttentionOne('male'), 'محتاج انتباهك');
      // جرعة is feminine: the dual agrees with it, not with the child.
      expect(ar.vaccineOverdueCount(2), 'جرعتين متأخرتين');
      expect(ar.vaccineMissingCount(2), 'جرعتين ناقصتين');
      expect(ar.vaccineMissingDosesTitle(2), 'جرعتين تطعيم ناقصتين');
      expect(
        ar.devIntro('female', 'female'),
        'علّمي على اللي بنتك بتعمله، واختاري اليوم اللي لاحظتيه فيه أول مرة.',
      );
      expect(
        ar.devIntro('male', 'male'),
        'علّم على اللي ابنك بيعمله، واختار اليوم اللي لاحظته فيه أول مرة.',
      );
      expect(ar.devIntro('female', 'male'), contains('ابنك بيعمله'));
      expect(ar.devIntro('male', 'female'), startsWith('علّم على اللي بنتك'));
      // No milestone addresses the reader as a man any more at 18 months.
      expect(
        ar.milestone('female', 'm18_cognitive'),
        'بتقلد شغل البيت اللي بتعملوه، زي الكنس',
      );
      expect(
        ar.milestone('male', 'm18_cognitive'),
        'بيقلد شغل البيت اللي بتعملوه، زي الكنس',
      );
      expect(en.homeNeedsAttentionOne('female'), 'needs your attention');
    },
  );
}
