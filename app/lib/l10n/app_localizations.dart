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
