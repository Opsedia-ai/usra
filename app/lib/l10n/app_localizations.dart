import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Usra'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get navFamily;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navSettings;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello! I\'m Dr. Usra'**
  String get homeGreeting;

  /// No description provided for @homeIntro.
  ///
  /// In en, this message translates to:
  /// **'Your family\'s health, in one safe place. Everything stays on this phone.'**
  String get homeIntro;

  /// No description provided for @homeColorGuide.
  ///
  /// In en, this message translates to:
  /// **'How colours work'**
  String get homeColorGuide;

  /// No description provided for @severityInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get severityInfo;

  /// No description provided for @severityGood.
  ///
  /// In en, this message translates to:
  /// **'All good'**
  String get severityGood;

  /// No description provided for @severityHeadsUp.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get severityHeadsUp;

  /// No description provided for @severityActSoon.
  ///
  /// In en, this message translates to:
  /// **'Act soon'**
  String get severityActSoon;

  /// No description provided for @severityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get severityUrgent;

  /// No description provided for @familyTitle.
  ///
  /// In en, this message translates to:
  /// **'Our family'**
  String get familyTitle;

  /// No description provided for @familyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add the people you care for: kids, parents, grandparents.'**
  String get familyEmpty;

  /// No description provided for @familyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a person'**
  String get familyAdd;

  /// No description provided for @familyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get familyNameLabel;

  /// No description provided for @familySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get familySave;

  /// No description provided for @familyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get familyCancel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this phone, encrypted.'**
  String get settingsPrivacy;

  /// No description provided for @recoveryNotice.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your earlier records on this phone, so we kept them aside safely and started fresh. You can restore them from your backup in More.'**
  String get recoveryNotice;

  /// No description provided for @notMedicalDevice.
  ///
  /// In en, this message translates to:
  /// **'Usra is not a medical device. Always ask your doctor before medical decisions.'**
  String get notMedicalDevice;

  /// No description provided for @familyNew.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get familyNew;

  /// No description provided for @familyEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get familyEdit;

  /// No description provided for @profileBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileBirthDate;

  /// No description provided for @profileSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get profileSex;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @profileBloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood type'**
  String get profileBloodType;

  /// No description provided for @profileAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get profileAllergies;

  /// No description provided for @profileConditions.
  ///
  /// In en, this message translates to:
  /// **'Chronic conditions'**
  String get profileConditions;

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get profileNotFound;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get pickDate;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age, plural, =0{Under 1 year} =1{1 year} other{{age} years}}'**
  String ageYears(int age);

  /// No description provided for @timelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records yet. Add the first visit, scan or vaccine.'**
  String get timelineEmpty;

  /// No description provided for @addRecord.
  ///
  /// In en, this message translates to:
  /// **'Add record'**
  String get addRecord;

  /// No description provided for @chooseRecordType.
  ///
  /// In en, this message translates to:
  /// **'What do you want to add?'**
  String get chooseRecordType;

  /// No description provided for @recordDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get recordDate;

  /// No description provided for @recordCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get recordCost;

  /// No description provided for @currencyEgp.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get currencyEgp;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @fieldInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check this value'**
  String get fieldInvalid;

  /// No description provided for @recordVisit.
  ///
  /// In en, this message translates to:
  /// **'Doctor visit'**
  String get recordVisit;

  /// No description provided for @recordScan.
  ///
  /// In en, this message translates to:
  /// **'Scan or X-ray'**
  String get recordScan;

  /// No description provided for @recordLab.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get recordLab;

  /// No description provided for @recordVaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get recordVaccine;

  /// No description provided for @recordSurgery.
  ///
  /// In en, this message translates to:
  /// **'Surgery'**
  String get recordSurgery;

  /// No description provided for @fieldDoctorName.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get fieldDoctorName;

  /// No description provided for @fieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get fieldReason;

  /// No description provided for @fieldDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get fieldDiagnosis;

  /// No description provided for @fieldNextVisit.
  ///
  /// In en, this message translates to:
  /// **'Next visit'**
  String get fieldNextVisit;

  /// No description provided for @fieldScanKind.
  ///
  /// In en, this message translates to:
  /// **'Type of scan'**
  String get fieldScanKind;

  /// No description provided for @fieldCenter.
  ///
  /// In en, this message translates to:
  /// **'Scan centre'**
  String get fieldCenter;

  /// No description provided for @fieldResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get fieldResult;

  /// No description provided for @fieldTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get fieldTest;

  /// No description provided for @fieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get fieldValue;

  /// No description provided for @fieldUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get fieldUnit;

  /// No description provided for @fieldVaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get fieldVaccine;

  /// No description provided for @fieldDose.
  ///
  /// In en, this message translates to:
  /// **'Dose number'**
  String get fieldDose;

  /// No description provided for @fieldNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next dose'**
  String get fieldNextDue;

  /// No description provided for @fieldProcedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get fieldProcedure;

  /// No description provided for @fieldHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get fieldHospital;

  /// No description provided for @fieldFilmed.
  ///
  /// In en, this message translates to:
  /// **'Filmed'**
  String get fieldFilmed;

  /// No description provided for @fieldDaysInHospital.
  ///
  /// In en, this message translates to:
  /// **'Days in hospital'**
  String get fieldDaysInHospital;

  /// No description provided for @scanXray.
  ///
  /// In en, this message translates to:
  /// **'X-ray'**
  String get scanXray;

  /// No description provided for @scanCt.
  ///
  /// In en, this message translates to:
  /// **'CT'**
  String get scanCt;

  /// No description provided for @scanMri.
  ///
  /// In en, this message translates to:
  /// **'MRI'**
  String get scanMri;

  /// No description provided for @scanUltrasound.
  ///
  /// In en, this message translates to:
  /// **'Ultrasound'**
  String get scanUltrasound;

  /// No description provided for @scanOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get scanOther;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get saveFailed;

  /// No description provided for @navDoctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get navDoctors;

  /// No description provided for @doctorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Family doctors'**
  String get doctorsTitle;

  /// No description provided for @doctorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No doctors yet. Add your family doctor to call them in one tap.'**
  String get doctorsEmpty;

  /// No description provided for @doctorsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add doctor'**
  String get doctorsAdd;

  /// No description provided for @doctorNew.
  ///
  /// In en, this message translates to:
  /// **'New doctor'**
  String get doctorNew;

  /// No description provided for @doctorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit doctor'**
  String get doctorEdit;

  /// No description provided for @doctorName.
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s name'**
  String get doctorName;

  /// No description provided for @doctorSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get doctorSpecialty;

  /// No description provided for @doctorPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get doctorPhone;

  /// No description provided for @doctorClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic or hospital'**
  String get doctorClinic;

  /// No description provided for @doctorAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get doctorAddress;

  /// No description provided for @doctorFee.
  ///
  /// In en, this message translates to:
  /// **'Visit fee'**
  String get doctorFee;

  /// No description provided for @doctorNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get doctorNotes;

  /// No description provided for @doctorCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get doctorCall;

  /// No description provided for @doctorWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get doctorWhatsapp;

  /// No description provided for @doctorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get doctorDelete;

  /// No description provided for @doctorDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your doctors? Past visits stay as they are.'**
  String doctorDeleteConfirm(String name);

  /// No description provided for @doctorVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get doctorVisits;

  /// No description provided for @doctorNoVisits.
  ///
  /// In en, this message translates to:
  /// **'No visits recorded with this doctor yet.'**
  String get doctorNoVisits;

  /// No description provided for @doctorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Doctor not found'**
  String get doctorNotFound;

  /// No description provided for @chooseDoctor.
  ///
  /// In en, this message translates to:
  /// **'Pick from family doctors'**
  String get chooseDoctor;

  /// No description provided for @contactFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that app on this phone'**
  String get contactFailed;

  /// No description provided for @navMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get navMoney;

  /// No description provided for @spendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical spending'**
  String get spendingTitle;

  /// No description provided for @spendingWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get spendingWeek;

  /// No description provided for @spendingMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get spendingMonth;

  /// No description provided for @spendingYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get spendingYear;

  /// No description provided for @spendingWholeFamily.
  ///
  /// In en, this message translates to:
  /// **'Whole family'**
  String get spendingWholeFamily;

  /// No description provided for @spendingPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get spendingPrevious;

  /// No description provided for @spendingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get spendingNext;

  /// No description provided for @spendingByType.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get spendingByType;

  /// No description provided for @spendingByPerson.
  ///
  /// In en, this message translates to:
  /// **'By person'**
  String get spendingByPerson;

  /// No description provided for @spendingByDoctor.
  ///
  /// In en, this message translates to:
  /// **'By doctor'**
  String get spendingByDoctor;

  /// No description provided for @spendingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No costs recorded in this period.'**
  String get spendingEmpty;

  /// No description provided for @spendingRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent periods'**
  String get spendingRecent;

  /// No description provided for @spendingRecords.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record} other{{count} records}}'**
  String spendingRecords(int count);

  /// No description provided for @memberSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get memberSpending;

  /// No description provided for @insuranceTitle.
  ///
  /// In en, this message translates to:
  /// **'Insurance cards'**
  String get insuranceTitle;

  /// No description provided for @insuranceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No insurance cards yet.'**
  String get insuranceEmpty;

  /// No description provided for @insuranceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add insurance card'**
  String get insuranceAdd;

  /// No description provided for @insuranceNew.
  ///
  /// In en, this message translates to:
  /// **'New insurance card'**
  String get insuranceNew;

  /// No description provided for @insuranceEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get insuranceEdit;

  /// No description provided for @insuranceLabel.
  ///
  /// In en, this message translates to:
  /// **'Card name (e.g. Union, Work)'**
  String get insuranceLabel;

  /// No description provided for @insuranceCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get insuranceCard;

  /// No description provided for @insuranceInsurer.
  ///
  /// In en, this message translates to:
  /// **'Insurance company'**
  String get insuranceInsurer;

  /// No description provided for @insuranceMemberNumber.
  ///
  /// In en, this message translates to:
  /// **'Member number'**
  String get insuranceMemberNumber;

  /// No description provided for @insuranceExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get insuranceExpiry;

  /// No description provided for @insuranceNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get insuranceNotes;

  /// No description provided for @insuranceFront.
  ///
  /// In en, this message translates to:
  /// **'Front of card'**
  String get insuranceFront;

  /// No description provided for @insuranceBack.
  ///
  /// In en, this message translates to:
  /// **'Back of card'**
  String get insuranceBack;

  /// No description provided for @insuranceShare.
  ///
  /// In en, this message translates to:
  /// **'Send on WhatsApp'**
  String get insuranceShare;

  /// No description provided for @insuranceShareHeader.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s insurance card'**
  String insuranceShareHeader(String name);

  /// No description provided for @insuranceExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String insuranceExpired(String date);

  /// No description provided for @insuranceExpiresSoon.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String insuranceExpiresSoon(String date);

  /// No description provided for @insuranceValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String insuranceValidUntil(String date);

  /// No description provided for @insuranceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get insuranceDelete;

  /// No description provided for @insuranceDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the {label} card? Its photos will be removed from this phone.'**
  String insuranceDeleteConfirm(String label);

  /// No description provided for @insuranceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Card not found'**
  String get insuranceNotFound;

  /// No description provided for @clearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get clearDate;

  /// No description provided for @photoCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoCamera;

  /// No description provided for @photoGallery.
  ///
  /// In en, this message translates to:
  /// **'From photos'**
  String get photoGallery;

  /// No description provided for @photoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get photoRemove;

  /// No description provided for @photoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the photo'**
  String get photoFailed;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open sharing'**
  String get shareFailed;

  /// No description provided for @emergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency card'**
  String get emergencyTitle;

  /// No description provided for @emergencyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get emergencyUnknown;

  /// No description provided for @emergencyNoneRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded'**
  String get emergencyNoneRecorded;

  /// No description provided for @emergencySurgeries.
  ///
  /// In en, this message translates to:
  /// **'Past surgeries'**
  String get emergencySurgeries;

  /// No description provided for @emergencyComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete emergency details'**
  String get emergencyComplete;

  /// No description provided for @emergencyCallAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Call ambulance {number}'**
  String emergencyCallAmbulance(String number);

  /// No description provided for @homeEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency cards'**
  String get homeEmergencyTitle;

  /// No description provided for @homeEmergencyHint.
  ///
  /// In en, this message translates to:
  /// **'Open fast if someone needs an ambulance'**
  String get homeEmergencyHint;

  /// No description provided for @emergencyLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get emergencyLoading;

  /// No description provided for @emergencyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the records'**
  String get emergencyLoadFailed;

  /// No description provided for @recordGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth measurement'**
  String get recordGrowth;

  /// No description provided for @fieldWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get fieldWeightKg;

  /// No description provided for @fieldHeightCm.
  ///
  /// In en, this message translates to:
  /// **'Length / height (cm)'**
  String get fieldHeightCm;

  /// No description provided for @fieldHeadCm.
  ///
  /// In en, this message translates to:
  /// **'Head circumference (cm)'**
  String get fieldHeadCm;

  /// No description provided for @memberGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth and vaccines'**
  String get memberGrowth;

  /// No description provided for @growthTitle.
  ///
  /// In en, this message translates to:
  /// **'Growth and vaccines'**
  String get growthTitle;

  /// No description provided for @growthAdd.
  ///
  /// In en, this message translates to:
  /// **'Add measurement'**
  String get growthAdd;

  /// No description provided for @growthWeightForAge.
  ///
  /// In en, this message translates to:
  /// **'Weight for age'**
  String get growthWeightForAge;

  /// No description provided for @growthHeightForAge.
  ///
  /// In en, this message translates to:
  /// **'Length / height for age'**
  String get growthHeightForAge;

  /// No description provided for @growthAgeAxis.
  ///
  /// In en, this message translates to:
  /// **'Age (months)'**
  String get growthAgeAxis;

  /// No description provided for @growthNoSex.
  ///
  /// In en, this message translates to:
  /// **'Add the child\'s sex to their profile to see the growth charts.'**
  String get growthNoSex;

  /// No description provided for @growthNoData.
  ///
  /// In en, this message translates to:
  /// **'No measurements yet.'**
  String get growthNoData;

  /// No description provided for @growthLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest: {value} on {date}'**
  String growthLatest(String value, String date);

  /// No description provided for @growthWithinRange.
  ///
  /// In en, this message translates to:
  /// **'Percentile {percentile}: within the usual range for this age.'**
  String growthWithinRange(String percentile);

  /// No description provided for @growthOutsideRange.
  ///
  /// In en, this message translates to:
  /// **'Percentile {percentile}: outside the usual range. Talk to your pediatrician.'**
  String growthOutsideRange(String percentile);

  /// No description provided for @growthSource.
  ///
  /// In en, this message translates to:
  /// **'Curves: WHO Child Growth Standards (3rd, 15th, 50th, 85th and 97th percentiles). For information only; your pediatrician reads your child\'s growth.'**
  String get growthSource;

  /// No description provided for @vaccinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Mandatory vaccinations'**
  String get vaccinesTitle;

  /// No description provided for @vaccinesDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Based on the Egyptian Ministry of Health and Population\'s mandatory schedule. Schedules change, so the child\'s health office card is the official record.'**
  String get vaccinesDisclaimer;

  /// No description provided for @vaccineAtBirth.
  ///
  /// In en, this message translates to:
  /// **'At birth'**
  String get vaccineAtBirth;

  /// No description provided for @vaccineAtMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{At 1 month} other{At {months} months}}'**
  String vaccineAtMonths(int months);

  /// No description provided for @vaccineDone.
  ///
  /// In en, this message translates to:
  /// **'Done {date}'**
  String vaccineDone(String date);

  /// No description provided for @vaccineDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String vaccineDue(String date);

  /// No description provided for @vaccineOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue since {date}'**
  String vaccineOverdue(String date);

  /// No description provided for @vaccineLater.
  ///
  /// In en, this message translates to:
  /// **'On {date}'**
  String vaccineLater(String date);

  /// No description provided for @vaccineDoseName.
  ///
  /// In en, this message translates to:
  /// **'{name}, dose {dose}'**
  String vaccineDoseName(String name, int dose);

  /// No description provided for @vaccineHepB.
  ///
  /// In en, this message translates to:
  /// **'Hepatitis B'**
  String get vaccineHepB;

  /// No description provided for @vaccineBcg.
  ///
  /// In en, this message translates to:
  /// **'BCG (tuberculosis)'**
  String get vaccineBcg;

  /// No description provided for @vaccineOpv.
  ///
  /// In en, this message translates to:
  /// **'Oral polio (drops)'**
  String get vaccineOpv;

  /// No description provided for @vaccineIpv.
  ///
  /// In en, this message translates to:
  /// **'Polio injection (IPV)'**
  String get vaccineIpv;

  /// No description provided for @vaccinePenta.
  ///
  /// In en, this message translates to:
  /// **'Pentavalent'**
  String get vaccinePenta;

  /// No description provided for @vaccineMmr.
  ///
  /// In en, this message translates to:
  /// **'MMR (measles, mumps, rubella)'**
  String get vaccineMmr;

  /// No description provided for @vaccineDtp.
  ///
  /// In en, this message translates to:
  /// **'DTP booster'**
  String get vaccineDtp;

  /// No description provided for @vaccineZeroDose.
  ///
  /// In en, this message translates to:
  /// **'{name}, birth dose'**
  String vaccineZeroDose(String name);

  /// No description provided for @growthUnderFiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Growth charts and the vaccination schedule are for children under 5 with a birth date in their profile.'**
  String get growthUnderFiveOnly;

  /// No description provided for @recordPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get recordPhotos;

  /// No description provided for @recordPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String recordPhotoCount(int count);

  /// No description provided for @recordNotFound.
  ///
  /// In en, this message translates to:
  /// **'This record was deleted'**
  String get recordNotFound;

  /// No description provided for @recordShare.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get recordShare;

  /// No description provided for @recordDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get recordDelete;

  /// No description provided for @recordDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this record? Its photos will be removed from this phone.'**
  String get recordDeleteConfirm;

  /// No description provided for @photoShare.
  ///
  /// In en, this message translates to:
  /// **'Send photo'**
  String get photoShare;

  /// No description provided for @photoDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get photoDelete;

  /// No description provided for @photoDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo from the record?'**
  String get photoDeleteConfirm;

  /// No description provided for @photoPosition.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {total}'**
  String photoPosition(int index, int total);

  /// No description provided for @fieldYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get fieldYes;

  /// No description provided for @fieldNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get fieldNo;

  /// No description provided for @navCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get navCall;

  /// No description provided for @settingsSimpleMode.
  ///
  /// In en, this message translates to:
  /// **'Simple Mode'**
  String get settingsSimpleMode;

  /// No description provided for @settingsSimpleModeHint.
  ///
  /// In en, this message translates to:
  /// **'Bigger text and buttons, fewer tabs. Good for grandparents using the phone on their own.'**
  String get settingsSimpleModeHint;

  /// No description provided for @settingsTutorial.
  ///
  /// In en, this message translates to:
  /// **'Show the tour again'**
  String get settingsTutorial;

  /// No description provided for @profileSimpleMode.
  ///
  /// In en, this message translates to:
  /// **'Uses Simple Mode'**
  String get profileSimpleMode;

  /// No description provided for @profileSimpleModeHint.
  ///
  /// In en, this message translates to:
  /// **'The phone in their hand: Home greets them by name. Turn Simple Mode on in More on that phone.'**
  String get profileSimpleModeHint;

  /// No description provided for @simpleHello.
  ///
  /// In en, this message translates to:
  /// **'Hello!'**
  String get simpleHello;

  /// No description provided for @simpleHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String simpleHelloName(String name);

  /// No description provided for @simpleMedicines.
  ///
  /// In en, this message translates to:
  /// **'My medicines'**
  String get simpleMedicines;

  /// No description provided for @simpleMedicinesSoon.
  ///
  /// In en, this message translates to:
  /// **'Medicine reminders are coming soon.'**
  String get simpleMedicinesSoon;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @simpleCallDoctor.
  ///
  /// In en, this message translates to:
  /// **'Call my doctor'**
  String get simpleCallDoctor;

  /// No description provided for @simpleFamily.
  ///
  /// In en, this message translates to:
  /// **'My family'**
  String get simpleFamily;

  /// No description provided for @simpleEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency card'**
  String get simpleEmergency;

  /// No description provided for @simplePickPerson.
  ///
  /// In en, this message translates to:
  /// **'Whose emergency card?'**
  String get simplePickPerson;

  /// No description provided for @tutorialSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tutorialSkip;

  /// No description provided for @tutorialNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutorialNext;

  /// No description provided for @tutorialBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tutorialBack;

  /// No description provided for @tutorialStart.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start'**
  String get tutorialStart;

  /// No description provided for @tutorialStep.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String tutorialStep(int current, int total);

  /// No description provided for @tutorialWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m Dr. Usra'**
  String get tutorialWelcomeTitle;

  /// No description provided for @tutorialWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Usra keeps your family\'s health in one place: doctor visits, tests, medicines and your doctors\' numbers.'**
  String get tutorialWelcomeBody;

  /// No description provided for @tutorialPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data stays with you'**
  String get tutorialPrivacyTitle;

  /// No description provided for @tutorialPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved on this phone, encrypted. No account needed.'**
  String get tutorialPrivacyBody;

  /// No description provided for @tutorialFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your family'**
  String get tutorialFamilyTitle;

  /// No description provided for @tutorialFamilyBody.
  ///
  /// In en, this message translates to:
  /// **'Add everyone you care for: kids, parents, grandparents. Each person gets their own page.'**
  String get tutorialFamilyBody;

  /// No description provided for @tutorialColorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Colours mean urgency'**
  String get tutorialColorsTitle;

  /// No description provided for @tutorialColorsBody.
  ///
  /// In en, this message translates to:
  /// **'Every colour comes with a word, so you always know what it means.'**
  String get tutorialColorsBody;

  /// No description provided for @tutorialEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'An emergency card for everyone'**
  String get tutorialEmergencyTitle;

  /// No description provided for @tutorialEmergencyBody.
  ///
  /// In en, this message translates to:
  /// **'Blood type, allergies and illnesses on one card, one tap from Home. Show it to a doctor or paramedic.'**
  String get tutorialEmergencyBody;

  /// No description provided for @tutorialElderWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'I\'m here to help you. Everything on the screen is big and clear.'**
  String get tutorialElderWelcomeBody;

  /// No description provided for @tutorialElderButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Big buttons on Home'**
  String get tutorialElderButtonsTitle;

  /// No description provided for @tutorialElderButtonsBody.
  ///
  /// In en, this message translates to:
  /// **'Press «Call my doctor» to call your doctor with one tap.'**
  String get tutorialElderButtonsBody;

  /// No description provided for @tutorialElderEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'If you feel unwell'**
  String get tutorialElderEmergencyTitle;

  /// No description provided for @tutorialElderEmergencyBody.
  ///
  /// In en, this message translates to:
  /// **'Press the red «Emergency card» button and show it to whoever is helping you.'**
  String get tutorialElderEmergencyBody;

  /// No description provided for @scanMedicineTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a medicine box'**
  String get scanMedicineTitle;

  /// No description provided for @scanMedicineIntro.
  ///
  /// In en, this message translates to:
  /// **'Take a clear photo of the front of the box in good light. Usra reads the name and strength printed in English letters.'**
  String get scanMedicineIntro;

  /// No description provided for @scanMedicineLimits.
  ///
  /// In en, this message translates to:
  /// **'Handwritten prescriptions and Arabic text can\'t be read on the phone yet. Type those in yourself.'**
  String get scanMedicineLimits;

  /// No description provided for @scanMedicinePrivacy.
  ///
  /// In en, this message translates to:
  /// **'The photo is read on this phone and isn\'t kept.'**
  String get scanMedicinePrivacy;

  /// No description provided for @scanMedicineReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the box…'**
  String get scanMedicineReading;

  /// No description provided for @scanMedicineSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Is it one of these?'**
  String get scanMedicineSuggestions;

  /// No description provided for @scanMedicineNoneFound.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find a medicine name. Type it in, or try another photo.'**
  String get scanMedicineNoneFound;

  /// No description provided for @scanMedicineFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this photo. Try another one, or type the name in.'**
  String get scanMedicineFailed;

  /// No description provided for @scanMedicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get scanMedicineName;

  /// No description provided for @scanMedicineStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength (optional), e.g. 500mg'**
  String get scanMedicineStrength;

  /// No description provided for @scanMedicineCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the name against the box before you use it.'**
  String get scanMedicineCheck;

  /// No description provided for @scanMedicineUse.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get scanMedicineUse;

  /// No description provided for @scanMedicineRetake.
  ///
  /// In en, this message translates to:
  /// **'Another photo'**
  String get scanMedicineRetake;

  /// No description provided for @scanMedicinePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo of the medicine box'**
  String get scanMedicinePhoto;

  /// No description provided for @followUpsTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups'**
  String get followUpsTitle;

  /// No description provided for @followUpsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing coming up.'**
  String get followUpsEmpty;

  /// No description provided for @followUpsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Suggestions from public guidance (WHO, USPSTF and others) and your records, not a diagnosis. Ask your doctor what suits each person.'**
  String get followUpsDisclaimer;

  /// No description provided for @followUpDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String followUpDue(String date);

  /// No description provided for @followUpOverdue.
  ///
  /// In en, this message translates to:
  /// **'Was due {date}'**
  String followUpOverdue(String date);

  /// No description provided for @followUpSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String followUpSource(String source);

  /// No description provided for @followUpAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {type}'**
  String followUpAdd(String type);

  /// No description provided for @followUpDismiss.
  ///
  /// In en, this message translates to:
  /// **'Hide until next time'**
  String get followUpDismiss;

  /// No description provided for @followUpDismissed.
  ///
  /// In en, this message translates to:
  /// **'Hidden until it\'s due again.'**
  String get followUpDismissed;

  /// No description provided for @followUpUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get followUpUndo;

  /// No description provided for @fuNextVisit.
  ///
  /// In en, this message translates to:
  /// **'Follow-up visit'**
  String get fuNextVisit;

  /// No description provided for @fuNextVisitBy.
  ///
  /// In en, this message translates to:
  /// **'{doctor} set this date at the last visit'**
  String fuNextVisitBy(String doctor);

  /// No description provided for @fuNextVisitSet.
  ///
  /// In en, this message translates to:
  /// **'Set at the last visit'**
  String get fuNextVisitSet;

  /// No description provided for @fuNextDose.
  ///
  /// In en, this message translates to:
  /// **'Next dose: {vaccine}'**
  String fuNextDose(String vaccine);

  /// No description provided for @fuNextDoseSet.
  ///
  /// In en, this message translates to:
  /// **'The date written on the last dose'**
  String get fuNextDoseSet;

  /// No description provided for @fuHba1c.
  ///
  /// In en, this message translates to:
  /// **'HbA1c (3-month sugar) test'**
  String get fuHba1c;

  /// No description provided for @fuLipids.
  ///
  /// In en, this message translates to:
  /// **'Lipid profile (cholesterol)'**
  String get fuLipids;

  /// No description provided for @fuKidney.
  ///
  /// In en, this message translates to:
  /// **'Kidney function and urine albumin'**
  String get fuKidney;

  /// No description provided for @fuScan.
  ///
  /// In en, this message translates to:
  /// **'Follow-up scan'**
  String get fuScan;

  /// No description provided for @fuScanResult.
  ///
  /// In en, this message translates to:
  /// **'The last scan\'s result mentions a follow-up'**
  String get fuScanResult;

  /// No description provided for @fuBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure check'**
  String get fuBloodPressure;

  /// No description provided for @fuBloodSugar.
  ///
  /// In en, this message translates to:
  /// **'Blood sugar test'**
  String get fuBloodSugar;

  /// No description provided for @fuMammogram.
  ///
  /// In en, this message translates to:
  /// **'Mammogram (breast screening)'**
  String get fuMammogram;

  /// No description provided for @fuColorectal.
  ///
  /// In en, this message translates to:
  /// **'Colon cancer screening'**
  String get fuColorectal;

  /// No description provided for @fuEyeExam.
  ///
  /// In en, this message translates to:
  /// **'Eye exam (retina)'**
  String get fuEyeExam;

  /// No description provided for @fuDental.
  ///
  /// In en, this message translates to:
  /// **'Dental check-up'**
  String get fuDental;

  /// No description provided for @fuChildCheckup.
  ///
  /// In en, this message translates to:
  /// **'Child check-up'**
  String get fuChildCheckup;

  /// No description provided for @fuChildCheckupAt.
  ///
  /// In en, this message translates to:
  /// **'The usual check-up at {age}'**
  String fuChildCheckupAt(String age);

  /// No description provided for @fuAgeMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{1 month} other{{months} months}}'**
  String fuAgeMonths(int months);

  /// No description provided for @fuVaccinesDue.
  ///
  /// In en, this message translates to:
  /// **'Mandatory vaccines'**
  String get fuVaccinesDue;

  /// No description provided for @fuVaccinesAt.
  ///
  /// In en, this message translates to:
  /// **'{age}: {names}'**
  String fuVaccinesAt(String age, String names);

  /// No description provided for @fuBecauseCondition.
  ///
  /// In en, this message translates to:
  /// **'Because of {condition}'**
  String fuBecauseCondition(String sex, String condition);

  /// No description provided for @fuLastDoneMonths.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =0{last one this month} =1{last one a month ago} other{last one {months} months ago}}'**
  String fuLastDoneMonths(int months);

  /// No description provided for @fuNeverRecorded.
  ///
  /// In en, this message translates to:
  /// **'none recorded yet'**
  String get fuNeverRecorded;

  /// No description provided for @fuAgeFrom.
  ///
  /// In en, this message translates to:
  /// **'Suggested from age {age}'**
  String fuAgeFrom(int age);

  /// No description provided for @fuAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Suggested at ages {from}–{to}'**
  String fuAgeRange(int from, int to);

  /// No description provided for @fuWomenAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Suggested for women aged {from}–{to}'**
  String fuWomenAgeRange(int from, int to);

  /// No description provided for @fuYearlyForAll.
  ///
  /// In en, this message translates to:
  /// **'Suggested once a year for everyone'**
  String get fuYearlyForAll;

  /// No description provided for @conditionDiabetes.
  ///
  /// In en, this message translates to:
  /// **'diabetes'**
  String get conditionDiabetes;

  /// No description provided for @conditionHypertension.
  ///
  /// In en, this message translates to:
  /// **'high blood pressure'**
  String get conditionHypertension;

  /// No description provided for @conditionHeart.
  ///
  /// In en, this message translates to:
  /// **'heart disease'**
  String get conditionHeart;

  /// No description provided for @conditionHighCholesterol.
  ///
  /// In en, this message translates to:
  /// **'high cholesterol'**
  String get conditionHighCholesterol;

  /// No description provided for @conditionKidney.
  ///
  /// In en, this message translates to:
  /// **'kidney disease'**
  String get conditionKidney;

  /// No description provided for @navMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get navMedicines;

  /// No description provided for @medicinesTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s medicines'**
  String get medicinesTodayTitle;

  /// No description provided for @medicinesTodayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No doses due today. Add a medicine from a person\'s page in Family.'**
  String get medicinesTodayEmpty;

  /// No description provided for @doseTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get doseTaken;

  /// No description provided for @doseSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get doseSkip;

  /// No description provided for @doseSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get doseSkipped;

  /// No description provided for @doseSnoozed.
  ///
  /// In en, this message translates to:
  /// **'Snoozed'**
  String get doseSnoozed;

  /// No description provided for @doseSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze 10 min'**
  String get doseSnooze;

  /// No description provided for @doseUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get doseUndo;

  /// No description provided for @doseMarkedAt.
  ///
  /// In en, this message translates to:
  /// **'{status} at {time}'**
  String doseMarkedAt(String status, String time);

  /// No description provided for @doseReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for {person}\'s medicine: {medicine}'**
  String doseReminderTitle(String person, String medicine);

  /// No description provided for @doseReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Taken once it\'s done'**
  String get doseReminderBody;

  /// No description provided for @doseChannelName.
  ///
  /// In en, this message translates to:
  /// **'Medicine reminders'**
  String get doseChannelName;

  /// No description provided for @doseChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders at the times the doctor prescribed'**
  String get doseChannelDescription;

  /// No description provided for @memberMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get memberMedicines;

  /// No description provided for @medicinesTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s medicines'**
  String medicinesTitle(String name);

  /// No description provided for @medicinesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No medicines yet. Add one exactly as the doctor wrote it.'**
  String get medicinesEmpty;

  /// No description provided for @medicineAdd.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get medicineAdd;

  /// No description provided for @medicineNew.
  ///
  /// In en, this message translates to:
  /// **'New medicine'**
  String get medicineNew;

  /// No description provided for @medicineEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit medicine'**
  String get medicineEdit;

  /// No description provided for @medicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get medicineName;

  /// No description provided for @medicineStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength (as on the box)'**
  String get medicineStrength;

  /// No description provided for @medicineForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get medicineForm;

  /// No description provided for @formTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get formTablet;

  /// No description provided for @formCapsule.
  ///
  /// In en, this message translates to:
  /// **'Capsule'**
  String get formCapsule;

  /// No description provided for @formSyrup.
  ///
  /// In en, this message translates to:
  /// **'Syrup'**
  String get formSyrup;

  /// No description provided for @formDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get formDrops;

  /// No description provided for @formInjection.
  ///
  /// In en, this message translates to:
  /// **'Injection'**
  String get formInjection;

  /// No description provided for @formCream.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get formCream;

  /// No description provided for @formInhaler.
  ///
  /// In en, this message translates to:
  /// **'Inhaler'**
  String get formInhaler;

  /// No description provided for @formOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get formOther;

  /// No description provided for @medicineInstructions.
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s instructions'**
  String get medicineInstructions;

  /// No description provided for @medicineInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Exactly as written on the prescription'**
  String get medicineInstructionsHint;

  /// No description provided for @medicineDoctor.
  ///
  /// In en, this message translates to:
  /// **'Prescribed by'**
  String get medicineDoctor;

  /// No description provided for @medicineNoDoctor.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get medicineNoDoctor;

  /// No description provided for @medicineStart.
  ///
  /// In en, this message translates to:
  /// **'First day'**
  String get medicineStart;

  /// No description provided for @medicineEnd.
  ///
  /// In en, this message translates to:
  /// **'Last day (optional)'**
  String get medicineEnd;

  /// No description provided for @medicineEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The last day is before the first day'**
  String get medicineEndBeforeStart;

  /// No description provided for @medicinePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos of the box or prescription'**
  String get medicinePhotos;

  /// No description provided for @medicineSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get medicineSchedule;

  /// No description provided for @medicineAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get medicineAddTime;

  /// No description provided for @medicineRemoveTime.
  ///
  /// In en, this message translates to:
  /// **'Remove {time}'**
  String medicineRemoveTime(String time);

  /// No description provided for @medicineNoTimes.
  ///
  /// In en, this message translates to:
  /// **'No times means no reminders (as needed).'**
  String get medicineNoTimes;

  /// No description provided for @medicineAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount each time'**
  String get medicineAmount;

  /// No description provided for @medicineAmountHint.
  ///
  /// In en, this message translates to:
  /// **'As the doctor wrote it, e.g. 1 tablet'**
  String get medicineAmountHint;

  /// No description provided for @medicineRepeat.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get medicineRepeat;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatDaily;

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Some days'**
  String get repeatWeekdays;

  /// No description provided for @repeatEveryN.
  ///
  /// In en, this message translates to:
  /// **'Every few days'**
  String get repeatEveryN;

  /// No description provided for @medicineEveryN.
  ///
  /// In en, this message translates to:
  /// **'Every how many days'**
  String get medicineEveryN;

  /// No description provided for @medicineEveryNInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 2 to 60'**
  String get medicineEveryNInvalid;

  /// No description provided for @medicineWeekdaysEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day'**
  String get medicineWeekdaysEmpty;

  /// No description provided for @medicineStop.
  ///
  /// In en, this message translates to:
  /// **'Stop taking'**
  String get medicineStop;

  /// No description provided for @medicineResume.
  ///
  /// In en, this message translates to:
  /// **'Taking it again'**
  String get medicineResume;

  /// No description provided for @medicineStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get medicineStopped;

  /// No description provided for @medicineEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get medicineEnded;

  /// No description provided for @medicineDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get medicineDelete;

  /// No description provided for @medicineDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and its history? Its photos will be removed from this phone.'**
  String medicineDeleteConfirm(String name);

  /// No description provided for @medicineNotFound.
  ///
  /// In en, this message translates to:
  /// **'This medicine was deleted'**
  String get medicineNotFound;

  /// No description provided for @medicineHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get medicineHistory;

  /// No description provided for @medicineHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing marked yet.'**
  String get medicineHistoryEmpty;

  /// No description provided for @medicineAsNeeded.
  ///
  /// In en, this message translates to:
  /// **'As needed, no reminders'**
  String get medicineAsNeeded;

  /// No description provided for @medicineNextDose.
  ///
  /// In en, this message translates to:
  /// **'Next dose: {when}'**
  String medicineNextDose(String when);

  /// No description provided for @medicineFromTo.
  ///
  /// In en, this message translates to:
  /// **'From {start} to {end}'**
  String medicineFromTo(String start, String end);

  /// No description provided for @medicineFrom.
  ///
  /// In en, this message translates to:
  /// **'From {start}'**
  String medicineFrom(String start);

  /// No description provided for @scheduleEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get scheduleEveryDay;

  /// No description provided for @scheduleEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Every day} other{Every {n} days}}'**
  String scheduleEveryNDays(int n);

  /// No description provided for @reminderOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders are off'**
  String get reminderOffTitle;

  /// No description provided for @reminderOffBody.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so Usra can remind you at medicine times.'**
  String get reminderOffBody;

  /// No description provided for @reminderExactOff.
  ///
  /// In en, this message translates to:
  /// **'Allow \"Alarms & reminders\" so doses ring on time, not a few minutes late.'**
  String get reminderExactOff;

  /// No description provided for @reminderAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get reminderAllow;

  /// No description provided for @reminderBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Make reminders reliable'**
  String get reminderBatteryTitle;

  /// No description provided for @reminderBatteryBody.
  ///
  /// In en, this message translates to:
  /// **'Some phones stop apps in the background to save battery. Set Usra\'s battery use to \"Unrestricted\" so reminders always ring.'**
  String get reminderBatteryBody;

  /// No description provided for @reminderBatteryOpen.
  ///
  /// In en, this message translates to:
  /// **'Battery settings'**
  String get reminderBatteryOpen;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @settingsBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Keep a copy of the family\'s records off this phone'**
  String get settingsBackupHint;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'A backup is one encrypted file with all the family\'s records and photos. Save it to Google Drive or Files, or send it to yourself on WhatsApp. To open it on a new phone you\'ll need your recovery key.'**
  String get backupIntro;

  /// No description provided for @backupNever.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get backupNever;

  /// No description provided for @backupLast.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String backupLast(String date);

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @backupWorking.
  ///
  /// In en, this message translates to:
  /// **'Preparing the backup…'**
  String get backupWorking;

  /// No description provided for @backupShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Usra backup'**
  String get backupShareSubject;

  /// No description provided for @backupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup ready. Keep it somewhere safe off this phone.'**
  String get backupDone;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the backup. Try again.'**
  String get backupFailed;

  /// No description provided for @backupDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up the family\'s records'**
  String get backupDueTitle;

  /// No description provided for @backupDueNever.
  ///
  /// In en, this message translates to:
  /// **'If this phone is lost, the records go with it. Make an encrypted backup and keep it off the phone.'**
  String get backupDueNever;

  /// No description provided for @backupDueOld.
  ///
  /// In en, this message translates to:
  /// **'Your last backup is more than 30 days old.'**
  String get backupDueOld;

  /// No description provided for @recoveryKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get recoveryKeyTitle;

  /// No description provided for @recoveryKeyIntro.
  ///
  /// In en, this message translates to:
  /// **'This is your recovery key. Write it on paper and keep it somewhere safe, away from this phone. You\'ll need it to open your backups on a new phone.'**
  String get recoveryKeyIntro;

  /// No description provided for @recoveryKeyShowIntro.
  ///
  /// In en, this message translates to:
  /// **'This is the key that opens your backups. Check it matches the one you wrote down.'**
  String get recoveryKeyShowIntro;

  /// No description provided for @recoveryKeyLoseWarning.
  ///
  /// In en, this message translates to:
  /// **'Without this key nobody can open your backups, not even us. If it\'s lost, we can\'t get it back.'**
  String get recoveryKeyLoseWarning;

  /// No description provided for @recoveryKeyWrittenDown.
  ///
  /// In en, this message translates to:
  /// **'I wrote it down'**
  String get recoveryKeyWrittenDown;

  /// No description provided for @recoveryKeyConfirmIntro.
  ///
  /// In en, this message translates to:
  /// **'To be sure it\'s written correctly, type these two groups from your paper.'**
  String get recoveryKeyConfirmIntro;

  /// No description provided for @recoveryKeyGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group {number}'**
  String recoveryKeyGroupLabel(int number);

  /// No description provided for @recoveryKeyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get recoveryKeyConfirm;

  /// No description provided for @recoveryKeyShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Show the key again'**
  String get recoveryKeyShowAgain;

  /// No description provided for @recoveryKeyMismatch.
  ///
  /// In en, this message translates to:
  /// **'Group {groups} doesn\'t match. Check your paper.'**
  String recoveryKeyMismatch(String groups);

  /// No description provided for @recoveryKeyShow.
  ///
  /// In en, this message translates to:
  /// **'Show recovery key'**
  String get recoveryKeyShow;

  /// No description provided for @restoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get restoreTitle;

  /// No description provided for @restoreHint.
  ///
  /// In en, this message translates to:
  /// **'Replaces everything on this phone'**
  String get restoreHint;

  /// No description provided for @restoreIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose your backup file (it ends in .usra) from Drive, Files or WhatsApp, then type your recovery key.'**
  String get restoreIntro;

  /// No description provided for @restorePick.
  ///
  /// In en, this message translates to:
  /// **'Choose the backup file'**
  String get restorePick;

  /// No description provided for @restoreKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery key (36 digits)'**
  String get restoreKeyLabel;

  /// No description provided for @restoreKeyGroupsWrong.
  ///
  /// In en, this message translates to:
  /// **'Group {groups} of the key isn\'t right. Check it against your paper.'**
  String restoreKeyGroupsWrong(String groups);

  /// No description provided for @restoreOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the backup'**
  String get restoreOpen;

  /// No description provided for @restoreNotABackup.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a Usra backup.'**
  String get restoreNotABackup;

  /// No description provided for @restoreWrongKey.
  ///
  /// In en, this message translates to:
  /// **'This recovery key doesn\'t open this backup. Check it, or try the key you had when the backup was made.'**
  String get restoreWrongKey;

  /// No description provided for @restoreDamaged.
  ///
  /// In en, this message translates to:
  /// **'This backup file is incomplete or damaged. Try downloading it again.'**
  String get restoreDamaged;

  /// No description provided for @restoreTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup was made with a newer version of Usra. Update the app, then try again.'**
  String get restoreTooNew;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the backup. Try again.'**
  String get restoreFailed;

  /// No description provided for @restoreFrom.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date}'**
  String restoreFrom(String date);

  /// No description provided for @restoreContents.
  ///
  /// In en, this message translates to:
  /// **'{people, plural, =1{1 person} other{{people} people}}, {records, plural, =1{1 record} other{{records} records}}, {medicines, plural, =1{1 medicine} other{{medicines} medicines}}, {photos, plural, =1{1 photo} other{{photos} photos}}'**
  String restoreContents(int people, int records, int medicines, int photos);

  /// No description provided for @restoreReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'Everything on this phone now will be replaced by this backup.'**
  String get restoreReplaceWarning;

  /// No description provided for @restoreReplace.
  ///
  /// In en, this message translates to:
  /// **'Restore and replace'**
  String get restoreReplace;

  /// No description provided for @restoreDoneNotice.
  ///
  /// In en, this message translates to:
  /// **'Your backup is restored.'**
  String get restoreDoneNotice;

  /// No description provided for @restoreFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t restore the backup, so your records stayed as they were.'**
  String get restoreFailedNotice;

  /// No description provided for @backupSavedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Did you save the backup or send it somewhere?'**
  String get backupSavedQuestion;

  /// No description provided for @backupSavedYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, saved'**
  String get backupSavedYes;

  /// No description provided for @backupSavedNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get backupSavedNo;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
