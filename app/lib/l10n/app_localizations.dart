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
