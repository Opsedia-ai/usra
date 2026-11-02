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
}
