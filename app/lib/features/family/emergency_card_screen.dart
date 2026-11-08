import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../core/database/app_database.dart';
import '../../core/design/buttons.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import '../../core/security/app_lock.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../app_lock/app_lock_module.dart' show confirmEmergencyOnLock;
import '../doctors/contact_links.dart' show callUri;
import '../doctors/call_buttons.dart';
import '../medicines/medicine_text.dart';
import '../medicines/medicines_providers.dart';
import 'family_screen.dart';
import 'member_screen.dart';
import 'person_status.dart';

/// Ambulance number shown on the emergency card. Egypt first; the app is
/// Egypt-only until the UAE and KSA launches.
const ambulanceNumber = '123';

/// Whether the card shows in the language other than the app's. Kept across
/// the person chips, so a paramedic switching people doesn't lose it, and
/// forgotten once the card is closed.
final _otherLanguageProvider =
    NotifierProvider.autoDispose<_OtherLanguage, bool>(_OtherLanguage.new);

class _OtherLanguage extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// The call first, then what a paramedic or ER nurse needs: allergies, blood
/// type, conditions, current medicines and past surgeries, as the family
/// recorded them.
class EmergencyCardScreen extends ConsumerWidget {
  const EmergencyCardScreen({
    super.key,
    required this.profileId,
    this.editable = true,
  });

  final String profileId;

  /// False when opened from Usra's lock screen: nothing there leads further
  /// into the app.
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    // Held here too, as the card isn't built while the next person loads.
    ref.watch(_otherLanguageProvider);
    return Scaffold(
      backgroundColor: context.usra.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _TitleRow(),
            const SizedBox(height: UsraSpacing.s3),
            const _AmbulanceButton(),
            const SizedBox(height: UsraSpacing.s3),
            // Never a choice on the lock screen, which lists its own people.
            if (editable && people.length > 1) ...[
              Semantics(
                label: l.emergencyPickPerson,
                container: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final other in people)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: _PersonChip(
                            person: other,
                            selected: other.id == profileId,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UsraSpacing.s3),
            ],
            // Under the people, so it's clear whose it is and they don't move
            // as it comes and goes.
            if (profile.value case final p?) ...[
              if (callUri(p.emergencyPhone) case final call?) ...[
                _EmergencyContact(person: p, call: call),
                const SizedBox(height: UsraSpacing.s3),
              ],
            ],
            ...profile.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Center(child: Text('$e'))],
              data: (p) => p == null
                  ? [Center(child: Text(l.profileNotFound))]
                  : [
                      _CardBody(profile: p),
                      if (editable &&
                          (p.bloodType == null || p.allergies == null)) ...[
                        const SizedBox(height: UsraSpacing.s1),
                        TextButton.icon(
                          key: const ValueKey('emergency-complete'),
                          onPressed: () =>
                              context.go('/family/$profileId/edit'),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l.emergencyComplete),
                        ),
                      ],
                      if (editable) ...[
                        const SizedBox(height: UsraSpacing.s3),
                        _LockControls(profile: p),
                      ],
                    ],
            ),
            const SizedBox(height: UsraSpacing.s4),
            Text(
              l.notMedicalDevice,
              style: UsraType.label.copyWith(color: context.usra.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow();

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Row(
      spacing: UsraSpacing.s3,
      children: [
        if (navigator.canPop())
          UsraRoundIconButton(
            key: const ValueKey('emergency-back'),
            icon: Icons.arrow_back,
            semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => navigator.maybePop(),
          ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              AppLocalizations.of(context).emergencyTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.person, required this.selected});

  final Profile person;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    return ChoiceChip(
      key: ValueKey('emergency-person-${person.id}'),
      label: Text(person.displayName),
      selected: selected,
      showCheckmark: false,
      labelStyle: UsraType.body.copyWith(
        color: selected ? c.onPrimary : c.ink,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 5),
      backgroundColor: c.surface,
      selectedColor: c.primary,
      side: selected ? BorderSide.none : BorderSide(color: c.lineStrong),
      shape: const StadiumBorder(),
      onSelected: (_) => context.replace('/family/${person.id}/emergency'),
    );
  }
}

/// One tap: the phone's own dialer asks before calling.
class _AmbulanceButton extends StatelessWidget {
  const _AmbulanceButton();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: c.shadowFloat,
      ),
      child: FilledButton.icon(
        key: const ValueKey('emergency-ambulance'),
        style: FilledButton.styleFrom(
          backgroundColor: c.urgent,
          foregroundColor: c.onUrgent,
          minimumSize: const Size.fromHeight(72),
          textStyle: UsraType.heading.copyWith(fontSize: 22),
        ),
        onPressed: () =>
            openContact(context, Uri(scheme: 'tel', path: ambulanceNumber)),
        icon: const Icon(Icons.call, size: 28),
        label: Text(
          l.emergencyAmbulanceShort(
            localizedDigits(context, int.parse(ambulanceNumber)),
          ),
          semanticsLabel: l.emergencyCallAmbulance(ambulanceNumber),
        ),
      ),
    );
  }
}

