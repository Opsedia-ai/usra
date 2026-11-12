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
  String get recoveryNotice =>
      'مقدرناش نفتح سجلاتك القديمة على الموبايل ده، فحفظناها على جنب بأمان وبدأنا من جديد. تقدر ترجعها من النسخة الاحتياطية في المزيد.';

  @override
  String get notMedicalDevice =>
      'أسرة مش جهاز طبي. اسأل دكتورك دايماً قبل أي قرار طبي.';

  @override
  String get aboutTitle => 'الخصوصية والشروط';

  @override
  String get aboutHint => 'البيانات بتتحفظ إزاي، ونسخة التطبيق';

  @override
  String get aboutPrivacyHeading => 'خصوصيتك، بكلام بسيط';

  @override
  String get aboutPrivacyOnPhone =>
      'كل اللي بتسجله بيفضل على الموبايل ده. السجلات في قاعدة بيانات متشفرة، والصور في المساحة الخاصة بالتطبيق، عمرها ما بتروح معرض الصور ولا النسخ الاحتياطية على السحابة. إحنا مش بنستلم أي حاجة منهم ومنقدرش نشوفها.';

  @override
  String get aboutPrivacyNoAccount =>
      'مفيش حساب ولا تسجيل دخول ولا إعلانات ولا تتبع. وعمرنا ما بنبيع ولا بنشارك بيانات حد.';

  @override
  String get aboutPrivacyOptionalAccount =>
      'حفظ السجلات محتاج تسجيل دخول، ومفيش إعلانات ولا تتبع. بنحتفظ بإيميلك ورقم تعريف للحساب ومعاهم اللغة ومعلومات الجهاز علشان الحساب يشتغل، وكمان اسمك ولينك صورة حسابك لو الدخول بـ Google. ومش بنستلم سجلاتك الصحية. وعمرنا ما بنبيع ولا بنشارك بيانات حد.';

  @override
  String get aboutPrivacyBackup =>
      'النسخة الاحتياطية ملف متشفر إنت بتحتفظ بيه في المكان اللي تختاره. ميتفتحش غير بمفتاح الاسترجاع بتاعك، وهو مش معانا.';

  @override
  String get aboutPrivacyPhotos =>
      'الكاميرا والصور بتتستخدم بس لما إنت تختار، والكلام بيتقرا منها على الموبايل ده.';

  @override
  String get aboutPrivacyReminders =>
      'التذكير بيتظبط على الموبايل ده. من الأول بيظهر فيه كلام عام من غير أسامي. ولو \"تنبيهات من غير أسامي\" اتقفلت، أسامي الأشخاص وأسامي الأدوية ممكن تظهر على شاشة القفل. الويدجت مفيهوش أسامي، مواعيد وعدد جرعات بس.';

  @override
  String get aboutPrivacyDelete =>
      'تقدر تمسح كل حاجة أسرة شايلاها على الموبايل ده في أي وقت: المزيد › امسح كل بياناتي.';

  @override
  String get aboutPrivacyGoogle =>
      'قارئ الكلام من جوجل، وممكن يبعت لجوجل بيانات تقنية برقم تثبيت عشوائي مش مربوط بيك. عمره ما بيبعت صورك ولا الكلام ولا سجلاتك.';

  @override
  String get aboutMedicalHeading => 'تنبيه طبي';

  @override
  String get aboutMedicalBody =>
      'أسرة مش جهاز طبي. مش بتشخّص ولا بتعالج، ومش بديل عن دكتورك. منحنيات النمو ومواعيد التطعيمات والاقتراحات والكلام اللي بيتقرا من الصور للتنظيم والمعرفة العامة، وممكن تكون غلط. اسأل دكتورك أو الصيدلي دايماً قبل أي قرار طبي. وفي الطوارئ كلّم الإسعاف ١٢٣ في مصر أو رقم الطوارئ في بلدك.';

  @override
  String aboutVersion(String version) {
    return 'النسخة $version';
  }

  @override
  String get aboutPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get aboutTerms => 'شروط الاستخدام';

  @override
  String get aboutLinkFailed => 'مقدرناش نفتح الصفحة. اتأكد من النت.';

  @override
  String get familyNew => 'فرد جديد';

  @override
  String get familyEdit => 'تعديل';

  @override
  String get profileBirthDate => 'تاريخ الميلاد';

  @override
  String get profileSex => 'النوع';

  @override
  String get profileRelationship => 'صلة القرابة';

  @override
  String relationshipMine(String relationship) {
    String _temp0 = intl.Intl.selectLogic(relationship, {
      'son': 'ابني',
      'daughter': 'بنتي',
      'husband': 'جوزي',
      'wife': 'مراتي',
      'father': 'بابا',
      'mother': 'ماما',
      'brother': 'أخويا',
      'sister': 'أختي',
      'grandfather': 'جدو',
      'grandmother': 'تيتة',
      'other': 'حد تاني',
    });
    return '$_temp0';
  }

  @override
  String relationshipYours(String relationship) {
    String _temp0 = intl.Intl.selectLogic(relationship, {
      'son': 'ابنك',
      'daughter': 'بنتك',
      'husband': 'جوزك',
      'wife': 'مراتك',
      'father': 'باباك',
      'mother': 'مامتك',
      'brother': 'أخوك',
      'sister': 'أختك',
      'grandfather': 'جدك',
      'grandmother': 'تيتتك',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get profileEmergencyPhone => 'رقم للطوارئ';

  @override
  String get profileEmergencyPhoneHint =>
      'اختياري. بيظهر في كارت الطوارئ، وعلى قفل أسرة لو الكارت متاح هناك.';

  @override
  String get profileEmergencyInvalid => 'ده مش رقم تليفون.';

  @override
  String get profileEmergencyName => 'صاحب الرقم';

  @override
  String get profileEmergencyNameHint => 'اختياري. مثلًا: آية، مامته.';

  @override
  String get emergencyContactNoName => 'رقم للطوارئ';

  @override
  String emergencyCallNumber(String phone) {
    return 'اتصل برقم الطوارئ: $phone';
  }

  @override
  String emergencyCallContact(String name, String phone) {
    return 'اتصل بـ $name: $phone';
  }

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
    final intl.NumberFormat ageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String ageString = ageNumberFormat.format(age);

    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$ageString سنة',
      few: '$ageString سنين',
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
  String get recordLab => 'تحاليل';

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
  String recordPdf(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'ملف PDF $numberString';
  }

  @override
  String get fieldLab => 'المعمل';

  @override
  String get fieldOrderedBy => 'الدكتور اللي طلبها (اختياري)';

  @override
  String get fieldTests => 'التحاليل';

  @override
  String get labResultsTitle => 'النتايج';

  @override
  String labTestNumber(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'تحليل $numberString';
  }

  @override
  String get labTestName => 'اسم التحليل';

  @override
  String get labTestValue => 'النتيجة';

  @override
  String get labTestUnit => 'الوحدة';

  @override
  String get labTestRange => 'المعدل المكتوب في ورقة المعمل';

  @override
  String get labTestRangeHint => 'مثلاً 4 - 11 أو < 200';

  @override
  String get labAddTest => 'زوّد تحليل';

  @override
  String get labRemoveTest => 'شيل التحليل ده';

  @override
  String get labNeedOneTest => 'اكتب تحليل واحد على الأقل بنتيجته';

  @override
  String get labFlagHigh => 'أعلى من معدل المعمل';

  @override
  String get labFlagLow => 'أقل من معدل المعمل';

  @override
  String get labFlagNormal => 'في حدود معدل المعمل';

  @override
  String get labFlagUnknown => 'مفيش معدل نقارن بيه';

  @override
  String get labInfoNote =>
      'المقارنة بالمعدل المكتوب في ورقة المعمل بس. ده مش تشخيص: اسأل دكتورك النتايج دي معناها إيه بالنسبة لك.';

  @override
  String get labScanTitle => 'اقرا الورقة من صورة';

  @override
  String get labScanCamera => 'صوّر الورقة';

  @override
  String get labScanGallery => 'من المعرض';

  @override
  String get labScanHelp =>
      'الموبايل بيقرا النتايج المطبوعة بالإنجليزي بنفسه، ومفيش حاجة بتتبعت لأي حتة. الصورة بتتحفظ متشفرة مع التقرير. راجع كل رقم على الورقة قبل ما تحفظ.';

  @override
  String get labScanReading => 'بنقرا الورقة…';

  @override
  String labScanFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'لقينا $countString نتيجة. الخانات المعلّمة الموبايل مكانش متأكد منها: راجعها على الورقة.';
  }

  @override
  String get labScanNothing =>
      'ملقيناش نتايج في الصورة دي. اكتبها بإيدك، والصورة هتتحفظ مع التقرير.';

  @override
  String get labScanFailed => 'مقدرناش نقرا الصورة';

  @override
  String labScanSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString تحاليل كانوا موجودين، فقراءتهم الجديدة متضافتش.',
      one: 'تحليل كان موجود، فقراءته الجديدة متضافتش.',
    );
    return '$_temp0';
  }

  @override
  String labScanReplace(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استخدم القراءات الجديدة ($countString)',
      one: 'استخدم القراءة الجديدة',
    );
    return '$_temp0';
  }

  @override
  String get labScanNothingNew =>
      'مفيش جديد في الصورة دي: نتايجها موجودة هنا خلاص.';

  @override
  String get labCheckThis => 'راجع دي على الورقة';

  @override
  String get labConfirmRow => 'مطابق للورقة';

  @override
  String get labConfirmFirstCheck => 'راجع الخانات المعلّمة الأول';

  @override
  String get labConfirmNeeded =>
      'قبل ما تحفظ، أكّد كل سطر اتقرا من الصورة، وراجع كل خانة معلّمة، على الورقة.';

  @override
  String get labCheckedIt => 'راجعتها';

  @override
  String get labPickRange => 'فيه أكتر من معدل مكتوب: اختار اللي ينطبق';

  @override
  String get labScanPhoto => 'صورة الورقة';

  @override
  String get labPhotoFullScreen => 'ملء الشاشة';

  @override
  String get labAttachPdf => 'ضيف ملف PDF';

  @override
  String get labRemovePdf => 'شيل الملف';

  @override
  String labRangeLine(String range) {
    return 'معدل المعمل: $range';
  }

  @override
  String labLatest(String value, String date) {
    return 'آخر نتيجة: $value يوم $date';
  }

  @override
  String get labNoResults => 'لسه مفيش نتايج تحاليل بأرقام.';

  @override
  String get labUnitsApart =>
      'النتايج بوحدات مختلفة بتظهر لوحدها، ومن غير تحويل.';

  @override
  String get labAllResults => 'كل النتايج';

  @override
  String get labAddReport => 'ضيف نتيجة تحاليل';

  @override
  String get memberLabs => 'التحاليل';

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
  String get fieldFilmed => 'اتصورت فيديو؟';

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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString سجل',
      few: '$countString سجلات',
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
  String get emergencyTitle => 'كارت الطوارئ';

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
  String get recordGrowth => 'قياس نمو';

  @override
  String get fieldWeightKg => 'الوزن (كجم)';

  @override
  String get fieldHeightCm => 'الطول (سم)';

  @override
  String get fieldHeadCm => 'محيط الراس (سم)';

  @override
  String get memberGrowth => 'النمو والتطعيمات';

  @override
  String get growthTitle => 'النمو والتطعيمات';

  @override
  String get growthAdd => 'ضيف قياس';

  @override
  String get growthWeightForAge => 'الوزن حسب السن';

  @override
  String get growthHeightForAge => 'الطول حسب السن';

  @override
  String get growthAgeAxis => 'السن (بالشهور)';

  @override
  String get growthNoSex =>
      'ضيف نوع الطفل (ولد ولا بنت) في بياناته عشان تشوف منحنيات النمو.';

  @override
  String get growthNoData => 'مفيش قياسات لسه.';

  @override
  String growthLatest(String value, String date) {
    return 'آخر قياس: $value يوم $date';
  }

  @override
  String growthWithinRange(String percentile) {
    return 'جوه المعدل المرجعي للسن ده (المئين $percentile).';
  }

  @override
  String growthOutsideRange(String percentile) {
    return 'المئين $percentile: برّه المدى المعتاد. اتكلم مع دكتور الأطفال.';
  }

  @override
  String get growthSource =>
      'المنحنيات من معايير نمو الطفل بتاعة منظمة الصحة العالمية (المئين ٣ و١٥ و٥٠ و٨٥ و٩٧). للمعلومة بس؛ دكتور الأطفال هو اللي يقيّم نمو طفلك.';

  @override
  String get vaccinesTitle => 'التطعيمات';

  @override
  String vaccinesDisclaimer(String date) {
    return 'التطعيمات الإجبارية حسب جدول وزارة الصحة والسكان المصرية، والاختيارية حسب الجداول المعتادة عند دكاترة الأطفال (اتراجعت $date). للمعلومة بس: الجداول بتتغير، وكارت التطعيم بتاع مكتب الصحة ودكتور الطفل هما المرجع.';
  }

  @override
  String get vaccineAtBirth => 'عند الولادة';

  @override
  String vaccineAtMonths(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'عند $monthsString شهر',
      few: 'عند $monthsString شهور',
      two: 'عند شهرين',
      one: 'عند شهر',
    );
    return '$_temp0';
  }

  @override
  String vaccineDone(String date) {
    return 'اتاخدت $date';
  }

  @override
  String vaccineDue(String date) {
    return 'ميعادها $date';
  }

  @override
  String vaccineOverdue(String date) {
    return 'متأخرة من $date';
  }

  @override
  String vaccineLater(String date) {
    return 'يوم $date';
  }

  @override
  String vaccineDoseName(String name, int dose) {
    final intl.NumberFormat doseNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doseString = doseNumberFormat.format(dose);

    return '$name، جرعة $doseString';
  }

  @override
  String get vaccineHepB => 'الالتهاب الكبدي ب';

  @override
  String get vaccineBcg => 'الدرن (BCG)';

  @override
  String get vaccineOpv => 'شلل الأطفال بالفم (نقط)';

  @override
  String get vaccineIpv => 'شلل الأطفال بالحقن (سولك)';

  @override
  String get vaccinePenta => 'الخماسي';

  @override
  String get vaccineMmr => 'الثلاثي الفيروسي (MMR)';

  @override
  String get vaccineDtp => 'الثلاثي البكتيري (منشّط)';

  @override
  String vaccineZeroDose(String name) {
    return '$name، الجرعة الصفرية';
  }

  @override
  String get growthUnderFiveOnly =>
      'منحنيات النمو وجدول التطعيمات للأطفال أقل من ٥ سنين اللي تاريخ ميلادهم متسجل.';

  @override
  String get recordPhotos => 'صور';

  @override
  String recordPhotoCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString صورة',
      few: '$countString صور',
      two: 'صورتين',
      one: 'صورة',
    );
    return '$_temp0';
  }

  @override
  String get recordNotFound => 'السجل ده اتمسح';

  @override
  String get recordShare => 'ابعت';

  @override
  String get recordDelete => 'مسح';

  @override
  String get recordClearDate => 'شيل التاريخ';

  @override
  String get recordDeleteConfirm => 'نمسح السجل ده؟ صوره هتتمسح من الموبايل.';

  @override
  String get photoShare => 'ابعت الصورة';

  @override
  String get photoDelete => 'امسح الصورة';

  @override
  String get photoDeleteConfirm => 'نمسح الصورة دي من السجل؟';

  @override
  String photoPosition(int index, int total) {
    final intl.NumberFormat indexNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'صورة $indexString من $totalString';
  }

  @override
  String get fieldYes => 'أيوه';

  @override
  String get fieldNo => 'لأ';

  @override
  String get navCall => 'اتصال';

  @override
  String get drUsraWelcome => 'دكتور أسرة بيسلّم عليك';

  @override
  String get drUsraExplaining => 'دكتور أسرة بيشرح';

  @override
  String get drUsraEmptyState => 'دكتور أسرة ماسك علامة زائد';

  @override
  String get drUsraCelebrating => 'دكتور أسرة فرحان';

  @override
  String get drUsraResting => 'دكتور أسرة بيرتاح';

  @override
  String get settingsTheme => 'شكل التطبيق';

  @override
  String get settingsThemeSystem => 'زي الموبايل';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'غامق';

  @override
  String get settingsSimpleMode => 'الوضع البسيط';

  @override
  String get settingsSimpleModeHint =>
      'كلام وزراير أكبر وتابات أقل. مناسب للجدّ والجدّة لما يستخدموا الموبايل لوحدهم.';

  @override
  String get settingsAiTitle => 'دكتور أسرة الذكي';

  @override
  String get settingsAiSoon => 'قريب';

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
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString من $totalString';
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
      'كل حاجة متسجّلة على الموبايل ده ومتشفّرة، من غير حساب.';

  @override
  String get tutorialPrivacyBodyAccount =>
      'السجلات متسجّلة على الموبايل ده ومتشفّرة، والحساب مش بيشيلها.';

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

  @override
  String get scanMedicineTitle => 'صوّر علبة الدوا';

  @override
  String get scanMedicineIntro =>
      'صوّر وش العلبة صورة واضحة في نور كويس. أسرة بتقرا الاسم والتركيز المكتوبين بالحروف الإنجليزي.';

  @override
  String get scanMedicineLimits =>
      'الروشتة المكتوبة بخط الإيد والكلام العربي لسه مش بيتقروا على الموبايل. اكتبهم بنفسك.';

  @override
  String get scanMedicinePrivacy => 'الصورة بتتقرا على الموبايل ده ومش بتتحفظ.';

  @override
  String get scanMedicineReading => 'بنقرا العلبة…';

  @override
  String get scanMedicineSuggestions => 'هو واحد من دول؟';

  @override
  String get scanMedicineNoneFound =>
      'ملقيناش اسم دوا. اكتبه بنفسك، أو جرّب صورة تانية.';

  @override
  String get scanMedicineFailed =>
      'مقدرناش نقرا الصورة دي. جرّب صورة تانية، أو اكتب الاسم بنفسك.';

  @override
  String get scanMedicineName => 'اسم الدوا';

  @override
  String get scanMedicineStrength => 'التركيز (اختياري)';

  @override
  String get scanMedicineCheck => 'راجع الاسم على العلبة قبل ما تستخدمه.';

  @override
  String get scanMedicineUse => 'استخدم ده';

  @override
  String get scanMedicineRetake => 'صورة تانية';

  @override
  String get scanMedicinePhoto => 'صورة علبة الدوا';

  @override
  String get followUpsTitle => 'المتابعات';

  @override
  String get followUpsEmpty => 'مفيش متابعات قريبة.';

  @override
  String get followUpsDisclaimer =>
      'اقتراحات من إرشادات عامة (منظمة الصحة العالمية وUSPSTF وغيرهم) ومن سجلاتكم، مش تشخيص. اسأل الدكتور إيه المناسب لكل واحد.';

  @override
  String followUpDue(String date) {
    return 'معاده $date';
  }

  @override
  String followUpOverdue(String date) {
    return 'كان معاده $date';
  }

  @override
  String followUpSource(String source) {
    return 'المصدر: $source';
  }

  @override
  String followUpAdd(String type) {
    return 'سجّل $type';
  }

  @override
  String get followUpDismiss => 'خبّيها لحد المرة الجاية';

  @override
  String get followUpDismissed => 'اتخبّت لحد ما ميعادها ييجي تاني.';

  @override
  String get followUpUndo => 'رجّعها';

  @override
  String get fuNextVisit => 'زيارة متابعة';

  @override
  String fuNextVisitBy(String doctor) {
    return '$doctor حدد الميعاد ده في آخر زيارة';
  }

  @override
  String get fuNextVisitSet => 'اتحدد في آخر زيارة';

  @override
  String fuNextDose(String vaccine) {
    return 'الجرعة الجاية: $vaccine';
  }

  @override
  String get fuNextDoseSet => 'الميعاد المكتوب في آخر جرعة';

  @override
  String get fuHba1c => 'تحليل السكر التراكمي';

  @override
  String get fuLipids => 'تحليل دهون الدم (الكوليسترول)';

  @override
  String get fuKidney => 'وظائف الكلى والزلال في البول';

  @override
  String get fuScan => 'أشعة متابعة';

  @override
  String get fuScanResult => 'نتيجة آخر أشعة فيها متابعة';

  @override
  String get fuBloodPressure => 'قياس الضغط';

  @override
  String get fuBloodSugar => 'تحليل السكر';

  @override
  String get fuMammogram => 'ماموجرام (فحص الثدي)';

  @override
  String get fuColorectal => 'فحص القولون';

  @override
  String get fuEyeExam => 'كشف عيون (قاع العين)';

  @override
  String get fuDental => 'كشف أسنان';

  @override
  String get fuChildCheckup => 'كشف متابعة للطفل';

  @override
  String fuChildCheckupAt(String age) {
    return 'الكشف المعتاد في سن $age';
  }

  @override
  String fuAgeMonths(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$monthsString شهر',
      few: '$monthsString شهور',
      two: 'شهرين',
      one: 'شهر',
    );
    return '$_temp0';
  }

  @override
  String get fuVaccinesDue => 'التطعيمات';

  @override
  String fuVaccinesAt(String age, String names) {
    return '$age: $names';
  }

  @override
  String fuBecauseCondition(String sex, String condition) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'لأن عندها $condition',
      'other': 'لأن عنده $condition',
    });
    return '$_temp0';
  }

  @override
  String fuLastDoneMonths(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'آخر مرة من $monthsString شهر',
      few: 'آخر مرة من $monthsString شهور',
      two: 'آخر مرة من شهرين',
      one: 'آخر مرة من شهر',
      zero: 'آخر مرة الشهر ده',
    );
    return '$_temp0';
  }

  @override
  String get fuNeverRecorded => 'مفيش واحد متسجل لسه';

  @override
  String fuAgeFrom(int age) {
    final intl.NumberFormat ageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String ageString = ageNumberFormat.format(age);

    return 'مقترح من سن $ageString';
  }

  @override
  String fuAgeRange(int from, int to) {
    final intl.NumberFormat fromNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String fromString = fromNumberFormat.format(from);
    final intl.NumberFormat toNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String toString = toNumberFormat.format(to);

    return 'مقترح من سن $fromString لـ $toString';
  }

  @override
  String fuWomenAgeRange(int from, int to) {
    final intl.NumberFormat fromNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String fromString = fromNumberFormat.format(from);
    final intl.NumberFormat toNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String toString = toNumberFormat.format(to);

    return 'مقترح للستات من سن $fromString لـ $toString';
  }

  @override
  String get fuYearlyForAll => 'مقترح للكل مرة في السنة';

  @override
  String get conditionDiabetes => 'سكر';

  @override
  String get conditionHypertension => 'ضغط';

  @override
  String get conditionHeart => 'مرض في القلب';

  @override
  String get conditionHighCholesterol => 'كوليسترول عالي';

  @override
  String get conditionKidney => 'مرض في الكلى';

  @override
  String get navMedicines => 'الأدوية';

  @override
  String get medicinesTodayTitle => 'أدوية النهارده';

  @override
  String get medicinesTodayEmpty =>
      'مفيش أدوية النهارده. ضيف دوا من صفحة أي حد في العيلة.';

  @override
  String get doseTaken => 'اتاخد';

  @override
  String get doseSkip => 'ماتاخدش';

  @override
  String get doseSkipped => 'ماتاخدش';

  @override
  String get doseSnoozed => 'متأجل';

  @override
  String get doseSnooze => 'أجّل ١٠ دقايق';

  @override
  String get doseUndo => 'تراجع';

  @override
  String doseMarkedAt(String status, String time) {
    return '$status الساعة $time';
  }

  @override
  String doseReminderTitle(String person, String medicine) {
    return 'ميعاد دوا $person: $medicine';
  }

  @override
  String doseReminderBody(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'دوس اتاخد بعد ما تاخده',
      'other': 'دوس اتاخد بعد ما ياخده',
    });
    return '$_temp0';
  }

  @override
  String get doseChannelName => 'مواعيد الأدوية';

  @override
  String get doseChannelDescription => 'تنبيه في المواعيد اللي الدكتور كتبها';

  @override
  String get widgetEmpty => 'مفيش أدوية النهارده';

  @override
  String get widgetStale => 'افتح أسرة عشان نحدّث الأدوية';

  @override
  String get memberMedicines => 'الأدوية';

  @override
  String medicinesTitle(String name) {
    return 'أدوية $name';
  }

  @override
  String get medicinesEmpty =>
      'مفيش أدوية لسه. ضيف الدوا زي ما الدكتور كتبه بالظبط.';

  @override
  String get medicineAdd => 'ضيف دوا';

  @override
  String get medicineNew => 'دوا جديد';

  @override
  String get medicineEdit => 'تعديل الدوا';

  @override
  String get medicineMoveAction => 'نقل لشخص تاني';

  @override
  String get medicineMoveTitle => 'نقل الدوا';

  @override
  String medicineMoveNow(String name) {
    return 'دلوقتي عند $name';
  }

  @override
  String get medicineMoveTo => 'ينتقل لمين؟';

  @override
  String get medicineMoveWhatTitle => 'هينقل مع الدوا';

  @override
  String get medicineMoveWhat => 'المواعيد والتذكير والجرعات المسجلة والصور.';

  @override
  String medicineMoveStaysTitle(String name) {
    return 'هيفضل عند $name';
  }

  @override
  String get medicineMoveStaysPrescription =>
      'الروشتة، بتاريخها وصورها. الدوا هيتشال من قايمتها.';

  @override
  String get medicineMoveStaysSickDays =>
      'الجرعات المتسجلة في أيام التعب، باسم الدوا.';

  @override
  String get medicineMoveStopsNextDose =>
      'تذكير الجرعة الجاية في يوم التعب هيتوقف.';

  @override
  String medicineMoveReminder(String to, String from) {
    return 'بعد النقل التذكير هيبقى ل$to، مش ل$from.';
  }

  @override
  String get medicineMoveChoose => 'اختار الشخص الأول';

  @override
  String medicineMoveConfirm(String name) {
    return 'نقل ل$name';
  }

  @override
  String medicineMoveKeep(String name) {
    return 'يفضل عند $name';
  }

  @override
  String medicineMoveDone(String name) {
    return 'الدوا اتنقل ل$name.';
  }

  @override
  String get medicineName => 'اسم الدوا';

  @override
  String get medicineStrength => 'التركيز (زي ما على العلبة)';

  @override
  String get medicineForm => 'الشكل';

  @override
  String get formTablet => 'أقراص';

  @override
  String get formCapsule => 'كبسول';

  @override
  String get formSyrup => 'شراب';

  @override
  String get formDrops => 'نقط';

  @override
  String get formInjection => 'حقن';

  @override
  String get formCream => 'كريم';

  @override
  String get formInhaler => 'بخاخ';

  @override
  String get formOther => 'تاني';

  @override
  String get medicineInstructions => 'تعليمات الدكتور';

  @override
  String get medicineInstructionsHint => 'زي ما مكتوبة في الروشتة بالظبط';

  @override
  String get medicineDoctor => 'الدكتور اللي كتبه';

  @override
  String get medicineNoDoctor => 'مش محدد';

  @override
  String get medicineStart => 'أول يوم';

  @override
  String get medicineEnd => 'آخر يوم (اختياري)';

  @override
  String get medicineEndBeforeStart => 'آخر يوم قبل أول يوم';

  @override
  String get medicinePhotos => 'صور العلبة أو الروشتة';

  @override
  String get medicineSchedule => 'المواعيد';

  @override
  String get medicineAddTime => 'ضيف ميعاد';

  @override
  String medicineRemoveTime(String time) {
    return 'شيل $time';
  }

  @override
  String get medicineNoTimes => 'من غير مواعيد مفيش تنبيهات (عند اللزوم).';

  @override
  String get medicineAmount => 'الكمية كل مرة';

  @override
  String get medicineAmountHint => 'زي ما الدكتور كتب';

  @override
  String get medicineRepeat => 'كل قد إيه';

  @override
  String get repeatDaily => 'كل يوم';

  @override
  String get repeatWeekdays => 'أيام معينة';

  @override
  String get repeatEveryN => 'كل كام يوم';

  @override
  String get medicineEveryN => 'كل كام يوم';

  @override
  String get medicineEveryNInvalid => 'اكتب رقم من ٢ لـ ٦٠';

  @override
  String get medicineWeekdaysEmpty => 'اختار يوم واحد على الأقل';

  @override
  String get medicineStop => 'وقف الدوا';

  @override
  String get medicineResume => 'رجع ياخده';

  @override
  String get medicineStopped => 'متوقف';

  @override
  String get medicineEnded => 'خلص';

  @override
  String get medicineDelete => 'امسح';

  @override
  String medicineDeleteConfirm(String name) {
    return 'تمسح $name وسجله؟ الصور هتتمسح من الموبايل ده.';
  }

  @override
  String get medicineNotFound => 'الدوا ده اتمسح';

  @override
  String get medicineHistory => 'السجل';

  @override
  String get medicineHistoryEmpty => 'مفيش حاجة متسجلة لسه.';

  @override
  String get medicineAsNeeded => 'عند اللزوم، من غير تنبيهات';

  @override
  String medicineNextDose(String when) {
    return 'الجرعة الجاية: $when';
  }

  @override
  String medicineFromTo(String start, String end) {
    return 'من $start لـ $end';
  }

  @override
  String medicineFrom(String start) {
    return 'من $start';
  }

  @override
  String get scheduleEveryDay => 'كل يوم';

  @override
  String scheduleEveryNDays(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'كل $nString يوم',
      few: 'كل $nString أيام',
      two: 'كل يومين',
      one: 'كل يوم',
    );
    return '$_temp0';
  }

  @override
  String get reminderOffTitle => 'التنبيهات مقفولة';

  @override
  String get reminderOffBody =>
      'اسمح بالإشعارات علشان أسرة تفكرك بمواعيد الأدوية.';

  @override
  String get reminderExactOff =>
      'اسمح بـ\"المنبهات والتذكيرات\" علشان الجرعات ترن في ميعادها بالظبط مش متأخر.';

  @override
  String get reminderAllow => 'اسمح';

  @override
  String get reminderBatteryTitle => 'خلّي التنبيهات مضمونة';

  @override
  String get reminderBatteryBody =>
      'بعض الموبايلات بتوقف التطبيقات علشان توفر البطارية. خلّي استهلاك البطارية لأسرة \"غير مقيد\" علشان التنبيهات ترن دايماً.';

  @override
  String get reminderBatteryOpen => 'إعدادات البطارية';

  @override
  String get backupTitle => 'النسخة الاحتياطية';

  @override
  String get backupIntro =>
      'النسخة الاحتياطية ملف واحد متشفّر فيه كل سجلات العيلة وصورها، وبيتحفظ على Google Drive أو في الملفات أو على واتساب. فتحه على موبايل جديد محتاج مفتاح الاسترجاع.';

  @override
  String get backupNever => 'لسه مفيش نسخة احتياطية';

  @override
  String backupLast(String date) {
    return 'آخر نسخة احتياطية: $date';
  }

  @override
  String get backupNow => 'نسخة احتياطية دلوقتي';

  @override
  String get backupWorking => 'بنجهّز النسخة…';

  @override
  String get backupShareSubject => 'نسخة احتياطية من أسرة';

  @override
  String get backupDone => 'النسخة جاهزة. احفظها في مكان أمين برّه الموبايل.';

  @override
  String get backupFailed => 'مقدرناش نعمل النسخة. جرّب تاني.';

  @override
  String get backupDueTitle => 'اعمل نسخة احتياطية لسجلات العيلة';

  @override
  String get backupDueNever =>
      'لو الموبايل ضاع، السجلات هتضيع معاه. اعمل نسخة احتياطية متشفّرة واحفظها برّه الموبايل.';

  @override
  String get backupDueOld => 'آخر نسخة احتياطية عملتها من أكتر من ٣٠ يوم.';

  @override
  String get recoveryKeyTitle => 'مفتاح الاسترجاع';

  @override
  String get recoveryKeyIntro =>
      'ده مفتاح الاسترجاع. مكانه ورقة في مكان أمين بعيد عن الموبايل. فتح النسخ الاحتياطية على موبايل جديد محتاجه.';

  @override
  String get recoveryKeyShowIntro =>
      'ده المفتاح اللي بيفتح النسخ الاحتياطية. لازم يكون زي اللي مكتوب على الورقة.';

  @override
  String get recoveryKeyLoseWarning =>
      'من غير المفتاح ده محدش يقدر يفتح نسخك الاحتياطية، ولا حتى إحنا. ولو ضاع مش هنقدر نرجّعه.';

  @override
  String get recoveryKeyWrittenDown => 'اتكتب على الورقة';

  @override
  String get recoveryKeyConfirmIntro =>
      'علشان نتأكد إنه مكتوب صح: المجموعتين دول من الورقة.';

  @override
  String recoveryKeyGroupLabel(int number) {
    return 'المجموعة $number';
  }

  @override
  String get recoveryKeyConfirm => 'تأكيد';

  @override
  String get recoveryKeyShowAgain => 'عرض المفتاح تاني';

  @override
  String get recoveryKeyCopy => 'نسخ المفتاح';

  @override
  String get recoveryKeyCopied =>
      'اتنسخ. هيتمسح من الحافظة بعد دقيقة: الصقه في مدير كلمات السر دلوقتي.';

  @override
  String get shareWarningTitle => 'تبعته برّه أسرة؟';

  @override
  String get shareWarningBody =>
      'أول ما يتبعت، قفل أسرة وتشفيرها مش هيحموه: التطبيق التاني، وأي حد يشوف المحادثة أو الفولدر ده، يقدر يفتحه. اتأكد إنك اخترت الشخص الصح.';

  @override
  String get shareWarningDontAsk => 'متسألنيش تاني';

  @override
  String get shareWarningCancel => 'إلغاء';

  @override
  String get shareWarningGo => 'ابعت';

  @override
  String get rootWarningTitle => 'حماية الموبايل ده مش شغّالة';

  @override
  String get rootWarningBody =>
      'الموبايل ده شكله معمول له روت أو جيلبريك. تطبيقات تانية عليه ممكن تقرا ملفات أسرة وتشوف الشاشة، فسجلات عيلتك أقل أمان هنا.\n\nأسرة هتشتغل عادي. لو تقدر، استخدم موبايل مش متعدّل، وخلّي قفل التطبيق شغال.';

  @override
  String get rootWarningOk => 'فهمت';

  @override
  String get settingsDeleteAll => 'امسح كل بياناتي';

  @override
  String get settingsDeleteAllHint =>
      'امسح كل حاجة أسرة شايلاها على الموبايل ده';

  @override
  String get wipeTitle => 'امسح كل بياناتي';

  @override
  String get wipeIntro =>
      'ده بيمسح كل حاجة أسرة شايلاها على الموبايل ده ويبدأها من جديد:';

  @override
  String get wipeList =>
      '• كل الأشخاص والسجلات والأدوية والدكاترة وكروت التأمين\n• كل الصور\n• المفاتيح اللي قافلة عليهم، ومفتاح الاسترجاع المحفوظ على الموبايل ده، وقفل التطبيق\n• التذكيرات وويدجت الشاشة الرئيسية والإعدادات\n• هتخرج من حسابك (الحساب نفسه هيفضل؛ امسحه من الحساب الأول لو عايز)';

  @override
  String get wipeKeeps =>
      'ملفات النسخ الاحتياطية اللي حفظتها في مكان تاني (درايف، واتساب، الملفات) مش هتتلمس. لسه بتتفتح بمفتاح الاسترجاع، فتقدر ترجّع السجلات.';

  @override
  String get wipeNoUndo =>
      'ده مينفعش يترجع. من غير نسخة احتياطية ومفتاحها، السجلات هتروح خالص.';

  @override
  String get wipeBackupFirst => 'اعمل نسخة احتياطية الأول';

  @override
  String get wipeConfirmWord => 'امسح';

  @override
  String wipeTypeLabel(String word) {
    return 'اكتب $word للتأكيد';
  }

  @override
  String get wipeButton => 'امسح كل حاجة';

  @override
  String get wipeWorking => 'بيتمسح…';

  @override
  String get wipeReopenFailed =>
      'أسرة مقدرتش تفتح تاني بعد المسح. اقفلها وافتحها تاني.';

  @override
  String get databaseKeyUnavailable =>
      'أسرة مقدرتش تفتح مفتاح سجلاتك دلوقتي. سجلاتك لسه موجودة ومتمسحتش. جرّب تاني، أو اقفل الموبايل وافتحه. لو المشكلة فضلت، كلمنا قبل ما تمسح التطبيق.';

  @override
  String get databaseOpenFailed =>
      'أسرة مقدرتش تفتح سجلاتك دلوقتي. سجلاتك لسه موجودة ومتمسحتش. اتأكد إن الموبايل فيه مساحة فاضية، وبعدين جرّب تاني أو اقفل الموبايل وافتحه. لو المشكلة فضلت، كلمنا قبل ما تمسح التطبيق.';

  @override
  String get databaseSupportLabel => 'للمساعدة والدعم:';

  @override
  String get databaseSupportAddress => 'aya@opsedia.ai';

  @override
  String get databaseStartFresh => 'ابدأ من جديد';

  @override
  String get databaseStartFreshHint =>
      'آخر حل، لو مفيش نسخة احتياطية والمشكلة مش بتروح. ده بيمسح كل حاجة أسرة شايلاها على الموبايل ده.';

  @override
  String get databaseStartFreshIntro =>
      'سجلاتك مش بتتفتح، وممكن تكون لسه موجودة على الموبايل. لو عندك نسخة احتياطية، ارجع وجرّب استرجاعها الأول. لو كلّمتنا الأول ممكن نساعد.';

  @override
  String get recoveryKeyCopyFailed =>
      'مقدرناش ننسخ المفتاح. اكتبه من على الشاشة بدل كده.';

  @override
  String get wipeDoneNotice =>
      'كل حاجة أسرة كانت شايلاها على الموبايل ده اتمسحت.';

  @override
  String get wipeIncompleteNotice =>
      'شوية من بيانات أسرة مااتمسحوش. أسرة هتحاول تاني أول ما تفتح المرة الجاية.';

  @override
  String get lockSettingsWipe => 'امسح بعد ١٠ أرقام سرية غلط';

  @override
  String get lockSettingsWipeHint =>
      'بيمسح كل البيانات على الموبايل ده بعد ١٠ أرقام سرية غلط ورا بعض';

  @override
  String get lockWipeConfirmTitle => 'تمسح بعد ١٠ أرقام سرية غلط؟';

  @override
  String get lockWipeConfirmBody =>
      'بعد ١٠ أرقام سرية غلط ورا بعض، أسرة هتمسح كل حاجة شايلاها على الموبايل ده، ومفيش رجوع. طفل بيلعب بالموبايل ممكن يعملها.\n\nشغّلها بس لو عندك نسخة احتياطية جديدة ومفتاح استرجاعها.';

  @override
  String get lockWipeConfirmYes => 'شغّل';

  @override
  String get lockWipeCancel => 'إلغاء';

  @override
  String lockTriesBeforeWipe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString أرقام سرية غلط كمان تمسح كل حاجة',
      one: 'رقم سري غلط كمان واحد يمسح كل حاجة',
    );
    return '$_temp0';
  }

  @override
  String recoveryKeyMismatch(String groups) {
    return 'المجموعة $groups مش مطابقة. راجع الورقة.';
  }

  @override
  String get restoreTitle => 'استرجاع من نسخة احتياطية';

  @override
  String get restoreHint => 'كل اللي على الموبايل ده هيتبدل';

  @override
  String get recoveryKeyRowHint => 'مكتوب على الورقة';

  @override
  String get restoreKeyHelp => '٦ مجموعات، كل مجموعة ٦ أرقام.';

  @override
  String get restoreCancel => 'رجوع من غير تغيير';

  @override
  String get restoreIntro =>
      'ملف النسخة الاحتياطية بينتهي بـ ‎.usra‎ وبيبقى على Drive أو في الملفات أو واتساب. بعد الملف، مفتاح الاسترجاع.';

  @override
  String get restorePick => 'اختيار ملف النسخة';

  @override
  String get restoreKeyLabel => 'مفتاح الاسترجاع (٣٦ رقم)';

  @override
  String restoreKeyGroupsWrong(String groups) {
    return 'المجموعة $groups من المفتاح مش مظبوطة. راجعها على الورقة.';
  }

  @override
  String get restoreOpen => 'فتح النسخة';

  @override
  String get restoreNotABackup => 'الملف ده مش نسخة احتياطية من أسرة.';

  @override
  String get restoreWrongKey =>
      'المفتاح ده مش بيفتح النسخة دي. راجعه، أو جرّب المفتاح اللي كان معاك لما اتعملت النسخة.';

  @override
  String get restoreDamaged => 'ملف النسخة ناقص أو بايظ. جرّب تنزّله تاني.';

  @override
  String get restoreTooNew =>
      'النسخة دي معمولة بإصدار أحدث من أسرة. حدّث التطبيق وجرّب تاني.';

  @override
  String get restoreFailed => 'مقدرناش نفتح النسخة. جرّب تاني.';

  @override
  String restoreFrom(String date) {
    return 'نسخة من $date';
  }

  @override
  String restoreContents(int people, int records, int medicines, int photos) {
    final intl.NumberFormat peopleNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String peopleString = peopleNumberFormat.format(people);
    final intl.NumberFormat recordsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String recordsString = recordsNumberFormat.format(records);
    final intl.NumberFormat medicinesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String medicinesString = medicinesNumberFormat.format(medicines);
    final intl.NumberFormat photosNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String photosString = photosNumberFormat.format(photos);

    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$peopleString شخص',
      few: '$peopleString أشخاص',
      two: 'شخصين',
      one: 'شخص واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      records,
      locale: localeName,
      other: '$recordsString سجل',
      few: '$recordsString سجلات',
      two: 'سجلين',
      one: 'سجل واحد',
    );
    String _temp2 = intl.Intl.pluralLogic(
      medicines,
      locale: localeName,
      other: '$medicinesString دوا',
      few: '$medicinesString أدوية',
      two: 'دوايين',
      one: 'دوا واحد',
    );
    String _temp3 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photosString صورة',
      few: '$photosString صور',
      two: 'صورتين',
      one: 'صورة واحدة',
    );
    return '$_temp0، $_temp1، $_temp2، $_temp3';
  }

  @override
  String get restoreReplaceWarning =>
      'كل اللي على الموبايل ده دلوقتي هيتشال ويتحط مكانه اللي في النسخة دي.';

  @override
  String get restoreReplace => 'استرجاع واستبدال';

  @override
  String get restoreDoneNotice => 'رجّعنا نسختك الاحتياطية.';

  @override
  String get restoreFailedNotice =>
      'مقدرناش نرجّع النسخة، فسيبنا سجلاتك زي ما كانت.';

  @override
  String get backupSavedQuestion => 'حفظت النسخة أو بعتها في مكان؟';

  @override
  String get backupSavedYes => 'أيوه، حفظتها';

  @override
  String get backupSavedNo => 'لأ';

  @override
  String get memberPregnancy => 'الحمل';

  @override
  String get memberDevelopment => 'التطور والمهارات';

  @override
  String get memberBabyLog => 'يوم البيبي';

  @override
  String get recordPregnancy => 'حمل';

  @override
  String get recordPregnancyCheck => 'وزن وضغط';

  @override
  String get recordPregnancyEnd => 'نهاية الحمل';

  @override
  String get fieldLmp => 'أول يوم في آخر دورة';

  @override
  String get fieldDueDate => 'ميعاد الولادة (من الدكتور)';

  @override
  String get fieldSystolic => 'الضغط العالي';

  @override
  String get fieldDiastolic => 'الضغط الواطي';

  @override
  String get fieldOutcome => 'النتيجة';

  @override
  String get outcomeBirth => 'ولادة';

  @override
  String get outcomeLoss => 'إجهاض';

  @override
  String get outcomeOther => 'غير كده';

  @override
  String get pregnancyTitle => 'متابعة الحمل';

  @override
  String get pregnancyNotEligible =>
      'متابعة الحمل للستات. راجع النوع وتاريخ الميلاد في البيانات.';

  @override
  String get pregnancyStartIntro =>
      'تابعي أسابيع الحمل وميعاد الولادة والزيارات والتحاليل. ابدئي بأول يوم في آخر دورة، أو ميعاد الولادة اللي الدكتور قالهولك.';

  @override
  String get pregnancyStart => 'ابدئي متابعة الحمل';

  @override
  String pregnancyWeek(int weeks, int days) {
    final intl.NumberFormat weeksNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String weeksString = weeksNumberFormat.format(weeks);
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeksString أسبوع',
      few: '$weeksString أسابيع',
      two: 'أسبوعين',
      one: 'أسبوع',
      zero: 'أقل من أسبوع',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString يوم',
      few: '$daysString أيام',
      two: 'يومين',
      one: 'يوم',
      zero: '٠ يوم',
    );
    return '$_temp0 و$_temp1';
  }

  @override
  String pregnancyTrimester(int trimester) {
    String _temp0 = intl.Intl.pluralLogic(
      trimester,
      locale: localeName,
      other: 'التلت الأخير',
      two: 'التلت التاني',
      one: 'التلت الأول',
    );
    return '$_temp0';
  }

  @override
  String pregnancyDue(String date) {
    return 'الولادة $date';
  }

  @override
  String pregnancyDaysLeft(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'فاضل $daysString يوم على ميعاد الولادة',
      few: 'فاضل $daysString أيام على ميعاد الولادة',
      two: 'فاضل يومين على ميعاد الولادة',
      one: 'فاضل يوم على ميعاد الولادة',
      zero: 'ميعاد الولادة النهارده',
    );
    return '$_temp0';
  }

  @override
  String get pregnancyPastDue =>
      'ميعاد الولادة عدّى. خليكي على تواصل مع دكتورك، وسجّلي نهاية الحمل لما البيبي ييجي.';

  @override
  String get pregnancyAddCheck => 'سجّلي الوزن والضغط';

  @override
  String get pregnancyEnd => 'سجّلي نهاية الحمل';

  @override
  String get pregnancyScheduleTitle => 'الزيارات والسونار والتحاليل';

  @override
  String get pregnancyScheduleSource =>
      'الزيارات: توصيات منظمة الصحة العالمية لمتابعة الحمل (٢٠١٦)، ٨ زيارات على الأقل. السونار والتحاليل: اللي الدكاترة في مصر بيطلبوه عادةً. دكتورك ممكن يرتب غير كده، وكلامه هو اللي يتمشي عليه.';

  @override
  String get pregnancyDisclaimer => 'للمعلومة بس، ومش بديل عن متابعة دكتورك.';

  @override
  String ancContact(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'زيارة متابعة الحمل $numberString من ٨';
  }

  @override
  String ancContactReason(int week) {
    final intl.NumberFormat weekNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String weekString = weekNumberFormat.format(week);

    return 'حوالي الأسبوع $weekString من الحمل';
  }

  @override
  String ancWindow(int from, int to) {
    final intl.NumberFormat fromNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String fromString = fromNumberFormat.format(from);
    final intl.NumberFormat toNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String toString = toNumberFormat.format(to);

    return 'عادةً بين الأسبوع $fromString والأسبوع $toString من الحمل';
  }

  @override
  String get ancBookingLabs =>
      'تحاليل أول الحمل (صورة دم، فصيلة، بول، سكر، فيروسات كبد)';

  @override
  String get ancFirstScan => 'سونار التلت الأول';

  @override
  String get ancAnomalyScan => 'سونار التشوهات (السونار المفصّل)';

  @override
  String get ancGlucoseTest => 'تحليل سكر الحمل (منحنى السكر)';

  @override
  String get ancBloodCount => 'صورة دم (للأنيميا)';

  @override
  String get ancGrowthScan => 'سونار نمو الجنين';

  @override
  String get ancDone => 'اتعمل';

  @override
  String get ancMissed => 'مش متسجل';

  @override
  String get pregDangerTitle => 'روحي المستشفى فورًا لو حصل أي حاجة من دول';

  @override
  String pregDangerSign(String sign) {
    String _temp0 = intl.Intl.selectLogic(sign, {
      'bleeding': 'نزيف من المهبل',
      'headache': 'صداع جامد',
      'vision': 'زغللة في النظر',
      'fits': 'تشنجات أو إغماء',
      'pain': 'وجع جامد في البطن',
      'fever': 'سخونية',
      'water': 'نزول مية من المهبل',
      'movement': 'حركة البيبي قلّت عن العادي أو وقفت',
      'swelling': 'تورّم في الوش أو الإيدين',
      'breathing': 'صعوبة في التنفس',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get pregDangerSource =>
      'علامات الخطر من إرشادات منظمة الصحة العالمية ووزارة الصحة المصرية لصحة الأم.';

  @override
  String get pregnancyWeightTitle => 'الوزن';

  @override
  String get pregnancyBpTitle => 'الضغط';

  @override
  String get pregnancyNoReadings => 'مفيش قياسات لسه.';

  @override
  String get pregnancyWeekAxis => 'أسبوع الحمل';

  @override
  String get bpUsual => 'في المدى المعتاد';

  @override
  String get bpHigh => 'عالي: كلّمي دكتورك النهارده';

  @override
  String get bpVeryHigh => 'عالي جدًا: روحي المستشفى فورًا';

  @override
  String get pregnancyBpSource =>
      'الحدود من منظمة الصحة العالمية: ١٤٠/٩٠ وأكتر يعتبر عالي في الحمل، و١٦٠/١١٠ وأكتر عالي جدًا. قياس واحد مش تشخيص؛ اسألي دكتورك.';

  @override
  String get devTitle => 'مهارات الطفل وتطوره';

  @override
  String get devUnderSixOnly =>
      'قايمة المهارات للأطفال أقل من ٦ سنين اللي تاريخ ميلادهم متسجل.';

  @override
  String get devIntro =>
      'علّم على اللي طفلك بيعمله، واختار اليوم اللي لاحظته فيه أول مرة.';

  @override
  String devLateBanner(String age) {
    return 'فيه مهارات بتاعة سن $age لسه متعلّمش عليها. اتكلم مع دكتور الأطفال عنها، ومتستناش.';
  }

  @override
  String devByAge(String age) {
    return 'في سن $age';
  }

  @override
  String devTickedCount(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString من $totalString';
  }

  @override
  String devDone(String date) {
    return 'من $date';
  }

  @override
  String get devUpcoming => 'بعدين';

  @override
  String get devWatch => 'خلّي بالك منها';

  @override
  String get devLate => 'اتكلم مع دكتور الأطفال';

  @override
  String get devNotTicked => 'متعلّمش عليها';

  @override
  String get devWhenSeen => 'لاحظتها أول مرة إمتى؟';

  @override
  String get devAreaSocial => 'اجتماعي ومشاعر';

  @override
  String get devAreaLanguage => 'كلام وتواصل';

  @override
  String get devAreaCognitive => 'تفكير وتعلّم';

  @override
  String get devAreaMovement => 'حركة';

  @override
  String get devSource =>
      'من مهارات «Learn the Signs. Act Early.» بتاعة مراكز السيطرة على الأمراض الأمريكية (CDC) نسخة ٢٠٢٢، مختارات منها: حاجات أغلب الأطفال (٧٥٪) بيعملوها في كل سن. القوايم الكاملة على cdc.gov/actearly. للمعلومة بس؛ دكتور الأطفال هو اللي يقيّم تطور طفلك.';

  @override
  String get recordMilestone => 'مهارة';

  @override
  String milestone(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'm2_social': 'بيضحك لما تكلمه أو تضحكله',
      'm2_language': 'بيطلّع أصوات غير العياط',
      'm2_cognitive': 'بيتابعك بعينه وانت بتتحرك',
      'm2_movement': 'بيرفع راسه وهو نايم على بطنه',
      'm4_social': 'بيضحك من نفسه عشان يلفت انتباهك',
      'm4_language': 'بيناغي بأصوات زي «أووو» و«آآه»',
      'm4_cognitive': 'بيبص على إيديه باهتمام',
      'm4_movement': 'بيثبّت راسه لوحده وانت شايله',
      'm6_social': 'بيعرف الناس اللي متعود عليهم',
      'm6_language': 'بيرد عليك بأصوات لما تكلمه',
      'm6_cognitive': 'بيمد إيده يمسك اللعبة اللي عايزها',
      'm6_movement': 'بيتقلب من بطنه لضهره',
      'm9_social': 'بيبص لما تنده اسمه',
      'm9_language': 'بيقول أصوات زي «ماماما» و«بابابا»',
      'm9_cognitive': 'بيدور على الحاجة لما تقع من قدامه',
      'm9_movement': 'بيقعد من غير سند',
      'm12_social': 'بيلعب معاك ألعاب زي التسقيف',
      'm12_language': 'بيعمل «باي باي» بإيده',
      'm12_cognitive': 'بيدور على الحاجة اللي شافك بتخبيها',
      'm12_movement': 'بيسند على حاجة ويقف',
      'm15_social': 'بيوريك حاجة بيحبها',
      'm15_language': 'بيحاول يقول كلمة أو اتنين غير «ماما» و«بابا»',
      'm15_cognitive': 'بيرص حاجتين صغيرين على بعض على الأقل',
      'm15_movement': 'بيمشي كام خطوة لوحده',
      'm18_social': 'بيشاور عشان يوريك حاجة لفتت نظره',
      'm18_language': 'بيحاول يقول ٣ كلمات أو أكتر غير «ماما» و«بابا»',
      'm18_cognitive': 'بيقلدك وانت بتعمل شغل البيت، زي الكنس',
      'm18_movement': 'بيمشي من غير ما يسند على حد أو حاجة',
      'm24_social': 'بياخد باله لما حد يتعور أو يزعل',
      'm24_language': 'بيقول كلمتين مع بعض على الأقل، زي «عايز لبن»',
      'm24_cognitive': 'بيحاول يشغّل الزراير أو المفاتيح في اللعب',
      'm24_movement': 'بيشوط الكورة',
      'm30_social': 'بيلعب جنب الأطفال التانيين وساعات معاهم',
      'm30_language': 'بيقول حوالي ٥٠ كلمة',
      'm30_cognitive': 'بيلعب تمثيل، زي إنه يأكّل العروسة',
      'm30_movement': 'بينط من على الأرض برجليه الاتنين',
      'm36_social': 'بياخد باله من الأطفال التانيين ويلعب معاهم',
      'm36_language': 'بيتكلم معاك ويرد عليك مرتين على الأقل في نفس الكلام',
      'm36_cognitive': 'بيرسم دايرة لما توريه إزاي',
      'm36_movement': 'بيلبس شوية من هدومه لوحده',
      'm48_social': 'بيطبطب على اللي متعور أو زعلان',
      'm48_language': 'بيقول جمل فيها ٤ كلمات أو أكتر',
      'm48_cognitive': 'بيعرف يسمي كام لون',
      'm48_movement': 'بيمسك الكورة الكبيرة أغلب الوقت',
      'm60_social': 'بيلتزم بقواعد اللعب ويستنى دوره',
      'm60_language': 'بيحكي حكاية سمعها أو ألّفها فيها حدثين على الأقل',
      'm60_cognitive': 'بيعد لحد ١٠',
      'm60_movement': 'بينط على رجل واحدة',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get infantLogTitle => 'يوم البيبي';

  @override
  String get infantLogUnderOneOnly =>
      'سجل الرضعات والنوم والحفاضات للبيبي أقل من سنة اللي تاريخ ميلاده متسجل.';

  @override
  String get logBreast => 'رضاعة طبيعية';

  @override
  String get logBottle => 'ببرونة';

  @override
  String get logSolids => 'أكل';

  @override
  String get logSleep => 'نوم';

  @override
  String get logWet => 'حفاضة مبلولة';

  @override
  String get logDirty => 'حفاضة فيها براز';

  @override
  String get logBottleAmount => 'شرب قد إيه؟';

  @override
  String get logSleepHowLong => 'نام قد إيه؟';

  @override
  String get logSkip => 'مش عارف';

  @override
  String logMl(int ml) {
    final intl.NumberFormat mlNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String mlString = mlNumberFormat.format(ml);

    return '$mlString مل';
  }

  @override
  String logDuration(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString س $minutesString د',
      zero: '$minutesString دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get logSaved => 'اتسجل';

  @override
  String get logToday => 'النهارده';

  @override
  String get logYesterday => 'امبارح';

  @override
  String get logEmptyDay => 'مفيش حاجة متسجلة.';

  @override
  String logSummaryFeeds(int count, int breast, int bottle, int solids) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat breastNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String breastString = breastNumberFormat.format(breast);
    final intl.NumberFormat bottleNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bottleString = bottleNumberFormat.format(bottle);
    final intl.NumberFormat solidsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String solidsString = solidsNumberFormat.format(solids);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString رضعة',
      few: '$countString رضعات',
      two: 'رضعتين',
      one: 'رضعة واحدة',
    );
    return '$_temp0 (طبيعي $breastString، ببرونة $bottleString، أكل $solidsString)';
  }

  @override
  String logSummaryBottleMl(int ml) {
    final intl.NumberFormat mlNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String mlString = mlNumberFormat.format(ml);

    return '$mlString مل من الببرونة';
  }

  @override
  String logSummarySleep(String duration) {
    return 'النوم: $duration';
  }

  @override
  String logSummaryDiapers(int wet, int dirty) {
    final intl.NumberFormat wetNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String wetString = wetNumberFormat.format(wet);
    final intl.NumberFormat dirtyNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String dirtyString = dirtyNumberFormat.format(dirty);

    return 'الحفاضات: $wetString مبلولة، $dirtyString فيها براز';
  }

  @override
  String get logDelete => 'امسح';

  @override
  String get logDisclaimer =>
      'مذكرة ليك وللدكتور. لو قلقان من الرضاعة أو النوم أو الحفاضات، اسأل دكتور الأطفال.';

  @override
  String get recordFeed => 'رضعة';

  @override
  String get recordDiaper => 'حفاضة';

  @override
  String get fieldFeedKind => 'نوع الرضعة';

  @override
  String get fieldAmountMl => 'الكمية (مل)';

  @override
  String get fieldMinutes => 'الدقايق';

  @override
  String get fieldDiaperKind => 'نوع الحفاضة';

  @override
  String get diaperWet => 'مبلولة';

  @override
  String get diaperDirty => 'فيها براز';

  @override
  String get diaperBoth => 'مبلولة وفيها براز';

  @override
  String get growthCheckTitle => 'افحص دلوقتي';

  @override
  String growthCheckIntro(String age) {
    return 'اكتب الوزن أو الطول أو محيط الراس النهارده وشوف مكانه على منحنيات منظمة الصحة العالمية في سن $age.';
  }

  @override
  String get growthCheckSave => 'احفظه كقياس';

  @override
  String get devUntick => 'شيل العلامة';

  @override
  String get devUntickConfirm =>
      'تشيل العلامة من المهارة دي؟ التاريخ اللي سجلته هيتمسح.';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountSettingsHint => 'سجلاتك فاضلة على الموبايل ده';

  @override
  String get accountPrivacy =>
      'سجلات العيلة الصحية فاضلة على الموبايل ده. الحساب مش بيرفعها.';

  @override
  String get accountSignInIntro =>
      'تقدر تتفرج وتقرا الأدلة من غير حساب. حفظ السجلات وإضافة العيلة والنسخ الاحتياطي محتاجين تسجيل دخول.';

  @override
  String get accountSignInConsent =>
      'تسجيل الدخول معناه موافقة إننا نحتفظ بالبيانات دي علشان الحساب يشتغل، زي ما سياسة الخصوصية بتقول.';

  @override
  String get accountSignInData =>
      'Google بيبعتلنا اسمك وإيميلك ولينك صورة حسابك ورقم تعريف للحساب، وApple بتبعتلنا إيميلك (أو عنوان بديل لو الإيميل متخبي) ورقم تعريف للحساب. بنخزن ده مع اللغة ومعلومات الجهاز علشان الحساب يشتغل.';

  @override
  String get accountGateTitle => 'حفظ سجلاتك';

  @override
  String get accountGateBody =>
      'حفظ السجلات محتاج تسجيل دخول. اللي اتكتب بيفضل في الصفحة.';

  @override
  String get accountGateBackupBody => 'النسخة الاحتياطية محتاجة تسجيل دخول.';

  @override
  String get accountGateKeepsTitle => 'الحساب بيحتفظ بـ';

  @override
  String get accountGateRecordsStay =>
      'السجلات والصور بتفضل على موبايلك ومتشفرة.';

  @override
  String get accountReadPrivacy => 'عن الخصوصية';

  @override
  String get accountSignInWithGoogle => 'تسجيل الدخول باستخدام Google';

  @override
  String get accountSignInWithApple => 'تسجيل الدخول باستخدام Apple';

  @override
  String get accountSignInUnavailable =>
      'الدخول مش متاح في النسخة دي من التطبيق.';

  @override
  String get accountSignedIn => 'الدخول على الحساب شغّال';

  @override
  String get accountSignOut => 'خروج من الحساب';

  @override
  String get accountSignOutConfirm =>
      'خروج من الحساب؟ السجلات فاضلة على الموبايل.';

  @override
  String get accountDelete => 'مسح الحساب';

  @override
  String get accountDeleteConfirm =>
      'مسح الحساب؟ الحساب والأجهزة والرصيد هيتمسحوا من السيرفرات بتاعتنا. السجلات اللي على الموبايل ده هتفضل زي ما هي.';

  @override
  String get accountDeleteAppleNote =>
      'Apple هتطلب منك تأكيد كمان مرة علشان نلغي ربط حسابك بالتطبيق.';

  @override
  String get accountDeleted => 'الحساب اتمسح';

  @override
  String get accountErrorTooMany => 'محاولات كتير. استنى شوية وجرّب تاني';

  @override
  String get accountErrorNetwork => 'مفيش اتصال. اتأكد من النت وجرّب تاني';

  @override
  String get accountErrorGeneric => 'حصلت مشكلة. جرّب تاني';

  @override
  String get accountRetry => 'جرّب تاني';

  @override
  String get accountErrorSignInAgain => 'الدخول انتهى. ادخل تاني';

  @override
  String get accountErrorFamilyHasMembers =>
      'إنت عامل عيلة فيها ناس تانيين، ومسح الحساب هيمسح سجلاتهم المشتركة كمان، فمينفعش يتمسح دلوقتي.';

  @override
  String get lockTitle => 'أسرة مقفولة';

  @override
  String get lockEnterPin => 'اكتب الرقم السري';

  @override
  String get lockUseBiometrics => 'افتح ببصمة الصباع أو الوش';

  @override
  String get lockBiometricReason => 'افتح أسرة عشان تشوف سجلات عيلتك';

  @override
  String get lockWrongPin => 'الرقم السري غلط. جرّب تاني.';

  @override
  String lockWait(String time) {
    return 'محاولات غلط كتير. جرّب تاني بعد $time.';
  }

  @override
  String get lockForgot => 'نسيت الرقم السري؟';

  @override
  String get lockForgotTitle => 'لو نسيت الرقم السري';

  @override
  String get lockForgotBody =>
      'عشان سجلات عيلتك تفضل سر، مفيش حاجة تعدّي الرقم السري، ولا حتى إحنا.\n\nعشان تبدأ من جديد:\n١. امسح بيانات أسرة. على أندرويد: إعدادات الموبايل › التطبيقات › أسرة › التخزين › مسح البيانات. على الآيفون: امسح أسرة ونزّلها تاني. ده بيمسح كل حاجة أسرة شايلاها على الموبايل ده.\n٢. افتح أسرة ورجّع آخر نسخة احتياطية بمفتاح الاسترجاع («عندي نسخة احتياطية» في أول شاشة).\n\nمن غير نسخة احتياطية ومفتاحها، السجلات مش هترجع.';

  @override
  String get lockEmergency => 'معلومات الطوارئ';

  @override
  String get lockEmergencyPick => 'كارت طوارئ مين؟';

  @override
  String get lockEmergencyNone => 'لسه محدش اتضاف.';

  @override
  String get pinOk => 'تمام';

  @override
  String get pinDelete => 'امسح';

  @override
  String get pinLengthHint => '٦ أرقام';

  @override
  String pinEntered(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'اتكتب $countString من ٦ أرقام';
  }

  @override
  String get lockSetupNewPin => 'اختار رقم سري من ٦ أرقام';

  @override
  String get lockSetupConfirmPin => 'اكتب نفس الرقم السري تاني';

  @override
  String get lockSetupMismatch => 'الرقمين مختلفين. اختار تاني.';

  @override
  String get lockSetupCurrentPin => 'اكتب الرقم السري الحالي';

  @override
  String get lockSetupBiometricsTitle => 'تستخدم بصمة الصباع أو الوش كمان؟';

  @override
  String get lockSetupBiometricsBody =>
      'بتفتح أسرة أسرع، والرقم السري بيشتغل دايماً برضه. أي حد بصمته أو وشه متسجلين على الموبايل ده، حتى لو من العيلة، هيقدر يفتح أسرة. لو في حد تاني بيستخدم الموبايل، اختار مش دلوقتي.';

  @override
  String get lockSetupBiometricsYes => 'أيوه، استخدمها';

  @override
  String get lockSetupDone => 'قفل التطبيق اشتغل';

  @override
  String get lockSetupWriteDown =>
      'احفظ الرقم السري في مكان أمان. لو نسيته، الطريقة الوحيدة إنك تمسح بيانات أسرة وترجّع نسخة احتياطية.';

  @override
  String get lockOfferTitle => 'تقفل أسرة برقم سري؟';

  @override
  String get lockOfferBody =>
      'لو الموبايل ضاع أو حد تاني مسكه، سجلات عيلتك تفضل مقفولة. وتقدر تفتح ببصمة صباعك أو وشك كمان.';

  @override
  String get lockOfferYes => 'اعمل القفل';

  @override
  String get lockOfferSkip => 'مش دلوقتي';

  @override
  String get lockOfferLater => 'تقدر تشغّله في أي وقت من المزيد › قفل التطبيق.';

  @override
  String get settingsAppLock => 'قفل التطبيق';

  @override
  String get settingsAppLockOn => 'شغّال: لازم الرقم السري عشان تفتح أسرة';

  @override
  String get settingsAppLockOff =>
      'مش شغّال: أي حد معاه الموبايل يقدر يفتح أسرة';

  @override
  String get lockSettingsSwitch => 'اقفل برقم سري';

  @override
  String get lockSettingsChangePin => 'غيّر الرقم السري';

  @override
  String get lockSettingsBiometrics => 'بصمة الصباع أو الوش';

  @override
  String get lockSettingsBiometricsHint =>
      'أي حد بصمته أو وشه متسجلين على الموبايل ده يقدر يفتح أسرة، حتى لو من العيلة. لو في حد تاني بيستخدم الموبايل، سيبها مش شغّالة واستخدم الرقم السري بس.';

  @override
  String get lockSettingsTimeout => 'اقفل تاني بعد ما تخرج من أسرة بـ';

  @override
  String get lockTimeoutImmediately => 'على طول';

  @override
  String get lockTimeoutOneMinute => 'دقيقة';

  @override
  String get lockTimeoutFiveMinutes => '٥ دقايق';

  @override
  String get lockSettingsEmergency => 'كارت الطوارئ على قفل أسرة';

  @override
  String get lockSettingsEmergencyHint =>
      'فصيلة الدم والحساسية والأمراض والعمليات والأدوية الحالية ورقم الطوارئ وصاحبه للناس اللي هتختارهم هنا، أي حد ماسك الموبايل وأسرة مفتوحة يقدر يشوفها من غير الرقم السري. ده قفل أسرة، مش قفل الموبايل: للموبايل المقفول استخدم Medical ID بتاع الموبايل نفسه.';

  @override
  String get lockVerifyTitle => 'أكّد إنه إنت';

  @override
  String get lockOffDone => 'قفل التطبيق اتلغى';

  @override
  String get lockUnavailable =>
      'مقدرناش نقرا القفل دلوقتي. جرّب تاني كمان شوية.';

  @override
  String get lockSetupTrivial =>
      'الرقم ده سهل يتخمّن. ابعد عن الأرقام المتكررة أو اللي ورا بعض.';

  @override
  String get lockEmergencyFor => 'يظهر على قفل أسرة';

  @override
  String get lockBackupFirstTitle => 'لازم نسخة احتياطية الأول';

  @override
  String get lockBackupFirstBody =>
      'لو الرقم السري اتنسى، الطريقة الوحيدة هي مسح بيانات أسرة واسترجاع نسخة احتياطية بمفتاح الاسترجاع بتاعها. ولسه مفيش نسخة احتياطية، ومن غيرها السجلات بتضيع.\n\nأول ما النسخة الاحتياطية تتعمل، القفل يقدر يشتغل.';

  @override
  String get lockBackupFirstMake => 'اعمل نسخة احتياطية';

  @override
  String get lockNothingYetTitle => 'العيلة الأول';

  @override
  String get lockNothingYetBody =>
      'القفل محتاج نسخة احتياطية، ولسه مفيش حاجة تتحفظ. لما حد من العيلة يتضاف وتتعمل نسخة احتياطية، القفل يقدر يشتغل.';

  @override
  String get lockOnNoBackupBody =>
      'القفل شغال بس لسه مفيش نسخة احتياطية. لو الرقم السري اتنسى، السجلات هتضيع.';

  @override
  String backupDonePhotosSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString صورة مقدرناش نفتحهم على الموبايل ده ومش فيها',
      few: '$countString صور مقدرناش نفتحهم على الموبايل ده ومش فيها',
      two: 'صورتين مقدرناش نفتحهم على الموبايل ده ومش فيها',
      one: 'صورة واحدة مقدرناش نفتحها على الموبايل ده ومش فيها',
    );
    return 'النسخة جاهزة، بس $_temp0. احفظها في مكان أمين برّه الموبايل.';
  }

  @override
  String restorePhotosSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString صورة في النسخة دي مش هيتفتحوا وهيتسابوا.',
      few: '$countString صور في النسخة دي مش هيتفتحوا وهيتسابوا.',
      two: 'صورتين في النسخة دي مش هيتفتحوا وهيتسابوا.',
      one: 'صورة واحدة في النسخة دي مش هتتفتح وهتتساب.',
    );
    return '$_temp0';
  }

  @override
  String get photosLocked =>
      'الصور مش بتتفتح على الموبايل ده. رجّع نسختك الاحتياطية عشان ترجعلك.';

  @override
  String get doseReminderDiscreetTitle => 'ميعاد الدوا';

  @override
  String get widgetDoseDue => 'ميعاد جرعة';

  @override
  String widgetDoseCount(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits جرعة',
      few: '$digits جرعات',
      two: 'جرعتين',
    );
    return '$_temp0';
  }

  @override
  String get settingsDiscreet => 'تنبيهات من غير أسامي';

  @override
  String get settingsDiscreetHint =>
      'التنبيهات بتقول \"ميعاد الدوا\" بس، من غير اسم الشخص ولا اسم الدوا. لو كذا جرعة قريبين من بعض، افتح أسرة عشان تعلّم عليهم.';

  @override
  String get settingsBlockScreenshots => 'امنع تصوير الشاشة';

  @override
  String get settingsBlockScreenshotsHint =>
      'مفيش سكرين شوت ولا تسجيل للشاشة في التطبيق كله. مفتاح الاسترجاع محمي على طول. سيبها مش شغّالة لو عايز تصوّر كارت الطوارئ.';

  @override
  String get doseReminderDiscreetBody => 'افتح أسرة عشان تشوف أنهي دوا';

  @override
  String doseReminderDiscreetTimeBody(String time) {
    return 'جرعة $time';
  }

  @override
  String get doseReminderDiscreetSeveralBody =>
      'فيه أكتر من جرعة ميعادها دلوقتي. افتح أسرة عشان تشوف أنهي دوا';

  @override
  String get memberVaccines => 'التطعيمات';

  @override
  String get vaccineHexa => 'السداسي';

  @override
  String get vaccinePcv => 'المكورات الرئوية (PCV)';

  @override
  String get vaccineRota => 'الروتا';

  @override
  String get vaccineVaricella => 'الجديري المائي';

  @override
  String get vaccineHepA => 'الالتهاب الكبدي أ';

  @override
  String get vaccineMening => 'الحمى الشوكية (السحائي)';

  @override
  String get vaccineFlu => 'الإنفلونزا';

  @override
  String vaccineBoosterDose(String name) {
    return '$name، جرعة منشطة';
  }

  @override
  String get vaccineRequired => 'إجباري';

  @override
  String get vaccineOptional => 'اختياري';

  @override
  String vaccineRequiredDone(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString/$totalString من الإجباري اتاخدوا';
  }

  @override
  String vaccineOptionalDone(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString/$totalString من الاختياري اتاخدوا';
  }

  @override
  String get vaccineFilterAll => 'الكل';

  @override
  String get vaccineFilterRequired => 'الإجباري';

  @override
  String get vaccineFilterOptional => 'الاختياري';

  @override
  String get vaccineFilterOverdue => 'المتأخر';

  @override
  String get vaccineFilterEmpty => 'مفيش حاجة هنا.';

  @override
  String get vaccinePlanTitle => 'خطة التطعيم';

  @override
  String get vaccineRouteTitle => 'الحقن بتتاخد إزاي؟';

  @override
  String get vaccineRouteGovernment => 'مكتب الصحة (ببلاش)';

  @override
  String get vaccineRouteGovernmentHint =>
      'الخماسي وحقنة شلل الأطفال (سولك) كل واحدة لوحدها، وجرعة منشطة من الثلاثي البكتيري عند سنة ونص.';

  @override
  String get vaccineRouteHexavalent => 'السداسي (خاص)';

  @override
  String get vaccineRouteHexavalentHint =>
      'حقنة سداسي واحدة بدل الخماسي وسولك عند شهرين و٤ و٦ شهور، وجرعة منشطة سداسي عند سنة ونص. نقط شلل الأطفال والدرن والكبدي ب عند الولادة والثلاثي الفيروسي زي ما هما.';

  @override
  String get vaccineOptionalTitle => 'التطعيمات الاختيارية اللي ماشيين عليها';

  @override
  String get vaccineOptionalHint =>
      'مش في جدول الوزارة المجاني. اسأل دكتور الطفل ياخد أنهي واحد؛ اللي بتعلّم عليه بس هو اللي بنفكّرك بيه أو نعتبره متأخر.';

  @override
  String get vaccineSetupTitle => 'تجهيز التطعيمات';

  @override
  String get vaccineSetupOpen => 'الخطة والجرعات اللي اتاخدت';

  @override
  String get vaccineSetupGiven => 'الجرعات اللي اتاخدت';

  @override
  String get vaccineSetupGivenHint =>
      'علّم على اللي في كارت الطفل. التاريخ هو ميعاد الجرعة إلا لو غيّرته.';

  @override
  String get vaccineSetupNoneYet => 'لسه مفيش جرعات جه ميعادها.';

  @override
  String get vaccineSetupSaved => 'التطعيمات اتحفظت';

  @override
  String get vaccineScanTitle => 'اقرا كارت التطعيمات';

  @override
  String get vaccineScanHelp =>
      'صوّر الكارت. الموبايل بيقرا التواريخ وأسامي التطعيمات المطبوعة بالإنجليزي بس، والمكتوب بخط الإيد غالبًا مش هيتقرا. مفيش حاجة بتتبعت لأي مكان، والصورة مش بتتحفظ. راجع كل جرعة على الكارت.';

  @override
  String get vaccineScanReading => 'بنقرا الكارت…';

  @override
  String vaccineScanFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لقينا $countString جرعات في الكارت.',
      two: 'لقينا جرعتين في الكارت.',
      one: 'لقينا جرعة واحدة في الكارت.',
    );
    return '$_temp0 راجع كل واحدة تحت وعلّم على «زي اللي في الكارت».';
  }

  @override
  String get vaccineScanNothing =>
      'ملقيناش جرعات بتواريخ في الصورة دي. علّم عليها بإيدك تحت.';

  @override
  String vaccineScanAlready(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString جرعات من الكارت كانت متسجلة قبل كده، فمغيّرناهاش.',
      one: 'جرعة من الكارت كانت متسجلة قبل كده، فمغيّرناهاش.',
    );
    return '$_temp0';
  }

  @override
  String vaccineScanFutureRows(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString سطور كان فيها تواريخ لسه مجتش (مواعيد الزيارة الجاية)، فمعلّمناش عليها.',
      one: 'سطر واحد كان فيه تاريخ لسه مجاش (ميعاد الزيارة الجاية)، فمعلّمناش عليه.',
    );
    return '$_temp0';
  }

  @override
  String get vaccineScanFailed => 'مقدرناش نقرا الصورة';

  @override
  String get vaccineScanRouteChanged =>
      'الجدول اتغيّر، فشيلنا اللي اتقرا من الكارت. صوّر الكارت تاني.';

  @override
  String vaccineFromCard(String row) {
    return 'في الكارت: $row';
  }

  @override
  String get vaccineDoseGuessed => 'الكارت مش مكتوب فيه رقم الجرعة: اتأكد منه.';

  @override
  String get vaccineDateCheck =>
      'راجع التاريخ على الكارت: السطر كان فيه أكتر من تاريخ، أو التاريخ مش مظبوط مع الجدول (قبل جرعة أقدم، أو بدري قوي عن سن الجرعة دي).';

  @override
  String get vaccineConfirmCard => 'زي اللي في الكارت';

  @override
  String get vaccineConfirmNeeded =>
      'قبل الحفظ، أكّد كل جرعة اتقرت من الكارت (أو شيل العلامة)، وقول كل سطر مش معروف هو أنهي جرعة، أو سيبه.';

  @override
  String get vaccineUnknownTitle => 'سطور الموبايل معرفش اسمها';

  @override
  String vaccineUnknownRow(String text, String date) {
    return '«$text»، اتاخدت $date';
  }

  @override
  String vaccineUnknownDateOnly(String date) {
    return 'جرعة اتاخدت $date';
  }

  @override
  String get vaccineUnknownPick => 'دي أنهي جرعة؟';

  @override
  String get vaccineUnknownSkip => 'سيبها';

  @override
  String get vaccineChangeDate => 'غيّر التاريخ';

  @override
  String get vaccineDoseGiven => 'اتاخدت';

  @override
  String get vaccineDoseDate => 'تاريخ الجرعة';

  @override
  String get vaccineDoseNote => 'ملاحظة';

  @override
  String get vaccineDoseNoteHint =>
      'مثلاً: اتاخدت في العيادة، سخونية خفيفة بعدها';

  @override
  String vaccineDueOn(String date) {
    return 'ميعادها $date';
  }

  @override
  String get vaccineNextVisit => 'ميعاد التطعيم الجاي';

  @override
  String vaccineInDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بعد $daysString يوم',
      few: 'بعد $daysString أيام',
      two: 'بعد يومين',
      one: 'بكره',
      zero: 'النهارده',
    );
    return '$_temp0';
  }

  @override
  String vaccineDaysAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'كان ميعاده من $daysString يوم',
      few: 'كان ميعاده من $daysString أيام',
      two: 'كان ميعاده من يومين',
      one: 'كان ميعاده امبارح',
    );
    return '$_temp0';
  }

  @override
  String vaccineOverdueCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString جرعة متأخرة',
      few: '$countString جرعات متأخرة',
      two: 'جرعتين متأخرين',
      one: 'جرعة متأخرة',
    );
    return '$_temp0';
  }

  @override
  String get vaccineAllDone => 'كل التطعيمات اللي في الخطة اتاخدت';

  @override
  String get vaccineOpenAll => 'كل التطعيمات';

  @override
  String get homeVaccinesTitle => 'التطعيمات';

  @override
  String get vaccineChannelName => 'مواعيد التطعيمات';

  @override
  String get vaccineReminderDiscreetTitle => 'فيه ميعاد زيارة صحية قرّب';

  @override
  String get vaccineReminderDiscreetTodayTitle =>
      'فيه ميعاد زيارة صحية النهارده';

  @override
  String get vaccineReminderDiscreetBody => 'افتح أسرة عشان تشوف التفاصيل';

  @override
  String vaccineReminderWeekTitle(String name) {
    return '$name: تطعيمات بعد أسبوع';
  }

  @override
  String vaccineReminderTodayTitle(String name) {
    return '$name: تطعيمات النهارده';
  }

  @override
  String get settingsVaccineReminders => 'تنبيهات التطعيمات';

  @override
  String settingsVaccineRemindersHint(String time) {
    return 'قبلها بأسبوع ويوم الميعاد، الساعة $time';
  }

  @override
  String get settingsVaccineReminderTime => 'ساعة التنبيه';

  @override
  String get vaccineSources => 'المصادر';

  @override
  String get reminderHiddenPreview => 'تنبيه من أسرة';

  @override
  String get vaccineTooLate => 'فات السن المسموح: اسأل الدكتور';

  @override
  String get vaccineNotNeeded => 'مش محتاجها في السن ده';

  @override
  String get vaccineRemoveRecordTitle => 'تمسح التسجيل اللي كتبته؟';

  @override
  String get vaccineRemoveRecordBody =>
      'الجرعة دي اتسجلت بإيدك، ويمكن معاها صورة الكارت أو الدكتور أو التكلفة. لو شلت العلامة، التسجيل ده هيتشال من سجل الطفل.';

  @override
  String get vaccineRemoveRecordConfirm => 'امسح';

  @override
  String get growthHeadForAge => 'محيط الراس حسب السن';

  @override
  String get prescriptionsSection => 'الروشتات';

  @override
  String get prescriptionAdd => 'ضيف روشتة';

  @override
  String get prescriptionNew => 'روشتة جديدة';

  @override
  String get prescriptionEdit => 'عدّل الروشتة';

  @override
  String get prescriptionDate => 'التاريخ (أول يوم علاج)';

  @override
  String get prescriptionDiagnosis => 'التشخيص أو السبب';

  @override
  String get prescriptionNotes => 'ملاحظات';

  @override
  String get prescriptionPhotos => 'صورة الروشتة';

  @override
  String get prescriptionMedicines => 'الأدوية';

  @override
  String get prescriptionAddMedicine => 'ضيف دوا كمان';

  @override
  String prescriptionMedicineN(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'دوا $nString';
  }

  @override
  String get prescriptionRemoveMedicine => 'شيل الدوا ده';

  @override
  String get prescriptionDose => 'الجرعة زي ما الدكتور كتبها';

  @override
  String get prescriptionDoseHint => 'زي ما مكتوبة في الروشتة بالظبط';

  @override
  String get prescriptionTimesPerDay =>
      'كام مرة في اليوم (تقدر تغيّر المواعيد)';

  @override
  String prescriptionTimesN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString مرة',
      few: '$countString مرات',
      two: 'مرتين',
      one: 'مرة',
    );
    return '$_temp0';
  }

  @override
  String get prescriptionDuration => 'لمدة قد إيه';

  @override
  String get prescriptionOngoing => 'مستمر';

  @override
  String get prescriptionForDays => 'عدد أيام محدد';

  @override
  String get prescriptionDays => 'عدد الأيام';

  @override
  String get prescriptionDaysInvalid => 'اكتب عدد أيام، ١ أو أكتر';

  @override
  String get prescriptionNoDoseAdvice =>
      'اكتب كل دوا زي ما هو مكتوب في الروشتة بالظبط. أسرة عمرها ما بتقترح ولا بتحسب جرعة.';

  @override
  String get prescriptionNeedsTimes =>
      'ضيف ميعاد واحد على الأقل، وإلا مفيش تنبيهات هترن';

  @override
  String get prescriptionStop => 'وقّف الروشتة كلها';

  @override
  String get prescriptionResume => 'رجّع الروشتة تاني';

  @override
  String get prescriptionDeleteConfirm =>
      'تمسح الروشتة دي وأدويتها وسجلها؟ صورها هتتمسح من الموبايل ده.';

  @override
  String get prescriptionNotFound => 'الروشتة دي اتمسحت';

  @override
  String prescriptionTitle(String date) {
    return 'روشتة $date';
  }

  @override
  String prescriptionCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString دوا',
      few: '$countString أدوية',
      two: 'دوايين',
      one: 'دوا واحد',
    );
    return '$_temp0';
  }

  @override
  String prescriptionDaysCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString يوم',
      few: '$countString أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get prescriptionLink => 'الروشتة';

  @override
  String courseDayOf(int day, int total) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'اليوم $dayString من $totalString';
  }

  @override
  String get prescriptionMoveTitle => 'تنقل مواعيد العلاج كمان؟';

  @override
  String get prescriptionMoveBody =>
      'العلاج اللي لسه مخلصش ممكن يبدأ من التاريخ الجديد. اللي خلص خلاص هيفضل بتواريخه ومش هترجعله تنبيهات.';

  @override
  String get prescriptionMoveYes => 'انقلها';

  @override
  String get prescriptionMoveKeep => 'سيب تواريخها';

  @override
  String prescriptionRemoveConfirm(String name) {
    return 'تشيل $name من الروشتة دي؟ هيتوقف وتنبيهاته هتخلص. سجل جرعاته هيفضل في صفحته.';
  }

  @override
  String get prescriptionEveryHours => 'كل كام ساعة';

  @override
  String get prescriptionInterval => 'زي ما الدكتور كتب';

  @override
  String prescriptionEveryNHours(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'كل $nString ساعة',
      few: 'كل $nString ساعات',
      two: 'كل ساعتين',
      one: 'كل ساعة',
    );
    return '$_temp0';
  }

  @override
  String prescriptionFirstDose(String time) {
    return 'أول مرة الساعة $time';
  }

  @override
  String get prescriptionTimesHint => 'اتأكد إن المواعيد زي ما الدكتور كتب.';

  @override
  String get rxScanTitle => 'اقرا الروشتة من صورة';

  @override
  String rxFor(String name) {
    return 'الروشتة دي ل$name';
  }

  @override
  String get rxScanHelp =>
      'الموبايل بيقرا أسامي الأدوية المطبوعة بالإنجليزي بنفسه، ومفيش حاجة بتتبعت لأي مكان. مبيقراش خط الإيد: لو الدكتور كاتب بإيده، اكتب الأدوية وإنت باصص على الصورة. الصورة بتتحفظ متشفّرة مع الروشتة.';

  @override
  String get rxScanReading => 'بنقرا الروشتة…';

  @override
  String rxScanFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لقينا $countString أدوية.',
      two: 'لقينا دوائين.',
      one: 'لقينا دوا واحد.',
    );
    return '$_temp0 راجع كل واحد على الورقة؛ الخانات المعلّمة الموبايل مكانش متأكد منها.';
  }

  @override
  String get rxScanUnclear =>
      'الروشتة شكلها بخط الإيد أو مش واضحة، فمكتبناش حاجة. الصورة محفوظة مع الروشتة: اكتب الأدوية وإنت باصص عليها.';

  @override
  String get rxScanNothing =>
      'ملقيناش أدوية في الصورة دي. اكتبها بإيدك، والصورة هتتحفظ مع الروشتة.';

  @override
  String get rxScanFailed => 'مقدرناش نقرا الصورة';

  @override
  String get rxScanPhoto => 'صورة الروشتة';

  @override
  String get rxFromPhoto => 'اتقرا من الصورة: راجعه على الورقة';

  @override
  String get rxConfirmMedicine => 'زي اللي في الورقة';

  @override
  String get rxTimesChecked => 'المواعيد زي اللي في الورقة';

  @override
  String rxDidYouMean(String name) {
    return 'تقصد $name؟';
  }

  @override
  String get rxConfirmFirstCheck => 'راجع الخانات المعلّمة الأول';

  @override
  String get rxConfirmNeeded =>
      'قبل الحفظ، راجع كل دوا اتقرا من الصورة على الورقة وعلّم على «زي اللي في الورقة»، وراجع التاريخ والدكتور.';

  @override
  String rxDoctorOnPaper(String name) {
    return 'في الورقة: $name';
  }

  @override
  String get rxDoctorAdd => 'ضيفه لدكاترتي';

  @override
  String get rxTimesFromPaper =>
      'عدد المرات اتقرا من الورقة، ومواعيد التنبيه متوزعة على اليوم بس. غيّرها لو الدكتور قال غير كده.';

  @override
  String get growthNoPrematurity =>
      'السن محسوب من يوم الولادة من غير تصحيح للأطفال المبتسرين. لو طفلك اتولد بدري، اسأل دكتور الأطفال إزاي تقرا المنحنى ده.';

  @override
  String get reportAppLine => 'اتعمل بتطبيق أسرة (Usra) لملف العيلة الصحي';

  @override
  String reportGenerated(String date) {
    return 'اتعمل يوم $date';
  }

  @override
  String reportPage(int page, int total) {
    final intl.NumberFormat pageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pageString = pageNumberFormat.format(page);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'صفحة $pageString من $totalString';
  }

  @override
  String get reportVaccinationTitle => 'سجل التطعيمات';

  @override
  String get reportVaccinationDisclaimer =>
      'سجل للمعلومات بس، عملته العيلة بتطبيق أسرة من اللي سجلته بنفسها. مش شهادة تطعيم رسمية: راجعوا كارت التطعيم بتاع الطفل.';

  @override
  String get reportName => 'الاسم';

  @override
  String get reportRoute => 'طريقة التطعيم';

  @override
  String get reportRouteGovernment => 'حكومي (مكتب الصحة)';

  @override
  String get reportRoutePrivate => 'خاص (السداسي)';

  @override
  String get reportDosesGiven => 'الجرعات اللي اتاخدت';

  @override
  String get reportNoDosesGiven => 'مفيش جرعات متسجلة لسه';

  @override
  String get reportUpcoming => 'الجرعات الجاية';

  @override
  String get reportNoUpcoming => 'مفيش جرعات فاضلة في الجدول';

  @override
  String get reportUpcomingOverFive => 'جدول أسرة بيتابع الأطفال لحد ٥ سنين.';

  @override
  String get reportColVaccine => 'التطعيم';

  @override
  String get reportColDate => 'التاريخ';

  @override
  String get reportColNotes => 'ملاحظات';

  @override
  String get reportColDue => 'الميعاد';

  @override
  String get reportOverdue => 'متأخرة';

  @override
  String get reportSummaryTitle => 'ملخص صحي للدكتور';

  @override
  String get reportSummaryDisclaimer =>
      'ده ملخص من اللي العيلة سجلته بتطبيق أسرة، مش رأي طبي. راجعوه على الروشتات والتقارير الأصلية.';

  @override
  String get reportAge => 'السن';

  @override
  String get reportSectionBasics => 'السن وفصيلة الدم';

  @override
  String get reportSectionMedicines => 'الأدوية الحالية';

  @override
  String get reportSectionVisits => 'آخر زيارات للدكتور';

  @override
  String get reportSectionLabs => 'آخر نتايج تحاليل';

  @override
  String get reportSectionGrowth => 'النمو';

  @override
  String get reportSectionVaccines => 'التطعيمات';

  @override
  String get reportColMedicine => 'الدوا';

  @override
  String get reportColHowTaken => 'زي ما الدكتور كتب';

  @override
  String get reportColDoctor => 'الدكتور';

  @override
  String get reportColDetails => 'السبب / التشخيص';

  @override
  String get reportColTest => 'التحليل';

  @override
  String get reportColResult => 'النتيجة';

  @override
  String get reportColRange => 'المعدل الطبيعي للمعمل';

  @override
  String get reportColMeasure => 'القياس';

  @override
  String get reportColValue => 'القيمة';

  @override
  String get reportColPercentile => 'المئين (منظمة الصحة العالمية)';

  @override
  String get reportAsNeeded => 'عند اللزوم';

  @override
  String reportSince(String date) {
    return 'من $date';
  }

  @override
  String reportUntil(String date) {
    return 'لحد $date';
  }

  @override
  String reportVaccineProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString من $totalString جرعة في الخطة اتاخدت';
  }

  @override
  String get reportVaccineNext => 'ميعاد التطعيم الجاي';

  @override
  String get reportVaccineOverdue => 'متأخر';

  @override
  String get reportGrowthNote =>
      'المئين من معايير منظمة الصحة العالمية لنمو الأطفال (أقل من ٥ سنين). للمعلومات، مش تشخيص.';

  @override
  String get reportNothing => 'مفيش حاجة متسجلة';

  @override
  String get memberDoctorSummary => 'ملخص للدكتور';

  @override
  String get reportSummaryIntro =>
      'ملخص PDF قصير توريه أو تبعته للدكتور. اختار إيه اللي يتكتب فيه.';

  @override
  String get reportChooseSections => 'إيه اللي يتكتب';

  @override
  String get reportLanguage => 'لغة الملف';

  @override
  String get reportSharePdf => 'ابعت PDF';

  @override
  String get reportIncludeNotes => 'اكتب ملاحظاتي على كل جرعة';

  @override
  String get reportVaccinationShare => 'ابعت سجل التطعيمات';

  @override
  String get reportVaccinationIntro =>
      'ملف PDF بالجرعات اللي اتاخدت والجاية، للمدرسة أو الحضانة أو الدكتور.';

  @override
  String get reportPickOne => 'اختار حاجة واحدة على الأقل';

  @override
  String get reportOnPhone =>
      'بيتعمل على الموبايل ده. الملف بيتمسح من الموبايل بعد ما يتبعت.';

  @override
  String get reportFailed => 'معرفناش نعمل الملف';

  @override
  String get reportNeedsBirthDate => 'ضيف تاريخ الميلاد في البروفايل الأول.';

  @override
  String get reportFlagHigh => 'عالي';

  @override
  String get reportFlagLow => 'واطي';

  @override
  String get reportTooLate => 'فات ميعاده: اسأل الدكتور';

  @override
  String get reportTooLateLabel => 'فات ميعاده (اسأل الدكتور)';

  @override
  String get reportSimpleIntro =>
      'ملف PDF فيه البيانات الصحية والأدوية والزيارات والتحاليل، توريه أو تبعته للدكتور.';

  @override
  String get memberSickDays => 'الحرارة والتعب';

  @override
  String get sickDaysTitle => 'الحرارة والتعب';

  @override
  String get sickDaysEmpty =>
      'مفيش أيام تعب متسجلة. لما حد يتعب، ابدأ يوم تعب وسجل الحرارة والأعراض والأدوية اللي اتاخدت.';

  @override
  String get sickDayStart => 'ابدأ يوم تعب';

  @override
  String sickDayOngoing(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'لسه تعبانة',
      'other': 'لسه تعبان',
    });
    return '$_temp0';
  }

  @override
  String get sickDayEnded => 'خلص';

  @override
  String sickDaySince(String date) {
    return 'من $date';
  }

  @override
  String sickDayRange(String start, String end) {
    return 'من $start لـ $end';
  }

  @override
  String get sickDayTitle => 'يوم تعب';

  @override
  String get sickDayStartedAt => 'بدأ';

  @override
  String get sickDayEnd => 'خلص التعب';

  @override
  String sickDayReopen(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'لسه تعبانة',
      'other': 'لسه تعبان',
    });
    return '$_temp0';
  }

  @override
  String get sickDayDelete => 'امسح يوم التعب ده';

  @override
  String get sickDayDeleteConfirm =>
      'تمسح يوم التعب ده بالحرارة والأدوية اللي اتسجلت فيه؟';

  @override
  String get sickDayTemperatures => 'الحرارة';

  @override
  String get sickDayAddReading => 'سجل الحرارة';

  @override
  String get sickDayNoReadings => 'لسه مفيش حرارة متسجلة.';

  @override
  String get sickDayChartTitle => 'رسم الحرارة';

  @override
  String get sickDayChartNote =>
      'الخط المتقطع: ٣٨ °م (١٠٠٫٤ °ف)، من عندها تبقى سخونية.';

  @override
  String get sickDaySymptoms => 'الأعراض';

  @override
  String get sickDayMedicines => 'الأدوية اللي اتاخدت';

  @override
  String get sickDayAddMedicine => 'سجل دوا اتاخد';

  @override
  String get sickDayNoMedicines => 'مفيش أدوية متسجلة.';

  @override
  String get sickDayNotes => 'ملاحظات';

  @override
  String get sickDayNotesSaved => 'الملاحظات اتحفظت';

  @override
  String sickDayPersonUnwell(String sex, String name) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'male': '$name تعبان',
      'female': '$name تعبانة',
      'other': '$name: يوم تعب',
    });
    return '$_temp0';
  }

  @override
  String sickDayPersonWasUnwell(String sex, String name) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'male': '$name كان تعبان',
      'female': '$name كانت تعبانة',
      'other': '$name: يوم تعب',
    });
    return '$_temp0';
  }

  @override
  String sickDaySinceToday(String time) {
    return 'من النهارده $time';
  }

  @override
  String sickDaySinceYesterday(String time) {
    return 'من امبارح $time';
  }

  @override
  String get sickDayLatestReading => 'آخر قراءة';

  @override
  String sickDayFeverLogged(String duration) {
    return 'سخونية متسجلة: $duration';
  }

  @override
  String get sickDayFeverUnderHour => 'أقل من ساعة';

  @override
  String sickDayFeverHours(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown ساعة',
      few: '$shown ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return '$_temp0';
  }

  @override
  String sickDayFeverDays(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown يوم',
      few: '$shown أيام',
      two: 'يومين',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String sickDayRecordedGiven(String what, String time) {
    return 'مسجل: $what · $time';
  }

  @override
  String sickDayChartSemantics(
    String start,
    String end,
    String values,
    String fever,
  ) {
    return 'القراءات من $start لحد $end: $values. الخط المتقطع عند $fever، من عندها تبقى سخونية.';
  }

  @override
  String get sickDayChartThen => ' ثم ';

  @override
  String get sickDayAddReadingShort => 'قراءة حرارة';

  @override
  String get sickDayGivenShort => 'دوا اتاخد';

  @override
  String get sickDayAllReadings => 'كل القراءات';

  @override
  String get sickDayNoSymptoms => 'لسه مفيش أعراض متسجلة.';

  @override
  String sickDayCallDoctorNamed(String name) {
    return 'كلّم $name';
  }

  @override
  String get sickDayBack => 'رجوع';

  @override
  String get readingValue => 'الحرارة';

  @override
  String get readingCelsius => '°م';

  @override
  String get readingFahrenheit => '°ف';

  @override
  String get readingSite => 'اتقاست فين';

  @override
  String readingSiteName(String site) {
    String _temp0 = intl.Intl.selectLogic(site, {
      'armpit': 'تحت الباط',
      'ear': 'الودن',
      'forehead': 'الجبهة',
      'mouth': 'البُق',
      'rectal': 'شرجي',
      'other': 'مش محدد',
    });
    return '$_temp0';
  }

  @override
  String get readingTime => 'الوقت';

  @override
  String get readingDate => 'التاريخ';

  @override
  String get readingImplausible =>
      'الرقم ده مش شكل حرارة جسم. راجع الرقم والوحدة.';

  @override
  String get readingFever => 'سخونية';

  @override
  String get readingDelete => 'امسح الحرارة دي';

  @override
  String get givenWhich => 'أنهي دوا';

  @override
  String get givenOther => 'دوا تاني (اكتب اسمه)';

  @override
  String get givenName => 'اسم الدوا';

  @override
  String get givenAmount => 'الكمية اللي اتاخدت';

  @override
  String get givenAmountHint => 'زي ما هتكتبها، من العلبة أو الروشتة مثلًا';

  @override
  String get givenTime => 'اتاخد إمتى';

  @override
  String givenFromPrescription(String date) {
    return 'من روشتة $date';
  }

  @override
  String get givenRemind => 'فكرني في الوقت ده';

  @override
  String get givenNoInterval =>
      'مفيش وقت ظاهر: الدوا ده مش متسجل له أقل عدد ساعات بين الجرعات. تقدر تضيفها من صفحة الدوا، زي ما مكتوب على العلبة أو من الدكتور.';

  @override
  String get givenDelete => 'امسح ده';

  @override
  String get givenRequired => 'اختار دوا أو اكتب اسمه';

  @override
  String get nextDoseDiscreetTitle => 'تذكير من أسرة';

  @override
  String get nextDoseDiscreetBody => 'افتح أسرة وشوف التفاصيل.';

  @override
  String nextDoseTitle(String person, String medicine) {
    return '$person: $medicine';
  }

  @override
  String nextDoseBody(String hours) {
    return 'عدّى $hours ساعة من الجرعة اللي سجلتها. راجع لو فيه دوا تاني بنفس المادة الفعالة.';
  }

  @override
  String symptomName(String symptom) {
    String _temp0 = intl.Intl.selectLogic(symptom, {
      'cough': 'كحة',
      'runnyNose': 'رشح',
      'soreThroat': 'التهاب في الزور',
      'earPain': 'وجع في الودن',
      'headache': 'صداع',
      'vomiting': 'ترجيع',
      'diarrhea': 'إسهال',
      'rash': 'طفح',
      'aches': 'تكسير في الجسم',
      'poorFeeding': 'بياكل أو بيشرب أقل',
      'dehydration': 'حفاضات ناشفة أو بيعمل حمام أقل أو مفيش دموع',
      'breathing': 'صعوبة في النفس',
      'drowsy': 'نعسان جدًا أو صعب يصحى',
      'seizure': 'تشنج',
      'rashNotFading': 'طفح مش بيختفي تحت الكوباية',
      'stiffNeck': 'تيبس في الرقبة',
      'other': 'تاني',
    });
    return '$_temp0';
  }

  @override
  String get warnTitle => 'علامات الخطر';

  @override
  String get warnLogged => 'من اللي سجلته:';

  @override
  String get warnEmergency => 'اتصل بالإسعاف (١٢٣) فورًا لو:';

  @override
  String get warnDoctorNow => 'كلم دكتور دلوقتي لو:';

  @override
  String warnSign(String sign) {
    String _temp0 = intl.Intl.selectLogic(sign, {
      'breathing': 'صعوبة في النفس، أو بيتنفس بسرعة جدًا، أو نفسه مقطوع',
      'seizure': 'تشنج',
      'rashGlass': 'طفح مش بيختفي لما تضغط عليه بكوباية',
      'drowsy': 'نعسان جدًا أو صعب يصحى، أو مش بيرد زي عادته',
      'stiffNeck': 'تيبس في الرقبة، أو النور بيضايق عينه',
      'skinColour': 'جلد أو شفايف أو لسان لونهم أزرق أو رمادي أو باهت جدًا أو مبقع، أو إيدين ورجلين ساقعين بشكل غريب',
      'confused': 'مش مركز أو متلخبط، أو متضايق جدًا ومش بيبطل عياط',
      'under3Months': 'سنه أقل من ٣ شهور وحرارته ٣٨ °م (١٠٠٫٤ °ف) أو أكتر',
      'months3to6': 'سنه من ٣ لـ ٦ شهور وحرارته ٣٩ °م (١٠٢٫٢ °ف) أو أكتر',
      'longUnder2': 'سنه أقل من سنتين والسخونية بقالها أكتر من ٢٤ ساعة',
      'longChild': 'سنه سنتين أو أكتر والسخونية بقالها أكتر من ٣ أيام',
      'fiveDays': 'السخونية بقالها ٥ أيام أو أكتر',
      'veryHigh': 'الحرارة عدت ٤٠ °م (١٠٤ °ف) أكتر من مرة',
      'notImproving': 'حرارة عالية مش بتتحسن أو بتزيد',
      'dehydration': 'علامات جفاف: حفاضات ناشفة أو بيعمل حمام أقل، مفيش دموع، عينين غايرة، بُق ناشف',
      'notDrinking': 'مش بيشرب أو مش بيرضع، أو مش زي عادته خالص',
      'vomitsEverything': 'بيرجّع أي حاجة ياخدها، أو مش بيبطل ترجيع',
      'armpitUnder3Months':
          'سنه أقل من ٣ شهور والحرارة تحت الباط ٣٧٫٥ °م (٩٩٫٥ °ف) أو أكتر',
      'lowUnder3Months': 'سنه أقل من ٣ شهور وحرارته أقل من ٣٦ °م (٩٦٫٨ °ف)',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get warnFooter =>
      'للمعلومة بس، مش تشخيص. لو قلقان، كلم دكتور أو اتصل بـ ١٢٣، حتى لو مفيش حاجة من دول.';

  @override
  String get warnSources => 'المصادر';

  @override
  String warnSourceName(String source) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'nhs': 'NHS (بريطانيا): السخونية عند الأطفال',
      'aap': 'الأكاديمية الأمريكية لطب الأطفال: إمتى تكلم الدكتور',
      'who': 'منظمة الصحة العالمية: علامات الخطر العامة (IMCI)',
      'stlouis': 'مستشفى أطفال سانت لويس: إزاي تقيس الحرارة',
      'womans': 'مستشفى وومانز: حرارة المولود',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get warnCallDoctor => 'الدكاترة بتوعي';

  @override
  String givenHoursAfter(String hours, String time) {
    return 'بعد $hours ساعة من الجرعة دي: $time';
  }

  @override
  String get givenCheckIngredient =>
      'قبل أي جرعة تانية، راجع لو فيه دوا تاني بنفس المادة الفعالة.';

  @override
  String get medicineMinHours => 'أقل عدد ساعات بين الجرعات';

  @override
  String get medicineMinHoursHint =>
      'زي ما مكتوب على العلبة أو من الدكتور. سيبها فاضية لو مش مكتوب.';

  @override
  String get medicineMinHoursInvalid => 'اكتب عدد ساعات من ٠٫٥ لـ ٧٢';

  @override
  String medicineMinHoursSuggest(String phrase, String hours) {
    return 'التعليمات بتقول «$phrase». تستخدم $hours ساعة؟';
  }

  @override
  String get medicineMinHoursUse => 'استخدم';

  @override
  String medicineMinHoursValue(String hours) {
    return '$hours ساعة';
  }

  @override
  String get warnArmpitNote =>
      'الحرارة تحت الباط بتطلع أقل. لو البيبي سخن أو شكله تعبان، كلم الدكتور حتى لو أقل من ٣٨ °م.';

  @override
  String get warnNoBirthDate =>
      'ضيف تاريخ الميلاد علشان تشوف العلامات المناسبة للسن.';

  @override
  String get readingConfirmTitle => 'الرقم ده صح؟';

  @override
  String readingConfirmBody(String value) {
    return '$value حرارة غريبة جدًا لجسم الإنسان. راجع الترمومتر والوحدة.';
  }

  @override
  String get readingConfirmYes => 'احفظ برضه';

  @override
  String get readingConfirmNo => 'عدّل';

  @override
  String backupLastCopy(String date) {
    return 'آخر نسخة بعتها لمكان تاني: $date';
  }

  @override
  String get backupAutoTitle => 'نسخة احتياطية تلقائية';

  @override
  String get backupAutoHint =>
      'لما أسرة تتفتح ويكون ميعاد النسخة جه، بتتحفظ نسخة متشفرة في فولدر من اختيارك، مش iCloud.';

  @override
  String get backupAutoFolder => 'الفولدر';

  @override
  String get backupAutoChooseFolder => 'اختيار فولدر';

  @override
  String get backupAutoFrequency => 'كل قد إيه';

  @override
  String get backupFrequencyDaily => 'كل يوم';

  @override
  String get backupFrequencyWeekly => 'كل أسبوع';

  @override
  String get backupFrequencyMonthly => 'كل شهر';

  @override
  String get backupAutoNever => 'لسه مفيش نسخة تلقائية';

  @override
  String get backupAutoRunning =>
      'بنعمل نسخة احتياطية. تقدر تكمل استخدام التطبيق عادي.';

  @override
  String get backupAutoDone => 'النسخة اتحفظت في الفولدر بتاعك.';

  @override
  String get backupSendCopy => 'نسخة لمكان تاني';

  @override
  String get backupBusy => 'فيه نسخة احتياطية شغالة دلوقتي. جرّب كمان شوية.';

  @override
  String get backupAutoDriveHint =>
      'ممكن Google Drive ميظهرش وإنت بتختار الفولدر، وأسرة مش بتطلب إذن تدخل على الدرايف بتاعك. علشان تحتفظ بنسخة على الدرايف، دوس \"نسخة لمكان تاني\" واختار Drive.';

  @override
  String get backupAutoOnPhone =>
      'الفولدر ده على الموبايل نفسه. لو الموبايل ضاع، النسخ دي هتضيع معاه، فابعت نسخة لمكان تاني كمان.';

  @override
  String get backupAutoIosHint =>
      'اختار مكان بره الموبايل لو تقدر، زي تطبيق تاني في Files أو هارد خارجي. الفولدر اللي في On My iPhone بيضيع مع الموبايل. وiCloud Drive مينفعش للسجلات الصحية.';

  @override
  String get backupICloudTitle => 'مينفعش iCloud Drive';

  @override
  String get backupICloudBody =>
      'قواعد Apple مش بتسمح بالسجلات الصحية على iCloud، حتى لو متشفرة، فأسرة مش هتحفظ النسخ هناك. اختار مكان تاني، زي تطبيق تاني في Files أو هارد خارجي.';

  @override
  String get backupFolderCantUseTitle => 'المكان ده مينفعش';

  @override
  String get backupFolderCantUseBody =>
      'أسرة مقدرتش تحفظ وتنظم ملفاتها هناك. اختار فولدر تاني.';

  @override
  String get backupAutoKeyFirstTitle => 'الأول، مفتاح الاسترجاع';

  @override
  String get backupAutoKeyFirstBody =>
      'النسخ بتبقى متشفرة، ومفيش غير مفتاح الاسترجاع بيفتحها. هتكتبه على ورقة دلوقتي. بيفضل في المخزن الآمن بتاع الموبايل ومش بيتحفظ أبدًا مع النسخ.';

  @override
  String get backupAutoKeyFirstContinue => 'كمّل';

  @override
  String get backupAutoFailedTitle => 'النسخة التلقائية مكملتش';

  @override
  String get backupAutoRetry => 'حاول تاني';

  @override
  String get backupAutoSetKey => 'جهّز المفتاح';

  @override
  String get backupAutoFailFolder =>
      'مش قادرين نوصل لفولدر النسخ. يمكن اتنقل أو اتمسح. اختاره تاني.';

  @override
  String get backupAutoFailICloud =>
      'فولدر النسخ بقى على iCloud Drive، وده مينفعش للسجلات الصحية. اختار مكان تاني.';

  @override
  String get backupAutoFailSpace =>
      'مفيش مساحة كفاية للنسخة. فضّي شوية مساحة وحاول تاني.';

  @override
  String get backupAutoFailLocked =>
      'الموبايل اتقفل أثناء النسخ. سيبه مفتوح وحاول تاني.';

  @override
  String get backupAutoFailKey =>
      'مفتاح الاسترجاع مبقاش على الموبايل ده. جهّزه تاني علشان النسخ تكمل.';

  @override
  String get backupAutoFailInterrupted =>
      'أسرة اتقفلت قبل ما النسخة تخلص. أي ملف مكملش هيتمسح المرة الجاية، والنسخ القديمة سليمة. حاول تاني.';

  @override
  String get backupAutoFailOther =>
      'حاجة وقفت النسخة. النسخ القديمة سليمة. حاول تاني.';

  @override
  String get backupAutoPaused =>
      'النسخ التلقائي واقف لأن أسرة بدأت من جديد، علشان النسخ الجديدة متمسحش اللي فيها سجلاتك. رجّع نسخة احتياطية، أو شغّله تاني.';

  @override
  String get backupDueAuto =>
      'لو فولدر النسخ على الموبايل نفسه، ضياع الموبايل معناه ضياع النسخ كمان. ابعت نسخة لمكان تاني.';

  @override
  String backupAutoLast(String date, String size) {
    return 'آخر نسخة تلقائية: $date ($size)';
  }

  @override
  String backupSizeKb(String size) {
    return '$size كيلوبايت';
  }

  @override
  String backupSizeMb(String size) {
    return '$size ميجابايت';
  }

  @override
  String backupSizeGb(String size) {
    return '$size جيجابايت';
  }

  @override
  String backupAutoPhotosSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString صورة مقدرناش نفتحها على الموبايل ده ومش في النسخة.',
      few: '$countString صور مقدرناش نفتحهم على الموبايل ده ومش في النسخة.',
      two: 'صورتين مقدرناش نفتحهم على الموبايل ده ومش في النسخة.',
      one: 'صورة واحدة مقدرناش نفتحها على الموبايل ده ومش في النسخة.',
    );
    return '$_temp0';
  }

  @override
  String get backupAutoOpen => 'افتح النسخة الاحتياطية';

  @override
  String get backupAutoPausedTitle => 'النسخ التلقائي واقف';

  @override
  String get backupAutoUnreadableTitle => 'النسخ التلقائي مش شغّال';

  @override
  String get backupAutoUnreadableBody =>
      'مقدرناش نقرا إعدادات النسخ التلقائي. نسخك لسه في الفولدر بتاعك. افتح النسخة الاحتياطية وشغّله تاني.';

  @override
  String get backupContentDroppedTitle =>
      'آخر نسخة فيها حاجات أقل من اللي قبلها';

  @override
  String get backupContentDroppedBody =>
      'فيها أشخاص أو سجلات أو صور أقل، أو فيه صور ناقصة، فسيبنا النسخ القديمة زي ما هي. لو إنت مسحتهم بنفسك، أكّد ده. لو لأ، رجّع نسخة أقدم.';

  @override
  String get backupContentDroppedAccept => 'أنا اللي مسحتهم';

  @override
  String get backupAutoFolderTop => 'الفولدر الرئيسي للمكان اللي اخترته';

  @override
  String get aboutPrivacyBackupAuto =>
      'لو شغّلت النسخ التلقائي، أسرة بتحفظ الملف ده لوحدها في فولدر تختاره. مش بتبعتلنا حاجة، ومش هتستخدم iCloud Drive.';

  @override
  String get navRecords => 'السجلات';

  @override
  String get navAdd => 'إضافة';

  @override
  String get homeMorning => 'صباح الخير';

  @override
  String get homeEvening => 'مساء الخير';

  @override
  String get homeNothingNeeded => 'مفيش حاجة مطلوبة';

  @override
  String get homeNeedsAttentionOne => 'محتاج انتباهك';

  @override
  String get homeNeedsAttentionMany => 'محتاجين انتباهك';

  @override
  String get homeNamesJoin => 'و';

  @override
  String get homeFamily => 'العيلة';

  @override
  String homeAllFamily(String count) {
    return 'كل العيلة ($count)';
  }

  @override
  String get homeUpcoming => 'الجاي النهارده';

  @override
  String get homeNewPerson => 'فرد جديد';

  @override
  String get homeEmergency => 'طوارئ';

  @override
  String homeBackupAgoDays(int days, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'آخر نسخة احتياطية من $shown يوم',
      many: 'آخر نسخة احتياطية من $shown يوم',
      few: 'آخر نسخة احتياطية من $shown أيام',
      two: 'آخر نسخة احتياطية من يومين',
      one: 'آخر نسخة احتياطية من يوم',
      zero: 'آخر نسخة احتياطية النهارده',
    );
    return '$_temp0';
  }

  @override
  String homeDoseLogged(String medicine, String person) {
    return 'اتسجل: $medicine لـ$person';
  }

  @override
  String get statusSick => 'تعبان';

  @override
  String get statusVaccineOverdue => 'تطعيم متأخر';

  @override
  String get statusDoseMissed => 'دوا فات';

  @override
  String statusDoseNext(String time) {
    return 'دوا $time';
  }

  @override
  String get familyAllTitle => 'كل العيلة';

  @override
  String familyCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown فرد',
      few: '$shown أفراد',
      two: 'فردين',
      one: 'فرد واحد',
    );
    return '$_temp0';
  }

  @override
  String get addSheetTitle => 'هنضيف إيه؟';

  @override
  String get addSheetFor => 'لمين؟';

  @override
  String get addSheetPickPerson => 'اختيار الشخص الأول';

  @override
  String get addSheetNoPeople => 'أول حاجة: فرد من العيلة';

  @override
  String get addMedicine => 'دوا';

  @override
  String get addVaccine => 'تطعيم';

  @override
  String get addVisit => 'زيارة';

  @override
  String get addLab => 'تحليل';

  @override
  String get addScan => 'أشعة';

  @override
  String get addFever => 'سخونية';

  @override
  String get addGrowth => 'وزن وطول';

  @override
  String get addInsurance => 'كارت تأمين';

  @override
  String get addSurgery => 'عملية';

  @override
  String get addPhotoTitle => 'صوّر روشتة أو علبة دوا';

  @override
  String get addPhotoHint =>
      'بنقرا على الموبايل الكلام المطبوع بالإنجليزي بس، والاسم والتركيز لازم يتأكدوا.';

  @override
  String get addPhotoPrescription => 'روشتة';

  @override
  String get addPhotoBox => 'علبة دوا';

  @override
  String get profileMoreDetails => 'تفاصيل أكتر';

  @override
  String profileSaveNamed(String name) {
    return 'حفظ $name';
  }

  @override
  String get recordsTitle => 'السجلات';

  @override
  String get recordsAll => 'الكل';

  @override
  String get recordsEmpty =>
      'لسه مفيش سجلات. دوس إضافة وسجّل أول زيارة أو تحليل.';

  @override
  String get recordsAdd => 'سجل جديد';

  @override
  String get moreFamily => 'كل العيلة';

  @override
  String get moreGroupFamily => 'العيلة';

  @override
  String get moreGroupSafety => 'الأمان';

  @override
  String get moreGroupApp => 'التطبيق';

  @override
  String get accountKeepsQuestion => 'الحساب بيحتفظ بإيه؟';

  @override
  String get accountKeeps =>
      'الإيميل ورقم تعريف للحساب واللغة ومعلومات الجهاز، وكمان الاسم ولينك صورة الحساب لو الدخول بـ Google. السجلات والصور مش عليه.';

  @override
  String get accountDeleteNote =>
      'مسح الحساب مش بيمسح السجلات اللي على الموبايل. مسحها من الخصوصية.';

  @override
  String get privacyEncryptedQ => 'إيه اللي متشفر؟';

  @override
  String get privacyEncryptedA => 'قاعدة البيانات والصور والنسخ الاحتياطية.';

  @override
  String get privacyCanSeeQ => 'نقدر نشوف سجلاتك؟';

  @override
  String get privacyCanSeeA => 'لأ. السجلات والصور بتفضل على موبايلك.';

  @override
  String get privacyBackupQ => 'النسخة الاحتياطية فيها إيه؟';

  @override
  String get privacyBackupA => 'السجلات والصور، متشفرة بمفتاح الاسترجاع.';

  @override
  String get privacyPinQ => 'لو الرقم السري اتنسي؟';

  @override
  String get privacyPinA =>
      'مفيش حاجة تعدّيه، ولا حتى إحنا. بيانات أسرة على الموبايل بتتمسح، وبترجع من النسخة الاحتياطية بمفتاح الاسترجاع. من غير نسخة، السجلات بتضيع.';

  @override
  String get privacyDeleteQ => 'لو البيانات اتمسحت؟';

  @override
  String get privacyDeleteA =>
      'بتتمسح من الموبايل. النسخ اللي اتحفظت في فولدر أو على واتساب بتفضل لحد ما تتمسح من هناك.';

  @override
  String get lockSetupBackupReady =>
      'الرقم السري محتاج نسخة احتياطية الأول، وفيه نسخة، فجاهز.';

  @override
  String get statusSickFemale => 'تعبانة';

  @override
  String get emergencyPickPerson => 'كارت مين؟';

  @override
  String get homeLoadError =>
      'مش قادرين نقرا البيانات دلوقتي. اقفل التطبيق وافتحه تاني.';

  @override
  String homeGreetingNamed(String greeting, String name) {
    return '$greeting يا $name';
  }

  @override
  String get welcomeHeadline => 'صحة العيلة كلها\nفي مكان واحد';

  @override
  String get welcomePrivacyLine =>
      'ملف لكل فرد وتذكير بالدوا. بياناتك على موبايلك ومتشفرة، وإحنا مش بنشوفها.';

  @override
  String get welcomeStart => 'يلا نبدأ';

  @override
  String get welcomeHaveBackup => 'عندي نسخة احتياطية';

  @override
  String get welcomeDisclaimer => 'أسرة مش جهاز طبي ومش بديل عن الدكتور.';

  @override
  String get welcomePrivacy => 'الخصوصية';

  @override
  String get welcomeTerms => 'الشروط';

  @override
  String get welcomeLanguageOther => 'English';

  @override
  String onboardingStep(String current, String total) {
    return 'خطوة $current من $total';
  }

  @override
  String get onboardingBack => 'رجوع';

  @override
  String get countryTitle => 'البلد';

  @override
  String get countryHint => 'علشان جدول التطعيمات ورقم الإسعاف يبقوا صح.';

  @override
  String get countryEgypt => 'مصر';

  @override
  String get countryEgyptDetail => 'وزارة الصحة والسكان · الإسعاف ١٢٣';

  @override
  String get countrySaudi => 'السعودية';

  @override
  String get countryJordan => 'الأردن';

  @override
  String get countrySoon => 'قريب';

  @override
  String get aboutYouTitle => 'أول ملف في عيلتك';

  @override
  String get aboutYouHint => 'ده ملفك، وممكن يتعدّل بعدين.';

  @override
  String get aboutYouSex => 'النوع';

  @override
  String get aboutYouSexHint => 'علشان منحنيات النمو والحمل.';

  @override
  String get aboutYouBirthDateHint => 'علشان الاقتراحات اللي بتعتمد على السن.';

  @override
  String get aboutYouBirthDateFuture =>
      'تاريخ الميلاد مينفعش يكون في المستقبل.';

  @override
  String get aboutYouDone => 'يلا بينا';

  @override
  String personAddFor(String name) {
    return 'إضافة ل$name';
  }

  @override
  String personVaccineWasDue(String date) {
    return 'كان ميعادها $date. اسأل الدكتور إمتى تتاخد.';
  }

  @override
  String get personDoctorSummary => 'ملخص للدكتور';

  @override
  String get personInsuranceOpen => 'افتح الكارت';

  @override
  String get personVaccineLog => 'اتاخدت؟ سجّلها';

  @override
  String personVaccineSource(String route, String date) {
    return 'المرجع: جدول التطعيمات في مصر، $route · اتراجع $date';
  }

  @override
  String personVaccineSourceOptional(String date) {
    return 'المرجع: الجداول المعتادة عند دكاترة الأطفال في مصر · اتراجع $date';
  }

  @override
  String personNextDose(String time) {
    return 'الجرعة الجاية · $time';
  }

  @override
  String personDoseWasAt(String time) {
    return 'كان ميعادها $time';
  }

  @override
  String get personRecordedTitle => 'اللي العيلة سجّلته';

  @override
  String get personTimelineTitle => 'كل السجلات';

  @override
  String get personTileGrowth => 'النمو';

  @override
  String get personTileVisits => 'الزيارات والتحاليل';

  @override
  String get personTileInsurance => 'التأمين';

  @override
  String get personTileDocuments => 'الورق والصور';

  @override
  String personVaccinesSummary(String done, String total) {
    return '$done من $total · جدول مصر';
  }

  @override
  String personGrowthWeight(String value, String date) {
    return '$value كجم · $date';
  }

  @override
  String personGrowthHeight(String value, String date) {
    return '$value سم · $date';
  }

  @override
  String personLatestOn(String date) {
    return 'آخرها $date';
  }

  @override
  String personInsuranceCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown كارت',
      few: '$shown كروت',
      two: 'كارتين',
      one: 'كارت واحد',
      zero: 'لسه مفيش',
    );
    return '$_temp0';
  }

  @override
  String personMedicinesCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown دوا',
      few: '$shown أدوية',
      two: 'دوايين',
      one: 'دوا واحد',
      zero: 'مفيش أدوية حالية',
    );
    return '$_temp0';
  }

  @override
  String personFollowUpsCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown متابعة',
      few: '$shown متابعات',
      two: 'متابعتين',
      one: 'متابعة واحدة',
      zero: 'مفيش دلوقتي',
    );
    return '$_temp0';
  }

  @override
  String personDocumentsCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown سجل فيه صور',
      few: '$shown سجلات فيها صور',
      two: 'سجلين فيهم صور',
      one: 'سجل واحد فيه صور',
      zero: 'لسه مفيش',
    );
    return '$_temp0';
  }

  @override
  String get personVisitsEmpty => 'لسه مفيش زيارات أو تحاليل متسجلة.';

  @override
  String get personDocumentsEmpty => 'لسه مفيش سجلات فيها صور.';

  @override
  String personAgeYears(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown سنة',
      few: '$shown سنين',
      two: 'سنتين',
      one: 'سنة',
    );
    return '$_temp0';
  }

  @override
  String personAgeMonths(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown شهر',
      few: '$shown شهور',
      two: 'شهرين',
      one: 'شهر',
      zero: 'أقل من شهر',
    );
    return '$_temp0';
  }

  @override
  String emergencyAmbulanceShort(String number) {
    return 'الإسعاف $number';
  }

  @override
  String get emergencyOtherLanguage => 'English';

  @override
  String get emergencyMedicines => 'أدوية حالية';

  @override
  String get emergencyAsTyped => 'ده اللي العيلة سجّلته، زي ما اتكتب.';

  @override
  String get emergencyLockTitle => 'إظهاره على قفل أسرة';

  @override
  String get emergencyLockHint => 'أي حد ماسك الموبايل وأسرة مفتوحة يقدر يشوفه';

  @override
  String get emergencyMedicalIdHint =>
      'قفل أسرة بيظهر بس بعد ما الموبايل نفسه يتفتح. عشان المسعف يقدر يقرا المعلومات دي والموبايل مقفول، سجّلها كمان في Medical ID أو معلومات الطوارئ في إعدادات الموبايل.';

  @override
  String lockEmergencyConfirmTitle(String name) {
    return 'يظهر كارت $name على قفل أسرة؟';
  }

  @override
  String get lockEmergencyConfirmBody =>
      'أي حد ماسك الموبايل وأسرة مفتوحة هيقدر يشوف فصيلة الدم والحساسية والأمراض والعمليات والأدوية الحالية ورقم الطوارئ وصاحبه من غير الرقم السري. ده قفل أسرة، مش قفل الموبايل.';

  @override
  String get lockEmergencyConfirmYes => 'أيوه، يظهر';

  @override
  String get insuranceCopyNumber => 'انسخ رقم العضوية';

  @override
  String get insuranceCopyFailed => 'مقدرناش ننسخ الرقم';

  @override
  String get insuranceNumberCopied => 'رقم العضوية اتنسخ';

  @override
  String get doseGroupMissed => 'فاتت';

  @override
  String get doseGroupNow => 'دلوقتي';

  @override
  String get doseGroupDone => 'اتسجلت';

  @override
  String get dayPartMorning => 'الصبح';

  @override
  String get dayPartNoon => 'الضهر';

  @override
  String get dayPartAfternoon => 'العصر';

  @override
  String get dayPartNight => 'بالليل';

  @override
  String get doseSnoozeShort => 'بعد ١٠ دقايق';

  @override
  String get doseTakenEarly => 'اتاخد بدري';

  @override
  String doseSnoozedUntil(String time) {
    return 'متأجل لحد $time';
  }

  @override
  String doseLoggedEarly(String medicine, String person) {
    return 'اتسجل بدري: $medicine لـ$person';
  }

  @override
  String doseLoggedNotTaken(String medicine, String person) {
    return 'اتسجل إنه ماتاخدش: $medicine لـ$person';
  }

  @override
  String doseLoggedSnoozed(String medicine, String person) {
    return 'هنفكّرك بعد ١٠ دقايق: $medicine لـ$person';
  }

  @override
  String get medicinesAll => 'كل الأدوية';

  @override
  String get medicinesFilterAll => 'الكل';

  @override
  String medicinesTodayEmptyFor(String name) {
    return 'مفيش أدوية لـ$name النهارده.';
  }

  @override
  String medicineFor(String name) {
    return 'الدوا ده ل$name';
  }

  @override
  String get medicineForChange => 'غيّر';

  @override
  String get medicineForPick => 'الدوا ده لمين؟';

  @override
  String medicineSaveFor(String name) {
    return 'احفظ ل$name';
  }

  @override
  String medicineSaveForRemind(String name) {
    return 'احفظ ل$name وفكّرني';
  }

  @override
  String medicineSavedFor(String medicine, String name) {
    return 'اتحفظ: $medicine لـ$name';
  }

  @override
  String get medicineScanOption => 'اقرا الاسم من صورة العلبة';

  @override
  String get medicineScanOptionBody => 'هتراجع الاسم والتركيز قبل الحفظ';

  @override
  String get medicineScanRead => 'اتقرا من صورة العلبة';

  @override
  String get medicineScanReview => 'راجع البيانات على العلبة قبل الحفظ';

  @override
  String get medicineScanConfirm => 'راجعت الاسم والتركيز على العلبة';

  @override
  String get medicineScanConfirmNeeded =>
      'علّم هنا بعد ما تراجع الاسم والتركيز';

  @override
  String get medicineScanPrescription => 'روشتة فيها كذا دوا؟ صوّرها';

  @override
  String get medicineUnsureValue => 'مش متأكدين من القراية، راجعها على العلبة';

  @override
  String get medicineFreqOnce => 'مرة في اليوم';

  @override
  String get medicineFreqTwice => 'مرتين';

  @override
  String get medicineFreqThrice => '٣ مرات';

  @override
  String get medicineFreqAsNeeded => 'لما يحتاج';

  @override
  String get medicineAddAnotherTime => 'ميعاد تاني';

  @override
  String medicineChangeTime(String time) {
    return 'غيّر $time';
  }

  @override
  String get medicineOngoing => 'على طول';

  @override
  String get medicineUntilDate => 'لحد يوم معين';

  @override
  String get medicineLastDay => 'آخر يوم';

  @override
  String get medicineMoreDetails => 'تفاصيل أكتر';

  @override
  String get medicineLessDetails => 'تفاصيل أقل';

  @override
  String get medicineClose => 'اقفل';

  @override
  String vaccinesTitleOf(String name) {
    return 'تطعيمات $name';
  }

  @override
  String vaccineProgressLine(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString من $totalString جرعة اتاخدت';
  }

  @override
  String get vaccineNewTitle => 'تطعيم جديد';

  @override
  String get vaccineDoneGroup => 'اللي خلص';

  @override
  String vaccineDoneGroupLast(String date) {
    return 'اتاخدت كلها · آخرها $date';
  }

  @override
  String vaccineGroupCount(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString من $totalString';
  }

  @override
  String get vaccineTickAll => 'تحديد الكل';

  @override
  String get vaccineSetupSkipNow => 'تخطي التطعيمات دلوقتي';

  @override
  String get fieldVaccinePlace => 'فين؟';

  @override
  String get vaccineCardPhoto => 'صورة كارت التطعيم';

  @override
  String get vaccineCardScanTitle => 'صوّر كارت التطعيم';

  @override
  String get vaccineCardScanBody =>
      'بنقرا على الموبايل التواريخ وأسامي التطعيمات المطبوعة بالإنجليزي بس، وإنت بتأكد كل جرعة.';

  @override
  String get vaccineWhich => 'أنهي تطعيم؟';

  @override
  String get vaccineOtherChoice => 'تطعيم تاني';

  @override
  String get vaccineWhoFor => 'لمين؟';

  @override
  String vaccineSavedFor(String vaccine, String name) {
    return 'اتحفظ: $vaccine لـ$name';
  }

  @override
  String vaccineChoiceOverdue(String dose) {
    return '$dose · متأخرة';
  }

  @override
  String growthTitleOf(String name) {
    return 'نمو $name';
  }

  @override
  String get growthNew => 'قياس جديد';

  @override
  String get growthTabWeight => 'الوزن';

  @override
  String get growthTabHeight => 'الطول';

  @override
  String get growthTabHead => 'محيط الراس';

  @override
  String get growthUnitKg => 'كجم';

  @override
  String get growthUnitCm => 'سم';

  @override
  String get growthHistoryTitle => 'القياسات';

  @override
  String growthLegendOwn(String name) {
    return 'قياسات $name';
  }

  @override
  String get growthLegendReference => 'المعدل المرجعي';

  @override
  String growthLastOn(String date) {
    return 'آخر قياس $date';
  }

  @override
  String get growthTabOutside => 'برّه المدى المعتاد';

  @override
  String get pregnancyAddRecord => 'سجّلي زيارة أو تحليل';

  @override
  String get pregnancyNextTitle => 'الجاي';

  @override
  String get pregnancyPastTitle => 'اللي فات';

  @override
  String get pregnancySupplementsTitle => 'الأدوية والمكمّلات النهارده';

  @override
  String get pregnancySupplementsEmpty => 'مفيش حاجة متسجلة للنهارده.';

  @override
  String get pregnancySupplementsAdd => 'ضيفي دوا أو مكمّل';

  @override
  String get reportSummaryNotOpinion =>
      'ده ملخص من اللي العيلة سجلته، مش رأي طبي.';

  @override
  String get followUpsThisWeek => 'النهارده والأسبوع ده';

  @override
  String get followUpsLater => 'بعد كده';

  @override
  String get followUpsAll => 'كل المتابعات';

  @override
  String insuranceWatermark(String name, String date) {
    return '$name · $date';
  }

  @override
  String get insuranceShareWarning =>
      'قبل ما تبعت: الكارت فيه بيانات شخصية، واللي هيستلمه ممكن يبعته لغيره. هنكتب على الصورة التاريخ واسم شركة التأمين لو متسجل.';

  @override
  String get insuranceShareWarningNoPhoto =>
      'قبل ما تبعت: رقم العضوية بيانات شخصية، واللي هيستلمه ممكن يبعته لغيره.';

  @override
  String get simpleNextDose => 'الدوا الجاي';

  @override
  String simpleThenDose(String medicine, String time) {
    return 'وبعده: $medicine الساعة $time';
  }

  @override
  String get simpleNoDoses => 'مفيش جرعات فاضلة النهارده.';

  @override
  String get simpleExit => 'خروج من الوضع البسيط';

  @override
  String get simpleExitWithPin => 'خروج من الوضع البسيط (بالرقم السري)';

  @override
  String get simpleExitConfirm => 'تخرج من الوضع البسيط؟';

  @override
  String get simpleExitStay => 'خليك فيه';

  @override
  String get simpleExitGo => 'اخرج';

  @override
  String get countrySoonNote =>
      'السعودية والأردن هيفتحوا لما جداولهم وأرقام الإسعاف يتراجعوا.';

  @override
  String get homeSetupIntro => 'خطوات ممكن تبدأ بيها. مفيش حاجة منهم إجبارية.';

  @override
  String get homeSetupFamily => 'فرد من العيلة';

  @override
  String get homeSetupFamilyHint => 'الاسم والنوع وتاريخ الميلاد وصلة القرابة';

  @override
  String get homeSetupReminders => 'التذكير بالدوا والتطعيمات';

  @override
  String get homeSetupRemindersHint => 'الإذن بيتطلب وقتها بس';

  @override
  String get homeSetupEmergency => 'كارت الطوارئ';

  @override
  String get homeSetupEmergencyHint => 'فصيلة الدم والحساسية ورقم للطوارئ';

  @override
  String get homeSetupLockNote =>
      'بعد أول نسخة احتياطية هنقترح قفل أسرة برقم سري.';

  @override
  String get homeSetupHide => 'إخفاء';

  @override
  String simpleThenDoseFor(String medicine, String name, String time) {
    return 'وبعده: $medicine لـ$name الساعة $time';
  }

  @override
  String vaccineCatchUp(String date) {
    return 'جرعة تعويضية · ميعادها $date';
  }

  @override
  String get vaccineNextCatchUp => 'جرعات تعويضية (فات سنّها)';

  @override
  String get vaccineDateAssumed =>
      'ده ميعادها على الجدول. غيّره لو اتاخدت في يوم تاني.';

  @override
  String vaccineOptionalWasDue(String date) {
    return 'اختياري · كان ميعادها $date';
  }

  @override
  String get vaccineDoseNotGiven => 'ماتاخدتش';

  @override
  String get prescriptionStopped => 'متوقفة';

  @override
  String get reminderExactOffTitle => 'التنبيهات ممكن تتأخر';

  @override
  String get vaccineCatchUpShort => 'تعويضية';

  @override
  String get vaccineMarkPast => 'علّم على كل اللي فات إنه اتاخد';

  @override
  String get vaccineMarkPastTitle => 'تعلّم على الجرعات اللي فاتت؟';

  @override
  String vaccineMarkPastBody(int count, String upTo) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جرعة إجبارية',
      few: '$count جرعات إجبارية',
      two: 'جرعتين إجباريتين',
      one: 'جرعة إجبارية واحدة',
    );
    return '$_temp0 $upTo هيتعلّم عليها إنها اتاخدت، كل واحدة في ميعادها على الجدول، مش النهارده. راجع كارت التطعيم الأول: الكارت ودكتور الطفل هما المرجع. تقدر ترجع فيها، أو تشيل العلامة من أي جرعة بعدين.';
  }

  @override
  String vaccineUpTo(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'لحد سن $months شهر',
      few: 'لحد سن $months شهور',
      two: 'لحد سن شهرين',
      one: 'لحد سن شهر',
      zero: 'عند الولادة',
    );
    return '$_temp0';
  }

  @override
  String vaccineMarkPastOptional(int count) {
    return 'ومعاها الاختياري اللي ماشيين عليه ($count)';
  }

  @override
  String get vaccineMarkPastOk => 'علّم عليها';

  @override
  String vaccineMarkPastDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اتعلّم على $count جرعة',
      few: 'اتعلّم على $count جرعات',
      two: 'اتعلّم على جرعتين',
      one: 'اتعلّم على جرعة واحدة',
    );
    return '$_temp0';
  }
}
