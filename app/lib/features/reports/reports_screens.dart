import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/preferences.dart' show simpleModeProvider;
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
import '../labs/lab_report.dart' show LabFields, LabReport;
import '../medicines/medicine_text.dart' show medicineEnded, medicineTitle;
import '../medicines/medicines_providers.dart' show medicinesProvider;
import 'doctor_summary.dart';
import 'report_share.dart';
import 'vaccination_record.dart';

/// The two languages a report can be made in, whatever the app's own.
const reportLanguages = ['ar', 'en'];

/// Arabic or English: a school abroad or a doctor who reads English may
/// need the other one.
class ReportLanguagePicker extends StatelessWidget {
  const ReportLanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SegmentedButton<String>(
      key: const ValueKey('report-language'),
      segments: [
        ButtonSegment(
          value: 'ar',
          label: Text(l.languageArabic, key: const ValueKey('report-lang-ar')),
        ),
        ButtonSegment(
          value: 'en',
          label: Text(l.languageEnglish, key: const ValueKey('report-lang-en')),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Where the share sheet points from on an iPad: the widget [context]
/// belongs to (the button tapped).
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
}

String _appLanguage(WidgetRef ref) {
  final code = ref.read(localeProvider).languageCode;
  return reportLanguages.contains(code) ? code : 'ar';
}

/// Asks for the language (and whether to add the family's notes), then
/// makes and shares [profileId]'s vaccination record (C4). In Simple Mode
/// it asks nothing: the app's language, no notes, straight to the share
/// warning.
Future<void> shareVaccinationRecord(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final origin = shareOriginOf(context);
  // Matched against the schedule from the birth date: say so up front
  // rather than after the share warning.
  final profile = ref.read(profileProvider(profileId)).value;
  if (profile != null && profile.birthDate == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).reportNeedsBirthDate),
      ),
    );
    return;
  }
  var language = _appLanguage(ref);
  var notes = false;
  final go =
      ref.read(simpleModeProvider) ||
      await showDialog<bool>(
            context: context,
            builder: (context) {
              final l = AppLocalizations.of(context);
              return StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  key: const ValueKey('vaccination-pdf-dialog'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l.reportVaccinationShare),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.reportVaccinationIntro),
                        const SizedBox(height: 16),
                        Text(l.reportLanguage),
                        const SizedBox(height: 8),
                        ReportLanguagePicker(
                          value: language,
                          onChanged: (v) => setState(() => language = v),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          key: const ValueKey('vaccination-pdf-notes'),
                          contentPadding: EdgeInsets.zero,
                          value: notes,
                          onChanged: (v) => setState(() => notes = v),
                          title: Text(l.reportIncludeNotes),
                        ),
                        Text(
                          l.reportOnPhone,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.usra.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l.familyCancel),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('vaccination-pdf-share'),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l.reportSharePdf),
                    ),
                  ],
                ),
              );
            },
          ) ==
          true;
  if (!go || !context.mounted) return;
  final db = ref.read(databaseProvider);
  final now = ref.read(todayProvider);
  await shareReportPdf(
    ref,
    fileName: vaccinationRecordFile,
    origin: origin,
    missing: AppLocalizations.of(context).reportNeedsBirthDate,
    build: () async {
      final inputs = await SummaryInputs.loadRecords(db, profileId);
      if (inputs == null) return null;
      return vaccinationRecord(
        l: lookupAppLocalizations(Locale(language)),
        profile: inputs.profile,
        events: inputs.events,
        now: now,
        includeNotes: notes,
      );
    },
  );
}

/// The summary at a glance: only what the family has recorded, under the
/// sections still ticked, and a line saying whose words these are.
class _SummaryPreview extends ConsumerWidget {
  const _SummaryPreview({
    required this.profile,
    required this.shown,
    required this.today,
  });

