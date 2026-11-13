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
  String get homeGreeting => 'Hello! I\'m your guide in Usra';

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
  String get recoveryNotice =>
      'We couldn\'t open your earlier records on this phone, so we kept them aside safely and started fresh. You can restore them from your backup in More.';

  @override
  String get notMedicalDevice =>
      'Usra is not a medical device. Always ask your doctor before medical decisions.';

  @override
  String get aboutTitle => 'Privacy and terms';

  @override
  String get aboutHint => 'How your data is kept, and the app version';

  @override
  String get aboutPrivacyHeading => 'Your privacy, in plain words';

  @override
  String get aboutPrivacyOnPhone =>
      'Everything you record stays on this phone. Records are in an encrypted database; photos are in the app\'s private storage, never in your gallery or in cloud backups. We don\'t receive any of it and can\'t see it.';

  @override
  String get aboutPrivacyNoAccount =>
      'No account, no sign-in, no ads and no tracking. We never sell or share anyone\'s data.';

  @override
  String get aboutPrivacyOptionalAccount =>
      'Saving records needs a sign-in, and there are no ads and no tracking. We keep your email, account ID, language and device information to run the account, plus your name and profile photo link if you use Google. We never receive your health records. We never sell or share anyone\'s data.';

  @override
  String get aboutPrivacyBackup =>
      'A backup is an encrypted file you keep wherever you choose. Only your recovery key opens it, and we don\'t have it.';

  @override
  String get aboutPrivacyPhotos =>
      'The camera and photos are used only when you choose, and text is read from them on this phone.';

  @override
  String get aboutPrivacyReminders =>
      'Reminders are set on this phone. From the start they show general text with no names. If \"Discreet notifications\" is turned off, people\'s names and medicine names can show on the lock screen. The home-screen widget has no names, only times and how many doses.';

  @override
  String get aboutPrivacyDelete =>
      'You can erase everything Usra keeps on this phone at any time: More › Delete all my data.';

  @override
  String get aboutPrivacyGoogle =>
      'The text reader is made by Google and may send Google technical data with a random install ID, not linked to you. Never your photos, the text or your records.';

  @override
  String get aboutMedicalHeading => 'Medical disclaimer';

  @override
  String get aboutMedicalBody =>
      'Usra is not a medical device. It doesn\'t diagnose or treat, and it doesn\'t replace your doctor. Growth charts, vaccine dates, suggestions and text read from photos are for organising and general information, and can be wrong. Always ask your doctor or pharmacist before medical decisions. In an emergency, call 123 in Egypt or your local emergency number.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutPrivacyPolicy => 'Privacy policy';

  @override
  String get aboutTerms => 'Terms of use';

  @override
  String get aboutLinkFailed =>
      'Couldn\'t open the page. Check your internet connection.';

  @override
  String get familyNew => 'New person';

  @override
  String get familyEdit => 'Edit';

  @override
  String get profileBirthDate => 'Date of birth';

  @override
  String get profileSex => 'Sex';

  @override
  String get profileRelationship => 'Relationship';

  @override
  String relationshipMine(String relationship) {
    String _temp0 = intl.Intl.selectLogic(relationship, {
      'son': 'My son',
      'daughter': 'My daughter',
      'husband': 'My husband',
      'wife': 'My wife',
      'father': 'My father',
      'mother': 'My mother',
      'brother': 'My brother',
      'sister': 'My sister',
      'grandfather': 'My grandfather',
      'grandmother': 'My grandmother',
      'other': 'Someone else',
    });
    return '$_temp0';
  }

  @override
  String relationshipYours(String relationship) {
    String _temp0 = intl.Intl.selectLogic(relationship, {
      'son': 'Your son',
      'daughter': 'Your daughter',
      'husband': 'Your husband',
      'wife': 'Your wife',
      'father': 'Your father',
      'mother': 'Your mother',
      'brother': 'Your brother',
      'sister': 'Your sister',
      'grandfather': 'Your grandfather',
      'grandmother': 'Your grandmother',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get profileEmergencyPhone => 'Emergency number';

  @override
  String get profileEmergencyPhoneHint =>
      'Optional. Shown on the emergency card, and on Usra\'s lock screen if the card is available there.';

  @override
  String get profileEmergencyInvalid => 'That isn\'t a phone number.';

  @override
  String get profileEmergencyName => 'Whose number';

  @override
  String get profileEmergencyNameHint =>
      'Optional. For example: Aya, his mother.';

  @override
  String get emergencyContactNoName => 'Emergency number';

  @override
  String emergencyCallNumber(String phone) {
    return 'Call the emergency number: $phone';
  }

  @override
  String emergencyCallContact(String name, String phone) {
    return 'Call $name: $phone';
  }

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
    final intl.NumberFormat ageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String ageString = ageNumberFormat.format(age);

    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$ageString years',
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
  String get recordLab => 'Lab results';

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
  String recordPdf(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'PDF $numberString';
  }

  @override
  String get fieldLab => 'Lab';

  @override
  String get fieldOrderedBy => 'Requested by (optional)';

  @override
  String get fieldTests => 'Tests';

  @override
  String get labResultsTitle => 'Results';

  @override
  String labTestNumber(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Test $numberString';
  }

  @override
  String get labTestName => 'Test name';

  @override
  String get labTestValue => 'Result';

  @override
  String get labTestUnit => 'Unit';

  @override
  String get labTestRange => 'Range printed by the lab';

  @override
  String get labTestRangeHint => 'e.g. 4 - 11 or < 200';

  @override
  String get labAddTest => 'Add another test';

  @override
  String get labRemoveTest => 'Remove this test';

  @override
  String get labNeedOneTest => 'Add at least one test with its result';

  @override
  String get labFlagHigh => 'Above the lab\'s range';

  @override
  String get labFlagLow => 'Below the lab\'s range';

  @override
  String get labFlagNormal => 'Within the lab\'s range';

  @override
  String get labFlagUnknown => 'No range to compare with';

  @override
  String get labInfoNote =>
      'Compared only with the range printed on the report. This isn\'t a diagnosis: ask your doctor what the results mean for you.';

  @override
  String get labScanTitle => 'Read the report from a photo';

  @override
  String get labScanCamera => 'Take a photo';

  @override
  String get labScanGallery => 'From the gallery';

  @override
  String get labScanHelp =>
      'The phone reads printed English results itself; nothing is sent anywhere. The photo is kept, encrypted, with the report. Check every value against the paper before saving.';

  @override
  String get labScanReading => 'Reading the report…';

  @override
  String labScanFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Found $countString results. Highlighted boxes are ones the phone wasn\'t sure of: check them against the paper.';
  }

  @override
  String get labScanNothing =>
      'Couldn\'t find results in this photo. Type them in; the photo is kept with the report.';

  @override
  String get labScanFailed => 'Couldn\'t read the photo';

  @override
  String labScanSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString tests were already in the form, so their new readings weren\'t added.',
      one: '1 test was already in the form, so its new reading wasn\'t added.',
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
      other: 'Use the $countString new readings',
      one: 'Use the new reading',
    );
    return '$_temp0';
  }

  @override
  String get labScanNothingNew =>
      'Nothing new on this photo: its results are already here.';

  @override
  String get labCheckThis => 'Check this against the paper';

  @override
  String get labConfirmRow => 'Matches the paper';

  @override
  String get labConfirmFirstCheck => 'Check the marked boxes first';

  @override
  String get labConfirmNeeded =>
      'Before saving, confirm each row read from the photo, and check every marked box, against the paper.';

  @override
  String get labCheckedIt => 'I checked it';

  @override
  String get labPickRange =>
      'Several ranges are printed: pick the one that applies';

  @override
  String get labScanPhoto => 'The photo of the report';

  @override
  String get labPhotoFullScreen => 'Full screen';

  @override
  String get labAttachPdf => 'Add a PDF';

  @override
  String get labRemovePdf => 'Remove the PDF';

  @override
  String labRangeLine(String range) {
    return 'Lab\'s range: $range';
  }

  @override
  String labLatest(String value, String date) {
    return 'Latest: $value on $date';
  }

  @override
  String get labNoResults => 'No lab results with numbers yet.';

  @override
  String get labUnitsApart =>
      'Results in different units are shown apart, never converted.';

  @override
  String get labAllResults => 'All results';

  @override
  String get labAddReport => 'Add a lab report';

  @override
  String get memberLabs => 'Lab results';

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
  String get fieldFilmed => 'Filmed?';

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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString records',
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
    return 'Within the reference range for this age (percentile $percentile).';
  }

  @override
  String growthOutsideRange(String percentile) {
    return 'Percentile $percentile: outside the usual range. Talk to your pediatrician.';
  }

  @override
  String get growthSource =>
      'Curves: WHO Child Growth Standards (3rd, 15th, 50th, 85th and 97th percentiles). For information only; your pediatrician reads your child\'s growth.';

  @override
  String get vaccinesTitle => 'Vaccinations';

  @override
  String vaccinesDisclaimer(String date) {
    return 'Required doses follow the Egyptian Ministry of Health and Population\'s schedule; optional ones follow common private-practice schedules (checked $date). For information only: schedules change, and the child\'s health office card and doctor are the reference.';
  }

  @override
  String get vaccineAtBirth => 'At birth';

  @override
  String vaccineAtMonths(int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'At $monthsString months',
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
    final intl.NumberFormat doseNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doseString = doseNumberFormat.format(dose);

    return '$name, dose $doseString';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos',
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
  String get recordClearDate => 'Remove the date';

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
    final intl.NumberFormat indexNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Photo $indexString of $totalString';
  }

  @override
  String get fieldYes => 'Yes';

  @override
  String get fieldNo => 'No';

  @override
  String get navCall => 'Call';

  @override
  String get drUsraWelcome => 'Dr. Usra waving';

  @override
  String get drUsraExplaining => 'Dr. Usra explaining';

  @override
  String get drUsraEmptyState => 'Dr. Usra holding a plus';

  @override
  String get drUsraCelebrating => 'Dr. Usra celebrating';

  @override
  String get drUsraResting => 'Dr. Usra resting';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get settingsThemeSystem => 'Same as phone';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsSimpleMode => 'Simple Mode';

  @override
  String get settingsSimpleModeHint =>
      'Bigger text and buttons, fewer tabs. Good for grandparents using the phone on their own.';

  @override
  String get settingsAiTitle => 'Dr. Usra AI';

  @override
  String get settingsAiSoon => 'Coming soon';

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
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString of $totalString';
  }

  @override
  String get tutorialWelcomeTitle => 'Hi, I\'m your guide in Usra';

  @override
  String get tutorialWelcomeBody =>
      'Usra keeps your family\'s health in one place: doctor visits, tests, medicines and your doctors\' numbers.';

  @override
  String get tutorialPrivacyTitle => 'Your data stays with you';

  @override
  String get tutorialPrivacyBody =>
      'Everything is saved on this phone, encrypted. No account needed.';

  @override
  String get tutorialPrivacyBodyAccount =>
      'Records are saved on this phone, encrypted. The account doesn\'t hold them.';

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
  String get scanMedicineStrength => 'Strength (optional)';

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
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$monthsString months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get fuVaccinesDue => 'Vaccinations';

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
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'last one $monthsString months ago',
      one: 'last one a month ago',
      zero: 'last one this month',
    );
    return '$_temp0';
  }

  @override
  String get fuNeverRecorded => 'none recorded yet';

  @override
  String fuAgeFrom(int age) {
    final intl.NumberFormat ageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String ageString = ageNumberFormat.format(age);

    return 'Suggested from age $ageString';
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

    return 'Suggested at ages $fromString–$toString';
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

    return 'Suggested for women aged $fromString–$toString';
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
  String get doseSkip => 'Not taken';

  @override
  String get doseSkipped => 'Not taken';

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
  String doseReminderBody(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'other': 'Tap Taken once it\'s done',
    });
    return '$_temp0';
  }

  @override
  String get doseChannelName => 'Medicine reminders';

  @override
  String get doseChannelDescription =>
      'Reminders at the times the doctor prescribed';

  @override
  String get widgetEmpty => 'No medicines today';

  @override
  String get widgetStale => 'Open Usra to refresh medicines';

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
  String get medicineMoveAction => 'Move to another person';

  @override
  String get medicineMoveTitle => 'Move medicine';

  @override
  String medicineMoveNow(String name) {
    return 'Now with $name';
  }

  @override
  String get medicineMoveTo => 'Move it to who?';

  @override
  String get medicineMoveWhatTitle => 'Moves with the medicine';

  @override
  String get medicineMoveWhat => 'Times, reminders, recorded doses and photos.';

  @override
  String medicineMoveStaysTitle(String name) {
    return 'Stays with $name';
  }

  @override
  String get medicineMoveStaysPrescription =>
      'The prescription, with its date and photos. The medicine comes off its list.';

  @override
  String get medicineMoveStaysSickDays =>
      'Doses recorded in sick days, by the medicine\'s name.';

  @override
  String get medicineMoveStopsNextDose =>
      'The next-dose reminder in the sick day stops.';

  @override
  String medicineMoveReminder(String to, String from) {
    return 'After the move, reminders are for $to, not $from.';
  }

  @override
  String get medicineMoveChoose => 'Choose a person first';

  @override
  String medicineMoveConfirm(String name) {
    return 'Move to $name';
  }

  @override
  String medicineMoveKeep(String name) {
    return 'Keep with $name';
  }

  @override
  String medicineMoveDone(String name) {
    return 'Medicine moved to $name.';
  }

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
  String get medicineAmountHint => 'As the doctor wrote it';

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
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $nString days',
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
      'If this phone is lost, the records go with it. The backup is encrypted and kept off the phone';

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
  String get recoveryKeyWrittenDown => 'I wrote it down, continue';

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
  String get recoveryKeyCopy => 'Copy the key';

  @override
  String get recoveryKeyCopied =>
      'Copied. It\'s cleared from the clipboard in a minute: paste it into your password manager now.';

  @override
  String get shareWarningTitle => 'Share outside Usra?';

  @override
  String get shareWarningBody =>
      'Once it\'s sent, Usra\'s lock and encryption no longer protect it: the other app, and anyone who sees that chat or folder, can open it. Check you\'ve picked the right person.';

  @override
  String get shareWarningDontAsk => 'Don\'t ask again';

  @override
  String get shareWarningCancel => 'Cancel';

  @override
  String get shareWarningGo => 'Share';

  @override
  String get rootWarningTitle => 'This phone\'s protections are switched off';

  @override
  String get rootWarningBody =>
      'This phone looks rooted or jailbroken. Other apps on it may be able to read Usra\'s files and see the screen, so your family\'s records are less safe here.\n\nUsra keeps working as normal. If you can, use a phone that isn\'t modified, and keep the app lock on.';

  @override
  String get rootWarningOk => 'I understand';

  @override
  String get settingsDeleteAll => 'Delete all my data';

  @override
  String get settingsDeleteAllHint =>
      'Erase everything Usra keeps on this phone';

  @override
  String get wipeTitle => 'Delete all my data';

  @override
  String get wipeIntro =>
      'This erases everything Usra keeps on this phone and starts it again as new:';

  @override
  String get wipeList =>
      '• Every person, record, medicine, doctor and insurance card\n• All photos\n• The keys that lock them, the recovery key saved on this phone and the app lock\n• Reminders, the home-screen widget and settings\n• You\'re signed out of your account (the account itself stays; delete it from Account first if you want)';

  @override
  String get wipeKeeps =>
      'Backup files you saved somewhere else (Drive, WhatsApp, Files) aren\'t touched. They still open with your recovery key, so you can bring the records back.';

  @override
  String get wipeNoUndo =>
      'This can\'t be undone. Without a backup and its recovery key, the records are gone for good.';

  @override
  String get wipeBackupFirst => 'Make a backup first';

  @override
  String get wipeConfirmWord => 'DELETE';

  @override
  String wipeTypeLabel(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get wipeButton => 'Delete everything';

  @override
  String get wipeWorking => 'Deleting…';

  @override
  String get wipeReopenFailed =>
      'Usra couldn\'t open again after deleting. Close it and open it again.';

  @override
  String get databaseKeyUnavailable =>
      'Usra can\'t open the key to your records right now. Your records are still here and nothing was deleted. Try again, or restart your phone. If this keeps happening, contact us before deleting the app.';

  @override
  String get databaseOpenFailed =>
      'Usra can\'t open your records right now. Your records are still here and nothing was deleted. Check that your phone has free storage, then try again or restart your phone. If this keeps happening, contact us before deleting the app.';

  @override
  String get databaseSupportLabel => 'Help and support:';

  @override
  String get databaseSupportAddress => 'aya@opsedia.ai';

  @override
  String get databaseStartFresh => 'Start fresh';

  @override
  String get databaseStartFreshHint =>
      'A last resort, if there\'s no backup and this won\'t go away. It deletes everything Usra keeps on this phone.';

  @override
  String get databaseStartFreshIntro =>
      'Your records won\'t open, but they may still be on this phone. If you have a backup, go back and try restoring it first. Writing to us first may help too.';

  @override
  String get recoveryKeyCopyFailed =>
      'Couldn\'t copy the key. Write it down from the screen instead.';

  @override
  String get wipeDoneNotice =>
      'Everything Usra kept on this phone was deleted.';

  @override
  String get wipeIncompleteNotice =>
      'Some of Usra\'s data couldn\'t be deleted. Usra will try again the next time it starts.';

  @override
  String get lockSettingsWipe => 'Erase after 10 wrong PINs';

  @override
  String get lockSettingsWipeHint =>
      'Deletes all data on this phone after 10 wrong PINs in a row';

  @override
  String get lockWipeConfirmTitle => 'Erase after 10 wrong PINs?';

  @override
  String get lockWipeConfirmBody =>
      'After 10 wrong PINs in a row, Usra deletes everything it keeps on this phone, with no way to undo it. A child playing with the phone could set it off.\n\nTurn this on only if you have a recent backup and its recovery key.';

  @override
  String get lockWipeConfirmYes => 'Turn on';

  @override
  String get lockWipeCancel => 'Cancel';

  @override
  String lockTriesBeforeWipe(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString more wrong PINs erase everything',
      one: '1 more wrong PIN erases everything',
    );
    return '$_temp0';
  }

  @override
  String recoveryKeyMismatch(String groups) {
    return 'Group $groups doesn\'t match. Check your paper.';
  }

  @override
  String get restoreTitle => 'Restore from a backup';

  @override
  String get restoreHint => 'Replaces everything on this phone';

  @override
  String get recoveryKeyRowHint => 'Written on your paper';

  @override
  String get restoreKeyHelp => '6 groups of 6 digits.';

  @override
  String get restoreCancel => 'Go back with no changes';

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
      other: '$peopleString people',
      one: '1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      records,
      locale: localeName,
      other: '$recordsString records',
      one: '1 record',
    );
    String _temp2 = intl.Intl.pluralLogic(
      medicines,
      locale: localeName,
      other: '$medicinesString medicines',
      one: '1 medicine',
    );
    String _temp3 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photosString photos',
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

  @override
  String get memberPregnancy => 'Pregnancy';

  @override
  String get memberDevelopment => 'Development';

  @override
  String get memberBabyLog => 'Baby\'s day';

  @override
  String get recordPregnancy => 'Pregnancy';

  @override
  String get recordPregnancyCheck => 'Weight and blood pressure';

  @override
  String get recordPregnancyEnd => 'Pregnancy outcome';

  @override
  String get fieldLmp => 'First day of last period';

  @override
  String get fieldDueDate => 'Due date (from the doctor)';

  @override
  String get fieldSystolic => 'Blood pressure, upper number';

  @override
  String get fieldDiastolic => 'Blood pressure, lower number';

  @override
  String get fieldOutcome => 'Outcome';

  @override
  String get outcomeBirth => 'Birth';

  @override
  String get outcomeLoss => 'Pregnancy loss';

  @override
  String get outcomeOther => 'Other';

  @override
  String get pregnancyTitle => 'Pregnancy follow-up';

  @override
  String get pregnancyNotEligible =>
      'Pregnancy follow-up is for women. Check the sex and birth date in their details.';

  @override
  String get pregnancyStartIntro =>
      'Follow the weeks, the due date, the antenatal visits and tests. Start with the first day of the last period, or the due date the doctor gave you.';

  @override
  String get pregnancyStart => 'Start pregnancy follow-up';

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
      other: '$weeksString weeks',
      one: '1 week',
      zero: 'Less than a week',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days',
      one: '1 day',
      zero: '0 days',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String pregnancyTrimester(int trimester) {
    String _temp0 = intl.Intl.pluralLogic(
      trimester,
      locale: localeName,
      other: '3rd trimester',
      two: '2nd trimester',
      one: '1st trimester',
    );
    return '$_temp0';
  }

  @override
  String pregnancyDue(String date) {
    return 'Due $date';
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
      other: '$daysString days to the due date',
      one: '1 day to the due date',
      zero: 'Due today',
    );
    return '$_temp0';
  }

  @override
  String get pregnancyPastDue =>
      'The due date has passed. Stay in touch with your doctor, and add the outcome when the baby comes.';

  @override
  String get pregnancyAddCheck => 'Add weight and blood pressure';

  @override
  String get pregnancyEnd => 'Record the outcome';

  @override
  String get pregnancyScheduleTitle => 'Visits, scans and tests';

  @override
  String get pregnancyScheduleSource =>
      'Visits: WHO antenatal care recommendations (2016), at least 8 contacts. Scans and tests: what doctors in Egypt usually ask for. Your doctor may plan differently; follow their plan.';

  @override
  String get pregnancyDisclaimer =>
      'For information only. It doesn\'t replace your doctor\'s follow-up.';

  @override
  String ancContact(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Antenatal visit $numberString of 8';
  }

  @override
  String ancContactReason(int week) {
    final intl.NumberFormat weekNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String weekString = weekNumberFormat.format(week);

    return 'Around week $weekString of pregnancy';
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

    return 'Usually between weeks $fromString and $toString of pregnancy';
  }

  @override
  String get ancBookingLabs =>
      'First pregnancy tests (blood count, blood group, urine, sugar, hepatitis)';

  @override
  String get ancFirstScan => 'First-trimester ultrasound';

  @override
  String get ancAnomalyScan => 'Anomaly scan (detailed ultrasound)';

  @override
  String get ancGlucoseTest => 'Pregnancy sugar test (glucose curve)';

  @override
  String get ancBloodCount => 'Blood count (anaemia check)';

  @override
  String get ancGrowthScan => 'Baby growth ultrasound';

  @override
  String get ancDone => 'Done';

  @override
  String get ancMissed => 'Not recorded';

  @override
  String get pregDangerTitle =>
      'Go to the hospital now if you notice any of these';

  @override
  String pregDangerSign(String sign) {
    String _temp0 = intl.Intl.selectLogic(sign, {
      'bleeding': 'Bleeding from the vagina',
      'headache': 'Severe headache',
      'vision': 'Blurred vision',
      'fits': 'Fits or fainting',
      'pain': 'Severe pain in the belly',
      'fever': 'Fever',
      'water': 'Water leaking from the vagina',
      'movement': 'The baby moving less than usual, or not at all',
      'swelling': 'Swelling of the face or hands',
      'breathing': 'Difficulty breathing',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get pregDangerSource =>
      'Danger signs from WHO and the Egyptian Ministry of Health maternal health guidance.';

  @override
  String get pregnancyWeightTitle => 'Weight';

  @override
  String get pregnancyBpTitle => 'Blood pressure';

  @override
  String get pregnancyNoReadings => 'No readings yet.';

  @override
  String get pregnancyWeekAxis => 'Pregnancy week';

  @override
  String get bpUsual => 'In the usual range';

  @override
  String get bpHigh => 'High: call your doctor today';

  @override
  String get bpVeryHigh => 'Very high: go to the hospital now';

  @override
  String get pregnancyBpSource =>
      'Levels from WHO: 140/90 and above is high in pregnancy, 160/110 and above is very high. One reading isn\'t a diagnosis; ask your doctor.';

  @override
  String get devTitle => 'Development milestones';

  @override
  String get devUnderSixOnly =>
      'The milestones checklist is for children under 6 whose birth date is recorded.';

  @override
  String get devIntro =>
      'Tick what your child does, with the day you first noticed it.';

  @override
  String devLateBanner(String age) {
    return 'Some milestones for $age aren\'t ticked yet. Talk to your pediatrician about them; there\'s no need to wait.';
  }

  @override
  String devByAge(String age) {
    return 'By $age';
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

    return '$doneString of $totalString ticked';
  }

  @override
  String devDone(String date) {
    return 'Since $date';
  }

  @override
  String get devUpcoming => 'Later';

  @override
  String get devWatch => 'Watch for it';

  @override
  String get devLate => 'Talk to your pediatrician';

  @override
  String get devNotTicked => 'Not ticked';

  @override
  String get devWhenSeen => 'When did you first notice it?';

  @override
  String get devAreaSocial => 'Social and emotional';

  @override
  String get devAreaLanguage => 'Language';

  @override
  String get devAreaCognitive => 'Thinking and learning';

  @override
  String get devAreaMovement => 'Movement';

  @override
  String get devSource =>
      'From CDC\'s \"Learn the Signs. Act Early.\" milestones (2022), a selection: things most children (75%) do by each age. Full checklists at cdc.gov/actearly. For information only; your pediatrician assesses your child\'s development.';

  @override
  String get recordMilestone => 'Milestone';

  @override
  String milestone(String sex, String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'm2_social': 'Smiles when you talk to or smile at them',
      'm2_language': 'Makes sounds other than crying',
      'm2_cognitive': 'Watches you as you move',
      'm2_movement': 'Holds head up when on tummy',
      'm4_social': 'Smiles on their own to get your attention',
      'm4_language': 'Makes cooing sounds like \"oooo\" and \"aahh\"',
      'm4_cognitive': 'Looks at their hands with interest',
      'm4_movement': 'Holds head steady without support when you hold them',
      'm6_social': 'Knows familiar people',
      'm6_language': 'Takes turns making sounds with you',
      'm6_cognitive': 'Reaches to grab a toy they want',
      'm6_movement': 'Rolls from tummy to back',
      'm9_social': 'Looks when you call their name',
      'm9_language': 'Makes sounds like \"mamama\" and \"bababa\"',
      'm9_cognitive': 'Looks for things when you drop them out of sight',
      'm9_movement': 'Sits without support',
      'm12_social': 'Plays games with you, like pat-a-cake',
      'm12_language': 'Waves \"bye-bye\"',
      'm12_cognitive': 'Looks for things they see you hide',
      'm12_movement': 'Pulls up to stand',
      'm15_social': 'Shows you an object they like',
      'm15_language':
          'Tries to say one or two words besides \"mama\" or \"dada\"',
      'm15_cognitive': 'Stacks at least two small objects',
      'm15_movement': 'Takes a few steps on their own',
      'm18_social': 'Points to show you something interesting',
      'm18_language':
          'Tries to say three or more words besides \"mama\" or \"dada\"',
      'm18_cognitive': 'Copies you doing chores, like sweeping',
      'm18_movement': 'Walks without holding on to anyone or anything',
      'm24_social': 'Notices when others are hurt or upset',
      'm24_language': 'Says at least two words together, like \"more milk\"',
      'm24_cognitive': 'Tries to use switches, knobs or buttons on a toy',
      'm24_movement': 'Kicks a ball',
      'm30_social': 'Plays next to other children and sometimes with them',
      'm30_language': 'Says about 50 words',
      'm30_cognitive': 'Uses things to pretend, like feeding a doll',
      'm30_movement': 'Jumps off the ground with both feet',
      'm36_social': 'Notices other children and joins them to play',
      'm36_language': 'Holds a conversation with you of at least two back-and-forth exchanges',
      'm36_cognitive': 'Draws a circle when you show them how',
      'm36_movement': 'Puts on some clothes by themselves',
      'm48_social': 'Comforts others who are hurt or sad',
      'm48_language': 'Says sentences with four or more words',
      'm48_cognitive': 'Names a few colours',
      'm48_movement': 'Catches a large ball most of the time',
      'm60_social': 'Follows rules or takes turns when playing games',
      'm60_language':
          'Tells a story they heard or made up, with at least two events',
      'm60_cognitive': 'Counts to 10',
      'm60_movement': 'Hops on one foot',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(sex, {'other': '$_temp0'});
    return '$_temp1';
  }

  @override
  String get infantLogTitle => 'Baby\'s day';

  @override
  String get infantLogUnderOneOnly =>
      'The feeds, sleep and diapers log is for babies under one whose birth date is recorded.';

  @override
  String get logBreast => 'Breastfeed';

  @override
  String get logBottle => 'Bottle';

  @override
  String get logSolids => 'Solids';

  @override
  String get logSleep => 'Sleep';

  @override
  String get logWet => 'Wet diaper';

  @override
  String get logDirty => 'Dirty diaper';

  @override
  String get logBottleAmount => 'How much?';

  @override
  String get logSleepHowLong => 'How long did they sleep?';

  @override
  String get logSkip => 'Don\'t know';

  @override
  String logMl(int ml) {
    final intl.NumberFormat mlNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String mlString = mlNumberFormat.format(ml);

    return '$mlString ml';
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
      other: '$hoursString h $minutesString min',
      zero: '$minutesString min',
    );
    return '$_temp0';
  }

  @override
  String get logSaved => 'Saved';

  @override
  String get logToday => 'Today';

  @override
  String get logYesterday => 'Yesterday';

  @override
  String get logEmptyDay => 'Nothing logged.';

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
      other: '$countString feeds',
      one: '1 feed',
    );
    return '$_temp0 (breast $breastString, bottle $bottleString, solids $solidsString)';
  }

  @override
  String logSummaryBottleMl(int ml) {
    final intl.NumberFormat mlNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String mlString = mlNumberFormat.format(ml);

    return '$mlString ml from the bottle';
  }

  @override
  String logSummarySleep(String duration) {
    return 'Sleep: $duration';
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

    return 'Diapers: $wetString wet, $dirtyString dirty';
  }

  @override
  String get logDelete => 'Delete';

  @override
  String get logDisclaimer =>
      'A diary for you and the doctor. If you\'re worried about feeding, sleep or diapers, ask your pediatrician.';

  @override
  String get recordFeed => 'Feed';

  @override
  String get recordDiaper => 'Diaper';

  @override
  String get fieldFeedKind => 'Type of feed';

  @override
  String get fieldAmountMl => 'Amount (ml)';

  @override
  String get fieldMinutes => 'Minutes';

  @override
  String get fieldDiaperKind => 'Type of diaper';

  @override
  String get diaperWet => 'Wet';

  @override
  String get diaperDirty => 'Dirty';

  @override
  String get diaperBoth => 'Wet and dirty';

  @override
  String get growthCheckTitle => 'Quick check';

  @override
  String growthCheckIntro(String age) {
    return 'Type today\'s weight, height or head circumference and see where it falls on the WHO curves at $age.';
  }

  @override
  String get growthCheckSave => 'Save as a measurement';

  @override
  String get devUntick => 'Untick';

  @override
  String get devUntickConfirm =>
      'Untick this milestone? The date you recorded will be removed.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSettingsHint => 'Your records stay on this phone';

  @override
  String get accountPrivacy =>
      'Your family\'s health records stay on this phone. An account doesn\'t upload them.';

  @override
  String get accountSignInIntro =>
      'You can look around and read the guides with no account. Saving records, adding family and backing up need a sign-in.';

  @override
  String get accountSignInConsent =>
      'By signing in, you agree that we keep this to run your account, as the privacy policy says.';

  @override
  String get accountSignInData =>
      'Google shares your name, email, profile photo link and an account ID with us; Apple shares your email (or a replacement address if you hide yours) and an account ID. We store these with your language and device information to run the account.';

  @override
  String get accountGateTitle => 'Save your records';

  @override
  String get accountGateBody =>
      'Saving records needs a sign-in. What was typed stays on the page.';

  @override
  String get accountGateBackupBody => 'Backing up needs a sign-in.';

  @override
  String get accountGateKeepsTitle => 'The account keeps';

  @override
  String get accountGateRecordsStay =>
      'Records and photos stay on your phone, encrypted.';

  @override
  String get accountReadPrivacy => 'Read about privacy';

  @override
  String get accountSignInWithGoogle => 'Sign in with Google';

  @override
  String get accountSignInWithApple => 'Sign in with Apple';

  @override
  String get accountSignInUnavailable =>
      'Sign-in isn\'t available in this version of the app.';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutConfirm =>
      'Sign out? Your records stay on this phone.';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteConfirm =>
      'Delete your account? Your account, devices and credits are erased from our servers. The records on this phone stay here.';

  @override
  String get accountDeleteAppleNote =>
      'Apple will ask you to confirm once more, so we can unlink your Apple ID from the app.';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get accountErrorTooMany =>
      'Too many tries. Wait a little and try again';

  @override
  String get accountErrorNetwork =>
      'No connection. Check the internet and try again';

  @override
  String get accountErrorGeneric => 'Something went wrong. Try again';

  @override
  String get accountRetry => 'Try again';

  @override
  String get accountErrorSignInAgain =>
      'Your sign-in has expired. Sign in again';

  @override
  String get accountErrorFamilyHasMembers =>
      'You created a family that other people are in. Their shared records would be deleted too, so this account can\'t be deleted yet.';

  @override
  String get lockTitle => 'Usra is locked';

  @override
  String get lockEnterPin => 'Enter your PIN';

  @override
  String get lockUseBiometrics => 'Unlock with fingerprint or face';

  @override
  String get lockBiometricReason => 'Unlock Usra to see your family\'s records';

  @override
  String get lockWrongPin => 'Wrong PIN. Try again.';

  @override
  String lockWait(String time) {
    return 'Too many wrong tries. Try again in $time.';
  }

  @override
  String get lockForgot => 'Forgot your PIN?';

  @override
  String get lockForgotTitle => 'If you forget your PIN';

  @override
  String get lockForgotBody =>
      'To keep your family\'s records private, nothing can skip the PIN, not even us.\n\nTo start again:\n1. Remove Usra\'s data. On Android: phone Settings › Apps › Usra › Storage › Clear data. On iPhone: delete Usra and install it again. This deletes everything Usra keeps on this phone.\n2. Open Usra and restore your latest backup with your recovery key (\"I have a backup\" on the first screen).\n\nWithout a backup and its recovery key, the records can\'t be brought back.';

  @override
  String get lockEmergency => 'Emergency info';

  @override
  String get lockEmergencyPick => 'Whose emergency card?';

  @override
  String get lockEmergencyNone => 'No one has been added yet.';

  @override
  String get pinOk => 'OK';

  @override
  String get pinDelete => 'Delete';

  @override
  String get pinLengthHint => '6 numbers';

  @override
  String pinEntered(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString of 6 numbers typed';
  }

  @override
  String get lockSetupNewPin => 'Choose a 6-number PIN';

  @override
  String get lockSetupConfirmPin => 'Type the same PIN again';

  @override
  String get lockSetupMismatch => 'The two PINs are different. Choose again.';

  @override
  String get lockSetupCurrentPin => 'Enter your current PIN';

  @override
  String get lockSetupBiometricsTitle => 'Use your fingerprint or face too?';

  @override
  String get lockSetupBiometricsBody =>
      'Opens Usra faster; the PIN always works too. Anyone whose fingerprint or face is set up on this phone, family members too, will be able to open Usra. If others use this phone, choose Not now.';

  @override
  String get lockSetupBiometricsYes => 'Yes, use it';

  @override
  String get lockSetupDone => 'App lock is on';

  @override
  String get lockSetupWriteDown =>
      'Keep your PIN somewhere safe. If you forget it, the only way back in is to remove Usra\'s data and restore a backup.';

  @override
  String get lockOfferTitle => 'Lock Usra with a PIN?';

  @override
  String get lockOfferBody =>
      'If your phone is lost or someone else picks it up, your family\'s records stay closed. You can unlock with your fingerprint or face too.';

  @override
  String get lockOfferYes => 'Set up the lock';

  @override
  String get lockOfferSkip => 'Not now';

  @override
  String get lockOfferLater =>
      'You can turn it on any time from More › App lock.';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockOn => 'On: PIN needed to open Usra';

  @override
  String get settingsAppLockOff => 'Off: anyone with the phone can open Usra';

  @override
  String get lockSettingsSwitch => 'Lock with a PIN';

  @override
  String get lockSettingsChangePin => 'Change PIN';

  @override
  String get lockSettingsBiometrics => 'Fingerprint or face';

  @override
  String get lockSettingsBiometricsHint =>
      'Anyone whose fingerprint or face is set up on this phone can open Usra, family members too. If others use this phone, keep this off and use the PIN only.';

  @override
  String get lockSettingsTimeout => 'Lock again after leaving Usra';

  @override
  String get lockTimeoutImmediately => 'Right away';

  @override
  String get lockTimeoutOneMinute => '1 minute';

  @override
  String get lockTimeoutFiveMinutes => '5 minutes';

  @override
  String get lockSettingsEmergency => 'Emergency card on Usra\'s lock screen';

  @override
  String get lockSettingsEmergencyHint =>
      'The blood type, allergies, conditions, surgeries, current medicines and emergency number and whose it is of the people you choose here can be seen without the PIN by anyone holding the phone with Usra open. This is Usra\'s lock screen, not the phone\'s: for a locked phone, use the phone\'s own Medical ID.';

  @override
  String get lockVerifyTitle => 'Confirm it\'s you';

  @override
  String get lockOffDone => 'App lock is off';

  @override
  String get lockUnavailable =>
      'Couldn\'t read the lock just now. Try again in a moment.';

  @override
  String get lockSetupTrivial =>
      'That PIN is too easy to guess. Avoid repeated or sequential numbers.';

  @override
  String get lockEmergencyFor => 'Show on Usra\'s lock screen';

  @override
  String get lockBackupFirstTitle => 'A backup comes first';

  @override
  String get lockBackupFirstBody =>
      'If the PIN is forgotten, the only way back in is to remove Usra\'s data and restore a backup with its recovery key. There\'s no backup yet, and without one the records are lost.\n\nOnce a backup is made, the lock can go on.';

  @override
  String get lockBackupFirstMake => 'Make a backup';

  @override
  String get lockNothingYetTitle => 'Family first';

  @override
  String get lockNothingYetBody =>
      'The lock needs a backup, and there\'s nothing to back up yet. Once someone is added to the family and a backup is made, the lock can go on.';

  @override
  String get lockOnNoBackupBody =>
      'The lock is on, but there\'s no backup yet. If the PIN is forgotten, the records are lost.';

  @override
  String backupDonePhotosSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString photos couldn\'t be opened on this phone and aren\'t',
      one: '1 photo couldn\'t be opened on this phone and isn\'t',
    );
    return 'Backup ready, but $_temp0 in it. Keep it somewhere safe off this phone.';
  }

  @override
  String restorePhotosSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString photos in this backup can\'t be opened and will be left out.',
      one: '1 photo in this backup can\'t be opened and will be left out.',
    );
    return '$_temp0';
  }

  @override
  String get photosLocked =>
      'Photos can\'t be opened on this phone. Restore your backup to get them back.';

  @override
  String get doseReminderDiscreetTitle => 'Your medicine time';

  @override
  String get widgetDoseDue => 'Dose due';

  @override
  String widgetDoseCount(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits doses due',
    );
    return '$_temp0';
  }

  @override
  String get settingsDiscreet => 'Discreet notifications';

  @override
  String get settingsDiscreetHint =>
      'Reminders say \"Your medicine time\", without the person\'s or the medicine\'s name. When several doses are close together, open Usra to mark them.';

  @override
  String get settingsBlockScreenshots => 'Block screenshots';

  @override
  String get settingsBlockScreenshotsHint =>
      'No screenshots or screen recording anywhere in the app. The recovery key is always protected. Leave off to screenshot the emergency card.';

  @override
  String get doseReminderDiscreetBody => 'Open Usra to see which';

  @override
  String doseReminderDiscreetTimeBody(String time) {
    return 'The $time dose';
  }

  @override
  String get doseReminderDiscreetSeveralBody =>
      'More than one dose is due around now. Open Usra to see which';

  @override
  String get memberVaccines => 'Vaccinations';

  @override
  String get vaccineHexa => 'Hexavalent';

  @override
  String get vaccinePcv => 'Pneumococcal (PCV)';

  @override
  String get vaccineRota => 'Rotavirus';

  @override
  String get vaccineVaricella => 'Chickenpox (varicella)';

  @override
  String get vaccineHepA => 'Hepatitis A';

  @override
  String get vaccineMening => 'Meningococcal (MenACWY)';

  @override
  String get vaccineFlu => 'Influenza (flu)';

  @override
  String vaccineBoosterDose(String name) {
    return '$name, booster';
  }

  @override
  String get vaccineRequired => 'Required';

  @override
  String get vaccineOptional => 'Optional';

  @override
  String vaccineRequiredDone(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString/$totalString required done';
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

    return '$doneString/$totalString optional done';
  }

  @override
  String get vaccineFilterAll => 'All';

  @override
  String get vaccineFilterRequired => 'Required';

  @override
  String get vaccineFilterOptional => 'Optional';

  @override
  String get vaccineFilterOverdue => 'Overdue';

  @override
  String get vaccineFilterEmpty => 'Nothing here.';

  @override
  String get vaccinePlanTitle => 'Vaccine plan';

  @override
  String get vaccineRouteTitle => 'How are the injections given?';

  @override
  String get vaccineRouteGovernment => 'Health office (free)';

  @override
  String get vaccineRouteGovernmentHint =>
      'Pentavalent and the polio injection (IPV) as separate shots, with a DTP booster at 18 months.';

  @override
  String get vaccineRouteHexavalent => 'Private hexavalent';

  @override
  String get vaccineRouteHexavalentHint =>
      'One hexavalent shot instead of pentavalent + IPV at 2, 4 and 6 months, and a hexavalent booster at 18 months. Oral polio drops, BCG, hepatitis B at birth and MMR stay the same.';

  @override
  String get vaccineOptionalTitle => 'Optional vaccines you follow';

  @override
  String get vaccineOptionalHint =>
      'Not on the ministry\'s free schedule. Ask the child\'s doctor which ones to give; only the ones you tick are reminded or counted late.';

  @override
  String get vaccineSetupTitle => 'Set up vaccinations';

  @override
  String get vaccineSetupOpen => 'Plan and doses given';

  @override
  String get vaccineSetupGiven => 'Doses already given';

  @override
  String get vaccineSetupGivenHint =>
      'Tick what\'s on the child\'s card. The date is the due date unless you change it.';

  @override
  String get vaccineSetupNoneYet => 'No doses are due yet.';

  @override
  String get vaccineSetupSaved => 'Vaccinations saved';

  @override
  String get vaccineScanTitle => 'Read the vaccination card';

  @override
  String get vaccineScanHelp =>
      'Take a photo of the card. The phone only reads dates and vaccine names printed in English; handwriting usually won\'t be read. Nothing is sent anywhere, and the photo isn\'t kept. Check every dose against the card.';

  @override
  String get vaccineScanReading => 'Reading the card…';

  @override
  String vaccineScanFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $countString doses on the card.',
      one: 'Found 1 dose on the card.',
    );
    return '$_temp0 Check each one below and tick “Matches the card”.';
  }

  @override
  String get vaccineScanNothing =>
      'Couldn\'t find dated doses in this photo. Tick them by hand below.';

  @override
  String vaccineScanAlready(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString doses on the card were already recorded, so they weren\'t changed.',
      one: '1 dose on the card was already recorded, so it wasn\'t changed.',
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
          '$countString rows only had dates still to come (next visits), so nothing was ticked for them.',
      one: '1 row only had a date still to come (the next visit), so nothing was ticked for it.',
    );
    return '$_temp0';
  }

  @override
  String get vaccineScanFailed => 'Couldn\'t read the photo';

  @override
  String get vaccineScanRouteChanged =>
      'The schedule changed, so what was read from the card was removed. Photograph the card again.';

  @override
  String vaccineFromCard(String row) {
    return 'On the card: $row';
  }

  @override
  String get vaccineDoseGuessed =>
      'The card doesn\'t say which dose this is: check the number.';

  @override
  String get vaccineDateCheck =>
      'Check the date against the card: the row had more than one, or it doesn\'t fit the schedule (before an earlier dose, or well before this dose\'s age).';

  @override
  String get vaccineConfirmCard => 'Matches the card';

  @override
  String get vaccineConfirmNeeded =>
      'Before saving, confirm each dose read from the card (or untick it), and say which dose each unnamed row is, or skip it.';

  @override
  String get vaccineUnknownTitle => 'Rows the phone couldn\'t name';

  @override
  String vaccineUnknownRow(String text, String date) {
    return '“$text”, given $date';
  }

  @override
  String vaccineUnknownDateOnly(String date) {
    return 'A dose given $date';
  }

  @override
  String get vaccineUnknownPick => 'Which dose is this?';

  @override
  String get vaccineUnknownSkip => 'Skip';

  @override
  String get vaccineChangeDate => 'Change date';

  @override
  String get vaccineDoseGiven => 'Given';

  @override
  String get vaccineDoseDate => 'Date given';

  @override
  String get vaccineDoseNote => 'Note';

  @override
  String get vaccineDoseNoteHint =>
      'e.g. given at the clinic, slight fever after';

  @override
  String vaccineDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get vaccineNextVisit => 'Next vaccine visit';

  @override
  String vaccineInDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $daysString days',
      one: 'Tomorrow',
      zero: 'Today',
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
      other: 'Was due $daysString days ago',
      one: 'Was due yesterday',
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
      other: '$countString doses overdue',
      one: '1 dose overdue',
    );
    return '$_temp0';
  }

  @override
  String get vaccineAllDone => 'All planned vaccines are given';

  @override
  String get vaccineOpenAll => 'All vaccinations';

  @override
  String get homeVaccinesTitle => 'Vaccines';

  @override
  String get vaccineChannelName => 'Vaccine reminders';

  @override
  String get vaccineReminderDiscreetTitle => 'A health visit is coming up';

  @override
  String get vaccineReminderDiscreetTodayTitle => 'A health visit is today';

  @override
  String get vaccineReminderDiscreetBody => 'Open Usra to see the details';

  @override
  String vaccineReminderWeekTitle(String name) {
    return '$name: vaccines in a week';
  }

  @override
  String vaccineReminderTodayTitle(String name) {
    return '$name: vaccines today';
  }

  @override
  String get settingsVaccineReminders => 'Vaccine reminders';

  @override
  String settingsVaccineRemindersHint(String time) {
    return 'A week before and on the day, at $time';
  }

  @override
  String get settingsVaccineReminderTime => 'Reminder time';

  @override
  String get vaccineSources => 'Sources';

  @override
  String get reminderHiddenPreview => 'A reminder from Usra';

  @override
  String get vaccineTooLate => 'Past the age limit: ask your doctor';

  @override
  String get vaccineNotNeeded => 'Not needed at this age';

  @override
  String get vaccineRemoveRecordTitle => 'Remove the record you entered?';

  @override
  String get vaccineRemoveRecordBody =>
      'This dose was entered by hand, maybe with a photo of the card, the doctor or the cost. Unticking it removes that record from the child\'s history.';

  @override
  String get vaccineRemoveRecordConfirm => 'Remove';

  @override
  String get growthHeadForAge => 'Head circumference for age';

  @override
  String get prescriptionsSection => 'Prescriptions';

  @override
  String get prescriptionAdd => 'Add prescription';

  @override
  String get prescriptionNew => 'New prescription';

  @override
  String get prescriptionEdit => 'Edit prescription';

  @override
  String get prescriptionDate => 'Date (first day of treatment)';

  @override
  String get prescriptionDiagnosis => 'Diagnosis or reason';

  @override
  String get prescriptionNotes => 'Notes';

  @override
  String get prescriptionPhotos => 'Photo of the prescription';

  @override
  String get prescriptionMedicines => 'Medicines';

  @override
  String get prescriptionAddMedicine => 'Add another medicine';

  @override
  String prescriptionMedicineN(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'Medicine $nString';
  }

  @override
  String get prescriptionRemoveMedicine => 'Remove this medicine';

  @override
  String get prescriptionDose => 'Dose, as the doctor wrote it';

  @override
  String get prescriptionDoseHint => 'Exactly as written on the prescription';

  @override
  String get prescriptionTimesPerDay =>
      'Times a day (you can change the times)';

  @override
  String prescriptionTimesN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString times',
      two: 'Twice',
      one: 'Once',
    );
    return '$_temp0';
  }

  @override
  String get prescriptionDuration => 'For how long';

  @override
  String get prescriptionOngoing => 'Ongoing';

  @override
  String get prescriptionForDays => 'A set number of days';

  @override
  String get prescriptionDays => 'Number of days';

  @override
  String get prescriptionDaysInvalid => 'Enter a number of days, 1 or more';

  @override
  String get prescriptionNoDoseAdvice =>
      'Write each medicine exactly as it is on the prescription. Usra never suggests or calculates a dose.';

  @override
  String get prescriptionNeedsTimes =>
      'Add at least one time, or no reminders will ring';

  @override
  String get prescriptionStop => 'Stop the whole prescription';

  @override
  String get prescriptionResume => 'Resume the prescription';

  @override
  String get prescriptionDeleteConfirm =>
      'Delete this prescription, its medicines and their history? Its photos will be removed from this phone.';

  @override
  String get prescriptionNotFound => 'This prescription was deleted';

  @override
  String prescriptionTitle(String date) {
    return 'Prescription of $date';
  }

  @override
  String prescriptionCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString medicines',
      one: '1 medicine',
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
      other: '$countString days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get prescriptionLink => 'Prescription';

  @override
  String courseDayOf(int day, int total) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Day $dayString of $totalString';
  }

  @override
  String get prescriptionMoveTitle => 'Move the courses too?';

  @override
  String get prescriptionMoveBody =>
      'Courses that haven\'t ended can start on the new date. Courses already over keep their dates and get no reminders back.';

  @override
  String get prescriptionMoveYes => 'Move them';

  @override
  String get prescriptionMoveKeep => 'Keep their dates';

  @override
  String prescriptionRemoveConfirm(String name) {
    return 'Take $name off this prescription? It will be stopped, so its reminders end. Its dose history stays on its own page.';
  }

  @override
  String get prescriptionEveryHours => 'Every few hours';

  @override
  String get prescriptionInterval => 'As the doctor wrote';

  @override
  String prescriptionEveryNHours(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $nString hours',
      one: 'Every hour',
    );
    return '$_temp0';
  }

  @override
  String prescriptionFirstDose(String time) {
    return 'First one at $time';
  }

  @override
  String get prescriptionTimesHint =>
      'Check the times match what the doctor wrote.';

  @override
  String get rxScanTitle => 'Read the prescription from a photo';

  @override
  String rxFor(String name) {
    return 'This prescription is for $name';
  }

  @override
  String get rxScanHelp =>
      'The phone reads printed medicine names in English itself; nothing is sent anywhere. It doesn\'t read handwriting: if the doctor wrote by hand, type the medicines from the photo. The photo is kept, encrypted, with the prescription.';

  @override
  String get rxScanReading => 'Reading the prescription…';

  @override
  String rxScanFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $countString medicines.',
      one: 'Found 1 medicine.',
    );
    return '$_temp0 Check each one against the paper; highlighted boxes are ones the phone wasn\'t sure of.';
  }

  @override
  String get rxScanUnclear =>
      'This looks handwritten or unclear, so nothing was filled in. The photo is kept with the prescription: type the medicines from it.';

  @override
  String get rxScanNothing =>
      'Couldn\'t find medicines in this photo. Type them in; the photo is kept with the prescription.';

  @override
  String get rxScanFailed => 'Couldn\'t read the photo';

  @override
  String get rxScanPhoto => 'The photo of the prescription';

  @override
  String get rxFromPhoto => 'Read from the photo: check it against the paper';

  @override
  String get rxConfirmMedicine => 'Matches the paper';

  @override
  String get rxTimesChecked => 'The times match the paper';

  @override
  String rxDidYouMean(String name) {
    return 'Did you mean $name?';
  }

  @override
  String get rxConfirmFirstCheck => 'Check the highlighted boxes first';

  @override
  String get rxConfirmNeeded =>
      'Before saving, check every medicine read from the photo against the paper and tick “Matches the paper”, and check the date and doctor.';

  @override
  String rxDoctorOnPaper(String name) {
    return 'On the paper: $name';
  }

  @override
  String get rxDoctorAdd => 'Add to my doctors';

  @override
  String get rxTimesFromPaper =>
      'How often was read from the paper; the reminder times are only spread over the day. Change them if the doctor said otherwise.';

  @override
  String get growthNoPrematurity =>
      'Uses age from birth, with no correction for babies born early. If your baby was premature, ask the pediatrician how to read this chart.';

  @override
  String get reportAppLine => 'Made with Usra (أسرة), a family health app';

  @override
  String reportGenerated(String date) {
    return 'Generated on $date';
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

    return 'Page $pageString of $totalString';
  }

  @override
  String get reportVaccinationTitle => 'Vaccination record';

  @override
  String get reportVaccinationDisclaimer =>
      'An informational record made by the family in the Usra app from their own entries. Not an official vaccination certificate: check with the child\'s vaccination card.';

  @override
  String get reportName => 'Name';

  @override
  String get reportRoute => 'Vaccination route';

  @override
  String get reportRouteGovernment => 'Government (health office)';

  @override
  String get reportRoutePrivate => 'Private (hexavalent)';

  @override
  String get reportDosesGiven => 'Doses given';

  @override
  String get reportNoDosesGiven => 'No doses recorded yet';

  @override
  String get reportUpcoming => 'Upcoming doses';

  @override
  String get reportNoUpcoming => 'No doses left on the schedule';

  @override
  String get reportUpcomingOverFive =>
      'The schedule in Usra follows children until age 5.';

  @override
  String get reportColVaccine => 'Vaccine';

  @override
  String get reportColDate => 'Date';

  @override
  String get reportColNotes => 'Notes';

  @override
  String get reportColDue => 'Due';

  @override
  String get reportOverdue => 'Overdue';

  @override
  String get reportSummaryTitle => 'Health summary for the doctor';

  @override
  String get reportSummaryDisclaimer =>
      'This summary is what the family recorded with the Usra app, not a medical opinion. Check it against the original prescriptions and reports.';

  @override
  String get reportAge => 'Age';

  @override
  String get reportSectionBasics => 'Age and blood type';

  @override
  String get reportSectionMedicines => 'Current medicines';

  @override
  String get reportSectionVisits => 'Recent doctor visits';

  @override
  String get reportSectionLabs => 'Recent lab results';

  @override
  String get reportSectionGrowth => 'Growth';

  @override
  String get reportSectionVaccines => 'Vaccines';

  @override
  String get reportColMedicine => 'Medicine';

  @override
  String get reportColHowTaken => 'As written by the doctor';

  @override
  String get reportColDoctor => 'Doctor';

  @override
  String get reportColDetails => 'Reason / diagnosis';

  @override
  String get reportColTest => 'Test';

  @override
  String get reportColResult => 'Result';

  @override
  String get reportColRange => 'Lab\'s range';

  @override
  String get reportColMeasure => 'Measurement';

  @override
  String get reportColValue => 'Value';

  @override
  String get reportColPercentile => 'WHO percentile';

  @override
  String get reportAsNeeded => 'When needed';

  @override
  String reportSince(String date) {
    return 'Since $date';
  }

  @override
  String reportUntil(String date) {
    return 'until $date';
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

    return '$doneString of $totalString doses in the plan given';
  }

  @override
  String get reportVaccineNext => 'Next vaccine visit';

  @override
  String get reportVaccineOverdue => 'Overdue';

  @override
  String get reportGrowthNote =>
      'Percentiles from the WHO Child Growth Standards (under 5). Informational, not a diagnosis.';

  @override
  String get reportNothing => 'Nothing recorded';

  @override
  String get memberDoctorSummary => 'Summary for the doctor';

  @override
  String get reportSummaryIntro =>
      'A short PDF summary to show or send to a doctor. Choose what goes in.';

  @override
  String get reportChooseSections => 'What to include';

  @override
  String get reportLanguage => 'Language of the PDF';

  @override
  String get reportSharePdf => 'Share PDF';

  @override
  String get reportIncludeNotes => 'Include my notes on each dose';

  @override
  String get reportVaccinationShare => 'Share vaccination record';

  @override
  String get reportVaccinationIntro =>
      'A PDF of the doses given and the ones coming up, for a school, nursery or doctor.';

  @override
  String get reportPickOne => 'Choose at least one section';

  @override
  String get reportOnPhone =>
      'Made on this phone. The file is deleted from the phone once it\'s shared.';

  @override
  String get reportFailed => 'Couldn\'t make the PDF';

  @override
  String get reportNeedsBirthDate =>
      'Add a date of birth to the profile first.';

  @override
  String get reportFlagHigh => 'High';

  @override
  String get reportFlagLow => 'Low';

  @override
  String get reportTooLate => 'Too late for this vaccine: ask the doctor';

  @override
  String get reportTooLateLabel => 'Too late (ask the doctor)';

  @override
  String get reportSimpleIntro =>
      'A PDF with this person\'s health details, medicines, visits and tests, to show or send to a doctor.';

  @override
  String get memberSickDays => 'Fever & sick days';

  @override
  String get sickDaysTitle => 'Fever and sick days';

  @override
  String get sickDaysEmpty =>
      'No sick days yet. When someone gets ill, start one to log temperatures, symptoms and the medicines given.';

  @override
  String get sickDayStart => 'Start a sick day';

  @override
  String sickDayOngoing(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {'other': 'Still ill'});
    return '$_temp0';
  }

  @override
  String get sickDayEnded => 'Over';

  @override
  String sickDaySince(String date) {
    return 'Since $date';
  }

  @override
  String sickDayRange(String start, String end) {
    return '$start to $end';
  }

  @override
  String get sickDayTitle => 'Sick day';

  @override
  String get sickDayStartedAt => 'Started';

  @override
  String get sickDayEnd => 'Mark as over';

  @override
  String sickDayReopen(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {'other': 'Still ill'});
    return '$_temp0';
  }

  @override
  String get sickDayDelete => 'Delete this sick day';

  @override
  String get sickDayDeleteConfirm =>
      'Delete this sick day with its temperatures and medicines given?';

  @override
  String get sickDayTemperatures => 'Temperature';

  @override
  String get sickDayAddReading => 'Add a temperature';

  @override
  String get sickDayNoReadings => 'No temperatures yet.';

  @override
  String get sickDayChartTitle => 'Temperature chart';

  @override
  String get sickDayChartNote =>
      'Dashed line: 38 °C (100.4 °F), where a fever starts.';

  @override
  String get sickDaySymptoms => 'Symptoms';

  @override
  String get sickDayMedicines => 'Medicines given';

  @override
  String get sickDayAddMedicine => 'Add a medicine given';

  @override
  String get sickDayNoMedicines => 'No medicines logged.';

  @override
  String get sickDayNotes => 'Notes';

  @override
  String get sickDayNotesSaved => 'Notes saved';

  @override
  String sickDayPersonUnwell(String sex, String name) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'male': '$name is unwell',
      'female': '$name is unwell',
      'other': '$name is unwell',
    });
    return '$_temp0';
  }

  @override
  String sickDayPersonWasUnwell(String sex, String name) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'male': '$name was unwell',
      'female': '$name was unwell',
      'other': '$name was unwell',
    });
    return '$_temp0';
  }

  @override
  String sickDaySinceToday(String time) {
    return 'Since today $time';
  }

  @override
  String sickDaySinceYesterday(String time) {
    return 'Since yesterday $time';
  }

  @override
  String get sickDayLatestReading => 'Latest reading';

  @override
  String sickDayHighestReading(String reading, String time) {
    return 'Highest reading: $reading – $time';
  }

  @override
  String sickDayFeverSpan(String from, String to) {
    return 'Fever readings from $from to $to';
  }

  @override
  String sickDayFeverOnce(String time) {
    return 'Fever reading: $time';
  }

  @override
  String sickDayRecordedGiven(String what, String time) {
    return 'Recorded: $what – $time';
  }

  @override
  String sickDayChartSemantics(
    String start,
    String end,
    String values,
    String fever,
  ) {
    return 'Readings from $start to $end: $values. The dashed line is at $fever, where a fever starts.';
  }

  @override
  String get sickDayChartThen => ', then ';

  @override
  String get sickDayAddReadingShort => 'Add reading';

  @override
  String get sickDayGivenShort => 'Medicine given';

  @override
  String get sickDayAllReadings => 'All readings';

  @override
  String get sickDayNoSymptoms => 'No symptoms logged yet.';

  @override
  String sickDayCallDoctorNamed(String name) {
    return 'Call $name';
  }

  @override
  String get sickDayBack => 'Back';

  @override
  String get readingValue => 'Temperature';

  @override
  String get readingCelsius => '°C';

  @override
  String get readingFahrenheit => '°F';

  @override
  String get readingSite => 'Where it was taken';

  @override
  String readingSiteName(String site) {
    String _temp0 = intl.Intl.selectLogic(site, {
      'armpit': 'Armpit',
      'ear': 'Ear',
      'forehead': 'Forehead',
      'mouth': 'Mouth',
      'rectal': 'Rectal',
      'other': 'Not said',
    });
    return '$_temp0';
  }

  @override
  String get readingTime => 'Time';

  @override
  String get readingDate => 'Date';

  @override
  String get readingImplausible =>
      'That doesn\'t look like a body temperature. Check the number and the unit.';

  @override
  String get readingFever => 'Fever';

  @override
  String get readingDelete => 'Delete this temperature';

  @override
  String get givenWhich => 'Which medicine';

  @override
  String get givenOther => 'Another medicine (type its name)';

  @override
  String get givenName => 'Medicine name';

  @override
  String get givenAmount => 'Amount given';

  @override
  String get givenAmountHint =>
      'As you\'d write it, e.g. from the box or prescription';

  @override
  String get givenTime => 'Time given';

  @override
  String givenFromPrescription(String date) {
    return 'From the prescription of $date';
  }

  @override
  String get givenRemind => 'Remind me at that time';

  @override
  String get givenNoInterval =>
      'No time shown: this medicine has no minimum hours between doses saved. You can add them on the medicine\'s page, as written on the label or by your doctor.';

  @override
  String get givenDelete => 'Delete this entry';

  @override
  String get givenRequired => 'Pick a medicine or type its name';

  @override
  String get nextDoseDiscreetTitle => 'A reminder from Usra';

  @override
  String get nextDoseDiscreetBody => 'Open Usra to see it.';

  @override
  String nextDoseTitle(String person, String medicine) {
    return '$person: $medicine';
  }

  @override
  String nextDoseBody(String hours) {
    return '$hours hours have passed since the dose you logged. Check other medicines with the same ingredient.';
  }

  @override
  String symptomName(String sex, String symptom) {
    String _temp0 = intl.Intl.selectLogic(symptom, {
      'cough': 'Cough',
      'runnyNose': 'Runny nose',
      'soreThroat': 'Sore throat',
      'earPain': 'Ear pain',
      'headache': 'Headache',
      'vomiting': 'Vomiting',
      'diarrhea': 'Diarrhoea',
      'rash': 'Rash',
      'aches': 'Body aches',
      'poorFeeding': 'Eating or drinking less',
      'dehydration': 'Fewer wet nappies, peeing less or no tears',
      'breathing': 'Hard to breathe',
      'drowsy': 'Very drowsy or hard to wake',
      'seizure': 'Fit (seizure)',
      'rashNotFading': 'Rash that doesn\'t fade under a glass',
      'stiffNeck': 'Stiff neck',
      'other': 'Other',
    });
    String _temp1 = intl.Intl.selectLogic(sex, {'other': '$_temp0'});
    return '$_temp1';
  }

  @override
  String get warnTitle => 'Warning signs';

  @override
  String get warnLogged => 'From what you logged:';

  @override
  String get warnEmergency => 'Call an ambulance (123) now if:';

  @override
  String get warnDoctorNow => 'Contact a doctor now if:';

  @override
  String warnSign(String sex, String sign) {
    String _temp0 = intl.Intl.selectLogic(sign, {
      'breathing': 'Hard to breathe, breathing very fast or breathless',
      'seizure': 'A fit (seizure)',
      'rashGlass': 'A rash that doesn\'t fade when you press a glass on it',
      'drowsy': 'Very drowsy or hard to wake, or not responding as usual',
      'stiffNeck': 'A stiff neck, or light hurts the eyes',
      'skinColour': 'Blue, grey, very pale or blotchy skin, lips or tongue, or unusually cold hands and feet',
      'confused': 'Confused, or very agitated and won\'t stop crying',
      'under3Months':
          'Under 3 months old with a temperature of 38 °C (100.4 °F) or higher',
      'months3to6':
          '3 to 6 months old with a temperature of 39 °C (102.2 °F) or higher',
      'longUnder2': 'Under 2 years old with a fever for more than 24 hours',
      'longChild': '2 years or older with a fever for more than 3 days',
      'fiveDays': 'A fever that has lasted 5 days or more',
      'veryHigh': 'A temperature above 40 °C (104 °F) more than once',
      'notImproving':
          'A high temperature that isn\'t getting better, or is getting worse',
      'dehydration': 'Signs of dehydration: fewer wet nappies or peeing less, no tears, sunken eyes, dry mouth',
      'notDrinking': 'Not drinking, not feeding or breastfeeding, or not acting like themselves',
      'vomitsEverything': 'Vomits everything, or keeps vomiting',
      'armpitUnder3Months': 'Under 3 months old with an armpit reading of 37.5 °C (99.5 °F) or higher',
      'lowUnder3Months':
          'Under 3 months old with a temperature below 36 °C (96.8 °F)',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(sex, {'other': '$_temp0'});
    return '$_temp1';
  }

  @override
  String get warnFooter =>
      'For information only, not a diagnosis. If you\'re worried, contact a doctor or call 123, even if nothing here matches.';

  @override
  String get warnSources => 'Sources';

  @override
  String warnSourceName(String source) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'nhs': 'NHS (UK): fever in children',
      'aap': 'American Academy of Pediatrics: when to call the pediatrician',
      'who': 'WHO: IMCI general danger signs',
      'stlouis': 'St. Louis Children\'s Hospital: how to take a temperature',
      'womans': 'Woman\'s Hospital: newborn temperature',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get warnCallDoctor => 'My doctors';

  @override
  String givenHoursAfter(String hours, String time) {
    return '$hours hours after this dose: $time';
  }

  @override
  String get givenCheckIngredient =>
      'Check other medicines with the same ingredient before giving another dose.';

  @override
  String get medicineMinHours => 'Minimum hours between doses';

  @override
  String get medicineMinHoursHint =>
      'As written on the label or by your doctor. Leave empty if it doesn\'t say.';

  @override
  String get medicineMinHoursInvalid => 'Enter hours between 0.5 and 72';

  @override
  String medicineMinHoursSuggest(String phrase, String hours) {
    return 'The instructions say “$phrase”. Use $hours hours?';
  }

  @override
  String get medicineMinHoursUse => 'Use';

  @override
  String medicineMinHoursValue(String hours) {
    return '$hours hours';
  }

  @override
  String get warnArmpitNote =>
      'Armpit readings run lower. If your baby feels hot or seems unwell, call the doctor even below 38 °C.';

  @override
  String get warnNoBirthDate =>
      'Add a date of birth to see the signs for this age.';

  @override
  String get readingConfirmTitle => 'Is this right?';

  @override
  String readingConfirmBody(String value) {
    return '$value is a very unusual body temperature. Check the thermometer and the unit.';
  }

  @override
  String get readingConfirmYes => 'Save anyway';

  @override
  String get readingConfirmNo => 'Change it';

  @override
  String backupLastCopy(String date) {
    return 'Last copy sent elsewhere: $date';
  }

  @override
  String get backupAutoTitle => 'Automatic backup';

  @override
  String get backupAutoHint =>
      'When you open Usra and a backup is due, it saves an encrypted copy in a folder you choose, never iCloud.';

  @override
  String get backupAutoFolder => 'Folder';

  @override
  String get backupAutoChooseFolder => 'Choose a folder';

  @override
  String get backupAutoFrequency => 'How often';

  @override
  String get backupFrequencyDaily => 'Every day';

  @override
  String get backupFrequencyWeekly => 'Every week';

  @override
  String get backupFrequencyMonthly => 'Every month';

  @override
  String get backupAutoNever => 'No automatic backup yet';

  @override
  String get backupAutoRunning => 'Backing up. You can keep using the app.';

  @override
  String get backupAutoDone => 'Backup saved in your folder.';

  @override
  String get backupSendCopy => 'Send a copy somewhere else';

  @override
  String get backupBusy =>
      'A backup is already running. Try again in a moment.';

  @override
  String get backupAutoDriveHint =>
      'Google Drive may not appear when you choose a folder, and Usra doesn\'t ask for access to your Drive. To keep a copy in Drive, tap \"Send a copy somewhere else\" and choose Drive.';

  @override
  String get backupAutoOnPhone =>
      'This folder is on this phone. If the phone is lost, these backups go with it, so send a copy somewhere else too.';

  @override
  String get backupAutoIosHint =>
      'Choose a place off this phone if you can, such as another app in Files or an external drive. A folder in On My iPhone is lost with the phone. iCloud Drive can\'t be used for health records.';

  @override
  String get backupICloudTitle => 'iCloud Drive can\'t be used';

  @override
  String get backupICloudBody =>
      'Apple\'s rules don\'t allow health records in iCloud, even encrypted, so Usra won\'t save backups there. Choose another place, such as another app in Files or an external drive.';

  @override
  String get backupFolderCantUseTitle => 'This place can\'t be used';

  @override
  String get backupFolderCantUseBody =>
      'Usra couldn\'t save and tidy up its files there. Choose another folder.';

  @override
  String get backupAutoKeyFirstTitle => 'First, your recovery key';

  @override
  String get backupAutoKeyFirstBody =>
      'Backups are encrypted, and only your recovery key opens them. You\'ll write it on paper now. It stays in this phone\'s secure storage and is never saved with the backups.';

  @override
  String get backupAutoKeyFirstContinue => 'Continue';

  @override
  String get backupAutoFailedTitle => 'The automatic backup didn\'t finish';

  @override
  String get backupAutoRetry => 'Try again';

  @override
  String get backupAutoSetKey => 'Set up the key';

  @override
  String get backupAutoFailFolder =>
      'We can\'t reach the backup folder. It may have been moved or removed. Choose it again.';

  @override
  String get backupAutoFailICloud =>
      'The backup folder is now in iCloud Drive, which can\'t be used for health records. Choose another place.';

  @override
  String get backupAutoFailSpace =>
      'There isn\'t enough storage space for the backup. Free up some space, then try again.';

  @override
  String get backupAutoFailLocked =>
      'The phone locked during the backup. Keep it unlocked, then try again.';

  @override
  String get backupAutoFailKey =>
      'The recovery key isn\'t on this phone any more. Set it up again to keep backing up.';

  @override
  String get backupAutoFailInterrupted =>
      'Usra closed before the backup finished. Any unfinished file is removed next time, and your earlier backups are safe. Try again.';

  @override
  String get backupAutoFailOther =>
      'Something stopped the backup. Your earlier backups are safe. Try again.';

  @override
  String get backupAutoPaused =>
      'Automatic backup is paused because Usra started fresh, so new backups don\'t push out the ones holding your records. Restore a backup, or turn this on again.';

  @override
  String get backupDueAuto =>
      'If your backup folder is on this phone, losing the phone loses the backups too. Send a copy somewhere else.';

  @override
  String backupAutoLast(String date, String size) {
    return 'Last automatic backup: $date ($size)';
  }

  @override
  String backupSizeKb(String size) {
    return '$size KB';
  }

  @override
  String backupSizeMb(String size) {
    return '$size MB';
  }

  @override
  String backupSizeGb(String size) {
    return '$size GB';
  }

  @override
  String backupAutoPhotosSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString photos couldn\'t be opened on this phone and aren\'t in this backup.',
      one: '1 photo couldn\'t be opened on this phone and isn\'t in this backup.',
    );
    return '$_temp0';
  }

  @override
  String get backupAutoOpen => 'Open Backup';

  @override
  String get backupAutoPausedTitle => 'Automatic backup is paused';

  @override
  String get backupAutoUnreadableTitle => 'Automatic backup is off';

  @override
  String get backupAutoUnreadableBody =>
      'We couldn\'t read your automatic backup settings. Your backups are still in your folder. Open Backup to turn it on again.';

  @override
  String get backupContentDroppedTitle =>
      'The latest backup holds less than before';

  @override
  String get backupContentDroppedBody =>
      'It has fewer people, records or photos, or some photos are missing, so we kept your older backups. If you deleted these on purpose, confirm it. If not, restore an older backup.';

  @override
  String get backupContentDroppedAccept => 'I deleted them on purpose';

  @override
  String get backupAutoFolderTop => 'The main folder of the place you chose';

  @override
  String get aboutPrivacyBackupAuto =>
      'If you turn on automatic backup, Usra saves that file by itself to a folder you pick. It sends us nothing, and it won\'t use iCloud Drive.';

  @override
  String get navRecords => 'Records';

  @override
  String get navAdd => 'Add';

  @override
  String get homeMorning => 'Good morning';

  @override
  String get homeEvening => 'Good evening';

  @override
  String get homeNothingNeeded => 'Nothing needed';

  @override
  String get homeNeedsAttentionOne => 'needs your attention';

  @override
  String get homeNeedsAttentionMany => 'need your attention';

  @override
  String get homeNamesJoin => 'and';

  @override
  String get homeFamily => 'Family';

  @override
  String homeAllFamily(String count) {
    return 'All family ($count)';
  }

  @override
  String get homeUpcoming => 'Next today';

  @override
  String get homeNewPerson => 'New person';

  @override
  String get homeEmergency => 'Emergency';

  @override
  String homeBackupAgoDays(int days, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last backup $shown days ago',
      one: 'Last backup 1 day ago',
      zero: 'Last backup today',
    );
    return '$_temp0';
  }

  @override
  String homeDoseLogged(String medicine, String person) {
    return 'Logged: $medicine for $person';
  }

  @override
  String get statusSick => 'Unwell';

  @override
  String get statusVaccineOverdue => 'Vaccine overdue';

  @override
  String get statusDoseMissed => 'Dose missed';

  @override
  String statusDoseNext(String time) {
    return 'Dose $time';
  }

  @override
  String get familyAllTitle => 'All family';

  @override
  String familyCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get addSheetTitle => 'What would you like to add?';

  @override
  String get addSheetFor => 'For';

  @override
  String get addSheetPickPerson => 'Choose a person first';

  @override
  String get addSheetNoPeople => 'Add a family member first';

  @override
  String get addMedicine => 'Medicine';

  @override
  String get addVaccine => 'Vaccine';

  @override
  String get addVisit => 'Visit';

  @override
  String get addLab => 'Lab test';

  @override
  String get addScan => 'Scan';

  @override
  String get addFever => 'Fever';

  @override
  String get addGrowth => 'Weight and height';

  @override
  String get addInsurance => 'Insurance card';

  @override
  String get addSurgery => 'Surgery';

  @override
  String get addPhotoTitle => 'Photograph a prescription or medicine box';

  @override
  String get addPhotoHint =>
      'Read on the phone: printed English only, and the name and strength still need checking.';

  @override
  String get addPhotoPrescription => 'Prescription';

  @override
  String get addPhotoBox => 'Medicine box';

  @override
  String get profileMoreDetails => 'More details';

  @override
  String profileSaveNamed(String name) {
    return 'Save $name';
  }

  @override
  String get recordsTitle => 'Records';

  @override
  String get recordsAll => 'All';

  @override
  String get recordsEmpty =>
      'No records yet. Tap Add to log a first visit or test.';

  @override
  String get recordsAdd => 'New record';

  @override
  String get moreFamily => 'All family';

  @override
  String get moreGroupFamily => 'Family';

  @override
  String get moreGroupSafety => 'Safety';

  @override
  String get moreGroupApp => 'App';

  @override
  String get accountKeepsQuestion => 'What does the account keep?';

  @override
  String get accountKeeps =>
      'Your email, an account ID, language and device information, plus your name and profile photo link if you use Google. Records and photos are not on it.';

  @override
  String get accountDeleteNote =>
      'Deleting the account doesn\'t delete the records on this phone. You can delete those from Privacy.';

  @override
  String get privacyEncryptedQ => 'What\'s encrypted?';

  @override
  String get privacyEncryptedA => 'The database, the photos and the backups.';

  @override
  String get privacyCanSeeQ => 'Can we see your records?';

  @override
  String get privacyCanSeeA => 'No. Records and photos stay on your phone.';

  @override
  String get privacyBackupQ => 'What\'s in a backup?';

  @override
  String get privacyBackupA =>
      'Your records and photos, encrypted with your recovery key.';

  @override
  String get privacyPinQ => 'What if the PIN is forgotten?';

  @override
  String get privacyPinA =>
      'Nothing gets past it, not even us. Usra\'s data on the phone is erased, then restored from a backup with the recovery key. With no backup, the records are lost.';

  @override
  String get privacyDeleteQ => 'What if the data is deleted?';

  @override
  String get privacyDeleteA =>
      'It\'s erased from the phone. Backups saved in a folder or on WhatsApp stay until they\'re deleted there.';

  @override
  String get lockSetupBackupReady =>
      'A PIN needs a backup first. There is one, so you can go ahead.';

  @override
  String get statusSickFemale => 'Unwell';

  @override
  String get emergencyPickPerson => 'Whose card?';

  @override
  String get homeLoadError =>
      'Can\'t read your data right now. Close the app and open it again.';

  @override
  String homeGreetingNamed(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get welcomeHeadline => 'The whole family\'s\nhealth in one place';

  @override
  String get welcomePrivacyLine =>
      'A file for each person and medicine reminders. Your data stays on your phone, encrypted, and we can\'t see it.';

  @override
  String get welcomeStart => 'Let\'s start';

  @override
  String get welcomeHaveBackup => 'I have a backup';

  @override
  String get welcomeDisclaimer =>
      'Usra is not a medical device and doesn\'t replace a doctor.';

  @override
  String get welcomePrivacy => 'Privacy';

  @override
  String get welcomeTerms => 'Terms';

  @override
  String get welcomeLanguageOther => 'العربية';

  @override
  String get consentTitle => 'Before you start';

  @override
  String get consentHint =>
      'Usra keeps health information, so it needs your agreement first.';

  @override
  String get consentUpdated =>
      'The privacy policy has changed. Usra needs your agreement again before going on.';

  @override
  String get consentPointLocal =>
      'Your family\'s health data stays on this phone, encrypted. We can\'t see it.';

  @override
  String get consentPointGuardian =>
      'You add family members\' information as their parent or guardian, or with their agreement.';

  @override
  String get consentPointDoctor =>
      'Usra doesn\'t diagnose or treat. Always check with a doctor.';

  @override
  String get consentPrivacyLink => 'Privacy policy';

  @override
  String get consentTermsLink => 'Terms of use';

  @override
  String consentVersion(String version) {
    return 'Privacy policy version $version';
  }

  @override
  String get consentCheckbox =>
      'I\'ve read the privacy policy and the terms, and I agree to Usra keeping my family\'s health data on this phone.';

  @override
  String get consentAgree => 'I agree';

  @override
  String get consentSaveFailed =>
      'Your agreement couldn\'t be saved. Try again.';

  @override
  String get consentDecline => 'Don\'t agree? Delete all my data';

  @override
  String onboardingStep(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingBack => 'Back';

  @override
  String get countryTitle => 'Country';

  @override
  String get countryHint =>
      'So the vaccine schedule and the ambulance number are right.';

  @override
  String get countryEgypt => 'Egypt';

  @override
  String get countryEgyptDetail =>
      'Ministry of Health and Population – Ambulance 123';

  @override
  String get countrySaudi => 'Saudi Arabia';

  @override
  String get countryJordan => 'Jordan';

  @override
  String get countrySoon => 'Coming soon';

  @override
  String get aboutYouTitle => 'The first file in your family';

  @override
  String get aboutYouHint => 'This one is yours, and it can be changed later.';

  @override
  String get aboutYouSex => 'Sex';

  @override
  String get aboutYouSexHint => 'For growth charts and pregnancy.';

  @override
  String get aboutYouBirthDateHint => 'For suggestions that depend on age.';

  @override
  String get aboutYouBirthDateFuture =>
      'A date of birth can\'t be in the future.';

  @override
  String get aboutYouDone => 'Let\'s go';

  @override
  String personAddFor(String name) {
    return 'Add for $name';
  }

  @override
  String personVaccineWasDue(String date) {
    return 'It was due on $date. Ask the doctor when to give it.';
  }

  @override
  String get personDoctorSummary => 'Doctor summary';

  @override
  String get personInsuranceOpen => 'Open card';

  @override
  String get personVaccineLog => 'Given? Log it';

  @override
  String personVaccineSource(String route, String date) {
    return 'Reference: Egypt\'s vaccine schedule, $route – checked $date';
  }

  @override
  String personVaccineSourceOptional(String date) {
    return 'Reference: pediatricians\' usual schedules in Egypt – checked $date';
  }

  @override
  String personNextDose(String time) {
    return 'Next dose – $time';
  }

  @override
  String personDoseWasAt(String time) {
    return 'Was due at $time';
  }

  @override
  String get personRecordedTitle => 'Recorded by the family';

  @override
  String get personTimelineTitle => 'All records';

  @override
  String get personTileGrowth => 'Growth';

  @override
  String get personTileVisits => 'Visits and labs';

  @override
  String get personTileInsurance => 'Insurance';

  @override
  String get personTileDocuments => 'Documents and photos';

  @override
  String personVaccinesSummary(String done, String total) {
    return '$done of $total – Egypt schedule';
  }

  @override
  String personGrowthWeight(String value, String date) {
    return '$value kg – $date';
  }

  @override
  String personGrowthHeight(String value, String date) {
    return '$value cm – $date';
  }

  @override
  String personLatestOn(String date) {
    return 'Latest $date';
  }

  @override
  String personInsuranceCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown cards',
      one: '1 card',
      zero: 'None yet',
    );
    return '$_temp0';
  }

  @override
  String personMedicinesCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown current',
      one: '1 current',
      zero: 'None current',
    );
    return '$_temp0';
  }

  @override
  String personFollowUpsCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown follow-ups',
      one: '1 follow-up',
      zero: 'None for now',
    );
    return '$_temp0';
  }

  @override
  String personDocumentsCount(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown records with photos',
      one: '1 record with photos',
      zero: 'None yet',
    );
    return '$_temp0';
  }

  @override
  String get personVisitsEmpty => 'No visits or lab results recorded yet.';

  @override
  String get personDocumentsEmpty => 'No records with photos yet.';

  @override
  String personAgeYears(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String personAgeMonths(int count, String shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$shown months',
      one: '1 month',
      zero: 'Under 1 month',
    );
    return '$_temp0';
  }

  @override
  String emergencyAmbulanceShort(String number) {
    return 'Ambulance $number';
  }

  @override
  String get emergencyOtherLanguage => 'عربي';

  @override
  String get emergencyMedicines => 'Current medicines';

  @override
  String get emergencyAsTyped =>
      'This is what the family recorded, as they typed it.';

  @override
  String get emergencyLockTitle => 'Show on Usra\'s lock screen';

  @override
  String get emergencyLockHint =>
      'Anyone holding the phone can see it once Usra is open';

  @override
  String get emergencyMedicalIdHint =>
      'Usra\'s lock screen only appears once the phone itself is unlocked. So a paramedic can read this on a locked phone, also add it to the phone\'s own Medical ID or emergency information, in the phone\'s settings.';

  @override
  String lockEmergencyConfirmTitle(String name) {
    return 'Show $name\'s card on Usra\'s lock screen?';
  }

  @override
  String get lockEmergencyConfirmBody =>
      'Anyone holding the phone with Usra open will be able to see the blood type, allergies, conditions, surgeries, current medicines and emergency number and whose it is without the PIN. This is Usra\'s lock screen, not the phone\'s.';

  @override
  String get lockEmergencyConfirmYes => 'Yes, show it';

  @override
  String get insuranceCopyNumber => 'Copy member number';

  @override
  String get insuranceCopyFailed => 'Couldn\'t copy the number';

  @override
  String get insuranceNumberCopied => 'Member number copied';

  @override
  String get doseGroupMissed => 'Missed';

  @override
  String get doseGroupNow => 'Now';

  @override
  String get doseGroupDone => 'Logged';

  @override
  String get dayPartMorning => 'Morning';

  @override
  String get dayPartNoon => 'Noon';

  @override
  String get dayPartAfternoon => 'Afternoon';

  @override
  String get dayPartNight => 'Night';

  @override
  String get doseSnoozeShort => 'In 10 min';

  @override
  String get doseTakenEarly => 'Taken early';

  @override
  String doseSnoozedUntil(String time) {
    return 'Snoozed until $time';
  }

  @override
  String doseLoggedEarly(String medicine, String person) {
    return 'Logged early: $medicine for $person';
  }

  @override
  String doseLoggedNotTaken(String medicine, String person) {
    return 'Logged as not taken: $medicine for $person';
  }

  @override
  String doseLoggedSnoozed(String medicine, String person) {
    return 'Reminder in 10 minutes: $medicine for $person';
  }

  @override
  String get medicinesAll => 'All medicines';

  @override
  String get medicinesFilterAll => 'All';

  @override
  String medicinesTodayEmptyFor(String name) {
    return 'No medicines for $name today.';
  }

  @override
  String medicineFor(String name) {
    return 'This medicine is for $name';
  }

  @override
  String get medicineForChange => 'Change';

  @override
  String get medicineForPick => 'Who is this medicine for?';

  @override
  String medicineSaveFor(String name) {
    return 'Save for $name';
  }

  @override
  String medicineSaveForRemind(String name) {
    return 'Save for $name and remind me';
  }

  @override
  String medicineSavedFor(String medicine, String name) {
    return 'Saved: $medicine for $name';
  }

  @override
  String get medicineScanOption => 'Read the name from a box photo';

  @override
  String get medicineScanOptionBody =>
      'You\'ll check the name and strength before saving';

  @override
  String get medicineScanRead => 'Read from the box photo';

  @override
  String get medicineScanReview => 'Check the details on the box before saving';

  @override
  String get medicineScanConfirm =>
      'I checked the name and strength on the box';

  @override
  String get medicineScanConfirmNeeded =>
      'Tick this once you\'ve checked the name and strength';

  @override
  String get medicineScanPrescription =>
      'A prescription with several medicines? Photograph it';

  @override
  String get medicineUnsureValue =>
      'We\'re not sure of this reading. Check it on the box';

  @override
  String get medicineFreqOnce => 'Once a day';

  @override
  String get medicineFreqTwice => 'Twice';

  @override
  String get medicineFreqThrice => '3 times';

  @override
  String get medicineFreqAsNeeded => 'When needed';

  @override
  String get medicineAddAnotherTime => 'Another time';

  @override
  String medicineChangeTime(String time) {
    return 'Change $time';
  }

  @override
  String get medicineOngoing => 'Ongoing';

  @override
  String get medicineUntilDate => 'Until a date';

  @override
  String get medicineLastDay => 'Last day';

  @override
  String get medicineMoreDetails => 'More details';

  @override
  String get medicineLessDetails => 'Fewer details';

  @override
  String get medicineClose => 'Close';

  @override
  String vaccinesTitleOf(String name) {
    return '$name\'s vaccines';
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

    return '$doneString of $totalString doses given';
  }

  @override
  String get vaccineNewTitle => 'New vaccine';

  @override
  String get vaccineDoneGroup => 'Done';

  @override
  String vaccineDoneGroupLast(String date) {
    return 'All given – the last on $date';
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

    return '$doneString of $totalString';
  }

  @override
  String get vaccineTickAll => 'Tick all';

  @override
  String get vaccineSetupSkipNow => 'Skip vaccines for now';

  @override
  String get fieldVaccinePlace => 'Where?';

  @override
  String get vaccineCardPhoto => 'Photo of the vaccine card';

  @override
  String get vaccineCardScanTitle => 'Photograph the vaccination card';

  @override
  String get vaccineCardScanBody =>
      'Read on the phone: only dates and vaccine names printed in English, and you confirm each dose.';

  @override
  String get vaccineWhich => 'Which vaccine?';

  @override
  String get vaccineOtherChoice => 'Another vaccine';

  @override
  String get vaccineWhoFor => 'For whom?';

  @override
  String vaccineSavedFor(String vaccine, String name) {
    return 'Saved: $vaccine for $name';
  }

  @override
  String vaccineChoiceOverdue(String dose) {
    return '$dose – overdue';
  }

  @override
  String growthTitleOf(String name) {
    return '$name\'s growth';
  }

  @override
  String get growthNew => 'New measurement';

  @override
  String get growthTabWeight => 'Weight';

  @override
  String get growthTabHeight => 'Height';

  @override
  String get growthTabHead => 'Head';

  @override
  String get growthUnitKg => 'kg';

  @override
  String get growthUnitCm => 'cm';

  @override
  String get growthHistoryTitle => 'Measurements';

  @override
  String growthLegendOwn(String name) {
    return '$name\'s measurements';
  }

  @override
  String get growthLegendReference => 'Reference range';

  @override
  String growthLastOn(String date) {
    return 'Last measured $date';
  }

  @override
  String get growthTabOutside => 'Outside the usual range';

  @override
  String get pregnancyAddRecord => 'Add a visit or test';

  @override
  String get pregnancyNextTitle => 'Coming up';

  @override
  String get pregnancyPastTitle => 'Earlier';

  @override
  String get pregnancySupplementsTitle => 'Medicines and supplements today';

  @override
  String get pregnancySupplementsEmpty => 'Nothing recorded for today.';

  @override
  String get pregnancySupplementsAdd => 'Add a medicine or supplement';

  @override
  String get reportSummaryNotOpinion =>
      'This summary is what the family recorded, not a medical opinion.';

  @override
  String get followUpsThisWeek => 'Today and this week';

  @override
  String get followUpsLater => 'Later';

  @override
  String get followUpsAll => 'All follow-ups';

  @override
  String insuranceWatermark(String name, String date) {
    return '$name – $date';
  }

  @override
  String get insuranceShareWarning =>
      'Before you send it: the card holds personal details, and whoever gets it could pass it on. We\'ll write the date and the insurer\'s name, if saved, across the picture.';

  @override
  String get insuranceShareWarningNoPhoto =>
      'Before you send it: the member number is personal, and whoever gets it could pass it on.';

  @override
  String get insuranceCopyShort => 'Copy';

  @override
  String get insuranceDeleteCard => 'Delete card';

  @override
  String get simpleNextDose => 'Next medicine';

  @override
  String simpleThenDose(String medicine, String time) {
    return 'Then: $medicine at $time';
  }

  @override
  String get simpleNoDoses => 'No doses left today.';

  @override
  String get simpleExit => 'Leave Simple Mode';

  @override
  String get simpleExitWithPin => 'Leave Simple Mode (with the PIN)';

  @override
  String get simpleExitConfirm => 'Leave Simple Mode?';

  @override
  String get simpleExitStay => 'Stay';

  @override
  String get simpleExitGo => 'Leave';

  @override
  String get countrySoonNote =>
      'Saudi Arabia and Jordan will open once their schedules and ambulance numbers are checked.';

  @override
  String get homeSetupIntro =>
      'Some places to start. None of them is required.';

  @override
  String get homeSetupFamily => 'A family member';

  @override
  String get homeSetupFamilyHint => 'Name, sex, date of birth and relationship';

  @override
  String get homeSetupReminders => 'Medicine and vaccine reminders';

  @override
  String get homeSetupRemindersHint => 'Permission is only asked for then';

  @override
  String get homeSetupEmergency => 'Emergency card';

  @override
  String get homeSetupEmergencyHint =>
      'Blood type, allergies and an emergency number';

  @override
  String get homeSetupLockNote =>
      'After the first backup we\'ll suggest locking Usra with a PIN.';

  @override
  String get homeSetupHide => 'Hide';

  @override
  String simpleThenDoseFor(String medicine, String name, String time) {
    return 'Then: $medicine for $name at $time';
  }

  @override
  String vaccineCatchUp(String date) {
    return 'Catch-up – due $date';
  }

  @override
  String get vaccineNextCatchUp => 'Catch-up doses (past their age)';

  @override
  String get vaccineDateAssumed =>
      'The date on the schedule. Change it if it was given on another day.';

  @override
  String vaccineOptionalWasDue(String date) {
    return 'Optional – was due $date';
  }

  @override
  String get vaccineDoseNotGiven => 'Not given';

  @override
  String get prescriptionStopped => 'Stopped';

  @override
  String get reminderExactOffTitle => 'Reminders may be late';

  @override
  String get vaccineCatchUpShort => 'catch-up';

  @override
  String get vaccineMarkPastTitle => 'Mark past doses as given?';

  @override
  String vaccineMarkPastAge(String sex, String age) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'She is $age now.',
      'male': 'He is $age now.',
      'other': 'Age now: $age.',
    });
    return '$_temp0';
  }

  @override
  String vaccineMarkPastBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString required doses due up to this age will be marked as given, each on its date on the schedule, not today.',
      one: '1 required dose due up to this age will be marked as given, on its date on the schedule, not today.',
      zero: 'No required dose is left to mark up to this age.',
    );
    return '$_temp0';
  }

  @override
  String get vaccineMarkPastSafety =>
      'Check the vaccination card first: the card and the child\'s doctor are the reference. You can undo this, or untick any dose later.';

  @override
  String vaccineMarkPastOptional(int count, String names) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString doses',
      one: '1 dose',
    );
    return 'Also the optional ones due by this age, each on its date: $names ($_temp0)';
  }

  @override
  String vaccineMarkPastOptionalHint(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'she didn\'t',
      'male': 'he didn\'t',
      'other': 'the child didn\'t',
    });
    return 'The optional ones are the private, paid vaccines. Untick if $_temp0 have them.';
  }

  @override
  String get vaccineMarkPastOk => 'Mark them';

  @override
  String vaccineMarkPastDone(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marked $countString doses as given',
      one: 'Marked 1 dose as given',
    );
    return '$_temp0';
  }

  @override
  String vaccineMissingCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString doses missing',
      one: '1 dose missing',
    );
    return '$_temp0';
  }

  @override
  String vaccineGivableNow(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Can be given now: $countString';
  }

  @override
  String get growthImplausibleTitle => 'Is this number right?';

  @override
  String growthImplausibleBody(String values) {
    return '$values: far from any measurement for a child of this age. It may be a typing mistake.';
  }

  @override
  String get growthImplausibleFix => 'Fix it';

  @override
  String get growthImplausibleKeep => 'Save as it is';

  @override
  String vaccineGivableNowCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString can be given now';
  }

  @override
  String get backupNoneTitle => 'No backup yet';

  @override
  String get sickDayNoReadingsYet => 'No readings yet';

  @override
  String get sickDaysPastHere => 'Past sick days will show here';

  @override
  String get warnEmergencyShort => 'Call an ambulance at once if you see';

  @override
  String get sickDayAllSigns => 'All the signs, and when to call the doctor';

  @override
  String get backupNeverShort => 'No backup yet';

  @override
  String get settingsStateOn => 'On';

  @override
  String get settingsStateOff => 'Off';

  @override
  String get settingsDiscreetHintShort =>
      'Reminders just say \"Your medicine time\"';

  @override
  String get settingsBlockScreenshotsHintShort =>
      'No screenshots or screen recording in the app';

  @override
  String vaccineMarkPastAsk(String sex) {
    String _temp0 = intl.Intl.selectLogic(sex, {
      'female': 'Had everything due so far? Mark it all at once',
      'male': 'Had everything due so far? Mark it all at once',
      'other': 'Everything due so far given? Mark it all at once',
    });
    return '$_temp0';
  }

  @override
  String vaccineGivableNowHeading(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Can be given now – $countString';
  }

  @override
  String vaccineWasDueAt(String age) {
    return 'Was due $age';
  }

  @override
  String get vaccineLogShort => 'Log';

  @override
  String get vaccineDoctorDecides => 'The doctor decides when they\'re given.';

  @override
  String vaccineAndMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $countString more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String vaccineThenInOrder(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'then $countString doses in order',
      one: 'then 1 dose in order',
    );
    return '$_temp0';
  }

  @override
  String vaccineMissingDosesTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString vaccine doses missing',
      one: '1 vaccine dose missing',
    );
    return '$_temp0';
  }

  @override
  String get sickDayReadingShort => 'Reading';
}
