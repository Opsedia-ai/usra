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
}
