// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'أسرة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navFamily => 'العيلة';

  @override
  String get navSettings => 'المزيد';

  @override
  String get homeGreeting => 'أهلاً! أنا دكتور أسرة';

  @override
  String get homeIntro =>
      'صحة عيلتك في مكان واحد آمن. كل حاجة بتفضل على موبايلك.';

  @override
  String get homeColorGuide => 'معنى الألوان';

  @override
  String get severityInfo => 'معلومة';

  @override
  String get severityGood => 'تمام';

  @override
  String get severityHeadsUp => 'قريباً';

  @override
  String get severityActSoon => 'محتاج تتصرف';

  @override
  String get severityUrgent => 'عاجل';

  @override
  String get familyTitle => 'عيلتنا';

  @override
  String get familyEmpty => 'ضيف اللي بتهتم بيهم: الأطفال، الأهل، الجد والجدة.';

  @override
  String get familyAdd => 'ضيف شخص';

  @override
  String get familyNameLabel => 'الاسم';

  @override
  String get familySave => 'حفظ';

  @override
  String get familyCancel => 'إلغاء';

  @override
  String get settingsTitle => 'المزيد';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsPrivacy => 'بياناتك بتفضل على الموبايل ده ومتشفرة.';

  @override
  String get recoveryNotice =>
      'مقدرناش نفتح سجلاتك القديمة على الموبايل ده، فحفظناها على جنب بأمان وبدأنا من جديد. تقدر ترجعها من النسخة الاحتياطية في المزيد.';

  @override
  String get notMedicalDevice =>
      'أسرة مش جهاز طبي. اسأل دكتورك دايماً قبل أي قرار طبي.';
}
