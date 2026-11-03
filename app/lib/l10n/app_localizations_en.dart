// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Usra';

  @override
  String get navHome => 'Home';

  @override
  String get navFamily => 'Family';

  @override
  String get navSettings => 'More';

  @override
  String get homeGreeting => 'Hello! I\'m Dr. Usra';

  @override
  String get homeIntro =>
      'Your family\'s health, in one safe place. Everything stays on this phone.';

  @override
  String get homeColorGuide => 'How colours work';

  @override
  String get severityInfo => 'Info';

  @override
  String get severityGood => 'All good';

  @override
  String get severityHeadsUp => 'Coming up';

  @override
  String get severityActSoon => 'Act soon';

  @override
  String get severityUrgent => 'Urgent';

  @override
  String get familyTitle => 'Our family';

  @override
  String get familyEmpty =>
      'Add the people you care for: kids, parents, grandparents.';

  @override
  String get familyAdd => 'Add a person';

  @override
  String get familyNameLabel => 'Name';

  @override
  String get familySave => 'Save';

  @override
  String get familyCancel => 'Cancel';

  @override
  String get settingsTitle => 'More';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsPrivacy => 'Your data stays on this phone, encrypted.';

  @override
  String get recoveryNotice =>
      'We couldn\'t open your earlier records on this phone, so we kept them aside safely and started fresh. You can restore them from your backup in More.';

  @override
  String get notMedicalDevice =>
      'Usra is not a medical device. Always ask your doctor before medical decisions.';

  @override
  String get familyNew => 'New person';

  @override
  String get familyEdit => 'Edit';

  @override
  String get profileBirthDate => 'Date of birth';

  @override
  String get profileSex => 'Sex';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexMale => 'Male';

  @override
  String get profileBloodType => 'Blood type';

  @override
  String get profileAllergies => 'Allergies';

  @override
  String get profileConditions => 'Chronic conditions';

  @override
  String get profileNotFound => 'Not found';

  @override
  String get pickDate => 'Choose a date';

  @override
  String ageYears(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age years',
      one: '1 year',
      zero: 'Under 1 year',
    );
    return '$_temp0';
  }

  @override
  String get timelineEmpty =>
      'No records yet. Add the first visit, scan or vaccine.';

  @override
  String get addRecord => 'Add record';

  @override
  String get chooseRecordType => 'What do you want to add?';

  @override
  String get recordDate => 'Date';

  @override
  String get recordCost => 'Cost';

  @override
  String get currencyEgp => 'EGP';

  @override
  String get fieldRequired => 'Required';

  @override
  String get fieldInvalid => 'Check this value';

  @override
  String get recordVisit => 'Doctor visit';

  @override
  String get recordScan => 'Scan or X-ray';

  @override
  String get recordLab => 'Lab test';

  @override
  String get recordVaccine => 'Vaccine';

  @override
  String get recordSurgery => 'Surgery';

  @override
  String get fieldDoctorName => 'Doctor';

  @override
  String get fieldReason => 'Reason';

  @override
  String get fieldDiagnosis => 'Diagnosis';

  @override
  String get fieldNextVisit => 'Next visit';

  @override
  String get fieldScanKind => 'Type of scan';

  @override
  String get fieldCenter => 'Scan centre';

  @override
  String get fieldResult => 'Result';

  @override
  String get fieldTest => 'Test';

  @override
  String get fieldValue => 'Value';

  @override
  String get fieldUnit => 'Unit';

  @override
  String get fieldVaccine => 'Vaccine';

  @override
  String get fieldDose => 'Dose number';

  @override
  String get fieldNextDue => 'Next dose';

  @override
  String get fieldProcedure => 'Procedure';

  @override
  String get fieldHospital => 'Hospital';

  @override
  String get fieldFilmed => 'Filmed';

  @override
  String get fieldDaysInHospital => 'Days in hospital';

  @override
  String get scanXray => 'X-ray';

  @override
  String get scanCt => 'CT';

  @override
  String get scanMri => 'MRI';

  @override
  String get scanUltrasound => 'Ultrasound';

  @override
  String get scanOther => 'Other';

  @override
  String get saveFailed => 'Could not save. Please try again.';

  @override
  String get navDoctors => 'Doctors';

  @override
  String get doctorsTitle => 'Family doctors';

  @override
  String get doctorsEmpty =>
      'No doctors yet. Add your family doctor to call them in one tap.';

  @override
  String get doctorsAdd => 'Add doctor';

  @override
  String get doctorNew => 'New doctor';

  @override
  String get doctorEdit => 'Edit doctor';

  @override
  String get doctorName => 'Doctor\'s name';

  @override
  String get doctorSpecialty => 'Specialty';

  @override
  String get doctorPhone => 'Phone number';

  @override
  String get doctorClinic => 'Clinic or hospital';

  @override
  String get doctorAddress => 'Address';

  @override
  String get doctorFee => 'Visit fee';

  @override
  String get doctorNotes => 'Notes';

  @override
  String get doctorCall => 'Call';

  @override
  String get doctorWhatsapp => 'WhatsApp';

  @override
  String get doctorDelete => 'Delete';

  @override
  String doctorDeleteConfirm(String name) {
    return 'Remove $name from your doctors? Past visits stay as they are.';
  }

  @override
  String get doctorVisits => 'Visits';

  @override
  String get doctorNoVisits => 'No visits recorded with this doctor yet.';

  @override
  String get doctorNotFound => 'Doctor not found';

  @override
  String get chooseDoctor => 'Pick from family doctors';

  @override
  String get contactFailed => 'Couldn\'t open that app on this phone';

  @override
  String get navMoney => 'Money';

  @override
  String get spendingTitle => 'Medical spending';

  @override
  String get spendingWeek => 'Week';

  @override
  String get spendingMonth => 'Month';

  @override
  String get spendingYear => 'Year';

  @override
  String get spendingWholeFamily => 'Whole family';

  @override
  String get spendingPrevious => 'Previous';

  @override
  String get spendingNext => 'Next';

  @override
  String get spendingByType => 'By type';

  @override
  String get spendingByPerson => 'By person';

  @override
  String get spendingByDoctor => 'By doctor';

  @override
  String get spendingEmpty => 'No costs recorded in this period.';

  @override
  String get spendingRecent => 'Recent periods';

  @override
  String spendingRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String get memberSpending => 'Spending';

  @override
  String get insuranceTitle => 'Insurance cards';

  @override
  String get insuranceEmpty => 'No insurance cards yet.';

  @override
  String get insuranceAdd => 'Add insurance card';

  @override
  String get insuranceNew => 'New insurance card';

  @override
  String get insuranceEdit => 'Edit card';

  @override
  String get insuranceLabel => 'Card name (e.g. Union, Work)';

  @override
  String get insuranceCard => 'Card';

  @override
  String get insuranceInsurer => 'Insurance company';

  @override
  String get insuranceMemberNumber => 'Member number';

  @override
  String get insuranceExpiry => 'Expiry date';

  @override
  String get insuranceNotes => 'Notes';

  @override
  String get insuranceFront => 'Front of card';

  @override
  String get insuranceBack => 'Back of card';

  @override
  String get insuranceShare => 'Send on WhatsApp';

  @override
  String insuranceShareHeader(String name) {
    return '$name\'s insurance card';
  }

  @override
  String insuranceExpired(String date) {
    return 'Expired $date';
  }

  @override
  String insuranceExpiresSoon(String date) {
    return 'Expires $date';
  }

  @override
  String insuranceValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get insuranceDelete => 'Delete';

  @override
  String insuranceDeleteConfirm(String label) {
    return 'Delete the $label card? Its photos will be removed from this phone.';
  }

  @override
  String get insuranceNotFound => 'Card not found';

  @override
  String get clearDate => 'Clear date';

  @override
  String get photoCamera => 'Take photo';

  @override
  String get photoGallery => 'From photos';

  @override
  String get photoRemove => 'Remove photo';

  @override
  String get photoFailed => 'Couldn\'t get the photo';

  @override
  String get shareFailed => 'Couldn\'t open sharing';

  @override
  String get emergencyTitle => 'Emergency card';

  @override
  String get emergencyUnknown => 'Not recorded';

  @override
  String get emergencyNoneRecorded => 'Nothing recorded';

  @override
  String get emergencySurgeries => 'Past surgeries';

  @override
  String get emergencyComplete => 'Complete emergency details';

  @override
  String emergencyCallAmbulance(String number) {
    return 'Call ambulance $number';
  }

  @override
  String get homeEmergencyTitle => 'Emergency cards';

  @override
  String get homeEmergencyHint => 'Open fast if someone needs an ambulance';

  @override
  String get emergencyLoading => 'Loading…';

  @override
  String get emergencyLoadFailed => 'Couldn\'t read the records';

  @override
  String get recordGrowth => 'Growth measurement';

  @override
  String get fieldWeightKg => 'Weight (kg)';

  @override
  String get fieldHeightCm => 'Length / height (cm)';

  @override
  String get fieldHeadCm => 'Head circumference (cm)';

  @override
  String get memberGrowth => 'Growth and vaccines';

  @override
  String get growthTitle => 'Growth and vaccines';

  @override
  String get growthAdd => 'Add measurement';

  @override
  String get growthWeightForAge => 'Weight for age';

  @override
  String get growthHeightForAge => 'Length / height for age';

  @override
  String get growthAgeAxis => 'Age (months)';

  @override
  String get growthNoSex =>
      'Add the child\'s sex to their profile to see the growth charts.';

  @override
  String get growthNoData => 'No measurements yet.';

  @override
  String growthLatest(String value, String date) {
    return 'Latest: $value on $date';
  }

  @override
  String growthWithinRange(String percentile) {
    return 'Percentile $percentile: within the usual range for this age.';
  }

  @override
  String growthOutsideRange(String percentile) {
    return 'Percentile $percentile: outside the usual range. Talk to your pediatrician.';
  }

  @override
  String get growthSource =>
      'Curves: WHO Child Growth Standards (3rd, 15th, 50th, 85th and 97th percentiles). For information only; your pediatrician reads your child\'s growth.';

  @override
  String get vaccinesTitle => 'Mandatory vaccinations';

  @override
  String get vaccinesDisclaimer =>
      'Based on the Egyptian Ministry of Health and Population\'s mandatory schedule. Schedules change, so the child\'s health office card is the official record.';

  @override
  String get vaccineAtBirth => 'At birth';

  @override
  String vaccineAtMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'At $months months',
      one: 'At 1 month',
    );
    return '$_temp0';
  }

  @override
  String vaccineDone(String date) {
    return 'Done $date';
  }

  @override
  String vaccineDue(String date) {
    return 'Due $date';
  }

  @override
  String vaccineOverdue(String date) {
    return 'Overdue since $date';
  }

  @override
  String vaccineLater(String date) {
    return 'On $date';
  }

  @override
  String vaccineDoseName(String name, int dose) {
    return '$name, dose $dose';
  }

  @override
  String get vaccineHepB => 'Hepatitis B';

  @override
  String get vaccineBcg => 'BCG (tuberculosis)';

  @override
  String get vaccineOpv => 'Oral polio (drops)';

  @override
  String get vaccineIpv => 'Polio injection (IPV)';

  @override
  String get vaccinePenta => 'Pentavalent';

  @override
  String get vaccineMmr => 'MMR (measles, mumps, rubella)';

  @override
  String get vaccineDtp => 'DTP booster';

  @override
  String vaccineZeroDose(String name) {
    return '$name, birth dose';
  }

  @override
  String get growthUnderFiveOnly =>
      'Growth charts and the vaccination schedule are for children under 5 with a birth date in their profile.';

  @override
  String get recordPhotos => 'Photos';

  @override
  String recordPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get recordNotFound => 'This record was deleted';

  @override
  String get recordShare => 'Send';

  @override
  String get recordDelete => 'Delete';

  @override
  String get recordDeleteConfirm =>
      'Delete this record? Its photos will be removed from this phone.';

  @override
  String get photoShare => 'Send photo';

  @override
  String get photoDelete => 'Delete photo';

  @override
  String get photoDeleteConfirm => 'Delete this photo from the record?';

  @override
  String photoPosition(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String get fieldYes => 'Yes';

  @override
  String get fieldNo => 'No';

  @override
  String get navCall => 'Call';

  @override
  String get settingsSimpleMode => 'Simple Mode';

  @override
  String get settingsSimpleModeHint =>
      'Bigger text and buttons, fewer tabs. Good for grandparents using the phone on their own.';

  @override
  String get settingsTutorial => 'Show the tour again';

  @override
  String get profileSimpleMode => 'Uses Simple Mode';

  @override
  String get profileSimpleModeHint =>
      'The phone in their hand: Home greets them by name. Turn Simple Mode on in More on that phone.';

  @override
  String get simpleHello => 'Hello!';

  @override
  String simpleHelloName(String name) {
    return 'Hello, $name';
  }

  @override
  String get simpleMedicines => 'My medicines';

  @override
  String get simpleMedicinesSoon => 'Medicine reminders are coming soon.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get simpleCallDoctor => 'Call my doctor';

  @override
  String get simpleFamily => 'My family';

  @override
  String get simpleEmergency => 'Emergency card';

  @override
  String get simplePickPerson => 'Whose emergency card?';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialBack => 'Back';

  @override
  String get tutorialStart => 'Let\'s start';

  @override
  String tutorialStep(int current, int total) {
    return '$current of $total';
  }

  @override
  String get tutorialWelcomeTitle => 'Hi, I\'m Dr. Usra';

  @override
  String get tutorialWelcomeBody =>
      'Usra keeps your family\'s health in one place: doctor visits, tests, medicines and your doctors\' numbers.';

  @override
  String get tutorialPrivacyTitle => 'Your data stays with you';

  @override
  String get tutorialPrivacyBody =>
      'Everything is saved on this phone, encrypted. No account needed.';

  @override
  String get tutorialFamilyTitle => 'Add your family';

  @override
  String get tutorialFamilyBody =>
      'Add everyone you care for: kids, parents, grandparents. Each person gets their own page.';

  @override
  String get tutorialColorsTitle => 'Colours mean urgency';

  @override
  String get tutorialColorsBody =>
      'Every colour comes with a word, so you always know what it means.';

  @override
  String get tutorialEmergencyTitle => 'An emergency card for everyone';

  @override
  String get tutorialEmergencyBody =>
      'Blood type, allergies and illnesses on one card, one tap from Home. Show it to a doctor or paramedic.';

  @override
  String get tutorialElderWelcomeBody =>
      'I\'m here to help you. Everything on the screen is big and clear.';

  @override
  String get tutorialElderButtonsTitle => 'Big buttons on Home';

  @override
  String get tutorialElderButtonsBody =>
      'Press «Call my doctor» to call your doctor with one tap.';

  @override
  String get tutorialElderEmergencyTitle => 'If you feel unwell';

  @override
  String get tutorialElderEmergencyBody =>
      'Press the red «Emergency card» button and show it to whoever is helping you.';

  @override
  String get scanMedicineTitle => 'Scan a medicine box';

  @override
  String get scanMedicineIntro =>
      'Take a clear photo of the front of the box in good light. Usra reads the name and strength printed in English letters.';

  @override
  String get scanMedicineLimits =>
      'Handwritten prescriptions and Arabic text can\'t be read on the phone yet. Type those in yourself.';

  @override
  String get scanMedicinePrivacy =>
      'The photo is read on this phone and isn\'t kept.';

  @override
  String get scanMedicineReading => 'Reading the box…';

  @override
  String get scanMedicineSuggestions => 'Is it one of these?';

  @override
  String get scanMedicineNoneFound =>
      'Couldn\'t find a medicine name. Type it in, or try another photo.';

  @override
  String get scanMedicineFailed =>
      'Couldn\'t read this photo. Try another one, or type the name in.';

  @override
  String get scanMedicineName => 'Medicine name';

  @override
  String get scanMedicineStrength => 'Strength (optional), e.g. 500mg';

  @override
  String get scanMedicineCheck =>
      'Check the name against the box before you use it.';

  @override
  String get scanMedicineUse => 'Use this';

  @override
  String get scanMedicineRetake => 'Another photo';

  @override
  String get scanMedicinePhoto => 'Photo of the medicine box';

  @override
  String get followUpsTitle => 'Follow-ups';

  @override
  String get followUpsEmpty => 'Nothing coming up.';

  @override
  String get followUpsDisclaimer =>
      'Suggestions from public guidance (WHO, USPSTF and others) and your records, not a diagnosis. Ask your doctor what suits each person.';

  @override
  String followUpDue(String date) {
    return 'Due $date';
  }

  @override
  String followUpOverdue(String date) {
    return 'Was due $date';
  }

  @override
  String followUpSource(String source) {
    return 'Source: $source';
  }

  @override
  String followUpAdd(String type) {
    return 'Add $type';
  }

  @override
  String get followUpDismiss => 'Hide until next time';

  @override
  String get followUpDismissed => 'Hidden until it\'s due again.';

  @override
  String get followUpUndo => 'Undo';

  @override
  String get fuNextVisit => 'Follow-up visit';

  @override
  String fuNextVisitBy(String doctor) {
    return '$doctor set this date at the last visit';
  }

  @override
  String get fuNextVisitSet => 'Set at the last visit';

  @override
  String fuNextDose(String vaccine) {
    return 'Next dose: $vaccine';
  }

  @override
  String get fuNextDoseSet => 'The date written on the last dose';

  @override
  String get fuHba1c => 'HbA1c (3-month sugar) test';

  @override
  String get fuLipids => 'Lipid profile (cholesterol)';

  @override
  String get fuKidney => 'Kidney function and urine albumin';

  @override
  String get fuScan => 'Follow-up scan';

  @override
  String get fuScanResult => 'The last scan\'s result mentions a follow-up';

  @override
  String get fuBloodPressure => 'Blood pressure check';

  @override
  String get fuBloodSugar => 'Blood sugar test';

  @override
  String get fuMammogram => 'Mammogram (breast screening)';

  @override
  String get fuColorectal => 'Colon cancer screening';

  @override
  String get fuEyeExam => 'Eye exam (retina)';

  @override
  String get fuDental => 'Dental check-up';

  @override
  String get fuChildCheckup => 'Child check-up';

  @override
  String fuChildCheckupAt(String age) {
    return 'The usual check-up at $age';
  }

  @override
  String fuAgeMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get fuVaccinesDue => 'Mandatory vaccines';

  @override
  String fuVaccinesAt(String age, String names) {
    return '$age: $names';
  }

  @override
  String fuBecauseCondition(String sex, String condition) {
    return 'Because of $condition';
  }

  @override
  String fuLastDoneMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'last one $months months ago',
      one: 'last one a month ago',
      zero: 'last one this month',
    );
    return '$_temp0';
  }

  @override
  String get fuNeverRecorded => 'none recorded yet';

  @override
  String fuAgeFrom(int age) {
    return 'Suggested from age $age';
  }

  @override
  String fuAgeRange(int from, int to) {
    return 'Suggested at ages $from–$to';
  }

  @override
  String fuWomenAgeRange(int from, int to) {
    return 'Suggested for women aged $from–$to';
  }

  @override
  String get fuYearlyForAll => 'Suggested once a year for everyone';

  @override
  String get conditionDiabetes => 'diabetes';

  @override
  String get conditionHypertension => 'high blood pressure';

  @override
  String get conditionHeart => 'heart disease';

  @override
  String get conditionHighCholesterol => 'high cholesterol';

  @override
  String get conditionKidney => 'kidney disease';

  @override
  String get navMedicines => 'Medicines';

  @override
  String get medicinesTodayTitle => 'Today\'s medicines';

  @override
  String get medicinesTodayEmpty =>
      'No doses due today. Add a medicine from a person\'s page in Family.';

  @override
  String get doseTaken => 'Taken';

  @override
  String get doseSkip => 'Skip';

  @override
  String get doseSkipped => 'Skipped';

  @override
  String get doseSnoozed => 'Snoozed';

  @override
  String get doseSnooze => 'Snooze 10 min';

  @override
  String get doseUndo => 'Undo';

  @override
  String doseMarkedAt(String status, String time) {
    return '$status at $time';
  }

  @override
  String doseReminderTitle(String person, String medicine) {
    return 'Time for $person\'s medicine: $medicine';
  }

  @override
  String get doseReminderBody => 'Tap Taken once it\'s done';

  @override
  String get doseChannelName => 'Medicine reminders';

  @override
  String get doseChannelDescription =>
      'Reminders at the times the doctor prescribed';

  @override
  String get memberMedicines => 'Medicines';

  @override
  String medicinesTitle(String name) {
    return '$name\'s medicines';
  }

  @override
  String get medicinesEmpty =>
      'No medicines yet. Add one exactly as the doctor wrote it.';

  @override
  String get medicineAdd => 'Add medicine';

  @override
  String get medicineNew => 'New medicine';

  @override
  String get medicineEdit => 'Edit medicine';

  @override
  String get medicineName => 'Medicine name';

  @override
  String get medicineStrength => 'Strength (as on the box)';

  @override
  String get medicineForm => 'Form';

  @override
  String get formTablet => 'Tablet';

  @override
  String get formCapsule => 'Capsule';

  @override
  String get formSyrup => 'Syrup';

  @override
  String get formDrops => 'Drops';

  @override
  String get formInjection => 'Injection';

  @override
  String get formCream => 'Cream';

  @override
  String get formInhaler => 'Inhaler';

  @override
  String get formOther => 'Other';

  @override
  String get medicineInstructions => 'Doctor\'s instructions';

  @override
  String get medicineInstructionsHint =>
      'Exactly as written on the prescription';

  @override
  String get medicineDoctor => 'Prescribed by';

  @override
  String get medicineNoDoctor => 'Not set';

  @override
  String get medicineStart => 'First day';

  @override
  String get medicineEnd => 'Last day (optional)';

  @override
  String get medicineEndBeforeStart => 'The last day is before the first day';

  @override
  String get medicinePhotos => 'Photos of the box or prescription';

  @override
  String get medicineSchedule => 'Schedule';

  @override
  String get medicineAddTime => 'Add a time';

  @override
  String medicineRemoveTime(String time) {
    return 'Remove $time';
  }

  @override
  String get medicineNoTimes => 'No times means no reminders (as needed).';

  @override
  String get medicineAmount => 'Amount each time';

  @override
  String get medicineAmountHint => 'As the doctor wrote it, e.g. 1 tablet';

  @override
  String get medicineRepeat => 'How often';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeekdays => 'Some days';

  @override
  String get repeatEveryN => 'Every few days';

  @override
  String get medicineEveryN => 'Every how many days';

  @override
  String get medicineEveryNInvalid => 'Enter a number from 2 to 60';

  @override
  String get medicineWeekdaysEmpty => 'Pick at least one day';

  @override
  String get medicineStop => 'Stop taking';

  @override
  String get medicineResume => 'Taking it again';

  @override
  String get medicineStopped => 'Stopped';

  @override
  String get medicineEnded => 'Ended';

  @override
  String get medicineDelete => 'Delete';

  @override
  String medicineDeleteConfirm(String name) {
    return 'Delete $name and its history? Its photos will be removed from this phone.';
  }

  @override
  String get medicineNotFound => 'This medicine was deleted';

  @override
  String get medicineHistory => 'History';

  @override
  String get medicineHistoryEmpty => 'Nothing marked yet.';

  @override
  String get medicineAsNeeded => 'As needed, no reminders';

  @override
  String medicineNextDose(String when) {
    return 'Next dose: $when';
  }

  @override
  String medicineFromTo(String start, String end) {
    return 'From $start to $end';
  }

  @override
  String medicineFrom(String start) {
    return 'From $start';
  }

  @override
  String get scheduleEveryDay => 'Every day';

  @override
  String scheduleEveryNDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String get reminderOffTitle => 'Reminders are off';

  @override
  String get reminderOffBody =>
      'Allow notifications so Usra can remind you at medicine times.';

  @override
  String get reminderExactOff =>
      'Allow \"Alarms & reminders\" so doses ring on time, not a few minutes late.';

  @override
  String get reminderAllow => 'Allow';

  @override
  String get reminderBatteryTitle => 'Make reminders reliable';

  @override
  String get reminderBatteryBody =>
      'Some phones stop apps in the background to save battery. Set Usra\'s battery use to \"Unrestricted\" so reminders always ring.';

  @override
  String get reminderBatteryOpen => 'Battery settings';

  @override
  String get backupTitle => 'Backup';

  @override
  String get settingsBackupHint =>
      'Keep a copy of the family\'s records off this phone';

  @override
  String get backupIntro =>
      'A backup is one encrypted file with all the family\'s records and photos. Save it to Google Drive or Files, or send it to yourself on WhatsApp. To open it on a new phone you\'ll need your recovery key.';

  @override
  String get backupNever => 'No backup yet';

  @override
  String backupLast(String date) {
    return 'Last backup: $date';
  }

  @override
  String get backupNow => 'Back up now';

  @override
  String get backupWorking => 'Preparing the backup…';

  @override
  String get backupShareSubject => 'Usra backup';

  @override
  String get backupDone =>
      'Backup ready. Keep it somewhere safe off this phone.';

  @override
  String get backupFailed => 'Couldn\'t make the backup. Try again.';

  @override
  String get backupDueTitle => 'Back up the family\'s records';

  @override
  String get backupDueNever =>
      'If this phone is lost, the records go with it. Make an encrypted backup and keep it off the phone.';

  @override
  String get backupDueOld => 'Your last backup is more than 30 days old.';

  @override
  String get recoveryKeyTitle => 'Recovery key';

  @override
  String get recoveryKeyIntro =>
      'This is your recovery key. Write it on paper and keep it somewhere safe, away from this phone. You\'ll need it to open your backups on a new phone.';

  @override
  String get recoveryKeyShowIntro =>
      'This is the key that opens your backups. Check it matches the one you wrote down.';

  @override
  String get recoveryKeyLoseWarning =>
      'Without this key nobody can open your backups, not even us. If it\'s lost, we can\'t get it back.';

  @override
  String get recoveryKeyWrittenDown => 'I wrote it down';

  @override
  String get recoveryKeyConfirmIntro =>
      'To be sure it\'s written correctly, type these two groups from your paper.';

  @override
  String recoveryKeyGroupLabel(int number) {
    return 'Group $number';
  }

  @override
  String get recoveryKeyConfirm => 'Confirm';

  @override
  String get recoveryKeyShowAgain => 'Show the key again';

  @override
  String recoveryKeyMismatch(String groups) {
    return 'Group $groups doesn\'t match. Check your paper.';
  }

  @override
  String get recoveryKeyShow => 'Show recovery key';

  @override
  String get restoreTitle => 'Restore from a backup';

  @override
  String get restoreHint => 'Replaces everything on this phone';

  @override
  String get restoreIntro =>
      'Choose your backup file (it ends in .usra) from Drive, Files or WhatsApp, then type your recovery key.';

  @override
  String get restorePick => 'Choose the backup file';

  @override
  String get restoreKeyLabel => 'Recovery key (36 digits)';

  @override
  String restoreKeyGroupsWrong(String groups) {
    return 'Group $groups of the key isn\'t right. Check it against your paper.';
  }

  @override
  String get restoreOpen => 'Open the backup';

  @override
  String get restoreNotABackup => 'This file isn\'t a Usra backup.';

  @override
  String get restoreWrongKey =>
      'This recovery key doesn\'t open this backup. Check it, or try the key you had when the backup was made.';

  @override
  String get restoreDamaged =>
      'This backup file is incomplete or damaged. Try downloading it again.';

  @override
  String get restoreTooNew =>
      'This backup was made with a newer version of Usra. Update the app, then try again.';

  @override
  String get restoreFailed => 'Couldn\'t open the backup. Try again.';

  @override
  String restoreFrom(String date) {
    return 'Backup from $date';
  }

  @override
  String restoreContents(int people, int records, int medicines, int photos) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      records,
      locale: localeName,
      other: '$records records',
      one: '1 record',
    );
    String _temp2 = intl.Intl.pluralLogic(
      medicines,
      locale: localeName,
      other: '$medicines medicines',
      one: '1 medicine',
    );
    String _temp3 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos photos',
      one: '1 photo',
    );
    return '$_temp0, $_temp1, $_temp2, $_temp3';
  }

  @override
  String get restoreReplaceWarning =>
      'Everything on this phone now will be replaced by this backup.';

  @override
  String get restoreReplace => 'Restore and replace';

  @override
  String get restoreDoneNotice => 'Your backup is restored.';

  @override
  String get restoreFailedNotice =>
      'We couldn\'t restore the backup, so your records stayed as they were.';

  @override
  String get backupSavedQuestion =>
      'Did you save the backup or send it somewhere?';

  @override
  String get backupSavedYes => 'Yes, saved';

  @override
  String get backupSavedNo => 'No';
}
