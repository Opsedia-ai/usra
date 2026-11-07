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

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About & privacy'**
  String get aboutTitle;

  /// No description provided for @aboutHint.
  ///
  /// In en, this message translates to:
  /// **'How your data is kept, and the app version'**
  String get aboutHint;

  /// No description provided for @aboutPrivacyHeading.
  ///
  /// In en, this message translates to:
  /// **'Your privacy, in plain words'**
  String get aboutPrivacyHeading;

  /// No description provided for @aboutPrivacyOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Everything you record stays on this phone. Records are in an encrypted database; photos are in the app\'s private storage, never in your gallery or in cloud backups. We don\'t receive any of it and can\'t see it.'**
  String get aboutPrivacyOnPhone;

  /// No description provided for @aboutPrivacyNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account, no sign-in, no ads and no tracking. We never sell or share anyone\'s data.'**
  String get aboutPrivacyNoAccount;

  /// No description provided for @aboutPrivacyOptionalAccount.
  ///
  /// In en, this message translates to:
  /// **'An account is optional, and there are no ads and no tracking. If you sign in, we keep your email (and your name with Google) to run the account, and we never receive your health records. We never sell or share anyone\'s data.'**
  String get aboutPrivacyOptionalAccount;

  /// No description provided for @aboutPrivacyBackup.
  ///
  /// In en, this message translates to:
  /// **'A backup is an encrypted file you keep wherever you choose. Only your recovery key opens it, and we don\'t have it.'**
  String get aboutPrivacyBackup;

  /// No description provided for @aboutPrivacyPhotos.
  ///
  /// In en, this message translates to:
  /// **'The camera and photos are used only when you choose, and text is read from them on this phone.'**
  String get aboutPrivacyPhotos;

  /// No description provided for @aboutPrivacyReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders are set on this phone. People\'s names and medicine names can show on the lock screen (the name as you typed it) and on the home-screen widget (first names).'**
  String get aboutPrivacyReminders;

  /// No description provided for @aboutPrivacyDelete.
  ///
  /// In en, this message translates to:
  /// **'You can erase everything Usra keeps on this phone at any time: More › Delete all my data.'**
  String get aboutPrivacyDelete;

  /// No description provided for @aboutPrivacyGoogle.
  ///
  /// In en, this message translates to:
  /// **'The text reader is made by Google and may send Google technical data with a random install ID, not linked to you. Never your photos, the text or your records.'**
  String get aboutPrivacyGoogle;

  /// No description provided for @aboutMedicalHeading.
  ///
  /// In en, this message translates to:
  /// **'Medical disclaimer'**
  String get aboutMedicalHeading;

  /// No description provided for @aboutMedicalBody.
  ///
  /// In en, this message translates to:
  /// **'Usra is not a medical device. It doesn\'t diagnose or treat, and it doesn\'t replace your doctor. Growth charts, vaccine dates, suggestions and text read from photos are for organising and general information, and can be wrong. Always ask your doctor or pharmacist before medical decisions. In an emergency, call 123 in Egypt or your local emergency number.'**
  String get aboutMedicalBody;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get aboutTerms;

  /// No description provided for @aboutLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the page. Check your internet connection.'**
  String get aboutLinkFailed;

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
  /// **'Lab results'**
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

  /// No description provided for @recordPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF {number}'**
  String recordPdf(int number);

  /// No description provided for @fieldLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get fieldLab;

  /// No description provided for @fieldOrderedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested by (optional)'**
  String get fieldOrderedBy;

  /// No description provided for @fieldTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get fieldTests;

  /// No description provided for @labResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get labResultsTitle;

  /// No description provided for @labTestNumber.
  ///
  /// In en, this message translates to:
  /// **'Test {number}'**
  String labTestNumber(int number);

  /// No description provided for @labTestName.
  ///
  /// In en, this message translates to:
  /// **'Test name'**
  String get labTestName;

  /// No description provided for @labTestValue.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get labTestValue;

  /// No description provided for @labTestUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get labTestUnit;

  /// No description provided for @labTestRange.
  ///
  /// In en, this message translates to:
  /// **'Range printed by the lab'**
  String get labTestRange;

  /// No description provided for @labTestRangeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4 - 11 or < 200'**
  String get labTestRangeHint;

  /// No description provided for @labAddTest.
  ///
  /// In en, this message translates to:
  /// **'Add another test'**
  String get labAddTest;

  /// No description provided for @labRemoveTest.
  ///
  /// In en, this message translates to:
  /// **'Remove this test'**
  String get labRemoveTest;

  /// No description provided for @labNeedOneTest.
  ///
  /// In en, this message translates to:
  /// **'Add at least one test with its result'**
  String get labNeedOneTest;

  /// No description provided for @labFlagHigh.
  ///
  /// In en, this message translates to:
  /// **'Above the lab\'s range'**
  String get labFlagHigh;

  /// No description provided for @labFlagLow.
  ///
  /// In en, this message translates to:
  /// **'Below the lab\'s range'**
  String get labFlagLow;

  /// No description provided for @labFlagNormal.
  ///
  /// In en, this message translates to:
  /// **'Within the lab\'s range'**
  String get labFlagNormal;

  /// No description provided for @labFlagUnknown.
  ///
  /// In en, this message translates to:
  /// **'No range to compare with'**
  String get labFlagUnknown;

  /// No description provided for @labInfoNote.
  ///
  /// In en, this message translates to:
  /// **'Compared only with the range printed on the report. This isn\'t a diagnosis: ask your doctor what the results mean for you.'**
  String get labInfoNote;

  /// No description provided for @labScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Read the report from a photo'**
  String get labScanTitle;

  /// No description provided for @labScanCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get labScanCamera;

  /// No description provided for @labScanGallery.
  ///
  /// In en, this message translates to:
  /// **'From the gallery'**
  String get labScanGallery;

  /// No description provided for @labScanHelp.
  ///
  /// In en, this message translates to:
  /// **'The phone reads printed English results itself; nothing is sent anywhere. The photo is kept, encrypted, with the report. Check every value against the paper before saving.'**
  String get labScanHelp;

  /// No description provided for @labScanReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the report…'**
  String get labScanReading;

  /// No description provided for @labScanFound.
  ///
  /// In en, this message translates to:
  /// **'Found {count} results. Highlighted boxes are ones the phone wasn\'t sure of: check them against the paper.'**
  String labScanFound(int count);

  /// No description provided for @labScanNothing.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find results in this photo. Type them in; the photo is kept with the report.'**
  String get labScanNothing;

  /// No description provided for @labScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the photo'**
  String get labScanFailed;

  /// No description provided for @labScanSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 test was already in the form, so its new reading wasn\'t added.} other{{count} tests were already in the form, so their new readings weren\'t added.}}'**
  String labScanSkipped(int count);

  /// No description provided for @labScanReplace.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Use the new reading} other{Use the {count} new readings}}'**
  String labScanReplace(int count);

  /// No description provided for @labScanNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing new on this photo: its results are already here.'**
  String get labScanNothingNew;

  /// No description provided for @labCheckThis.
  ///
  /// In en, this message translates to:
  /// **'Check this against the paper'**
  String get labCheckThis;

  /// No description provided for @labConfirmRow.
  ///
  /// In en, this message translates to:
  /// **'Matches the paper'**
  String get labConfirmRow;

  /// No description provided for @labConfirmFirstCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the marked boxes first'**
  String get labConfirmFirstCheck;

  /// No description provided for @labConfirmNeeded.
  ///
  /// In en, this message translates to:
  /// **'Before saving, confirm each row read from the photo, and check every marked box, against the paper.'**
  String get labConfirmNeeded;

  /// No description provided for @labCheckedIt.
  ///
  /// In en, this message translates to:
  /// **'I checked it'**
  String get labCheckedIt;

  /// No description provided for @labPickRange.
  ///
  /// In en, this message translates to:
  /// **'Several ranges are printed: pick the one that applies'**
  String get labPickRange;

  /// No description provided for @labScanPhoto.
  ///
  /// In en, this message translates to:
  /// **'The photo of the report'**
  String get labScanPhoto;

  /// No description provided for @labPhotoFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get labPhotoFullScreen;

  /// No description provided for @labAttachPdf.
  ///
  /// In en, this message translates to:
  /// **'Add a PDF'**
  String get labAttachPdf;

  /// No description provided for @labRemovePdf.
  ///
  /// In en, this message translates to:
  /// **'Remove the PDF'**
  String get labRemovePdf;

  /// No description provided for @labRangeLine.
  ///
  /// In en, this message translates to:
  /// **'Lab\'s range: {range}'**
  String labRangeLine(String range);

  /// No description provided for @labLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest: {value} on {date}'**
  String labLatest(String value, String date);

  /// No description provided for @labNoResults.
  ///
  /// In en, this message translates to:
  /// **'No lab results with numbers yet.'**
  String get labNoResults;

  /// No description provided for @labUnitsApart.
  ///
  /// In en, this message translates to:
  /// **'Results in different units are shown apart, never converted.'**
  String get labUnitsApart;

  /// No description provided for @labAllResults.
  ///
  /// In en, this message translates to:
  /// **'All results'**
  String get labAllResults;

  /// No description provided for @labAddReport.
  ///
  /// In en, this message translates to:
  /// **'Add a lab report'**
  String get labAddReport;

  /// No description provided for @memberLabs.
  ///
  /// In en, this message translates to:
  /// **'Lab results'**
  String get memberLabs;

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
  /// **'Vaccinations'**
  String get vaccinesTitle;

  /// No description provided for @vaccinesDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Required doses follow the Egyptian Ministry of Health and Population\'s schedule; optional ones follow common private-practice schedules (checked {date}). For information only: schedules change, and the child\'s health office card and doctor are the reference.'**
  String vaccinesDisclaimer(String date);

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

  /// No description provided for @drUsraWelcome.
  ///
  /// In en, this message translates to:
  /// **'Dr. Usra waving'**
  String get drUsraWelcome;

  /// No description provided for @drUsraExplaining.
  ///
  /// In en, this message translates to:
  /// **'Dr. Usra explaining'**
  String get drUsraExplaining;

  /// No description provided for @drUsraEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Dr. Usra holding a plus'**
  String get drUsraEmptyState;

  /// No description provided for @drUsraCelebrating.
  ///
  /// In en, this message translates to:
  /// **'Dr. Usra celebrating'**
  String get drUsraCelebrating;

  /// No description provided for @drUsraResting.
  ///
  /// In en, this message translates to:
  /// **'Dr. Usra resting'**
  String get drUsraResting;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

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

  /// No description provided for @settingsAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Dr. Usra AI'**
  String get settingsAiTitle;

  /// No description provided for @settingsAiSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsAiSoon;

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
  /// **'Vaccinations'**
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

  /// No description provided for @widgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No medicines today'**
  String get widgetEmpty;

  /// No description provided for @widgetStale.
  ///
  /// In en, this message translates to:
  /// **'Open Usra to refresh medicines'**
  String get widgetStale;

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

  /// No description provided for @recoveryKeyCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy the key'**
  String get recoveryKeyCopy;

  /// No description provided for @recoveryKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied. It\'s cleared from the clipboard in a minute: paste it into your password manager now.'**
  String get recoveryKeyCopied;

  /// No description provided for @shareWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Share outside Usra?'**
  String get shareWarningTitle;

  /// No description provided for @shareWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Once it\'s sent, Usra\'s lock and encryption no longer protect it: the other app, and anyone who sees that chat or folder, can open it. Check you\'ve picked the right person.'**
  String get shareWarningBody;

  /// No description provided for @shareWarningDontAsk.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get shareWarningDontAsk;

  /// No description provided for @shareWarningCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shareWarningCancel;

  /// No description provided for @shareWarningGo.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareWarningGo;

  /// No description provided for @rootWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s protections are switched off'**
  String get rootWarningTitle;

  /// No description provided for @rootWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This phone looks rooted or jailbroken. Other apps on it may be able to read Usra\'s files and see the screen, so your family\'s records are less safe here.\n\nUsra keeps working as normal. If you can, use a phone that isn\'t modified, and keep the app lock on.'**
  String get rootWarningBody;

  /// No description provided for @rootWarningOk.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get rootWarningOk;

  /// No description provided for @settingsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all my data'**
  String get settingsDeleteAll;

  /// No description provided for @settingsDeleteAllHint.
  ///
  /// In en, this message translates to:
  /// **'Erase everything Usra keeps on this phone'**
  String get settingsDeleteAllHint;

  /// No description provided for @wipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all my data'**
  String get wipeTitle;

  /// No description provided for @wipeIntro.
  ///
  /// In en, this message translates to:
  /// **'This erases everything Usra keeps on this phone and starts it again as new:'**
  String get wipeIntro;

  /// No description provided for @wipeList.
  ///
  /// In en, this message translates to:
  /// **'• Every person, record, medicine, doctor and insurance card\n• All photos\n• The keys that lock them, the recovery key saved on this phone and the app lock\n• Reminders, the home-screen widget and settings\n• You\'re signed out of your account (the account itself stays; delete it from Account first if you want)'**
  String get wipeList;

  /// No description provided for @wipeKeeps.
  ///
  /// In en, this message translates to:
  /// **'Backup files you saved somewhere else (Drive, WhatsApp, Files) aren\'t touched. They still open with your recovery key, so you can bring the records back.'**
  String get wipeKeeps;

  /// No description provided for @wipeNoUndo.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone. Without a backup and its recovery key, the records are gone for good.'**
  String get wipeNoUndo;

  /// No description provided for @wipeBackupFirst.
  ///
  /// In en, this message translates to:
  /// **'Make a backup first'**
  String get wipeBackupFirst;

  /// No description provided for @wipeConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get wipeConfirmWord;

  /// No description provided for @wipeTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String wipeTypeLabel(String word);

  /// No description provided for @wipeButton.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get wipeButton;

  /// No description provided for @wipeWorking.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get wipeWorking;

  /// No description provided for @wipeReopenFailed.
  ///
  /// In en, this message translates to:
  /// **'Usra couldn\'t open again after deleting. Close it and open it again.'**
  String get wipeReopenFailed;

  /// No description provided for @databaseKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Usra can\'t open the key to your records right now. Your records are still here and nothing was deleted. Try again, or restart your phone. If this keeps happening, contact us before deleting the app.'**
  String get databaseKeyUnavailable;

  /// No description provided for @recoveryKeyCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t copy the key. Write it down from the screen instead.'**
  String get recoveryKeyCopyFailed;

  /// No description provided for @wipeDoneNotice.
  ///
  /// In en, this message translates to:
  /// **'Everything Usra kept on this phone was deleted.'**
  String get wipeDoneNotice;

  /// No description provided for @wipeIncompleteNotice.
  ///
  /// In en, this message translates to:
  /// **'Some of Usra\'s data couldn\'t be deleted. Usra will try again the next time it starts.'**
  String get wipeIncompleteNotice;

  /// No description provided for @lockSettingsWipe.
  ///
  /// In en, this message translates to:
  /// **'Erase after 10 wrong PINs'**
  String get lockSettingsWipe;

  /// No description provided for @lockSettingsWipeHint.
  ///
  /// In en, this message translates to:
  /// **'Deletes all data on this phone after 10 wrong PINs in a row'**
  String get lockSettingsWipeHint;

  /// No description provided for @lockWipeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase after 10 wrong PINs?'**
  String get lockWipeConfirmTitle;

  /// No description provided for @lockWipeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'After 10 wrong PINs in a row, Usra deletes everything it keeps on this phone, with no way to undo it. A child playing with the phone could set it off.\n\nTurn this on only if you have a recent backup and its recovery key.'**
  String get lockWipeConfirmBody;

  /// No description provided for @lockWipeConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get lockWipeConfirmYes;

  /// No description provided for @lockWipeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get lockWipeCancel;

  /// No description provided for @lockTriesBeforeWipe.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more wrong PIN erases everything} other{{count} more wrong PINs erase everything}}'**
  String lockTriesBeforeWipe(int count);

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

  /// No description provided for @memberPregnancy.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get memberPregnancy;

  /// No description provided for @memberDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get memberDevelopment;

  /// No description provided for @memberBabyLog.
  ///
  /// In en, this message translates to:
  /// **'Baby\'s day'**
  String get memberBabyLog;

  /// No description provided for @recordPregnancy.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get recordPregnancy;

  /// No description provided for @recordPregnancyCheck.
  ///
  /// In en, this message translates to:
  /// **'Weight and blood pressure'**
  String get recordPregnancyCheck;

  /// No description provided for @recordPregnancyEnd.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy outcome'**
  String get recordPregnancyEnd;

  /// No description provided for @fieldLmp.
  ///
  /// In en, this message translates to:
  /// **'First day of last period'**
  String get fieldLmp;

  /// No description provided for @fieldDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date (from the doctor)'**
  String get fieldDueDate;

  /// No description provided for @fieldSystolic.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure, upper number'**
  String get fieldSystolic;

  /// No description provided for @fieldDiastolic.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure, lower number'**
  String get fieldDiastolic;

  /// No description provided for @fieldOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get fieldOutcome;

  /// No description provided for @outcomeBirth.
  ///
  /// In en, this message translates to:
  /// **'Birth'**
  String get outcomeBirth;

  /// No description provided for @outcomeLoss.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy loss'**
  String get outcomeLoss;

  /// No description provided for @outcomeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get outcomeOther;

  /// No description provided for @pregnancyTitle.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy follow-up'**
  String get pregnancyTitle;

  /// No description provided for @pregnancyNotEligible.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy follow-up is for women. Check the sex and birth date in their details.'**
  String get pregnancyNotEligible;

  /// No description provided for @pregnancyStartIntro.
  ///
  /// In en, this message translates to:
  /// **'Follow the weeks, the due date, the antenatal visits and tests. Start with the first day of the last period, or the due date the doctor gave you.'**
  String get pregnancyStartIntro;

  /// No description provided for @pregnancyStart.
  ///
  /// In en, this message translates to:
  /// **'Start pregnancy follow-up'**
  String get pregnancyStart;

  /// No description provided for @pregnancyWeek.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =0{أقل من أسبوع} =1{أسبوع} =2{أسبوعين} few{{weeks} أسابيع} other{{weeks} أسبوع}} و{days, plural, =0{0 يوم} =1{يوم} =2{يومين} few{{days} أيام} other{{days} يوم}}'**
  String pregnancyWeek(int weeks, int days);

  /// No description provided for @pregnancyTrimester.
  ///
  /// In en, this message translates to:
  /// **'{trimester, plural, =1{1st trimester} =2{2nd trimester} other{3rd trimester}}'**
  String pregnancyTrimester(int trimester);

  /// No description provided for @pregnancyDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String pregnancyDue(String date);

  /// No description provided for @pregnancyDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Due today} =1{1 day to the due date} other{{days} days to the due date}}'**
  String pregnancyDaysLeft(int days);

  /// No description provided for @pregnancyPastDue.
  ///
  /// In en, this message translates to:
  /// **'The due date has passed. Stay in touch with your doctor, and add the outcome when the baby comes.'**
  String get pregnancyPastDue;

  /// No description provided for @pregnancyAddCheck.
  ///
  /// In en, this message translates to:
  /// **'Add weight and blood pressure'**
  String get pregnancyAddCheck;

  /// No description provided for @pregnancyEnd.
  ///
  /// In en, this message translates to:
  /// **'Record the outcome'**
  String get pregnancyEnd;

  /// No description provided for @pregnancyScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits, scans and tests'**
  String get pregnancyScheduleTitle;

  /// No description provided for @pregnancyScheduleSource.
  ///
  /// In en, this message translates to:
  /// **'Visits: WHO antenatal care recommendations (2016), at least 8 contacts. Scans and tests: what doctors in Egypt usually ask for. Your doctor may plan differently; follow their plan.'**
  String get pregnancyScheduleSource;

  /// No description provided for @pregnancyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'For information only. It doesn\'t replace your doctor\'s follow-up.'**
  String get pregnancyDisclaimer;

  /// No description provided for @ancContact.
  ///
  /// In en, this message translates to:
  /// **'Antenatal visit {number} of 8'**
  String ancContact(int number);

  /// No description provided for @ancContactReason.
  ///
  /// In en, this message translates to:
  /// **'Around week {week} of pregnancy'**
  String ancContactReason(int week);

  /// No description provided for @ancWindow.
  ///
  /// In en, this message translates to:
  /// **'Usually between weeks {from} and {to} of pregnancy'**
  String ancWindow(int from, int to);

  /// No description provided for @ancBookingLabs.
  ///
  /// In en, this message translates to:
  /// **'First pregnancy tests (blood count, blood group, urine, sugar, hepatitis)'**
  String get ancBookingLabs;

  /// No description provided for @ancFirstScan.
  ///
  /// In en, this message translates to:
  /// **'First-trimester ultrasound'**
  String get ancFirstScan;

  /// No description provided for @ancAnomalyScan.
  ///
  /// In en, this message translates to:
  /// **'Anomaly scan (detailed ultrasound)'**
  String get ancAnomalyScan;

  /// No description provided for @ancGlucoseTest.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy sugar test (glucose curve)'**
  String get ancGlucoseTest;

  /// No description provided for @ancBloodCount.
  ///
  /// In en, this message translates to:
  /// **'Blood count (anaemia check)'**
  String get ancBloodCount;

  /// No description provided for @ancGrowthScan.
  ///
  /// In en, this message translates to:
  /// **'Baby growth ultrasound'**
  String get ancGrowthScan;

  /// No description provided for @ancDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get ancDone;

  /// No description provided for @ancMissed.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get ancMissed;

  /// No description provided for @pregDangerTitle.
  ///
  /// In en, this message translates to:
  /// **'Go to the hospital now if you notice any of these'**
  String get pregDangerTitle;

  /// No description provided for @pregDangerSign.
  ///
  /// In en, this message translates to:
  /// **'{sign, select, bleeding{Bleeding from the vagina} headache{Severe headache} vision{Blurred vision} fits{Fits or fainting} pain{Severe pain in the belly} fever{Fever} water{Water leaking from the vagina} movement{The baby moving less than usual, or not at all} swelling{Swelling of the face or hands} breathing{Difficulty breathing} other{}}'**
  String pregDangerSign(String sign);

  /// No description provided for @pregDangerSource.
  ///
  /// In en, this message translates to:
  /// **'Danger signs from WHO and the Egyptian Ministry of Health maternal health guidance.'**
  String get pregDangerSource;

  /// No description provided for @pregnancyWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get pregnancyWeightTitle;

  /// No description provided for @pregnancyBpTitle.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get pregnancyBpTitle;

  /// No description provided for @pregnancyNoReadings.
  ///
  /// In en, this message translates to:
  /// **'No readings yet.'**
  String get pregnancyNoReadings;

  /// No description provided for @pregnancyWeekAxis.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy week'**
  String get pregnancyWeekAxis;

  /// No description provided for @bpUsual.
  ///
  /// In en, this message translates to:
  /// **'In the usual range'**
  String get bpUsual;

  /// No description provided for @bpHigh.
  ///
  /// In en, this message translates to:
  /// **'High: call your doctor today'**
  String get bpHigh;

  /// No description provided for @bpVeryHigh.
  ///
  /// In en, this message translates to:
  /// **'Very high: go to the hospital now'**
  String get bpVeryHigh;

  /// No description provided for @pregnancyBpSource.
  ///
  /// In en, this message translates to:
  /// **'Levels from WHO: 140/90 and above is high in pregnancy, 160/110 and above is very high. One reading isn\'t a diagnosis; ask your doctor.'**
  String get pregnancyBpSource;

  /// No description provided for @devTitle.
  ///
  /// In en, this message translates to:
  /// **'Development milestones'**
  String get devTitle;

  /// No description provided for @devUnderSixOnly.
  ///
  /// In en, this message translates to:
  /// **'The milestones checklist is for children under 6 whose birth date is recorded.'**
  String get devUnderSixOnly;

  /// No description provided for @devIntro.
  ///
  /// In en, this message translates to:
  /// **'Tick what your child does, with the day you first noticed it.'**
  String get devIntro;

  /// No description provided for @devLateBanner.
  ///
  /// In en, this message translates to:
  /// **'Some milestones for {age} aren\'t ticked yet. Talk to your pediatrician about them; there\'s no need to wait.'**
  String devLateBanner(String age);

  /// No description provided for @devByAge.
  ///
  /// In en, this message translates to:
  /// **'By {age}'**
  String devByAge(String age);

  /// No description provided for @devTickedCount.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} ticked'**
  String devTickedCount(int done, int total);

  /// No description provided for @devDone.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String devDone(String date);

  /// No description provided for @devUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get devUpcoming;

  /// No description provided for @devWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch for it'**
  String get devWatch;

  /// No description provided for @devLate.
  ///
  /// In en, this message translates to:
  /// **'Talk to your pediatrician'**
  String get devLate;

  /// No description provided for @devNotTicked.
  ///
  /// In en, this message translates to:
  /// **'Not ticked'**
  String get devNotTicked;

  /// No description provided for @devWhenSeen.
  ///
  /// In en, this message translates to:
  /// **'When did you first notice it?'**
  String get devWhenSeen;

  /// No description provided for @devAreaSocial.
  ///
  /// In en, this message translates to:
  /// **'Social and emotional'**
  String get devAreaSocial;

  /// No description provided for @devAreaLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get devAreaLanguage;

  /// No description provided for @devAreaCognitive.
  ///
  /// In en, this message translates to:
  /// **'Thinking and learning'**
  String get devAreaCognitive;

  /// No description provided for @devAreaMovement.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get devAreaMovement;

  /// No description provided for @devSource.
  ///
  /// In en, this message translates to:
  /// **'From CDC\'s \"Learn the Signs. Act Early.\" milestones (2022), a selection: things most children (75%) do by each age. Full checklists at cdc.gov/actearly. For information only; your pediatrician assesses your child\'s development.'**
  String get devSource;

  /// No description provided for @recordMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get recordMilestone;

  /// No description provided for @milestone.
  ///
  /// In en, this message translates to:
  /// **'{id, select, m2_social{Smiles when you talk to or smile at them} m2_language{Makes sounds other than crying} m2_cognitive{Watches you as you move} m2_movement{Holds head up when on tummy} m4_social{Smiles on their own to get your attention} m4_language{Makes cooing sounds like \"oooo\" and \"aahh\"} m4_cognitive{Looks at their hands with interest} m4_movement{Holds head steady without support when you hold them} m6_social{Knows familiar people} m6_language{Takes turns making sounds with you} m6_cognitive{Reaches to grab a toy they want} m6_movement{Rolls from tummy to back} m9_social{Looks when you call their name} m9_language{Makes sounds like \"mamama\" and \"bababa\"} m9_cognitive{Looks for things when you drop them out of sight} m9_movement{Sits without support} m12_social{Plays games with you, like pat-a-cake} m12_language{Waves \"bye-bye\"} m12_cognitive{Looks for things they see you hide} m12_movement{Pulls up to stand} m15_social{Shows you an object they like} m15_language{Tries to say one or two words besides \"mama\" or \"dada\"} m15_cognitive{Stacks at least two small objects} m15_movement{Takes a few steps on their own} m18_social{Points to show you something interesting} m18_language{Tries to say three or more words besides \"mama\" or \"dada\"} m18_cognitive{Copies you doing chores, like sweeping} m18_movement{Walks without holding on to anyone or anything} m24_social{Notices when others are hurt or upset} m24_language{Says at least two words together, like \"more milk\"} m24_cognitive{Tries to use switches, knobs or buttons on a toy} m24_movement{Kicks a ball} m30_social{Plays next to other children and sometimes with them} m30_language{Says about 50 words} m30_cognitive{Uses things to pretend, like feeding a doll} m30_movement{Jumps off the ground with both feet} m36_social{Notices other children and joins them to play} m36_language{Holds a conversation with you of at least two back-and-forth exchanges} m36_cognitive{Draws a circle when you show them how} m36_movement{Puts on some clothes by themselves} m48_social{Comforts others who are hurt or sad} m48_language{Says sentences with four or more words} m48_cognitive{Names a few colours} m48_movement{Catches a large ball most of the time} m60_social{Follows rules or takes turns when playing games} m60_language{Tells a story they heard or made up, with at least two events} m60_cognitive{Counts to 10} m60_movement{Hops on one foot} other{}}'**
  String milestone(String id);

  /// No description provided for @infantLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Baby\'s day'**
  String get infantLogTitle;

  /// No description provided for @infantLogUnderOneOnly.
  ///
  /// In en, this message translates to:
  /// **'The feeds, sleep and diapers log is for babies under one whose birth date is recorded.'**
  String get infantLogUnderOneOnly;

  /// No description provided for @logBreast.
  ///
  /// In en, this message translates to:
  /// **'Breastfeed'**
  String get logBreast;

  /// No description provided for @logBottle.
  ///
  /// In en, this message translates to:
  /// **'Bottle'**
  String get logBottle;

  /// No description provided for @logSolids.
  ///
  /// In en, this message translates to:
  /// **'Solids'**
  String get logSolids;

  /// No description provided for @logSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get logSleep;

  /// No description provided for @logWet.
  ///
  /// In en, this message translates to:
  /// **'Wet diaper'**
  String get logWet;

  /// No description provided for @logDirty.
  ///
  /// In en, this message translates to:
  /// **'Dirty diaper'**
  String get logDirty;

  /// No description provided for @logBottleAmount.
  ///
  /// In en, this message translates to:
  /// **'How much?'**
  String get logBottleAmount;

  /// No description provided for @logSleepHowLong.
  ///
  /// In en, this message translates to:
  /// **'How long did they sleep?'**
  String get logSleepHowLong;

  /// No description provided for @logSkip.
  ///
  /// In en, this message translates to:
  /// **'Don\'t know'**
  String get logSkip;

  /// No description provided for @logMl.
  ///
  /// In en, this message translates to:
  /// **'{ml} ml'**
  String logMl(int ml);

  /// No description provided for @logDuration.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =0{{minutes} min} other{{hours} h {minutes} min}}'**
  String logDuration(int hours, int minutes);

  /// No description provided for @logSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get logSaved;

  /// No description provided for @logToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get logToday;

  /// No description provided for @logYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get logYesterday;

  /// No description provided for @logEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged.'**
  String get logEmptyDay;

  /// No description provided for @logSummaryFeeds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 feed} other{{count} feeds}} (breast {breast}, bottle {bottle}, solids {solids})'**
  String logSummaryFeeds(int count, int breast, int bottle, int solids);

  /// No description provided for @logSummaryBottleMl.
  ///
  /// In en, this message translates to:
  /// **'{ml} ml from the bottle'**
  String logSummaryBottleMl(int ml);

  /// No description provided for @logSummarySleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep: {duration}'**
  String logSummarySleep(String duration);

  /// No description provided for @logSummaryDiapers.
  ///
  /// In en, this message translates to:
  /// **'Diapers: {wet} wet, {dirty} dirty'**
  String logSummaryDiapers(int wet, int dirty);

  /// No description provided for @logDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get logDelete;

  /// No description provided for @logDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'A diary for you and the doctor. If you\'re worried about feeding, sleep or diapers, ask your pediatrician.'**
  String get logDisclaimer;

  /// No description provided for @recordFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get recordFeed;

  /// No description provided for @recordDiaper.
  ///
  /// In en, this message translates to:
  /// **'Diaper'**
  String get recordDiaper;

  /// No description provided for @fieldFeedKind.
  ///
  /// In en, this message translates to:
  /// **'Type of feed'**
  String get fieldFeedKind;

  /// No description provided for @fieldAmountMl.
  ///
  /// In en, this message translates to:
  /// **'Amount (ml)'**
  String get fieldAmountMl;

  /// No description provided for @fieldMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get fieldMinutes;

  /// No description provided for @fieldDiaperKind.
  ///
  /// In en, this message translates to:
  /// **'Type of diaper'**
  String get fieldDiaperKind;

  /// No description provided for @diaperWet.
  ///
  /// In en, this message translates to:
  /// **'Wet'**
  String get diaperWet;

  /// No description provided for @diaperDirty.
  ///
  /// In en, this message translates to:
  /// **'Dirty'**
  String get diaperDirty;

  /// No description provided for @diaperBoth.
  ///
  /// In en, this message translates to:
  /// **'Wet and dirty'**
  String get diaperBoth;

  /// No description provided for @growthCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick check'**
  String get growthCheckTitle;

  /// No description provided for @growthCheckIntro.
  ///
  /// In en, this message translates to:
  /// **'Type today\'s weight, height or head circumference and see where it falls on the WHO curves at {age}.'**
  String growthCheckIntro(String age);

  /// No description provided for @growthCheckSave.
  ///
  /// In en, this message translates to:
  /// **'Save as a measurement'**
  String get growthCheckSave;

  /// No description provided for @devUntick.
  ///
  /// In en, this message translates to:
  /// **'Untick'**
  String get devUntick;

  /// No description provided for @devUntickConfirm.
  ///
  /// In en, this message translates to:
  /// **'Untick this milestone? The date you recorded will be removed.'**
  String get devUntickConfirm;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. Your records stay on this phone'**
  String get accountSettingsHint;

  /// No description provided for @accountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your family\'s health records stay on this phone. An account doesn\'t upload them: it only holds what we need to run your account.'**
  String get accountPrivacy;

  /// No description provided for @accountSignInIntro.
  ///
  /// In en, this message translates to:
  /// **'You don\'t need an account in this version of the app. Google shares your name and email with us; Apple shares your email.'**
  String get accountSignInIntro;

  /// No description provided for @accountSignInConsent.
  ///
  /// In en, this message translates to:
  /// **'By signing in, you agree that we keep this to run your account, as the privacy policy says.'**
  String get accountSignInConsent;

  /// No description provided for @accountReadPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Read about privacy'**
  String get accountReadPrivacy;

  /// No description provided for @accountSignInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get accountSignInWithGoogle;

  /// No description provided for @accountSignInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get accountSignInWithApple;

  /// No description provided for @accountSignInUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn\'t available in this version of the app.'**
  String get accountSignInUnavailable;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedIn;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out? Your records stay on this phone.'**
  String get accountSignOutConfirm;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete your account? Your account and everything linked to it are erased from our servers. The records on this phone stay here.'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleteAppleNote.
  ///
  /// In en, this message translates to:
  /// **'Apple will ask you to confirm once more, so we can unlink your Apple ID from the app.'**
  String get accountDeleteAppleNote;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @accountErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a little and try again'**
  String get accountErrorTooMany;

  /// No description provided for @accountErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again'**
  String get accountErrorNetwork;

  /// No description provided for @accountErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again'**
  String get accountErrorGeneric;

  /// No description provided for @accountRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get accountRetry;

  /// No description provided for @accountErrorSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in has expired. Sign in again'**
  String get accountErrorSignInAgain;

  /// No description provided for @accountErrorFamilyHasMembers.
  ///
  /// In en, this message translates to:
  /// **'You created a family that other people are in. Their shared records would be deleted too, so this account can\'t be deleted yet.'**
  String get accountErrorFamilyHasMembers;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Usra is locked'**
  String get lockTitle;

  /// No description provided for @lockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockEnterPin;

  /// No description provided for @lockUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face'**
  String get lockUseBiometrics;

  /// No description provided for @lockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Usra to see your family\'s records'**
  String get lockBiometricReason;

  /// No description provided for @lockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. Try again.'**
  String get lockWrongPin;

  /// No description provided for @lockWait.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Try again in {time}.'**
  String lockWait(String time);

  /// No description provided for @lockForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN?'**
  String get lockForgot;

  /// No description provided for @lockForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'If you forget your PIN'**
  String get lockForgotTitle;

  /// No description provided for @lockForgotBody.
  ///
  /// In en, this message translates to:
  /// **'To keep your family\'s records private, nothing can skip the PIN, not even us.\n\nTo start again:\n1. Remove Usra\'s data. On Android: phone Settings › Apps › Usra › Storage › Clear data. On iPhone: delete Usra and install it again. This deletes everything Usra keeps on this phone.\n2. Open Usra and restore your latest backup with your recovery key (More › Backup).\n\nWithout a backup and its recovery key, the records can\'t be brought back.'**
  String get lockForgotBody;

  /// No description provided for @lockEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency info'**
  String get lockEmergency;

  /// No description provided for @lockEmergencyPick.
  ///
  /// In en, this message translates to:
  /// **'Whose emergency card?'**
  String get lockEmergencyPick;

  /// No description provided for @lockEmergencyNone.
  ///
  /// In en, this message translates to:
  /// **'No one has been added yet.'**
  String get lockEmergencyNone;

  /// No description provided for @pinOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get pinOk;

  /// No description provided for @pinDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pinDelete;

  /// No description provided for @pinLengthHint.
  ///
  /// In en, this message translates to:
  /// **'6 numbers'**
  String get pinLengthHint;

  /// No description provided for @pinEntered.
  ///
  /// In en, this message translates to:
  /// **'{count} of 6 numbers typed'**
  String pinEntered(int count);

  /// No description provided for @lockSetupNewPin.
  ///
  /// In en, this message translates to:
  /// **'Choose a 6-number PIN'**
  String get lockSetupNewPin;

  /// No description provided for @lockSetupConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Type the same PIN again'**
  String get lockSetupConfirmPin;

  /// No description provided for @lockSetupMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two PINs are different. Choose again.'**
  String get lockSetupMismatch;

  /// No description provided for @lockSetupCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN'**
  String get lockSetupCurrentPin;

  /// No description provided for @lockSetupBiometricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face too?'**
  String get lockSetupBiometricsTitle;

  /// No description provided for @lockSetupBiometricsBody.
  ///
  /// In en, this message translates to:
  /// **'Opens Usra faster; the PIN always works too. Anyone whose fingerprint or face is set up on this phone, family members too, will be able to open Usra. If others use this phone, choose Not now.'**
  String get lockSetupBiometricsBody;

  /// No description provided for @lockSetupBiometricsYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, use it'**
  String get lockSetupBiometricsYes;

  /// No description provided for @lockSetupDone.
  ///
  /// In en, this message translates to:
  /// **'App lock is on'**
  String get lockSetupDone;

  /// No description provided for @lockSetupWriteDown.
  ///
  /// In en, this message translates to:
  /// **'Keep your PIN somewhere safe. If you forget it, the only way back in is to remove Usra\'s data and restore a backup.'**
  String get lockSetupWriteDown;

  /// No description provided for @lockOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock Usra with a PIN?'**
  String get lockOfferTitle;

  /// No description provided for @lockOfferBody.
  ///
  /// In en, this message translates to:
  /// **'If your phone is lost or someone else picks it up, your family\'s records stay closed. You can unlock with your fingerprint or face too.'**
  String get lockOfferBody;

  /// No description provided for @lockOfferYes.
  ///
  /// In en, this message translates to:
  /// **'Set up the lock'**
  String get lockOfferYes;

  /// No description provided for @lockOfferSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get lockOfferSkip;

  /// No description provided for @lockOfferLater.
  ///
  /// In en, this message translates to:
  /// **'You can turn it on any time from More › App lock.'**
  String get lockOfferLater;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockOn.
  ///
  /// In en, this message translates to:
  /// **'On: PIN needed to open Usra'**
  String get settingsAppLockOn;

  /// No description provided for @settingsAppLockOff.
  ///
  /// In en, this message translates to:
  /// **'Off: anyone with the phone can open Usra'**
  String get settingsAppLockOff;

  /// No description provided for @lockSettingsSwitch.
  ///
  /// In en, this message translates to:
  /// **'Lock with a PIN'**
  String get lockSettingsSwitch;

  /// No description provided for @lockSettingsChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get lockSettingsChangePin;

  /// No description provided for @lockSettingsBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint or face'**
  String get lockSettingsBiometrics;

  /// No description provided for @lockSettingsBiometricsHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone whose fingerprint or face is set up on this phone can open Usra, family members too. If others use this phone, keep this off and use the PIN only.'**
  String get lockSettingsBiometricsHint;

  /// No description provided for @lockSettingsTimeout.
  ///
  /// In en, this message translates to:
  /// **'Lock again after leaving Usra'**
  String get lockSettingsTimeout;

  /// No description provided for @lockTimeoutImmediately.
  ///
  /// In en, this message translates to:
  /// **'Right away'**
  String get lockTimeoutImmediately;

  /// No description provided for @lockTimeoutOneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get lockTimeoutOneMinute;

  /// No description provided for @lockTimeoutFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get lockTimeoutFiveMinutes;

  /// No description provided for @lockSettingsEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency card on the lock screen'**
  String get lockSettingsEmergency;

  /// No description provided for @lockSettingsEmergencyHint.
  ///
  /// In en, this message translates to:
  /// **'A paramedic can see the blood type, allergies and conditions of the people you choose here without the PIN. Anyone holding the phone can see them too.'**
  String get lockSettingsEmergencyHint;

  /// No description provided for @lockVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get lockVerifyTitle;

  /// No description provided for @lockOffDone.
  ///
  /// In en, this message translates to:
  /// **'App lock is off'**
  String get lockOffDone;

  /// No description provided for @lockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the lock just now. Try again in a moment.'**
  String get lockUnavailable;

  /// No description provided for @lockSetupTrivial.
  ///
  /// In en, this message translates to:
  /// **'That PIN is too easy to guess. Avoid repeated or sequential numbers.'**
  String get lockSetupTrivial;

  /// No description provided for @lockEmergencyFor.
  ///
  /// In en, this message translates to:
  /// **'Show on the lock screen'**
  String get lockEmergencyFor;

  /// No description provided for @lockBackupFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'Make a backup first?'**
  String get lockBackupFirstTitle;

  /// No description provided for @lockBackupFirstBody.
  ///
  /// In en, this message translates to:
  /// **'If you forget your PIN, the only way back in is to remove Usra\'s data and restore a backup with its recovery key. You don\'t have a backup yet.'**
  String get lockBackupFirstBody;

  /// No description provided for @lockBackupFirstMake.
  ///
  /// In en, this message translates to:
  /// **'Make a backup'**
  String get lockBackupFirstMake;

  /// No description provided for @lockBackupFirstSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue without'**
  String get lockBackupFirstSkip;

  /// No description provided for @backupDonePhotosSkipped.
  ///
  /// In en, this message translates to:
  /// **'Backup ready, but {count, plural, =1{1 photo couldn\'t be opened on this phone and isn\'t} other{{count} photos couldn\'t be opened on this phone and aren\'t}} in it. Keep it somewhere safe off this phone.'**
  String backupDonePhotosSkipped(int count);

  /// No description provided for @restorePhotosSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo in this backup can\'t be opened and will be left out.} other{{count} photos in this backup can\'t be opened and will be left out.}}'**
  String restorePhotosSkipped(int count);

  /// No description provided for @photosLocked.
  ///
  /// In en, this message translates to:
  /// **'Photos can\'t be opened on this phone. Restore your backup to get them back.'**
  String get photosLocked;

  /// No description provided for @doseReminderDiscreetTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for a medicine'**
  String get doseReminderDiscreetTitle;

  /// No description provided for @widgetDiscreetDose.
  ///
  /// In en, this message translates to:
  /// **'Dose due'**
  String get widgetDiscreetDose;

  /// No description provided for @settingsDiscreet.
  ///
  /// In en, this message translates to:
  /// **'Discreet notifications'**
  String get settingsDiscreet;

  /// No description provided for @settingsDiscreetHint.
  ///
  /// In en, this message translates to:
  /// **'Reminders and the home-screen widget say \"Time for a medicine\", without the person\'s or the medicine\'s name.'**
  String get settingsDiscreetHint;

  /// No description provided for @settingsBlockScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get settingsBlockScreenshots;

  /// No description provided for @settingsBlockScreenshotsHint.
  ///
  /// In en, this message translates to:
  /// **'No screenshots or screen recording anywhere in the app. The recovery key is always protected. Leave off to screenshot the emergency card.'**
  String get settingsBlockScreenshotsHint;

  /// No description provided for @doseReminderDiscreetBody.
  ///
  /// In en, this message translates to:
  /// **'Open Usra to see which'**
  String get doseReminderDiscreetBody;

  /// No description provided for @memberVaccines.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get memberVaccines;

  /// No description provided for @vaccineHexa.
  ///
  /// In en, this message translates to:
  /// **'Hexavalent'**
  String get vaccineHexa;

  /// No description provided for @vaccinePcv.
  ///
  /// In en, this message translates to:
  /// **'Pneumococcal (PCV)'**
  String get vaccinePcv;

  /// No description provided for @vaccineRota.
  ///
  /// In en, this message translates to:
  /// **'Rotavirus'**
  String get vaccineRota;

  /// No description provided for @vaccineVaricella.
  ///
  /// In en, this message translates to:
  /// **'Chickenpox (varicella)'**
  String get vaccineVaricella;

  /// No description provided for @vaccineHepA.
  ///
  /// In en, this message translates to:
  /// **'Hepatitis A'**
  String get vaccineHepA;

  /// No description provided for @vaccineMening.
  ///
  /// In en, this message translates to:
  /// **'Meningococcal (MenACWY)'**
  String get vaccineMening;

  /// No description provided for @vaccineFlu.
  ///
  /// In en, this message translates to:
  /// **'Influenza (flu)'**
  String get vaccineFlu;

  /// No description provided for @vaccineBoosterDose.
  ///
  /// In en, this message translates to:
  /// **'{name}, booster'**
  String vaccineBoosterDose(String name);

  /// No description provided for @vaccineRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get vaccineRequired;

  /// No description provided for @vaccineOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get vaccineOptional;

  /// No description provided for @vaccineNotFollowed.
  ///
  /// In en, this message translates to:
  /// **'Not in your plan'**
  String get vaccineNotFollowed;

  /// No description provided for @vaccineRequiredDone.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} required done'**
  String vaccineRequiredDone(int done, int total);

  /// No description provided for @vaccineOptionalDone.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} optional done'**
  String vaccineOptionalDone(int done, int total);

  /// No description provided for @vaccineFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get vaccineFilterAll;

  /// No description provided for @vaccineFilterRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get vaccineFilterRequired;

  /// No description provided for @vaccineFilterOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get vaccineFilterOptional;

  /// No description provided for @vaccineFilterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get vaccineFilterOverdue;

  /// No description provided for @vaccineFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here.'**
  String get vaccineFilterEmpty;

  /// No description provided for @vaccinePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccine plan'**
  String get vaccinePlanTitle;

  /// No description provided for @vaccineRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'How are the injections given?'**
  String get vaccineRouteTitle;

  /// No description provided for @vaccineRouteGovernment.
  ///
  /// In en, this message translates to:
  /// **'Health office (free)'**
  String get vaccineRouteGovernment;

  /// No description provided for @vaccineRouteGovernmentHint.
  ///
  /// In en, this message translates to:
  /// **'Pentavalent and the polio injection (IPV) as separate shots, with a DTP booster at 18 months.'**
  String get vaccineRouteGovernmentHint;

  /// No description provided for @vaccineRouteHexavalent.
  ///
  /// In en, this message translates to:
  /// **'Private hexavalent'**
  String get vaccineRouteHexavalent;

  /// No description provided for @vaccineRouteHexavalentHint.
  ///
  /// In en, this message translates to:
  /// **'One hexavalent shot instead of pentavalent + IPV at 2, 4 and 6 months, and a hexavalent booster at 18 months. Oral polio drops, BCG, hepatitis B at birth and MMR stay the same.'**
  String get vaccineRouteHexavalentHint;

  /// No description provided for @vaccineOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional vaccines you follow'**
  String get vaccineOptionalTitle;

  /// No description provided for @vaccineOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Not on the ministry\'s free schedule. Ask the child\'s doctor which ones to give; only the ones you tick are reminded or counted late.'**
  String get vaccineOptionalHint;

  /// No description provided for @vaccineSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up vaccinations'**
  String get vaccineSetupTitle;

  /// No description provided for @vaccineSetupOpen.
  ///
  /// In en, this message translates to:
  /// **'Plan and doses given'**
  String get vaccineSetupOpen;

  /// No description provided for @vaccineSetupGiven.
  ///
  /// In en, this message translates to:
  /// **'Doses already given'**
  String get vaccineSetupGiven;

  /// No description provided for @vaccineSetupGivenHint.
  ///
  /// In en, this message translates to:
  /// **'Tick what\'s on the child\'s card. The date is the due date unless you change it.'**
  String get vaccineSetupGivenHint;

  /// No description provided for @vaccineSetupNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No doses are due yet.'**
  String get vaccineSetupNoneYet;

  /// No description provided for @vaccineSetupSkip.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get vaccineSetupSkip;

  /// No description provided for @vaccineSetupSaved.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations saved'**
  String get vaccineSetupSaved;

  /// No description provided for @vaccineChangeDate.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get vaccineChangeDate;

  /// No description provided for @vaccineDoseGiven.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get vaccineDoseGiven;

  /// No description provided for @vaccineDoseDate.
  ///
  /// In en, this message translates to:
  /// **'Date given'**
  String get vaccineDoseDate;

  /// No description provided for @vaccineDoseNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get vaccineDoseNote;

  /// No description provided for @vaccineDoseNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. given at the clinic, slight fever after'**
  String get vaccineDoseNoteHint;

  /// No description provided for @vaccineDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String vaccineDueOn(String date);

  /// No description provided for @vaccineNextVisit.
  ///
  /// In en, this message translates to:
  /// **'Next vaccine visit'**
  String get vaccineNextVisit;

  /// No description provided for @vaccineInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Today} =1{Tomorrow} other{In {days} days}}'**
  String vaccineInDays(int days);

  /// No description provided for @vaccineDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Was due yesterday} other{Was due {days} days ago}}'**
  String vaccineDaysAgo(int days);

  /// No description provided for @vaccineOverdueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dose overdue} other{{count} doses overdue}}'**
  String vaccineOverdueCount(int count);

  /// No description provided for @vaccineAllDone.
  ///
  /// In en, this message translates to:
  /// **'All planned vaccines are given'**
  String get vaccineAllDone;

  /// No description provided for @vaccineOpenAll.
  ///
  /// In en, this message translates to:
  /// **'All vaccinations'**
  String get vaccineOpenAll;

  /// No description provided for @homeVaccinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccines'**
  String get homeVaccinesTitle;

  /// No description provided for @vaccineChannelName.
  ///
  /// In en, this message translates to:
  /// **'Vaccine reminders'**
  String get vaccineChannelName;

  /// No description provided for @vaccineReminderDiscreetTitle.
  ///
  /// In en, this message translates to:
  /// **'A health visit is coming up'**
  String get vaccineReminderDiscreetTitle;

  /// No description provided for @vaccineReminderDiscreetTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'A health visit is today'**
  String get vaccineReminderDiscreetTodayTitle;

  /// No description provided for @vaccineReminderDiscreetBody.
  ///
  /// In en, this message translates to:
  /// **'Open Usra to see the details'**
  String get vaccineReminderDiscreetBody;

  /// No description provided for @vaccineReminderWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: vaccines in a week'**
  String vaccineReminderWeekTitle(String name);

  /// No description provided for @vaccineReminderTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: vaccines today'**
  String vaccineReminderTodayTitle(String name);

  /// No description provided for @settingsVaccineReminders.
  ///
  /// In en, this message translates to:
  /// **'Vaccine reminders'**
  String get settingsVaccineReminders;

  /// No description provided for @settingsVaccineRemindersHint.
  ///
  /// In en, this message translates to:
  /// **'A week before and on the day, at {time}'**
  String settingsVaccineRemindersHint(String time);

  /// No description provided for @settingsVaccineReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get settingsVaccineReminderTime;

  /// No description provided for @vaccineSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get vaccineSources;

  /// No description provided for @reminderHiddenPreview.
  ///
  /// In en, this message translates to:
  /// **'A reminder from Usra'**
  String get reminderHiddenPreview;

  /// No description provided for @vaccineTooLate.
  ///
  /// In en, this message translates to:
  /// **'Past the age limit: ask your doctor'**
  String get vaccineTooLate;

  /// No description provided for @vaccineNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'Not needed at this age'**
  String get vaccineNotNeeded;

  /// No description provided for @vaccineRemoveRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the record you entered?'**
  String get vaccineRemoveRecordTitle;

  /// No description provided for @vaccineRemoveRecordBody.
  ///
  /// In en, this message translates to:
  /// **'This dose was entered by hand, maybe with a photo of the card, the doctor or the cost. Unticking it removes that record from the child\'s history.'**
  String get vaccineRemoveRecordBody;

  /// No description provided for @vaccineRemoveRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get vaccineRemoveRecordConfirm;

  /// No description provided for @growthHeadForAge.
  ///
  /// In en, this message translates to:
  /// **'Head circumference for age'**
  String get growthHeadForAge;

  /// No description provided for @prescriptionsSection.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get prescriptionsSection;

  /// No description provided for @prescriptionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add prescription'**
  String get prescriptionAdd;

  /// No description provided for @prescriptionNew.
  ///
  /// In en, this message translates to:
  /// **'New prescription'**
  String get prescriptionNew;

  /// No description provided for @prescriptionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit prescription'**
  String get prescriptionEdit;

  /// No description provided for @prescriptionDate.
  ///
  /// In en, this message translates to:
  /// **'Date (first day of treatment)'**
  String get prescriptionDate;

  /// No description provided for @prescriptionDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis or reason'**
  String get prescriptionDiagnosis;

  /// No description provided for @prescriptionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get prescriptionNotes;

  /// No description provided for @prescriptionPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photo of the prescription'**
  String get prescriptionPhotos;

  /// No description provided for @prescriptionMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get prescriptionMedicines;

  /// No description provided for @prescriptionAddMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add another medicine'**
  String get prescriptionAddMedicine;

  /// No description provided for @prescriptionMedicineN.
  ///
  /// In en, this message translates to:
  /// **'Medicine {n}'**
  String prescriptionMedicineN(int n);

  /// No description provided for @prescriptionRemoveMedicine.
  ///
  /// In en, this message translates to:
  /// **'Remove this medicine'**
  String get prescriptionRemoveMedicine;

  /// No description provided for @prescriptionDose.
  ///
  /// In en, this message translates to:
  /// **'Dose, as the doctor wrote it'**
  String get prescriptionDose;

  /// No description provided for @prescriptionDoseHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5 ml after meals'**
  String get prescriptionDoseHint;

  /// No description provided for @prescriptionTimesPerDay.
  ///
  /// In en, this message translates to:
  /// **'Times a day (you can change the times)'**
  String get prescriptionTimesPerDay;

  /// No description provided for @prescriptionTimesN.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Once} =2{Twice} other{{count} times}}'**
  String prescriptionTimesN(int count);

  /// No description provided for @prescriptionDuration.
  ///
  /// In en, this message translates to:
  /// **'For how long'**
  String get prescriptionDuration;

  /// No description provided for @prescriptionOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get prescriptionOngoing;

  /// No description provided for @prescriptionForDays.
  ///
  /// In en, this message translates to:
  /// **'A set number of days'**
  String get prescriptionForDays;

  /// No description provided for @prescriptionDays.
  ///
  /// In en, this message translates to:
  /// **'Number of days'**
  String get prescriptionDays;

  /// No description provided for @prescriptionDaysInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of days, 1 or more'**
  String get prescriptionDaysInvalid;

  /// No description provided for @prescriptionNoDoseAdvice.
  ///
  /// In en, this message translates to:
  /// **'Write each medicine exactly as it is on the prescription. Usra never suggests or calculates a dose.'**
  String get prescriptionNoDoseAdvice;

  /// No description provided for @prescriptionNeedsTimes.
  ///
  /// In en, this message translates to:
  /// **'Add at least one time, or no reminders will ring'**
  String get prescriptionNeedsTimes;

  /// No description provided for @prescriptionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop the whole prescription'**
  String get prescriptionStop;

  /// No description provided for @prescriptionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume the prescription'**
  String get prescriptionResume;

  /// No description provided for @prescriptionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this prescription, its medicines and their history? Its photos will be removed from this phone.'**
  String get prescriptionDeleteConfirm;

  /// No description provided for @prescriptionNotFound.
  ///
  /// In en, this message translates to:
  /// **'This prescription was deleted'**
  String get prescriptionNotFound;

  /// No description provided for @prescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescription of {date}'**
  String prescriptionTitle(String date);

  /// No description provided for @prescriptionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medicine} other{{count} medicines}}'**
  String prescriptionCount(int count);

  /// No description provided for @prescriptionDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String prescriptionDaysCount(int count);

  /// No description provided for @prescriptionLink.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get prescriptionLink;

  /// No description provided for @courseDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String courseDayOf(int day, int total);

  /// No description provided for @prescriptionMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move the courses too?'**
  String get prescriptionMoveTitle;

  /// No description provided for @prescriptionMoveBody.
  ///
  /// In en, this message translates to:
  /// **'Courses that haven\'t ended can start on the new date. Courses already over keep their dates and get no reminders back.'**
  String get prescriptionMoveBody;

  /// No description provided for @prescriptionMoveYes.
  ///
  /// In en, this message translates to:
  /// **'Move them'**
  String get prescriptionMoveYes;

  /// No description provided for @prescriptionMoveKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep their dates'**
  String get prescriptionMoveKeep;

  /// No description provided for @prescriptionRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Take {name} off this prescription? It will be stopped, so its reminders end. Its dose history stays on its own page.'**
  String prescriptionRemoveConfirm(String name);

  /// No description provided for @prescriptionEveryHours.
  ///
  /// In en, this message translates to:
  /// **'Every few hours'**
  String get prescriptionEveryHours;

  /// No description provided for @prescriptionInterval.
  ///
  /// In en, this message translates to:
  /// **'As the doctor wrote'**
  String get prescriptionInterval;

  /// No description provided for @prescriptionEveryNHours.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Every hour} other{Every {n} hours}}'**
  String prescriptionEveryNHours(int n);

  /// No description provided for @prescriptionFirstDose.
  ///
  /// In en, this message translates to:
  /// **'First one at {time}'**
  String prescriptionFirstDose(String time);

  /// No description provided for @prescriptionTimesHint.
  ///
  /// In en, this message translates to:
  /// **'Check the times match what the doctor wrote, e.g. every 8 hours.'**
  String get prescriptionTimesHint;

  /// No description provided for @growthNoPrematurity.
  ///
  /// In en, this message translates to:
  /// **'Uses age from birth, with no correction for babies born early. If your baby was premature, ask the pediatrician how to read this chart.'**
  String get growthNoPrematurity;

  /// No description provided for @reportAppLine.
  ///
  /// In en, this message translates to:
  /// **'Made with Usra (أسرة), a family health app'**
  String get reportAppLine;

  /// No description provided for @reportGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated on {date}'**
  String reportGenerated(String date);

  /// No description provided for @reportPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String reportPage(int page, int total);

  /// No description provided for @reportVaccinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccination record'**
  String get reportVaccinationTitle;

  /// No description provided for @reportVaccinationDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'An informational record made by the family in the Usra app from their own entries. Not an official vaccination certificate: check with the child\'s vaccination card.'**
  String get reportVaccinationDisclaimer;

  /// No description provided for @reportName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reportName;

  /// No description provided for @reportRoute.
  ///
  /// In en, this message translates to:
  /// **'Vaccination route'**
  String get reportRoute;

  /// No description provided for @reportRouteGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government (health office)'**
  String get reportRouteGovernment;

  /// No description provided for @reportRoutePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private (hexavalent)'**
  String get reportRoutePrivate;

  /// No description provided for @reportDosesGiven.
  ///
  /// In en, this message translates to:
  /// **'Doses given'**
  String get reportDosesGiven;

  /// No description provided for @reportNoDosesGiven.
  ///
  /// In en, this message translates to:
  /// **'No doses recorded yet'**
  String get reportNoDosesGiven;

  /// No description provided for @reportUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming doses'**
  String get reportUpcoming;

  /// No description provided for @reportNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No doses left on the schedule'**
  String get reportNoUpcoming;

  /// No description provided for @reportUpcomingOverFive.
  ///
  /// In en, this message translates to:
  /// **'The schedule in Usra follows children until age 5.'**
  String get reportUpcomingOverFive;

  /// No description provided for @reportColVaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get reportColVaccine;

  /// No description provided for @reportColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportColDate;

  /// No description provided for @reportColNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get reportColNotes;

  /// No description provided for @reportColDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get reportColDue;

  /// No description provided for @reportOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get reportOverdue;

  /// No description provided for @reportSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Health summary for the doctor'**
  String get reportSummaryTitle;

  /// No description provided for @reportSummaryDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'A summary made by the family in the Usra app from their own records. Informational only: check against the original prescriptions and reports.'**
  String get reportSummaryDisclaimer;

  /// No description provided for @reportAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get reportAge;

  /// No description provided for @reportSectionBasics.
  ///
  /// In en, this message translates to:
  /// **'Age and blood type'**
  String get reportSectionBasics;

  /// No description provided for @reportSectionMedicines.
  ///
  /// In en, this message translates to:
  /// **'Current medicines'**
  String get reportSectionMedicines;

  /// No description provided for @reportSectionVisits.
  ///
  /// In en, this message translates to:
  /// **'Recent doctor visits'**
  String get reportSectionVisits;

  /// No description provided for @reportSectionLabs.
  ///
  /// In en, this message translates to:
  /// **'Recent lab results'**
  String get reportSectionLabs;

  /// No description provided for @reportSectionGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get reportSectionGrowth;

  /// No description provided for @reportSectionVaccines.
  ///
  /// In en, this message translates to:
  /// **'Vaccines'**
  String get reportSectionVaccines;

  /// No description provided for @reportColMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get reportColMedicine;

  /// No description provided for @reportColHowTaken.
  ///
  /// In en, this message translates to:
  /// **'As written by the doctor'**
  String get reportColHowTaken;

  /// No description provided for @reportColDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get reportColDoctor;

  /// No description provided for @reportColDetails.
  ///
  /// In en, this message translates to:
  /// **'Reason / diagnosis'**
  String get reportColDetails;

  /// No description provided for @reportColTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get reportColTest;

  /// No description provided for @reportColResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get reportColResult;

  /// No description provided for @reportColRange.
  ///
  /// In en, this message translates to:
  /// **'Lab\'s range'**
  String get reportColRange;

  /// No description provided for @reportColMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get reportColMeasure;

  /// No description provided for @reportColValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get reportColValue;

  /// No description provided for @reportColPercentile.
  ///
  /// In en, this message translates to:
  /// **'WHO percentile'**
  String get reportColPercentile;

  /// No description provided for @reportAsNeeded.
  ///
  /// In en, this message translates to:
  /// **'When needed'**
  String get reportAsNeeded;

  /// No description provided for @reportSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String reportSince(String date);

  /// No description provided for @reportUntil.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String reportUntil(String date);

  /// No description provided for @reportVaccineProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} doses in the plan given'**
  String reportVaccineProgress(int done, int total);

  /// No description provided for @reportVaccineNext.
  ///
  /// In en, this message translates to:
  /// **'Next vaccine visit'**
  String get reportVaccineNext;

  /// No description provided for @reportVaccineOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get reportVaccineOverdue;

  /// No description provided for @reportGrowthNote.
  ///
  /// In en, this message translates to:
  /// **'Percentiles from the WHO Child Growth Standards (under 5). Informational, not a diagnosis.'**
  String get reportGrowthNote;

  /// No description provided for @reportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded'**
  String get reportNothing;

  /// No description provided for @memberDoctorSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary for the doctor'**
  String get memberDoctorSummary;

  /// No description provided for @reportSummaryIntro.
  ///
  /// In en, this message translates to:
  /// **'A short PDF summary to show or send to a doctor. Choose what goes in.'**
  String get reportSummaryIntro;

  /// No description provided for @reportChooseSections.
  ///
  /// In en, this message translates to:
  /// **'What to include'**
  String get reportChooseSections;

  /// No description provided for @reportLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language of the PDF'**
  String get reportLanguage;

  /// No description provided for @reportSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get reportSharePdf;

  /// No description provided for @reportIncludeNotes.
  ///
  /// In en, this message translates to:
  /// **'Include my notes on each dose'**
  String get reportIncludeNotes;

  /// No description provided for @reportVaccinationShare.
  ///
  /// In en, this message translates to:
  /// **'Share vaccination record'**
  String get reportVaccinationShare;

  /// No description provided for @reportVaccinationIntro.
  ///
  /// In en, this message translates to:
  /// **'A PDF of the doses given and the ones coming up, for a school, nursery or doctor.'**
  String get reportVaccinationIntro;

  /// No description provided for @reportPickOne.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one section'**
  String get reportPickOne;

  /// No description provided for @reportOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Made on this phone. The file is deleted from the phone once it\'s shared.'**
  String get reportOnPhone;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the PDF'**
  String get reportFailed;

  /// No description provided for @reportNeedsBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Add a date of birth to the profile first.'**
  String get reportNeedsBirthDate;

  /// No description provided for @reportFlagHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get reportFlagHigh;

  /// No description provided for @reportFlagLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get reportFlagLow;

  /// No description provided for @reportTooLate.
  ///
  /// In en, this message translates to:
  /// **'Too late for this vaccine: ask the doctor'**
  String get reportTooLate;

  /// No description provided for @reportTooLateLabel.
  ///
  /// In en, this message translates to:
  /// **'Too late (ask the doctor)'**
  String get reportTooLateLabel;

  /// No description provided for @reportSimpleIntro.
  ///
  /// In en, this message translates to:
  /// **'A PDF with this person\'s health details, medicines, visits and tests, to show or send to a doctor.'**
  String get reportSimpleIntro;

  /// No description provided for @memberSickDays.
  ///
  /// In en, this message translates to:
  /// **'Fever & sick days'**
  String get memberSickDays;

  /// No description provided for @sickDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Fever and sick days'**
  String get sickDaysTitle;

  /// No description provided for @sickDaysEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sick days yet. When someone gets ill, start one to log temperatures, symptoms and the medicines given.'**
  String get sickDaysEmpty;

  /// No description provided for @sickDayStart.
  ///
  /// In en, this message translates to:
  /// **'Start a sick day'**
  String get sickDayStart;

  /// No description provided for @sickDayOngoing.
  ///
  /// In en, this message translates to:
  /// **'Still ill'**
  String get sickDayOngoing;

  /// No description provided for @sickDayEnded.
  ///
  /// In en, this message translates to:
  /// **'Over'**
  String get sickDayEnded;

  /// No description provided for @sickDaySince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String sickDaySince(String date);

  /// No description provided for @sickDayRange.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String sickDayRange(String start, String end);

  /// No description provided for @sickDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Sick day'**
  String get sickDayTitle;

  /// No description provided for @sickDayStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get sickDayStartedAt;

  /// No description provided for @sickDayEnd.
  ///
  /// In en, this message translates to:
  /// **'Mark as over'**
  String get sickDayEnd;

  /// No description provided for @sickDayReopen.
  ///
  /// In en, this message translates to:
  /// **'Still ill'**
  String get sickDayReopen;

  /// No description provided for @sickDayDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this sick day'**
  String get sickDayDelete;

  /// No description provided for @sickDayDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this sick day with its temperatures and medicines given?'**
  String get sickDayDeleteConfirm;

  /// No description provided for @sickDayTemperatures.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get sickDayTemperatures;

  /// No description provided for @sickDayAddReading.
  ///
  /// In en, this message translates to:
  /// **'Add a temperature'**
  String get sickDayAddReading;

  /// No description provided for @sickDayNoReadings.
  ///
  /// In en, this message translates to:
  /// **'No temperatures yet.'**
  String get sickDayNoReadings;

  /// No description provided for @sickDayChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature chart'**
  String get sickDayChartTitle;

  /// No description provided for @sickDayChartNote.
  ///
  /// In en, this message translates to:
  /// **'Dashed line: 38 °C (100.4 °F), where a fever starts.'**
  String get sickDayChartNote;

  /// No description provided for @sickDaySymptoms.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get sickDaySymptoms;

  /// No description provided for @sickDayMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines given'**
  String get sickDayMedicines;

  /// No description provided for @sickDayAddMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add a medicine given'**
  String get sickDayAddMedicine;

  /// No description provided for @sickDayNoMedicines.
  ///
  /// In en, this message translates to:
  /// **'No medicines logged.'**
  String get sickDayNoMedicines;

  /// No description provided for @sickDayNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get sickDayNotes;

  /// No description provided for @sickDayNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes saved'**
  String get sickDayNotesSaved;

  /// No description provided for @readingValue.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get readingValue;

  /// No description provided for @readingCelsius.
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get readingCelsius;

  /// No description provided for @readingFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'°F'**
  String get readingFahrenheit;

  /// No description provided for @readingSite.
  ///
  /// In en, this message translates to:
  /// **'Where it was taken'**
  String get readingSite;

  /// No description provided for @readingSiteName.
  ///
  /// In en, this message translates to:
  /// **'{site, select, armpit{Armpit} ear{Ear} forehead{Forehead} mouth{Mouth} rectal{Rectal} other{Not said}}'**
  String readingSiteName(String site);

  /// No description provided for @readingTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get readingTime;

  /// No description provided for @readingDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get readingDate;

  /// No description provided for @readingImplausible.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a body temperature. Check the number and the unit.'**
  String get readingImplausible;

  /// No description provided for @readingFever.
  ///
  /// In en, this message translates to:
  /// **'Fever'**
  String get readingFever;

  /// No description provided for @readingDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this temperature'**
  String get readingDelete;

  /// No description provided for @givenWhich.
  ///
  /// In en, this message translates to:
  /// **'Which medicine'**
  String get givenWhich;

  /// No description provided for @givenOther.
  ///
  /// In en, this message translates to:
  /// **'Another medicine (type its name)'**
  String get givenOther;

  /// No description provided for @givenName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get givenName;

  /// No description provided for @givenAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount given'**
  String get givenAmount;

  /// No description provided for @givenAmountHint.
  ///
  /// In en, this message translates to:
  /// **'As you\'d write it, e.g. from the box or prescription'**
  String get givenAmountHint;

  /// No description provided for @givenTime.
  ///
  /// In en, this message translates to:
  /// **'Time given'**
  String get givenTime;

  /// No description provided for @givenFromPrescription.
  ///
  /// In en, this message translates to:
  /// **'From the prescription of {date}'**
  String givenFromPrescription(String date);

  /// No description provided for @givenRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind me at that time'**
  String get givenRemind;

  /// No description provided for @givenNoInterval.
  ///
  /// In en, this message translates to:
  /// **'No time shown: this medicine has no minimum hours between doses saved. You can add them on the medicine\'s page, as written on the label or by your doctor.'**
  String get givenNoInterval;

  /// No description provided for @givenDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry'**
  String get givenDelete;

  /// No description provided for @givenRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a medicine or type its name'**
  String get givenRequired;

  /// No description provided for @nextDoseDiscreetTitle.
  ///
  /// In en, this message translates to:
  /// **'A reminder from Usra'**
  String get nextDoseDiscreetTitle;

  /// No description provided for @nextDoseDiscreetBody.
  ///
  /// In en, this message translates to:
  /// **'Open Usra to see it.'**
  String get nextDoseDiscreetBody;

  /// No description provided for @nextDoseTitle.
  ///
  /// In en, this message translates to:
  /// **'{person}: {medicine}'**
  String nextDoseTitle(String person, String medicine);

  /// No description provided for @nextDoseBody.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours have passed since the dose you logged. Check other medicines with the same ingredient.'**
  String nextDoseBody(String hours);

  /// No description provided for @symptomName.
  ///
  /// In en, this message translates to:
  /// **'{symptom, select, cough{Cough} runnyNose{Runny nose} soreThroat{Sore throat} earPain{Ear pain} headache{Headache} vomiting{Vomiting} diarrhea{Diarrhoea} rash{Rash} aches{Body aches} poorFeeding{Eating or drinking less} dehydration{Fewer wet nappies, peeing less or no tears} breathing{Hard to breathe} drowsy{Very drowsy or hard to wake} seizure{Fit (seizure)} rashNotFading{Rash that doesn\'t fade under a glass} stiffNeck{Stiff neck} other{Other}}'**
  String symptomName(String symptom);

  /// No description provided for @warnTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning signs'**
  String get warnTitle;

  /// No description provided for @warnLogged.
  ///
  /// In en, this message translates to:
  /// **'From what you logged:'**
  String get warnLogged;

  /// No description provided for @warnEmergency.
  ///
  /// In en, this message translates to:
  /// **'Call an ambulance (123) now if:'**
  String get warnEmergency;

  /// No description provided for @warnDoctorNow.
  ///
  /// In en, this message translates to:
  /// **'Contact a doctor now if:'**
  String get warnDoctorNow;

  /// No description provided for @warnSign.
  ///
  /// In en, this message translates to:
  /// **'{sign, select, breathing{Hard to breathe, breathing very fast or breathless} seizure{A fit (seizure)} rashGlass{A rash that doesn\'t fade when you press a glass on it} drowsy{Very drowsy or hard to wake, or not responding as usual} stiffNeck{A stiff neck, or light hurts the eyes} skinColour{Blue, grey, very pale or blotchy skin, lips or tongue, or unusually cold hands and feet} confused{Confused, or very agitated and won\'t stop crying} under3Months{Under 3 months old with a temperature of 38 °C (100.4 °F) or higher} months3to6{3 to 6 months old with a temperature of 39 °C (102.2 °F) or higher} longUnder2{Under 2 years old with a fever for more than 24 hours} longChild{2 years or older with a fever for more than 3 days} fiveDays{A fever that has lasted 5 days or more} veryHigh{A temperature above 40 °C (104 °F) more than once} notImproving{A high temperature that isn\'t getting better, or is getting worse} dehydration{Signs of dehydration: fewer wet nappies or peeing less, no tears, sunken eyes, dry mouth} notDrinking{Not drinking, not feeding or breastfeeding, or not acting like themselves} vomitsEverything{Vomits everything, or keeps vomiting} armpitUnder3Months{Under 3 months old with an armpit reading of 37.5 °C (99.5 °F) or higher} lowUnder3Months{Under 3 months old with a temperature below 36 °C (96.8 °F)} other{}}'**
  String warnSign(String sign);

  /// No description provided for @warnFooter.
  ///
  /// In en, this message translates to:
  /// **'For information only, not a diagnosis. If you\'re worried, contact a doctor or call 123, even if nothing here matches.'**
  String get warnFooter;

  /// No description provided for @warnSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get warnSources;

  /// No description provided for @warnSourceName.
  ///
  /// In en, this message translates to:
  /// **'{source, select, nhs{NHS (UK): fever in children} aap{American Academy of Pediatrics: when to call the pediatrician} who{WHO: IMCI general danger signs} stlouis{St. Louis Children\'s Hospital: how to take a temperature} womans{Woman\'s Hospital: newborn temperature} other{}}'**
  String warnSourceName(String source);

  /// No description provided for @warnCallDoctor.
  ///
  /// In en, this message translates to:
  /// **'My doctors'**
  String get warnCallDoctor;

  /// No description provided for @givenHoursAfter.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours after this dose: {time}'**
  String givenHoursAfter(String hours, String time);

  /// No description provided for @givenCheckIngredient.
  ///
  /// In en, this message translates to:
  /// **'Check other medicines with the same ingredient before giving another dose.'**
  String get givenCheckIngredient;

  /// No description provided for @medicineMinHours.
  ///
  /// In en, this message translates to:
  /// **'Minimum hours between doses'**
  String get medicineMinHours;

  /// No description provided for @medicineMinHoursHint.
  ///
  /// In en, this message translates to:
  /// **'As written on the label or by your doctor. Leave empty if it doesn\'t say.'**
  String get medicineMinHoursHint;

  /// No description provided for @medicineMinHoursInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter hours between 0.5 and 72'**
  String get medicineMinHoursInvalid;

  /// No description provided for @medicineMinHoursSuggest.
  ///
  /// In en, this message translates to:
  /// **'The instructions say “{phrase}”. Use {hours} hours?'**
  String medicineMinHoursSuggest(String phrase, String hours);

  /// No description provided for @medicineMinHoursUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get medicineMinHoursUse;

  /// No description provided for @medicineMinHoursValue.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String medicineMinHoursValue(String hours);

  /// No description provided for @warnArmpitNote.
  ///
  /// In en, this message translates to:
  /// **'Armpit readings run lower. If your baby feels hot or seems unwell, call the doctor even below 38 °C.'**
  String get warnArmpitNote;

  /// No description provided for @warnNoBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Add a date of birth to see the signs for this age.'**
  String get warnNoBirthDate;

  /// No description provided for @readingConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Is this right?'**
  String get readingConfirmTitle;

  /// No description provided for @readingConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{value} is a very unusual body temperature. Check the thermometer and the unit.'**
  String readingConfirmBody(String value);

  /// No description provided for @readingConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get readingConfirmYes;

  /// No description provided for @readingConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'Change it'**
  String get readingConfirmNo;

  /// No description provided for @backupLastCopy.
  ///
  /// In en, this message translates to:
  /// **'Last copy sent elsewhere: {date}'**
  String backupLastCopy(String date);

  /// No description provided for @backupAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get backupAutoTitle;

  /// No description provided for @backupAutoHint.
  ///
  /// In en, this message translates to:
  /// **'When you open Usra and a backup is due, it saves an encrypted copy in a folder you choose. No account needed.'**
  String get backupAutoHint;

  /// No description provided for @backupAutoFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get backupAutoFolder;

  /// No description provided for @backupAutoChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get backupAutoChooseFolder;

  /// No description provided for @backupAutoFrequency.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get backupAutoFrequency;

  /// No description provided for @backupFrequencyDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get backupFrequencyDaily;

  /// No description provided for @backupFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get backupFrequencyWeekly;

  /// No description provided for @backupFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get backupFrequencyMonthly;

  /// No description provided for @backupAutoNever.
  ///
  /// In en, this message translates to:
  /// **'No automatic backup yet'**
  String get backupAutoNever;

  /// No description provided for @backupAutoRunning.
  ///
  /// In en, this message translates to:
  /// **'Backing up. You can keep using the app.'**
  String get backupAutoRunning;

  /// No description provided for @backupAutoDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved in your folder.'**
  String get backupAutoDone;

  /// No description provided for @backupSendCopy.
  ///
  /// In en, this message translates to:
  /// **'Send a copy somewhere else'**
  String get backupSendCopy;

  /// No description provided for @backupBusy.
  ///
  /// In en, this message translates to:
  /// **'A backup is already running. Try again in a moment.'**
  String get backupBusy;

  /// No description provided for @backupAutoDriveHint.
  ///
  /// In en, this message translates to:
  /// **'Google Drive may not appear when you choose a folder, and Usra doesn\'t ask for access to your Drive. To keep a copy in Drive, tap \"Send a copy somewhere else\" and choose Drive.'**
  String get backupAutoDriveHint;

  /// No description provided for @backupAutoOnPhone.
  ///
  /// In en, this message translates to:
  /// **'This folder is on this phone. If the phone is lost, these backups go with it, so send a copy somewhere else too.'**
  String get backupAutoOnPhone;

  /// No description provided for @backupAutoIosHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a place off this phone if you can, such as another app in Files or an external drive. A folder in On My iPhone is lost with the phone. iCloud Drive can\'t be used for health records.'**
  String get backupAutoIosHint;

  /// No description provided for @backupICloudTitle.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive can\'t be used'**
  String get backupICloudTitle;

  /// No description provided for @backupICloudBody.
  ///
  /// In en, this message translates to:
  /// **'Apple\'s rules don\'t allow health records in iCloud, even encrypted, so Usra won\'t save backups there. Choose another place, such as another app in Files or an external drive.'**
  String get backupICloudBody;

  /// No description provided for @backupFolderCantUseTitle.
  ///
  /// In en, this message translates to:
  /// **'This place can\'t be used'**
  String get backupFolderCantUseTitle;

  /// No description provided for @backupFolderCantUseBody.
  ///
  /// In en, this message translates to:
  /// **'Usra couldn\'t save and tidy up its files there. Choose another folder.'**
  String get backupFolderCantUseBody;

  /// No description provided for @backupAutoKeyFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'First, your recovery key'**
  String get backupAutoKeyFirstTitle;

  /// No description provided for @backupAutoKeyFirstBody.
  ///
  /// In en, this message translates to:
  /// **'Backups are encrypted, and only your recovery key opens them. You\'ll write it on paper now. It stays in this phone\'s secure storage and is never saved with the backups.'**
  String get backupAutoKeyFirstBody;

  /// No description provided for @backupAutoKeyFirstContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get backupAutoKeyFirstContinue;

  /// No description provided for @backupAutoFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The automatic backup didn\'t finish'**
  String get backupAutoFailedTitle;

  /// No description provided for @backupAutoRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get backupAutoRetry;

  /// No description provided for @backupAutoSetKey.
  ///
  /// In en, this message translates to:
  /// **'Set up the key'**
  String get backupAutoSetKey;

  /// No description provided for @backupAutoFailFolder.
  ///
  /// In en, this message translates to:
  /// **'We can\'t reach the backup folder. It may have been moved or removed. Choose it again.'**
  String get backupAutoFailFolder;

  /// No description provided for @backupAutoFailICloud.
  ///
  /// In en, this message translates to:
  /// **'The backup folder is now in iCloud Drive, which can\'t be used for health records. Choose another place.'**
  String get backupAutoFailICloud;

  /// No description provided for @backupAutoFailSpace.
  ///
  /// In en, this message translates to:
  /// **'There isn\'t enough storage space for the backup. Free up some space, then try again.'**
  String get backupAutoFailSpace;

  /// No description provided for @backupAutoFailLocked.
  ///
  /// In en, this message translates to:
  /// **'The phone locked during the backup. Keep it unlocked, then try again.'**
  String get backupAutoFailLocked;

  /// No description provided for @backupAutoFailKey.
  ///
  /// In en, this message translates to:
  /// **'The recovery key isn\'t on this phone any more. Set it up again to keep backing up.'**
  String get backupAutoFailKey;

  /// No description provided for @backupAutoFailInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Usra closed before the backup finished. Any unfinished file is removed next time, and your earlier backups are safe. Try again.'**
  String get backupAutoFailInterrupted;

  /// No description provided for @backupAutoFailOther.
  ///
  /// In en, this message translates to:
  /// **'Something stopped the backup. Your earlier backups are safe. Try again.'**
  String get backupAutoFailOther;

  /// No description provided for @backupAutoPaused.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup is paused because Usra started fresh, so new backups don\'t push out the ones holding your records. Restore a backup, or turn this on again.'**
  String get backupAutoPaused;

  /// No description provided for @backupDueAuto.
  ///
  /// In en, this message translates to:
  /// **'If your backup folder is on this phone, losing the phone loses the backups too. Send a copy somewhere else.'**
  String get backupDueAuto;

  /// No description provided for @backupAutoLast.
  ///
  /// In en, this message translates to:
  /// **'Last automatic backup: {date} ({size})'**
  String backupAutoLast(String date, String size);

  /// No description provided for @backupSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String backupSizeKb(String size);

  /// No description provided for @backupSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String backupSizeMb(String size);

  /// No description provided for @backupSizeGb.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String backupSizeGb(String size);

  /// No description provided for @backupAutoPhotosSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo couldn\'t be opened on this phone and isn\'t in this backup.} other{{count} photos couldn\'t be opened on this phone and aren\'t in this backup.}}'**
  String backupAutoPhotosSkipped(int count);

  /// No description provided for @backupAutoOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Backup'**
  String get backupAutoOpen;

  /// No description provided for @backupAutoPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup is paused'**
  String get backupAutoPausedTitle;

  /// No description provided for @backupAutoUnreadableTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup is off'**
  String get backupAutoUnreadableTitle;

  /// No description provided for @backupAutoUnreadableBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read your automatic backup settings. Your backups are still in your folder. Open Backup to turn it on again.'**
  String get backupAutoUnreadableBody;

  /// No description provided for @backupContentDroppedTitle.
  ///
  /// In en, this message translates to:
  /// **'The latest backup holds less than before'**
  String get backupContentDroppedTitle;

  /// No description provided for @backupContentDroppedBody.
  ///
  /// In en, this message translates to:
  /// **'It has fewer people, records or photos, or some photos are missing, so we kept your older backups. If you deleted these on purpose, confirm it. If not, restore an older backup.'**
  String get backupContentDroppedBody;

  /// No description provided for @backupContentDroppedAccept.
  ///
  /// In en, this message translates to:
  /// **'I deleted them on purpose'**
  String get backupContentDroppedAccept;

  /// No description provided for @backupAutoFolderTop.
  ///
  /// In en, this message translates to:
  /// **'The main folder of the place you chose'**
  String get backupAutoFolderTop;

  /// No description provided for @aboutPrivacyBackupAuto.
  ///
  /// In en, this message translates to:
  /// **'If you turn on automatic backup, Usra saves that file by itself to a folder you pick. It sends us nothing, and it won\'t use iCloud Drive.'**
  String get aboutPrivacyBackupAuto;

  /// No description provided for @navRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get navRecords;

  /// No description provided for @navAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get navAdd;

  /// No description provided for @homeMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeMorning;

  /// No description provided for @homeEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeEvening;

  /// No description provided for @homeNothingNeeded.
  ///
  /// In en, this message translates to:
  /// **'Nothing needed'**
  String get homeNothingNeeded;

  /// No description provided for @homeNeedsAttentionOne.
  ///
  /// In en, this message translates to:
  /// **'needs your attention'**
  String get homeNeedsAttentionOne;

  /// No description provided for @homeNeedsAttentionMany.
  ///
  /// In en, this message translates to:
  /// **'need your attention'**
  String get homeNeedsAttentionMany;

  /// No description provided for @homeNamesJoin.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get homeNamesJoin;

  /// No description provided for @homeFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get homeFamily;

  /// No description provided for @homeAllFamily.
  ///
  /// In en, this message translates to:
  /// **'All family ({count})'**
  String homeAllFamily(String count);

  /// No description provided for @homeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Next today'**
  String get homeUpcoming;

  /// No description provided for @homeNewPerson.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get homeNewPerson;

  /// No description provided for @homeEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get homeEmergency;

  /// No description provided for @homeBackupAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Last backup today} =1{Last backup 1 day ago} other{Last backup {shown} days ago}}'**
  String homeBackupAgoDays(int days, String shown);

  /// No description provided for @homeDoseLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged: {medicine} for {person}'**
  String homeDoseLogged(String medicine, String person);

  /// No description provided for @statusSick.
  ///
  /// In en, this message translates to:
  /// **'Unwell'**
  String get statusSick;

  /// No description provided for @statusVaccineOverdue.
  ///
  /// In en, this message translates to:
  /// **'Vaccine overdue'**
  String get statusVaccineOverdue;

  /// No description provided for @statusDoseMissed.
  ///
  /// In en, this message translates to:
  /// **'Dose missed'**
  String get statusDoseMissed;

  /// No description provided for @statusDoseNext.
  ///
  /// In en, this message translates to:
  /// **'Dose {time}'**
  String statusDoseNext(String time);

  /// No description provided for @familyAllTitle.
  ///
  /// In en, this message translates to:
  /// **'All family'**
  String get familyAllTitle;

  /// No description provided for @familyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{shown} people}}'**
  String familyCount(int count, String shown);

  /// No description provided for @addSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to add?'**
  String get addSheetTitle;

  /// No description provided for @addSheetFor.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get addSheetFor;

  /// No description provided for @addSheetPickPerson.
  ///
  /// In en, this message translates to:
  /// **'Choose a person first'**
  String get addSheetPickPerson;

  /// No description provided for @addSheetNoPeople.
  ///
  /// In en, this message translates to:
  /// **'Add a family member first'**
  String get addSheetNoPeople;

  /// No description provided for @addMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get addMedicine;

  /// No description provided for @addVaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get addVaccine;

  /// No description provided for @addVisit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get addVisit;

  /// No description provided for @addLab.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get addLab;

  /// No description provided for @addScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get addScan;

  /// No description provided for @addFever.
  ///
  /// In en, this message translates to:
  /// **'Fever'**
  String get addFever;

  /// No description provided for @addGrowth.
  ///
  /// In en, this message translates to:
  /// **'Weight and height'**
  String get addGrowth;

  /// No description provided for @addInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance card'**
  String get addInsurance;

  /// No description provided for @recordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get recordsTitle;

  /// No description provided for @recordsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get recordsAll;

  /// No description provided for @recordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records yet. Tap Add to log a first visit or test.'**
  String get recordsEmpty;

  /// No description provided for @recordsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a record'**
  String get recordsAdd;

  /// No description provided for @moreFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get moreFamily;

  /// No description provided for @statusSickFemale.
  ///
  /// In en, this message translates to:
  /// **'Unwell'**
  String get statusSickFemale;

  /// No description provided for @emergencyPickPerson.
  ///
  /// In en, this message translates to:
  /// **'Whose card?'**
  String get emergencyPickPerson;

  /// No description provided for @homeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Can\'t read your data right now. Close the app and open it again.'**
  String get homeLoadError;
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