  final Profile profile;
  final Set<SummarySection> shown;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final all = ref.watch(medicinesProvider(profile.id)).value;
    final events = ref.watch(timelineProvider(profile.id)).value;
    return Card(
      key: const ValueKey('summary-preview'),
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Builder(
          builder: (context) {
            Widget row(String key, String label, String value) => Padding(
              key: ValueKey('summary-preview-$key'),
              padding: const EdgeInsets.only(bottom: UsraSpacing.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: UsraType.label.copyWith(color: c.inkMuted),
                  ),
                  Text(
                    value,
                    style: UsraType.body.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
            final medicines = [
              for (final m in all ?? const <Medicine>[])
                if (m.active && !medicineEnded(m, today)) medicineTitle(m),
            ];
            final lab = events
                ?.where((e) => e.type == LabFields.type)
                .firstOrNull;
            final labName = lab == null ? null : LabReport.of(lab).lab;
            final labDate = lab == null
                ? null
                : DateFormat.yMMMd(locale).format(lab.occurredAt);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (shown.contains(SummarySection.allergies))
                  if (profile.allergies case final v?)
                    row('allergies', l.profileAllergies, v),
                if (shown.contains(SummarySection.conditions))
                  if (profile.conditions case final v?)
                    row('conditions', l.profileConditions, v),
                if (shown.contains(SummarySection.medicines) &&
                    medicines.isNotEmpty)
                  row(
                    'medicines',
                    l.reportSectionMedicines,
                    medicines.join('\n'),
                  ),
                if (shown.contains(SummarySection.labs) && lab != null)
                  row(
                    'labs',
                    l.reportSectionLabs,
                    [?labName, labDate!].join(' · '),
                  ),
                Text(
                  l.reportSummaryNotOpinion,
                  key: const ValueKey('summary-not-opinion'),
                  style: UsraType.body.copyWith(color: c.ink),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Picks what goes in the summary for the doctor (C10) and its
/// language, then makes and shares it.
class DoctorSummaryScreen extends ConsumerStatefulWidget {
  const DoctorSummaryScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<DoctorSummaryScreen> createState() =>
      _DoctorSummaryScreenState();
}

class _DoctorSummaryScreenState extends ConsumerState<DoctorSummaryScreen> {
  late var _language = _appLanguage(ref);

  /// Unticked sections; everything starts ticked.
  final _off = <SummarySection>{};
  var _busy = false;

  String _label(AppLocalizations l, SummarySection s) => switch (s) {
    SummarySection.basics => l.reportSectionBasics,
    SummarySection.allergies => l.profileAllergies,
    SummarySection.conditions => l.profileConditions,
    SummarySection.medicines => l.reportSectionMedicines,
    SummarySection.visits => l.reportSectionVisits,
    SummarySection.labs => l.reportSectionLabs,
    SummarySection.growth => l.reportSectionGrowth,
    SummarySection.vaccines => l.reportSectionVaccines,
  };

  Future<void> _share(List<SummarySection> offered, Rect? origin) async {
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final now = ref.read(todayProvider);
    final chosen = {...offered};
    final language = ref.read(simpleModeProvider)
        ? _appLanguage(ref)
        : _language;
    try {
      await shareReportPdf(
        ref,
        fileName: doctorSummaryFile,
        origin: origin,
        build: () async {
          final inputs = await SummaryInputs.load(db, widget.profileId);
          if (inputs == null) return null;
          return doctorSummary(
            l: lookupAppLocalizations(Locale(language)),
            inputs: inputs,
            sections: chosen,
            now: now,
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final id = widget.profileId;
    final profile = ref.watch(profileProvider(id));
    final today = ref.watch(todayProvider);
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.usra.inkMuted);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.memberDoctorSummary),
        leading: BackButton(onPressed: () => context.go('/family/$id')),
      ),
      body: switch (profile) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncData(value: null) => Center(child: Text(l.profileNotFound)),
        AsyncValue(value: final p?) => Builder(
          builder: (context) {
            final offered = summarySectionsFor(p, today);
            // Simple Mode: everything in, in the app's language, one button.
            final simple = ref.watch(simpleModeProvider);
            final none = !simple && offered.every(_off.contains);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  p.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(simple ? l.reportSimpleIntro : l.reportSummaryIntro),
                const SizedBox(height: 16),
                _SummaryPreview(
                  profile: p,
                  shown: {
                    for (final s in offered)
                      if (simple || !_off.contains(s)) s,
                  },
                  today: today,
                ),
                const SizedBox(height: 16),
                if (!simple) ...[
                  Text(
                    l.reportChooseSections,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final s in offered)
                    CheckboxListTile(
                      key: ValueKey('summary-section-${s.name}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: !_off.contains(s),
                      onChanged: (v) => setState(
                        () => v == true ? _off.remove(s) : _off.add(s),
                      ),
                      title: Text(_label(l, s)),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    l.reportLanguage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ReportLanguagePicker(
                    value: _language,
                    onChanged: (v) => setState(() => _language = v),
                  ),
                ],
                const SizedBox(height: 20),
                if (none) ...[
                  Text(l.reportPickOne, style: muted),
                  const SizedBox(height: 8),
                ],
                Builder(
                  builder: (button) => FilledButton.icon(
                    key: const ValueKey('summary-share'),
                    onPressed: none || _busy
                        ? null
                        : () => _share(
                            simple
                                ? offered
                                : [
                                    for (final s in offered)
                                      if (!_off.contains(s)) s,
                                  ],
                            shareOriginOf(button),
                          ),
                    // Disabled while busy, but no spinner: the share warning
                    // comes up first, and a spinner behind it reads as stuck.
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l.reportSharePdf),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.reportOnPhone, style: muted),
                if (offered.contains(SummarySection.vaccines)) ...[
                  const SizedBox(height: 24),
                  Builder(
                    builder: (button) => OutlinedButton.icon(
                      key: const ValueKey('summary-vaccination-record'),
                      onPressed: () => shareVaccinationRecord(button, ref, id),
                      icon: const Icon(Icons.vaccines_outlined),
                      label: Text(l.reportVaccinationShare),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
