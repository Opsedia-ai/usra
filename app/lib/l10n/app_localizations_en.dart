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
}
