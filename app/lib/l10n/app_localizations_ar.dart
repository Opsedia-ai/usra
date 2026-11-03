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
    return 'المئين $percentile: في المدى المعتاد للسن ده.';
  }

  @override
  String growthOutsideRange(String percentile) {
    return 'المئين $percentile: برّه المدى المعتاد. اتكلم مع دكتور الأطفال.';
  }

  @override
  String get growthSource =>
      'المنحنيات من معايير نمو الطفل بتاعة منظمة الصحة العالمية (المئين ٣ و١٥ و٥٠ و٨٥ و٩٧). للمعلومة بس؛ دكتور الأطفال هو اللي يقيّم نمو طفلك.';

  @override
  String get vaccinesTitle => 'التطعيمات الإجبارية';

  @override
  String get vaccinesDisclaimer =>
      'حسب جدول التطعيمات الإجبارية بتاع وزارة الصحة والسكان المصرية. الجداول بتتغير، وكارت التطعيم بتاع مكتب الصحة هو المرجع الرسمي.';

  @override
  String get vaccineAtBirth => 'عند الولادة';

  @override
  String vaccineAtMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'عند $months شهر',
      few: 'عند $months شهور',
      two: 'عند شهرين',
      one: 'عند شهر',
    );
    return '$_temp0';
  }

  @override
  String vaccineDone(String date) {
    return 'اتاخد $date';
  }

  @override
  String vaccineDue(String date) {
    return 'معاده $date';
  }

  @override
  String vaccineOverdue(String date) {
    return 'متأخر من $date';
  }

  @override
  String vaccineLater(String date) {
    return 'يوم $date';
  }

  @override
  String vaccineDoseName(String name, int dose) {
    return '$name، جرعة $dose';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة',
      few: '$count صور',
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
  String get recordDelete => 'امسح';

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
    return 'صورة $index من $total';
  }

  @override
  String get fieldYes => 'أيوه';

  @override
  String get fieldNo => 'لأ';

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
  String get doseSkip => 'فوّته';

  @override
  String get doseSkipped => 'اتفوّت';

  @override
  String get doseSnoozed => 'متأجل';

  @override
  String get doseSnooze => 'أجّل 10 دقايق';

  @override
  String get doseUndo => 'رجوع';

  @override
  String doseMarkedAt(String status, String time) {
    return '$status الساعة $time';
  }

  @override
  String doseReminderTitle(String person, String medicine) {
    return 'ميعاد دوا $person: $medicine';
  }

  @override
  String get doseReminderBody => 'دوس اتاخد بعد ما ياخده';

  @override
  String get doseChannelName => 'مواعيد الأدوية';

  @override
  String get doseChannelDescription => 'تنبيه في المواعيد اللي الدكتور كتبها';

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
  String get medicineAmountHint => 'زي ما الدكتور كتب، مثلاً: قرص واحد';

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
  String get medicineEveryNInvalid => 'اكتب رقم من 2 لـ 60';

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
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'كل $n يوم',
      few: 'كل $n أيام',
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
}
