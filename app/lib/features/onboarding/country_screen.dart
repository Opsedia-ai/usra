import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/buttons.dart';
import '../../core/log.dart';
import '../../core/preferences.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_chrome.dart';
import 'onboarding_module.dart';

/// Only Egypt can be chosen today. The vaccine schedule, the ambulance number
/// on every screen, and the warning wording are all Egypt's, so offering
/// another country would dial the wrong number in an emergency.
class CountryScreen extends ConsumerWidget {
  const CountryScreen({super.key});

  Future<void> _next(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(keyValueStoreProvider).setString(PrefKeys.country, 'EG');
    } catch (e) {
      // Egypt is what a missing value means anyway.
      Log.error('Country save failed', e);
    }
    if (context.mounted) await context.push(welcomeAboutPath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return OnboardingPage(
      step: 1,
      title: l.countryTitle,
      hint: l.countryHint,
      button: UsraPillButton(
        key: const ValueKey('country-next'),
        label: l.tutorialNext,
        onPressed: () => _next(context, ref),
      ),
      children: [
        ChoiceCard(
          key: const ValueKey('country-egypt'),
          title: l.countryEgypt,
          detail: l.countryEgyptDetail,
          selected: true,
          onTap: () {},
        ),
        const SizedBox(height: 10),
        ChoiceCard(
          key: const ValueKey('country-saudi'),
          title: l.countrySaudi,
          detail: l.countrySoon,
          selected: false,
          onTap: null,
        ),
        const SizedBox(height: 10),
        ChoiceCard(
          key: const ValueKey('country-jordan'),
          title: l.countryJordan,
          detail: l.countrySoon,
          selected: false,
          onTap: null,
        ),
      ],
    );
  }
}
