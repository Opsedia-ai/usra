import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../medicines/medicines_providers.dart';
import 'fever.dart';
import '../medicines/min_hours.dart';
import '../../core/util/time_picker.dart';
import '../../core/util/date_picker.dart';

/// A date and time row that opens the pickers.
class _WhenField extends StatelessWidget {
  const _WhenField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.now,
    this.first,
    this.keyPrefix = 'when',
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime now;
  final DateTime? first;
  final String keyPrefix;

  /// Never later than now: a time in the future would move the chart and
  /// the next-dose time.
  void _set(DateTime v) => onChanged(v.isAfter(now) ? now : v);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: ValueKey('$keyPrefix-date'),
                onPressed: () async {
                  final d = await pickDate(
                    context,
                    initialDate: value,
                    firstDate: first ?? DateTime(now.year - 1),
                    lastDate: now,
                    helpText: l.readingDate,
                  );
                  if (d != null) {
                    _set(
                      DateTime(
                        d.year,
                        d.month,
                        d.day,
                        value.hour,
                        value.minute,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat.MMMd(locale).format(value)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: ValueKey('$keyPrefix-time'),
                onPressed: () async {
                  final t = await pickTime(
                    context,
                    initialTime: TimeOfDay.fromDateTime(value),
                    helpText: l.readingTime,
                  );
                  if (t != null) {
                    _set(
                      DateTime(
                        value.year,
                        value.month,
                        value.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.schedule),
                label: Text(DateFormat.jm(locale).format(value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Adds a temperature reading to [episode].
Future<void> showReadingSheet(
  BuildContext context, {
  required SickEpisode episode,
  TemperatureReading? last,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ReadingSheet(episode: episode, last: last),
);

class _ReadingSheet extends ConsumerStatefulWidget {
  const _ReadingSheet({required this.episode, this.last});

  final SickEpisode episode;
  final TemperatureReading? last;

  @override
  ConsumerState<_ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends ConsumerState<_ReadingSheet> {
  final _value = TextEditingController();
  late String _unit = widget.last?.unit ?? TemperatureUnit.celsius;
  late String? _site = widget.last?.site;
  late DateTime _at = ref.read(clockProvider)();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final typed = parseDecimal(_value.text);
    if (typed == null || !isPlausible(typed, _unit)) {
      setState(() => _error = l.readingImplausible);
      return;
    }
    final v = roundReading(typed);
    if (needsConfirm(v, _unit) && !await _confirm(v)) return;
    if (!mounted) return;
    setState(() => _saving = true);
    if (!await ref.read(saveGateProvider).allow()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    await ref
        .read(databaseProvider)
        .saveReading(
          episodeId: widget.episode.id,
          takenAt: _at,
          value: v,
          unit: _unit,
          site: _site,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirm(double v) async {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = _unit == TemperatureUnit.fahrenheit
        ? l.readingFahrenheit
        : l.readingCelsius;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.readingConfirmTitle),
        content: Text(
          l.readingConfirmBody(
            '${NumberFormat('0.0', locale).format(v)} $unit',
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('reading-confirm-no'),
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.readingConfirmNo),
          ),
          FilledButton(
            key: const ValueKey('reading-confirm-yes'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.readingConfirmYes),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = ref.read(clockProvider)();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.sickDayAddReading,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('reading-value'),
                    controller: _value,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                    decoration: InputDecoration(
                      labelText: l.readingValue,
                      errorText: _error,
                      errorMaxLines: 3,
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  key: const ValueKey('reading-unit'),
                  // Ink on the selected unit: primary on its soft fill was
                  // too faint in dark mode.
                  style: SegmentedButton.styleFrom(
                    selectedForegroundColor: context.usra.ink,
                  ),
                  segments: [
                    ButtonSegment(
                      value: TemperatureUnit.celsius,
                      label: Text(l.readingCelsius),
                    ),
                    ButtonSegment(
                      value: TemperatureUnit.fahrenheit,
                      label: Text(l.readingFahrenheit),
                    ),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (s) => setState(() => _unit = s.single),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.readingSite, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in TemperatureSite.all)
                  UsraPill(
                    key: ValueKey('reading-site-$s'),
                    label: l.readingSiteName(s),
                    selected: _site == s,
                    // Tapping the chosen one again clears it, as before.
                    onTap: () => setState(() => _site = _site == s ? null : s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _WhenField(
              label: l.readingTime,
              value: _at,
              now: now,
              first: widget.episode.startedAt.toLocal().subtract(
                const Duration(days: 1),
              ),
              keyPrefix: 'reading',
              onChanged: (v) => setState(() => _at = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('reading-save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _saving ? null : _save,
              child: Text(l.familySave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logs a medicine given in [episode].
Future<void> showGivenSheet(
  BuildContext context, {
  required SickEpisode episode,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _GivenSheet(episode: episode),
);

class _GivenSheet extends ConsumerStatefulWidget {
  const _GivenSheet({required this.episode});

  final SickEpisode episode;

  @override
  ConsumerState<_GivenSheet> createState() => _GivenSheetState();
}

/// "Another medicine" in the medicine list.
const _other = '';

class _GivenSheetState extends ConsumerState<_GivenSheet> {
  final _name = TextEditingController();

  // Never filled in by the app: the amount is the family's own words.
  final _amount = TextEditingController();
  String? _medicineId;
  late DateTime _at = ref.read(clockProvider)();
  bool _remind = false;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Medicine? _picked(List<Medicine> medicines) {
    for (final m in medicines) {
      if (m.id == _medicineId) return m;
    }
    return null;
  }

  Future<void> _save(List<Medicine> medicines) async {
    final l = AppLocalizations.of(context);
    final medicine = _picked(medicines);
    final name = medicine?.name ?? _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.givenRequired);
      return;
    }
    final hours = medicine?.minHoursBetweenDoses;
    setState(() => _saving = true);
    if (!await ref.read(saveGateProvider).allow()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    await ref
        .read(databaseProvider)
        .saveGivenMedicine(
          episodeId: widget.episode.id,
          medicineId: medicine?.id,
          prescriptionId: medicine?.prescriptionId,
          name: name,
          amount: _amount.text,
          givenAt: _at,
          remindNext: medicine != null && hours != null && _remind,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.read(clockProvider)();
    final medicines =
        ref.watch(medicinesProvider(widget.episode.profileId)).value ??
        const <Medicine>[];
    final prescriptions = {
      for (final p
          in ref.watch(prescriptionsProvider(widget.episode.profileId)).value ??
              const <Prescription>[])
        p.id: p,
    };
    final medicine = _picked(medicines);
    // Only what the family typed on the medicine; never read or guessed.
    final hours = medicine?.minHoursBetweenDoses;
    String label(Medicine m) {
      final rx = prescriptions[m.prescriptionId];
      final name = [m.name, ?m.strength].join(' ');
      return rx == null
          ? name
          : '$name · ${l.givenFromPrescription(DateFormat.yMMMd(locale).format(rx.prescribedOn))}';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.sickDayAddMedicine,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (medicines.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('given-medicine'),
                initialValue: _medicineId ?? _other,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.givenWhich),
                items: [
                  for (final m in medicines)
                    DropdownMenuItem(
                      value: m.id,
                      child: Text(label(m), overflow: TextOverflow.ellipsis),
                    ),
                  DropdownMenuItem(value: _other, child: Text(l.givenOther)),
                ],
                onChanged: (v) => setState(() {
                  _medicineId = v == _other ? null : v;
                  _remind = false;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
            ],
            if (medicine == null) ...[
              TextField(
                key: const ValueKey('given-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.givenName,
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('given-amount'),
              controller: _amount,
              decoration: InputDecoration(
                labelText: l.givenAmount,
                helperText: l.givenAmountHint,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            _WhenField(
              label: l.givenTime,
              value: _at,
              now: now,
              first: widget.episode.startedAt.toLocal().subtract(
                const Duration(days: 1),
              ),
              keyPrefix: 'given',
              onChanged: (v) => setState(() => _at = v),
            ),
            if (medicine != null) ...[
              const SizedBox(height: 12),
              if (hours == null)
                Text(
                  l.givenNoInterval,
                  key: const ValueKey('given-no-interval'),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else ...[
                Text(
                  l.givenHoursAfter(
                    formatHours(hours, locale),
                    DateFormat.MMMd(locale).add_jm().format(
                      _at.add(Duration(minutes: (hours * 60).round())),
                    ),
                  ),
                  key: const ValueKey('given-hours-after'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(l.givenCheckIngredient),
                SwitchListTile(
                  key: const ValueKey('given-remind'),
                  contentPadding: EdgeInsets.zero,
                  value: _remind,
                  onChanged: (v) => setState(() => _remind = v),
                  title: Text(l.givenRemind),
                ),
              ],
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('given-save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _saving ? null : () => _save(medicines),
              child: Text(l.familySave),
            ),
          ],
        ),
      ),
    );
  }
}
