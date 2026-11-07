import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/buttons.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_chrome.dart';

/// Name and sex, which make the first family member and remember them as
/// "me". The wording here stays neutral: the app doesn't know how to address
/// this person until they answer.
class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key});

  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> {
  final _name = TextEditingController();
  String? _sex;
  bool _nameMissing = false;
  bool _sexMissing = false;
  bool _saving = false;

  /// Made on an earlier try that then failed: a retry mustn't make another.
  String? _madeId;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// If the app stopped between saving this profile and finishing, it's
  /// shown again rather than making a second "me".
  Future<void> _prefill() async {
    final id = ref.read(meProfileIdProvider);
    if (id == null) return;
    final me = await ref.read(databaseProvider).watchProfile(id).first;
    if (me == null || !mounted) return;
    setState(() {
      _name.text = me.displayName;
      _sex = me.sex;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final name = _name.text.trim();
    final sex = _sex;
    setState(() {
      _nameMissing = name.isEmpty;
      _sexMissing = sex == null;
    });
    if (name.isEmpty || sex == null) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final me = ref.read(meProfileIdProvider.notifier);
    final onboarding = ref.read(onboardingProvider.notifier);
    try {
      final id = _madeId ?? ref.read(meProfileIdProvider);
      final existing = id == null ? null : await db.watchProfile(id).first;
      if (existing == null) {
        _madeId = await db.addProfile(name, sex: sex);
      } else {
        // Saving replaces the whole profile: everything else stays as it is.
        await db.updateProfile(
          existing.id,
          displayName: name,
          sex: sex,
          birthDate: existing.birthDate,
          bloodType: existing.bloodType,
          allergies: existing.allergies,
          conditions: existing.conditions,
        );
        _madeId = existing.id;
      }
      await me.set(_madeId!);
      await onboarding.finish();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
      return;
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return OnboardingPage(
      step: 2,
      title: l.aboutYouTitle,
      hint: l.aboutYouHint,
      button: UsraPillButton(
        key: const ValueKey('about-done'),
        label: l.aboutYouDone,
        onPressed: _saving ? null : _done,
      ),
      children: [
        TextField(
          key: const ValueKey('about-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l.familyNameLabel,
            errorText: _nameMissing ? l.fieldRequired : null,
          ),
        ),
        const SizedBox(height: 20),
        Text(l.aboutYouSex, style: text.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (i, (value, label)) in [
              ('male', l.sexMale),
              ('female', l.sexFemale),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: ChoiceCard(
                  key: ValueKey('about-sex-$value'),
                  title: label,
                  selected: _sex == value,
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() {
                      _sex = value;
                      _sexMissing = false;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (_sexMissing)
          Text(
            l.fieldRequired,
            key: const ValueKey('about-sex-missing'),
            style: text.bodySmall?.copyWith(color: c.error),
          ),
        Text(l.aboutYouSexHint, style: text.bodySmall),
      ],
    );
  }
}