/// The number to call for this person, and whose it is. The phone's own dialer
/// asks before calling. Reachable from the lock screen too: finding someone to
/// call is what the card is for there. Follows the card's language.
class _EmergencyContact extends ConsumerWidget {
  const _EmergencyContact({required this.person, required this.call});

  final Profile person;
  final Uri call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = ref.watch(_otherLanguageProvider);
    final appLanguage = Localizations.localeOf(context).languageCode;
    final l = lookupAppLocalizations(
      Locale(
        !other
            ? appLanguage
            : appLanguage == 'ar'
            ? 'en'
            : 'ar',
      ),
    );
    final c = context.usra;
    final phone = person.emergencyPhone!;
    final holder = person.emergencyContactName;
    final name = holder ?? l.emergencyContactNoName;
    const shape = StadiumBorder();
    final nameText = Text(
      name,
      style: UsraType.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
    );
    final phoneText = Text(
      phone,
      key: const ValueKey('emergency-contact-phone'),
      textDirection: TextDirection.ltr,
      style: UsraType.body.copyWith(color: c.ink),
    );
    // A number must never break across lines, so with big text it gets its own.
    final stacked = MediaQuery.textScalerOf(context).scale(100) >= 130;
    void dial() => openContact(context, call);
    return Semantics(
      button: true,
      label: holder == null
          ? l.emergencyCallNumber(phone)
          : l.emergencyCallContact(holder, phone),
      onTap: dial,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: shape,
        elevation: 1,
        shadowColor: c.ink.withValues(alpha: 0.2),
        child: InkWell(
          key: const ValueKey('emergency-contact'),
          customBorder: shape,
          onTap: dial,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.goodSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.call, color: c.good, size: 22),
                  ),
                  if (stacked)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [nameText, phoneText],
                      ),
                    )
                  else ...[
                    Expanded(child: nameText),
                    phoneText,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card itself, in the app's language or the other one. Only the labels
/// change: what the family typed stays as they typed it, and the card says so.
class _CardBody extends ConsumerWidget {
  const _CardBody({required this.profile});

  final Profile profile;

  /// "Appendix removal · 2019", from the surgery record's procedure field.
  static String _surgeryLine(MedicalEvent e, String language) {
    return [
      ?decodeRecordData(e.dataJson)['procedure']?.toString(),
      digitsIn(language, '${e.occurredAt.year}'),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = ref.watch(_otherLanguageProvider);
    final appLanguage = Localizations.localeOf(context).languageCode;
    final language = !other
        ? appLanguage
        : appLanguage == 'ar'
        ? 'en'
        : 'ar';
    final l = lookupAppLocalizations(Locale(language));
    final c = context.usra;
    final now = ref.watch(clockProvider)();

    final timeline = ref.watch(timelineProvider(profile.id));
    final surgeries = [
      for (final e in timeline.value ?? const <MedicalEvent>[])
        if (e.type == 'surgery') _surgeryLine(e, language),
    ];
    final medicines = ref.watch(medicinesProvider(profile.id));
    final current = [
      for (final m in medicines.value ?? const <Medicine>[])
        if (m.active && !medicineEnded(m, now)) medicineTitle(m),
    ];
    // Never claim "nothing" before the records have loaded.
    String empty(AsyncValue<Object?> v) => switch (v) {
      AsyncData() => l.emergencyNoneRecorded,
      AsyncError() => l.emergencyLoadFailed,
      _ => l.emergencyLoading,
    };

    final details = [
      ?ageLabel(l, profile.birthDate, now),
      if (profile.sex == 'female') l.sexFemale,
      if (profile.sex == 'male') l.sexMale,
    ].join(' · ');
    final allergy = _Fact(
      key: const ValueKey('emergency-allergies'),
      label: l.profileAllergies,
      lines: [?profile.allergies],
      emptyText: l.emergencyNoneRecorded,
      color: c.urgent,
      fill: profile.allergies == null ? c.surfaceSoft : c.urgentSoft,
      big: true,
    );
    final blood = _Fact(
      key: const ValueKey('emergency-blood'),
      label: l.profileBloodType,
      lines: [?profile.bloodType],
      emptyText: l.emergencyUnknown,
      fill: c.surfaceSoft,
      big: true,
    );

    return Directionality(
      textDirection: Bidi.isRtlLanguage(language)
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Card(
        key: const ValueKey('emergency-card'),
        child: Padding(
          padding: const EdgeInsets.all(UsraSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: UsraSpacing.s3,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: UsraSpacing.s2,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          key: const ValueKey('emergency-name'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            key: const ValueKey('emergency-details'),
                            style: UsraType.body.copyWith(color: c.inkMuted),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('emergency-language'),
                    onPressed: () =>
                        ref.read(_otherLanguageProvider.notifier).toggle(),
                    child: Text(l.emergencyOtherLanguage),
                  ),
                ],
              ),
              if (MediaQuery.textScalerOf(context).scale(100) >= 130) ...[
                allergy,
                blood,
              ] else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: UsraSpacing.s2,
                    children: [
                      Expanded(child: allergy),
                      Expanded(child: blood),
                    ],
                  ),
                ),
              _Fact(
                key: const ValueKey('emergency-conditions'),
                label: l.profileConditions,
                lines: [?profile.conditions],
                emptyText: l.emergencyNoneRecorded,
              ),
              _Fact(
                key: const ValueKey('emergency-medicines'),
                label: l.emergencyMedicines,
                lines: current,
                emptyText: empty(medicines),
              ),
              _Fact(
                key: const ValueKey('emergency-surgeries'),
                label: l.emergencySurgeries,
                lines: surgeries,
                emptyText: empty(timeline),
              ),
              Text(
                l.emergencyAsTyped,
                key: const ValueKey('emergency-as-typed'),
                style: UsraType.label.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled fact. Missing facts are shown, not hidden, so a reader knows
/// they were not recorded rather than absent. Each line reads in its own
/// direction, so "Concor 5 mg" stays whole on an Arabic card.
class _Fact extends StatelessWidget {
  const _Fact({
    super.key,
    required this.label,
    required this.lines,
    required this.emptyText,
    this.color,
    this.fill,
    this.big = false,
  });

  final String label;
  final List<String> lines;
  final String emptyText;
  final Color? color;
  final Color? fill;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final strong = color ?? c.ink;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: UsraType.label.copyWith(
            color: fill == null ? c.inkMuted : c.ink,
          ),
        ),
        if (lines.isEmpty)
          Text(emptyText, style: UsraType.body.copyWith(color: c.inkMuted))
        else
          for (final line in lines)
            Text(
              line,
              textDirection: Bidi.detectRtlDirectionality(line)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              style: UsraType.body.copyWith(
                color: strong,
                fontSize: big ? 20 : 17,
                height: big ? 28 / 20 : 26 / 17,
                fontWeight: big ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
      ],
    );
    if (fill == null) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(UsraRadius.md),
      ),
      child: content,
    );
  }
}

/// Whether this card opens from Usra's own lock screen, and where a card that
/// must open on a locked phone really belongs.
class _LockControls extends ConsumerWidget {
  const _LockControls({required this.profile});

  final Profile profile;

  Future<void> _set(BuildContext context, AppLock lock, bool on) async {
    final failed = AppLocalizations.of(context).saveFailed;
    final messenger = ScaffoldMessenger.of(context);
    if (on && !await confirmEmergencyOnLock(context, profile.displayName)) {
      return;
    }
    try {
      await lock.setEmergencyProfile(profile.id, on);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final lock = ref.watch(appLockProvider);
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: UsraSpacing.s2,
        children: [
          // Without the app lock the card opens anyway; there's nothing to
          // choose.
          if (lock.enabled)
            SwitchListTile(
              key: const ValueKey('emergency-lock-switch'),
              contentPadding: EdgeInsets.zero,
              value: lock.emergencyProfiles.contains(profile.id),
              onChanged: (on) => _set(context, lock, on),
              title: Text(
                l.emergencyLockTitle,
                style: UsraType.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                l.emergencyLockHint,
                style: UsraType.label.copyWith(color: c.inkMuted),
              ),
            ),
          Text(
            l.emergencyMedicalIdHint,
            key: const ValueKey('emergency-medical-id'),
            style: UsraType.label.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}
