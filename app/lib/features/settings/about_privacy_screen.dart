import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/list_row.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_providers.dart';
import '../account/account_providers.dart';
import 'delete_data_screen.dart';

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

/// Opens [uri] in the browser, with a message if it can't.
Future<void> openLink(BuildContext context, WidgetRef ref, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).aboutLinkFailed;
  var ok = false;
  try {
    ok = await ref.read(openLinkProvider)(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

/// What happens to the family's data, the medical disclaimer, the version,
/// and links to the full policy and terms.
class AboutPrivacyScreen extends ConsumerWidget {
  const AboutPrivacyScreen({super.key, this.canDelete = true});

  /// Left out where leaving for another page would lose a waiting form.
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;

    Future<void> open(Uri uri) => openLink(context, ref, uri);

    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            key: const ValueKey('privacy-answers'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (question, answer)) in [
                    (l.privacyEncryptedQ, l.privacyEncryptedA),
                    (
                      l.privacyCanSeeQ,
                      ref.watch(supabaseConfigProvider).isConfigured
                          ? '${l.privacyCanSeeA} ${l.accountKeeps}'
                          : l.privacyCanSeeA,
                    ),
                    (l.privacyBackupQ, l.privacyBackupA),
                    (l.privacyPinQ, l.privacyPinA),
                    (l.privacyDeleteQ, l.privacyDeleteA),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(height: 16),
                    Text(
                      question,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(answer, style: text.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l.aboutPrivacyHeading, style: text.titleMedium),
          const SizedBox(height: 8),
          UsraListCard(
            children: [
              _Point(Icons.phone_android, l.aboutPrivacyOnPhone),
              _Point(
                Icons.block,
                ref.watch(supabaseConfigProvider).isConfigured
                    ? l.aboutPrivacyOptionalAccount
                    : l.aboutPrivacyNoAccount,
              ),
              _Point(Icons.backup_outlined, l.aboutPrivacyBackup),
              _Point(Icons.schedule, l.aboutPrivacyBackupAuto),
              _Point(Icons.photo_camera_outlined, l.aboutPrivacyPhotos),
              _Point(Icons.notifications_none, l.aboutPrivacyReminders),
              _Point(Icons.text_fields, l.aboutPrivacyGoogle),
              _Point(Icons.delete_forever_outlined, l.aboutPrivacyDelete),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            key: const ValueKey('about-medical'),
            child: Padding(
              padding: const EdgeInsets.all(UsraSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusDotText(
                    label: l.aboutMedicalHeading,
                    color: context.usra.ink,
                    style: UsraType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: UsraSpacing.s2),
                  Text(l.aboutMedicalBody, style: text.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          UsraListCard(
            children: [
              UsraListRow(
                key: const ValueKey('about-privacy-policy'),
                icon: Icons.privacy_tip_outlined,
                title: l.aboutPrivacyPolicy,
                trailing: ExcludeSemantics(
                  child: Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: context.usra.inkMuted,
                  ),
                ),
                onTap: () => open(privacyPolicyUrl(language)),
              ),
              UsraListRow(
                key: const ValueKey('about-terms'),
                icon: Icons.description_outlined,
                title: l.aboutTerms,
                trailing: ExcludeSemantics(
                  child: Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: context.usra.inkMuted,
                  ),
                ),
                onTap: () => open(termsUrl(language)),
              ),
            ],
          ),
          if (canDelete) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('privacy-delete-all'),
              onPressed: () => context.go(deleteDataPath),
              child: Text(l.settingsDeleteAll),
            ),
          ],
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
  Widget build(BuildContext context) => UsraListRow(icon: icon, title: text);
}
