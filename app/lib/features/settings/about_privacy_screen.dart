import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_providers.dart';

const aboutPath = '/settings/about';

/// Where the privacy policy and terms (docs/legal) are hosted. Store builds
/// pass the real site, the same one given to Google Play and App Store
/// Connect:
///
///     flutter build appbundle --dart-define=USRA_RELEASE=true \
///       --dart-define=USRA_WEBSITE=https://<real domain>
const usraWebsite = String.fromEnvironment(
  'USRA_WEBSITE',
  defaultValue: placeholderWebsite,
);

/// Used until the domain is chosen; links to it are dead.
const placeholderWebsite = 'https://usra.example';

/// True only in store builds (`--dart-define=USRA_RELEASE=true`).
const isStoreRelease = bool.fromEnvironment('USRA_RELEASE');

/// Fails the compile of a store build that still has the placeholder site:
/// a const assert is checked while compiling, release builds included.
const releaseWebsiteCheck = _ReleaseWebsiteCheck();

class _ReleaseWebsiteCheck {
  const _ReleaseWebsiteCheck()
    : assert(
        !isStoreRelease || usraWebsite != placeholderWebsite,
        'Store build without USRA_WEBSITE: set the hosted privacy policy site.',
      );
}

Uri privacyPolicyUrl(String languageCode) =>
    Uri.parse('$usraWebsite/$languageCode/privacy');

Uri termsUrl(String languageCode) =>
    Uri.parse('$usraWebsite/$languageCode/terms');

/// Opens [uri] in the browser. Overridden in tests.
final openLinkProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// What happens to the family's data, the medical disclaimer, the version,
/// and links to the full policy and terms.
class AboutPrivacyScreen extends ConsumerWidget {
  const AboutPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;

    Future<void> open(Uri uri) async {
      final messenger = ScaffoldMessenger.of(context);
      var ok = false;
      try {
        ok = await ref.read(openLinkProvider)(uri);
      } catch (_) {
        ok = false;
      }
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(l.aboutLinkFailed)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.aboutPrivacyHeading, style: text.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _Point(Icons.phone_android, l.aboutPrivacyOnPhone),
                _Point(Icons.block, l.aboutPrivacyNoAccount),
                _Point(Icons.backup_outlined, l.aboutPrivacyBackup),
                _Point(Icons.photo_camera_outlined, l.aboutPrivacyPhotos),
                _Point(Icons.notifications_none, l.aboutPrivacyReminders),
                _Point(Icons.text_fields, l.aboutPrivacyGoogle),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            key: const ValueKey('about-medical'),
            color: Severity.headsUp.background,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.aboutMedicalHeading,
                    style: text.titleMedium?.copyWith(
                      color: Severity.headsUp.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.aboutMedicalBody, style: text.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('about-privacy-policy'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.aboutPrivacyPolicy),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => open(privacyPolicyUrl(language)),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('about-terms'),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l.aboutTerms),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => open(termsUrl(language)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              l.aboutVersion(ref.watch(appVersionProvider)),
              key: const ValueKey('about-version'),
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: UsraColors.primary),
    title: Text(text),
  );
}
