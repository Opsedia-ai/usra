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
  String get aboutTitle => 'About & privacy';

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
      'An account is optional, and there are no ads and no tracking. If you sign in, we keep your email (and your name with Google) to run the account, and we never receive your health records. We never sell or share anyone\'s data.';

  @override
  String get aboutPrivacyBackup =>
      'A backup is an encrypted file you keep wherever you choose. Only your recovery key opens it, and we don\'t have it.';

  @override
  String get aboutPrivacyPhotos =>
      'The camera and photos are used only when you choose, and text is read from them on this phone.';

  @override
  String get aboutPrivacyReminders =>
      'Reminders are set on this phone. People\'s names and medicine names can show on the lock screen (the name as you typed it) and on the home-screen widget (first names).';

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
    return 'PDF $number';
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
    return 'Test $number';
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
    return 'Found $count results. Highlighted boxes are ones the phone wasn\'t sure of: check them against the paper.';
  }

  @override
  String get labScanNothing =>
      'Couldn\'t find results in this photo. Type them in; the photo is kept with the report.';

  @override
  String get labScanFailed => 'Couldn\'t read the photo';

  @override
  String labScanSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tests were already in the form, so their new readings weren\'t added.',
      one: '1 test was already in the form, so its new reading wasn\'t added.',
    );
    return '$_temp0';
  }

  @override
  String labScanReplace(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Use the $count new readings',
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
  String get vaccinesTitle => 'Vaccinations';

  @override
  String vaccinesDisclaimer(String date) {
    return 'Required doses follow the Egyptian Ministry of Health and Population\'s schedule; optional ones follow common private-practice schedules (checked $date). For information only: schedules change, and the child\'s health office card and doctor are the reference.';
  }

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more wrong PINs erase everything',
      one: '1 more wrong PIN erases everything',
    );
    return '$_temp0';
  }

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
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks أسبوع',
      few: '$weeks أسابيع',
      two: 'أسبوعين',
      one: 'أسبوع',
      zero: 'أقل من أسبوع',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      few: '$days أيام',
      two: 'يومين',
      one: 'يوم',
      zero: '0 يوم',
    );
    return '$_temp0 و$_temp1';
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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days to the due date',
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
    return 'Antenatal visit $number of 8';
  }

  @override
  String ancContactReason(int week) {
    return 'Around week $week of pregnancy';
  }

  @override
  String ancWindow(int from, int to) {
    return 'Usually between weeks $from and $to of pregnancy';
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
    return '$done of $total ticked';
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
  String milestone(String id) {
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
    return '$_temp0';
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
    return '$ml ml';
  }

  @override
  String logDuration(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours h $minutes min',
      zero: '$minutes min',
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count feeds',
      one: '1 feed',
    );
    return '$_temp0 (breast $breast, bottle $bottle, solids $solids)';
  }

  @override
  String logSummaryBottleMl(int ml) {
    return '$ml ml from the bottle';
  }

  @override
  String logSummarySleep(String duration) {
    return 'Sleep: $duration';
  }

  @override
  String logSummaryDiapers(int wet, int dirty) {
    return 'Diapers: $wet wet, $dirty dirty';
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
  String get accountSettingsHint => 'Optional. Your records stay on this phone';

  @override
  String get accountPrivacy =>
      'Your family\'s health records stay on this phone. An account doesn\'t upload them: it only gets things ready for syncing between your family\'s phones and for AI features later, and you\'ll choose before anything is shared.';

  @override
  String get accountSignInIntro =>
      'An account is optional: the app works fully without one. Google shares your name and email with us; Apple shares your email.';

  @override
  String get accountSignInConsent =>
      'By signing in, you agree that we keep this to run your account, as the privacy policy says.';

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
      'To keep your family\'s records private, nothing can skip the PIN, not even us.\n\nTo start again:\n1. Remove Usra\'s data. On Android: phone Settings › Apps › Usra › Storage › Clear data. On iPhone: delete Usra and install it again. This deletes everything Usra keeps on this phone.\n2. Open Usra and restore your latest backup with your recovery key (More › Backup).\n\nWithout a backup and its recovery key, the records can\'t be brought back.';

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
    return '$count of 6 numbers typed';
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
  String get lockSettingsEmergency => 'Emergency card on the lock screen';

  @override
  String get lockSettingsEmergencyHint =>
      'A paramedic can see the blood type, allergies and conditions of the people you choose here without the PIN. Anyone holding the phone can see them too.';

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
  String get lockEmergencyFor => 'Show on the lock screen';

  @override
  String get lockBackupFirstTitle => 'Make a backup first?';

  @override
  String get lockBackupFirstBody =>
      'If you forget your PIN, the only way back in is to remove Usra\'s data and restore a backup with its recovery key. You don\'t have a backup yet.';

  @override
  String get lockBackupFirstMake => 'Make a backup';

  @override
  String get lockBackupFirstSkip => 'Continue without';

  @override
  String backupDonePhotosSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos couldn\'t be opened on this phone and aren\'t',
      one: '1 photo couldn\'t be opened on this phone and isn\'t',
    );
    return 'Backup ready, but $_temp0 in it. Keep it somewhere safe off this phone.';
  }

  @override
  String restorePhotosSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count photos in this backup can\'t be opened and will be left out.',
      one: '1 photo in this backup can\'t be opened and will be left out.',
    );
    return '$_temp0';
  }

  @override
  String get photosLocked =>
      'Photos can\'t be opened on this phone. Restore your backup to get them back.';

  @override
  String get doseReminderDiscreetTitle => 'Time for a medicine';

  @override
  String get widgetDiscreetDose => 'Dose due';

  @override
  String get settingsDiscreet => 'Discreet notifications';

  @override
  String get settingsDiscreetHint =>
      'Reminders and the home-screen widget say \"Time for a medicine\", without the person\'s or the medicine\'s name.';

  @override
  String get settingsBlockScreenshots => 'Block screenshots';

  @override
  String get settingsBlockScreenshotsHint =>
      'No screenshots or screen recording anywhere in the app. The recovery key is always protected. Leave off to screenshot the emergency card.';

  @override
  String get doseReminderDiscreetBody => 'Open Usra to see which';

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
  String get vaccineNotFollowed => 'Not in your plan';

  @override
  String vaccineRequiredDone(int done, int total) {
    return '$done/$total required done';
  }

  @override
  String vaccineOptionalDone(int done, int total) {
    return '$done/$total optional done';
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
  String get vaccineSetupSkip => 'Later';

  @override
  String get vaccineSetupSaved => 'Vaccinations saved';

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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'Tomorrow',
      zero: 'Today',
    );
    return '$_temp0';
  }

  @override
  String vaccineDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Was due $days days ago',
      one: 'Was due yesterday',
    );
    return '$_temp0';
  }

  @override
  String vaccineOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses overdue',
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
    return 'Medicine $n';
  }

  @override
  String get prescriptionRemoveMedicine => 'Remove this medicine';

  @override
  String get prescriptionDose => 'Dose, as the doctor wrote it';

  @override
  String get prescriptionDoseHint => 'e.g. 5 ml after meals';

  @override
  String get prescriptionTimesPerDay =>
      'Times a day (you can change the times)';

  @override
  String prescriptionTimesN(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medicines',
      one: '1 medicine',
    );
    return '$_temp0';
  }

  @override
  String prescriptionDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get prescriptionLink => 'Prescription';

  @override
  String courseDayOf(int day, int total) {
    return 'Day $day of $total';
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
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n hours',
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
      'Check the times match what the doctor wrote, e.g. every 8 hours.';

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
    return 'Page $page of $total';
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
      'A summary made by the family in the Usra app from their own records. Informational only: check against the original prescriptions and reports.';

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
    return '$done of $total doses in the plan given';
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
  String get sickDayOngoing => 'Still ill';

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
  String get sickDayReopen => 'Still ill';

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
  String symptomName(String symptom) {
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
    return '$_temp0';
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
  String warnSign(String sign) {
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
    return '$_temp0';
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
      'When you open Usra and a backup is due, it saves an encrypted copy in a folder you choose. No account needed.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count photos couldn\'t be opened on this phone and aren\'t in this backup.',
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
  String get recordsTitle => 'Records';

  @override
  String get recordsAll => 'All';

  @override
  String get recordsEmpty =>
      'No records yet. Tap Add to log a first visit or test.';

  @override
  String get recordsAdd => 'Add a record';

  @override
  String get moreFamily => 'Family';
}
