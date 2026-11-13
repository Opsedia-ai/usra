import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/consent.dart';
import '../../core/design/buttons.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/log.dart';
import '../../core/preferences.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../medicines/medicines_providers.dart' show clockProvider;
import '../settings/about_privacy_screen.dart';

/// Explicit consent (Egypt PDPL 151/2020: health data is sensitive), asked
/// before any health data is saved: after Welcome, before the country, About
/// you or a restore, and again whenever [consentPolicyVersion] changes.
/// Nothing goes on until the box is ticked and "I agree" is pressed; the
/// version and the time are then saved on the phone.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, this.next});

  /// Where to go once agreed: the page that was asked for.
  final String? next;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _ticked = false;
  bool _saving = false;
  bool _failed = false;

  /// Only a page inside the app, never a link elsewhere.
  String get _next {
    final next = widget.next;
    final firstRun = ref.read(onboardingProvider);
    if (next == null ||
        !next.startsWith('/') ||
        next.startsWith('//') ||
        next.startsWith(consentPath)) {
      return firstRun ? welcomePath : '/home';
    }
    return next;
  }

  Future<void> _agree() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref
          .read(consentNeededProvider.notifier)
          .agree(ref.read(clockProvider)());
    } catch (e) {
      Log.error('Consent save failed', e);
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
      return;
    }
    if (mounted) context.go(_next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final text = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final firstRun = ref.watch(onboardingProvider);
    final updated =
        ref.read(consentNeededProvider.notifier).previousVersion != null;
    final link = TextButton.styleFrom(
      minimumSize: const Size(UsraSizes.touchTarget, UsraSizes.touchTarget),
      foregroundColor: c.primary,
      textStyle: UsraType.label.copyWith(decoration: TextDecoration.underline),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (firstRun)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: UsraRoundIconButton(
                          key: const ValueKey('consent-back'),
                          icon: Icons.arrow_back,
                          semanticLabel: l.onboardingBack,
                          onPressed: () => context.go(welcomePath),
                        ),
                      ),
                    const SizedBox(height: UsraSpacing.s5),
                    Semantics(
                      header: true,
                      child: Text(
                        l.consentTitle,
                        key: const ValueKey('consent-title'),
                        style: text.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: UsraSpacing.s1),
                    Text(
                      updated && !firstRun ? l.consentUpdated : l.consentHint,
                      key: const ValueKey('consent-hint'),
                      style: text.bodyLarge?.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: UsraSpacing.s5),
                    UsraListCard(
                      children: [
                        UsraListRow(
                          key: const ValueKey('consent-point-local'),
                          icon: Icons.lock_outline,
                          title: l.consentPointLocal,
                        ),
                        UsraListRow(
                          key: const ValueKey('consent-point-guardian'),
                          icon: Icons.family_restroom_outlined,
                          title: l.consentPointGuardian,
                        ),
                        UsraListRow(
                          key: const ValueKey('consent-point-doctor'),
                          icon: Icons.medical_services_outlined,
                          title: l.consentPointDoctor,
                        ),
                      ],
                    ),
                    const SizedBox(height: UsraSpacing.s3),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const ValueKey('consent-privacy'),
                          style: link,
                          onPressed: () => openLink(
                            context,
                            ref,
                            privacyPolicyUrl(language),
                          ),
                          child: Text(l.consentPrivacyLink),
                        ),
                        TextButton(
                          key: const ValueKey('consent-terms'),
                          style: link,
                          onPressed: () =>
                              openLink(context, ref, termsUrl(language)),
                          child: Text(l.consentTermsLink),
                        ),
                      ],
                    ),
                    Text(
                      l.consentVersion(
                        localizedDigitsIn(context, consentPolicyVersion),
                      ),
                      key: const ValueKey('consent-version'),
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: UsraSpacing.s4),
                    Card(
                      child: CheckboxListTile(
                        key: const ValueKey('consent-tick'),
                        value: _ticked,
                        controlAffinity: ListTileControlAffinity.leading,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(UsraRadius.card),
                          ),
                        ),
                        title: Text(
                          l.consentCheckbox,
                          style: UsraType.body.copyWith(color: c.ink),
                        ),
                        onChanged: (v) => setState(() => _ticked = v ?? false),
                      ),
                    ),
                    if (_failed) ...[
                      const SizedBox(height: UsraSpacing.s3),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l.consentSaveFailed,
                          key: const ValueKey('consent-failed'),
                          style: UsraType.body.copyWith(color: c.ink),
                        ),
                      ),
                    ],
                    if (!firstRun) ...[
                      const SizedBox(height: UsraSpacing.s3),
                      Center(
                        child: TextButton(
                          key: const ValueKey('consent-delete'),
                          style: link,
                          onPressed: () => context.go(consentDeletePath),
                          child: Text(l.consentDecline),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: UsraPillButton(
                key: const ValueKey('consent-agree'),
                label: l.consentAgree,
                onPressed: _ticked && !_saving ? _agree : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
