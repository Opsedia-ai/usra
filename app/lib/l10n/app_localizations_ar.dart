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

  @override
  String get familyNew => 'شخص جديد';

  @override
  String get familyEdit => 'تعديل';

  @override
  String get profileBirthDate => 'تاريخ الميلاد';

  @override
  String get profileSex => 'النوع';

  @override
  String get sexFemale => 'أنثى';

  @override
  String get sexMale => 'ذكر';

  @override
  String get profileBloodType => 'فصيلة الدم';

  @override
  String get profileAllergies => 'حساسية';

  @override
  String get profileConditions => 'أمراض مزمنة';

  @override
  String get profileNotFound => 'مش موجود';

  @override
  String get pickDate => 'اختار تاريخ';

  @override
  String ageYears(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age سنة',
      few: '$age سنين',
      two: 'سنتين',
      one: 'سنة',
      zero: 'أقل من سنة',
    );
    return '$_temp0';
  }

  @override
  String get timelineEmpty => 'مفيش سجلات لسه. ضيف أول زيارة أو أشعة أو تطعيم.';

  @override
  String get addRecord => 'ضيف سجل';

  @override
  String get chooseRecordType => 'عايز تضيف إيه؟';

  @override
  String get recordDate => 'التاريخ';

  @override
  String get recordCost => 'التكلفة';

  @override
  String get currencyEgp => 'ج.م';

  @override
  String get fieldRequired => 'مطلوب';

  @override
  String get fieldInvalid => 'راجع القيمة دي';

  @override
  String get recordVisit => 'زيارة دكتور';

  @override
  String get recordScan => 'أشعة';

  @override
  String get recordLab => 'تحليل';

  @override
  String get recordVaccine => 'تطعيم';

  @override
  String get recordSurgery => 'عملية';

  @override
  String get fieldDoctorName => 'الدكتور';

  @override
  String get fieldReason => 'السبب';

  @override
  String get fieldDiagnosis => 'التشخيص';

  @override
  String get fieldNextVisit => 'الزيارة الجاية';

  @override
  String get fieldScanKind => 'نوع الأشعة';

  @override
  String get fieldCenter => 'مركز الأشعة';

  @override
  String get fieldResult => 'النتيجة';

  @override
  String get fieldTest => 'التحليل';

  @override
  String get fieldValue => 'القيمة';

  @override
  String get fieldUnit => 'الوحدة';

  @override
  String get fieldVaccine => 'التطعيم';

  @override
  String get fieldDose => 'رقم الجرعة';

  @override
  String get fieldNextDue => 'الجرعة الجاية';

  @override
  String get fieldProcedure => 'العملية';

  @override
  String get fieldHospital => 'المستشفى';

  @override
  String get fieldFilmed => 'اتصورت فيديو';

  @override
  String get fieldDaysInHospital => 'أيام في المستشفى';

  @override
  String get scanXray => 'أشعة عادية';

  @override
  String get scanCt => 'أشعة مقطعية';

  @override
  String get scanMri => 'رنين مغناطيسي';

  @override
  String get scanUltrasound => 'سونار';

  @override
  String get scanOther => 'تانية';

  @override
  String get saveFailed => 'حصلت مشكلة في الحفظ، جرّب تاني';

  @override
  String get navDoctors => 'الدكاترة';

  @override
  String get doctorsTitle => 'دكاترة العيلة';

  @override
  String get doctorsEmpty =>
      'لسه مفيش دكاترة. ضيف دكتور العيلة عشان تكلّمه بلمسة واحدة.';

  @override
  String get doctorsAdd => 'ضيف دكتور';

  @override
  String get doctorNew => 'دكتور جديد';

  @override
  String get doctorEdit => 'تعديل الدكتور';

  @override
  String get doctorName => 'اسم الدكتور';

  @override
  String get doctorSpecialty => 'التخصص';

  @override
  String get doctorPhone => 'رقم التليفون';

  @override
  String get doctorClinic => 'العيادة أو المستشفى';

  @override
  String get doctorAddress => 'العنوان';

  @override
  String get doctorFee => 'سعر الكشف';

  @override
  String get doctorNotes => 'ملاحظات';

  @override
  String get doctorCall => 'اتصل';

  @override
  String get doctorWhatsapp => 'واتساب';

  @override
  String get doctorDelete => 'امسح';

  @override
  String doctorDeleteConfirm(String name) {
    return 'نمسح $name من القائمة؟ الزيارات القديمة هتفضل زي ما هي.';
  }

  @override
  String get doctorVisits => 'الزيارات';

  @override
  String get doctorNoVisits => 'مفيش زيارات متسجلة مع الدكتور ده لسه.';

  @override
  String get doctorNotFound => 'الدكتور ده مش موجود';

  @override
  String get chooseDoctor => 'اختار من دكاترة العيلة';

  @override
  String get contactFailed => 'مقدرناش نفتح التطبيق ده على الموبايل';

  @override
  String get navMoney => 'الفلوس';

  @override
  String get spendingTitle => 'مصاريف العلاج';

  @override
  String get spendingWeek => 'أسبوع';

  @override
  String get spendingMonth => 'شهر';

  @override
  String get spendingYear => 'سنة';

  @override
  String get spendingWholeFamily => 'العيلة كلها';

  @override
  String get spendingPrevious => 'اللي قبله';

  @override
  String get spendingNext => 'اللي بعده';

  @override
  String get spendingByType => 'حسب النوع';

  @override
  String get spendingByPerson => 'حسب الشخص';

  @override
  String get spendingByDoctor => 'حسب الدكتور';

  @override
  String get spendingEmpty => 'مفيش مصاريف متسجلة في الفترة دي.';

  @override
  String get spendingRecent => 'آخر الفترات';

  @override
  String spendingRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجل',
      few: '$count سجلات',
      two: 'سجلين',
      one: 'سجل واحد',
    );
    return '$_temp0';
  }

  @override
  String get memberSpending => 'المصاريف';

  @override
  String get insuranceTitle => 'كروت التأمين';

  @override
  String get insuranceEmpty => 'مفيش كروت تأمين لسه.';

  @override
  String get insuranceAdd => 'ضيف كارت تأمين';

  @override
  String get insuranceNew => 'كارت تأمين جديد';

  @override
  String get insuranceEdit => 'تعديل الكارت';

  @override
  String get insuranceLabel => 'اسم الكارت (مثلاً: نقابة، شغل)';

  @override
  String get insuranceCard => 'الكارت';

  @override
  String get insuranceInsurer => 'شركة التأمين';

  @override
  String get insuranceMemberNumber => 'رقم العضوية';

  @override
  String get insuranceExpiry => 'تاريخ الانتهاء';

  @override
  String get insuranceNotes => 'ملاحظات';

  @override
  String get insuranceFront => 'وش الكارت';

  @override
  String get insuranceBack => 'ضهر الكارت';

  @override
  String get insuranceShare => 'ابعت على واتساب';

  @override
  String insuranceShareHeader(String name) {
    return 'كارت التأمين بتاع $name';
  }

  @override
  String insuranceExpired(String date) {
    return 'انتهى $date';
  }

  @override
  String insuranceExpiresSoon(String date) {
    return 'بينتهي $date';
  }

  @override
  String insuranceValidUntil(String date) {
    return 'ساري لحد $date';
  }

  @override
  String get insuranceDelete => 'امسح';

  @override
  String insuranceDeleteConfirm(String label) {
    return 'نمسح كارت $label؟ صوره هتتمسح من الموبايل.';
  }

  @override
  String get insuranceNotFound => 'الكارت ده مش موجود';

  @override
  String get clearDate => 'امسح التاريخ';

  @override
  String get photoCamera => 'صوّر';

  @override
  String get photoGallery => 'من الصور';

  @override
  String get photoRemove => 'شيل الصورة';

  @override
  String get photoFailed => 'مقدرناش نجيب الصورة';

  @override
  String get shareFailed => 'مقدرناش نفتح المشاركة';

  @override
  String get emergencyTitle => 'بطاقة الطوارئ';

  @override
  String get emergencyUnknown => 'مش متسجلة';

  @override
  String get emergencyNoneRecorded => 'مفيش حاجة متسجلة';

  @override
  String get emergencySurgeries => 'عمليات قبل كده';

  @override
  String get emergencyComplete => 'كمّل بيانات الطوارئ';

  @override
  String emergencyCallAmbulance(String number) {
    return 'اتصل بالإسعاف $number';
  }

  @override
  String get homeEmergencyTitle => 'بطاقات الطوارئ';

  @override
  String get homeEmergencyHint => 'افتحها بسرعة لو حد احتاج إسعاف';

  @override
  String get emergencyLoading => 'بنحمّل…';

  @override
  String get emergencyLoadFailed => 'مقدرناش نقرا السجلات';

  @override
  String get navCall => 'اتصال';

  @override
  String get settingsSimpleMode => 'الوضع البسيط';

  @override
  String get settingsSimpleModeHint =>
      'كلام وزراير أكبر وتابات أقل. مناسب للجدّ والجدّة لما يستخدموا الموبايل لوحدهم.';

  @override
  String get settingsTutorial => 'اعرض الشرح تاني';

  @override
  String get profileSimpleMode => 'بيستخدم الوضع البسيط';

  @override
  String get profileSimpleModeHint =>
      'صاحب الموبايل ده: الرئيسية هتسلّم عليه باسمه. شغّل الوضع البسيط من «المزيد» على موبايله.';

  @override
  String get simpleHello => 'أهلاً بيك!';

  @override
  String simpleHelloName(String name) {
    return 'أهلاً يا $name';
  }

  @override
  String get simpleMedicines => 'أدويتي';

  @override
  String get simpleMedicinesSoon => 'تذكير الأدوية جاي قريب.';

  @override
  String get comingSoon => 'قريبًا';

  @override
  String get simpleCallDoctor => 'كلّم دكتوري';

  @override
  String get simpleFamily => 'عيلتي';

  @override
  String get simpleEmergency => 'كارت الطوارئ';

  @override
  String get simplePickPerson => 'كارت الطوارئ بتاع مين؟';

  @override
  String get tutorialSkip => 'تخطّي';

  @override
  String get tutorialNext => 'التالي';

  @override
  String get tutorialBack => 'رجوع';

  @override
  String get tutorialStart => 'يلا نبدأ';

  @override
  String tutorialStep(int current, int total) {
    return '$current من $total';
  }

  @override
  String get tutorialWelcomeTitle => 'أهلاً، أنا دكتور أسرة';

  @override
  String get tutorialWelcomeBody =>
      'أسرة بتجمع صحة عيلتك في مكان واحد: زيارات الدكاترة والتحاليل والأدوية وأرقام الدكاترة.';

  @override
  String get tutorialPrivacyTitle => 'بياناتك معاك إنت';

  @override
  String get tutorialPrivacyBody =>
      'كل حاجة متسجّلة على الموبايل ده ومتشفّرة. مش محتاج حساب.';

  @override
  String get tutorialFamilyTitle => 'ضيف عيلتك';

  @override
  String get tutorialFamilyBody =>
      'ضيف كل اللي بتهتم بيهم: الأولاد والأهل والجدود. كل واحد ليه صفحته.';

  @override
  String get tutorialColorsTitle => 'الألوان معناها الأهمية';

  @override
  String get tutorialColorsBody => 'كل لون معاه كلمة، فتعرف على طول معناه إيه.';

  @override
  String get tutorialEmergencyTitle => 'كارت طوارئ لكل واحد';

  @override
  String get tutorialEmergencyBody =>
      'فصيلة الدم والحساسية والأمراض في كارت واحد، على بُعد دوسة من الرئيسية. وريه للدكتور أو للإسعاف.';

  @override
  String get tutorialElderWelcomeBody =>
      'أنا هنا عشان أساعدك. كل حاجة على الشاشة كبيرة وواضحة.';

  @override
  String get tutorialElderButtonsTitle => 'زراير كبيرة في الرئيسية';

  @override
  String get tutorialElderButtonsBody =>
      'دوس على «كلّم دكتوري» عشان تكلّم الدكتور بدوسة واحدة.';

  @override
  String get tutorialElderEmergencyTitle => 'لو تعبت';

  @override
  String get tutorialElderEmergencyBody =>
      'دوس على الزرار الأحمر «كارت الطوارئ» ووريه للي بيساعدك.';
}
