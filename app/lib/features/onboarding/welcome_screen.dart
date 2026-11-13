import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/buttons.dart';
import '../../core/design/dr_usra.dart';
import '../../core/design/pebble.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/design/usra_mark.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_notices.dart';
import '../settings/about_privacy_screen.dart';
import 'onboarding_module.dart';

/// The first thing anyone sees: the language, Dr. Usra, the promise, and two
/// ways in. Sign-in isn't here: it stays optional, in Account, and hidden
/// when this build has no sign-in set up.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final text = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final link = TextButton.styleFrom(
      minimumSize: const Size(UsraSizes.touchTarget, UsraSizes.touchTarget),
      foregroundColor: c.primary,
      textStyle: UsraType.label.copyWith(decoration: TextDecoration.underline),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 20),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _LanguagePill(
                        label: l.welcomeLanguageOther,
                        onTap: () => ref
                            .read(localeProvider.notifier)
                            .change(Locale(language == 'ar' ? 'en' : 'ar')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const BackupNotices(outcomesOnly: true),
                    Center(
                      child: _Art(
                        // Smaller on short screens or with very large text.
                        size: (box.maxHeight * 0.32)
                            .clamp(120.0, 260.0)
                            .toDouble(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // The brand moment: Dr. Usra's mark and the app's name.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: UsraMarkTitle(
                        l.appTitle,
                        key: const ValueKey('welcome-brand'),
                        markSize: UsraMark.hero,
                        style: UsraType.title.copyWith(color: c.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      child: Text(
                        l.welcomeHeadline,
                        key: const ValueKey('welcome-headline'),
                        style: text.headlineLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.welcomePrivacyLine,
                      style: UsraType.body.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    const Spacer(),
                    UsraPillButton(
                      key: const ValueKey('welcome-start'),
                      label: l.welcomeStart,
                      onPressed: () => context.go(welcomeCountryPath),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: const ValueKey('welcome-restore'),
                      onPressed: () => context.go(welcomeRestorePath),
                      child: Text(l.welcomeHaveBackup),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.welcomeDisclaimer,
                      key: const ValueKey('welcome-disclaimer'),
                      style: text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const ValueKey('welcome-privacy'),
                          style: link,
                          onPressed: () => openLink(
                            context,
                            ref,
                            privacyPolicyUrl(language),
                          ),
                          child: Text(l.welcomePrivacy),
                        ),
                        TextButton(
                          key: const ValueKey('welcome-terms'),
                          style: link,
                          onPressed: () =>
                              openLink(context, ref, termsUrl(language)),
                          child: Text(l.welcomeTerms),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dr. Usra's wave, on the one aura behind him.
class _Art extends StatelessWidget {
  const _Art({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: context.usra.primarySoft,
              shape: RoundedRectangleBorder(
                borderRadius: PebbleShape.fromSeed(7)
                    .radiiFor(Size.square(size)),
              ),
            ),
          ),
        ),
        DrUsra(size: size * 0.82),
      ],
    ),
  );
}

/// The other language, written in that language, so it can be found by
/// someone who can't read this one.
class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    return Material(
      color: c.surface,
      // A hairline, not a shadow, as on every card since the polish.
      shape: StadiumBorder(side: BorderSide(color: c.line)),
      child: InkWell(
        key: const ValueKey('welcome-language'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: UsraSizes.touchTarget,
            minWidth: UsraSizes.touchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: UsraType.label.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
