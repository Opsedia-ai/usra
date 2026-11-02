import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/records/record_type.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../insurance/insurance_section.dart';
import 'family_screen.dart';

final profileProvider = StreamProvider.family<Profile?, String>(
  (ref, id) => ref.watch(databaseProvider).watchProfile(id),
);

final timelineProvider = StreamProvider.family<List<MedicalEvent>, String>(
  (ref, id) => ref.watch(databaseProvider).watchTimeline(id),
);

/// One person: their health details and every record, newest first.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final timeline = ref.watch(timelineProvider(profileId));
    final types = ref.watch(moduleRegistryProvider).recordTypes;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.value?.displayName ?? ''),
        actions: [
          IconButton(
            key: const ValueKey('open-emergency'),
            tooltip: l.emergencyTitle,
            color: UsraColors.emergency,
            icon: const Icon(Icons.emergency_outlined),
            onPressed: () => context.go('/family/$profileId/emergency'),
          ),
          IconButton(
            tooltip: l.familyEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/family/$profileId/edit'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-record'),
        onPressed: () => _chooseType(context, types),
        icon: const Icon(Icons.add),
        label: Text(l.addRecord),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          if (p == null) return Center(child: Text(l.profileNotFound));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              _Header(profile: p),
              const SizedBox(height: 12),
              // No spending charts in Simple Mode.
              if (!ref.watch(simpleModeProvider))
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const ValueKey('member-spending'),
                    onPressed: () => context.go('/money?person=$profileId'),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(l.memberSpending),
                  ),
                ),
              const SizedBox(height: 20),
              InsuranceSection(profileId: profileId),
              const SizedBox(height: 28),
              ...timeline.when(
                loading: () => [
                  const Center(child: CircularProgressIndicator()),
                ],
                error: (e, _) => [Text('$e')],
                data: (events) => events.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            l.timelineEmpty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ]
                    : [
                        for (final e in events) ...[
                          _EventCard(event: e, type: types[e.type]),
                          const SizedBox(height: 10),
                        ],
                      ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _chooseType(BuildContext context, RecordTypeRegistry types) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l.chooseRecordType,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final t in types.all)
              ListTile(
                key: ValueKey('type-${t.key}'),
                leading: Icon(t.icon, color: UsraColors.primary),
                title: Text(t.labelOf(context)),
                onTap: () {
                  Navigator.pop(sheet);
                  context.go('/family/$profileId/add/${t.key}');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final age = ageInYears(profile.birthDate);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: UsraColors.primaryTint,
          foregroundColor: UsraColors.primary,
          child: Text(
            initialOf(profile.displayName),
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (age != null)
                SeverityChip(severity: Severity.info, label: l.ageYears(age)),
              if (profile.bloodType != null)
                SeverityChip(
                  severity: Severity.info,
                  label: '${l.profileBloodType}: ${profile.bloodType}',
                ),
              if (profile.allergies != null)
                SeverityChip(
                  severity: Severity.urgent,
                  label: '${l.profileAllergies}: ${profile.allergies}',
                ),
              if (profile.conditions != null)
                SeverityChip(
                  severity: Severity.info,
                  label: profile.conditions!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.type});

  final MedicalEvent event;
  final RecordTypeDefinition? type;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final data = _decode(event.dataJson);
    final titleField = type?.titleField;
    final title = titleField == null ? null : data[titleField.key];
    final currency = event.currency;
    final money = event.costMinor == null
        ? null
        : formatMoney(
            event.costMinor!,
            locale: locale,
            currency: currency == null || currency == 'EGP'
                ? AppLocalizations.of(context).currencyEgp
                : currency,
          );

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: UsraColors.primaryTint,
          child: Icon(
            type?.icon ?? Icons.description_outlined,
            color: UsraColors.primary,
          ),
        ),
        title: Text(
          [
            type?.labelOf(context) ?? event.type,
            if (title != null) _display(context, titleField!, title),
          ].join(' · '),
        ),
        subtitle: Text(
          [
            DateFormat.yMMMd(locale).format(event.occurredAt),
            ?money,
          ].join(' · '),
        ),
      ),
    );
  }

  static String _display(BuildContext context, FieldSpec field, Object value) =>
      field.kind == FieldKind.choice
      ? field.choiceLabelOf(context, '$value')
      : '$value';

  static Map<String, Object?> _decode(String json) {
    try {
      final v = jsonDecode(json);
      return v is Map<String, Object?> ? v : const {};
    } catch (_) {
      return const {};
    }
  }
}
