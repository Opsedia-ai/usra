import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../core/log.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctors_providers.dart';
import '../family/member_screen.dart' show eventProvider;
import 'lab_providers.dart';
import 'lab_report.dart';
import 'lab_report_parser.dart';
import 'lab_tests.dart';
import 'lab_widgets.dart';

/// Adds or changes a lab report: date, lab, the doctor who asked for it,
/// cost, any number of results, and photos or PDFs of the paper.
///
/// A photo of the report can fill the results in. What the phone read is
/// only a suggestion: it shows here, with what it wasn't sure of marked,
/// and nothing is saved until the person presses Save.
class LabReportFormScreen extends ConsumerStatefulWidget {
  const LabReportFormScreen({super.key, required this.profileId, this.eventId});

  final String profileId;

  /// The report to change; null adds a new one.
  final String? eventId;

  static String editPath(String profileId, String eventId) =>
      '/family/$profileId/labs/$eventId/edit';

  @override
  ConsumerState<LabReportFormScreen> createState() =>
      _LabReportFormScreenState();
}

class _TestRow {
  _TestRow({
    String name = '',
    String value = '',
    String unit = '',
    String range = '',
    Set<LabField> unsure = const {},
  }) : name = TextEditingController(text: name),
       value = TextEditingController(text: value),
       unit = TextEditingController(text: unit),
       range = TextEditingController(text: range),
       unsure = {...unsure};

  factory _TestRow.of(LabTest t) => _TestRow(
    name: t.name,
    value: t.shownValue,
    unit: t.unit ?? '',
    range: t.range.format(),
  );

  factory _TestRow.candidate(LabCandidate c) => _TestRow(
    name: c.name,
    value: c.value,
    unit: c.unit ?? '',
    range: c.range,
    unsure: c.unsure,
  );

  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController unit;
  final TextEditingController range;
  final focus = FocusNode();

  /// What the phone read but wasn't sure of; cleared field by field as the
  /// person edits.
  final Set<LabField> unsure;

  bool get isBlank =>
      name.text.trim().isEmpty &&
      value.text.trim().isEmpty &&
      unit.text.trim().isEmpty &&
      range.text.trim().isEmpty;

  LabTest? toTest() {
    final n = name.text.trim();
    final v = LabTest.readValue(value.text);
    if (n.isEmpty || (v.value == null && v.text == null)) return null;
    final u = unit.text.trim();
    return LabTest(
      name: n,
      value: v.value,
      valueText: v.text,
      unit: u.isEmpty ? null : u,
      range: LabRange.parse(range.text),
    );
  }

  void dispose() {
    name.dispose();
    value.dispose();
    unit.dispose();
    range.dispose();
    focus.dispose();
  }
}

class _LabReportFormScreenState extends ConsumerState<LabReportFormScreen> {
  late DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _dateTouched = false;
  final _lab = TextEditingController();
  final _doctor = TextEditingController();
  final _cost = TextEditingController();
  String? _doctorId;
  final _rows = <_TestRow>[_TestRow()];
  final _photos = <String>[];
  final _pdfs = <String>[];
  bool _loaded = false;
  bool _submitting = false;
  bool _submitted = false;
  bool _costInvalid = false;
  bool _reading = false;

  /// A PDF was picked at some point, so the picker left a plain copy.
  bool _pickedPdf = false;

  /// How many results the last photo gave, shown until the next one.
  int? _scanned;

  bool get _editing => widget.eventId != null;

  late final Future<void> Function() _cleanUpPicked;

  @override
  void initState() {
    super.initState();
    _cleanUpPicked = ref.read(pickedFilesCleanupProvider);
    _doctor.addListener(() {
      if (_doctorId != null && _doctor.text.trim() != _doctorName) {
        setState(() => _doctorId = null);
      }
    });
    if (_editing) {
      _load();
    } else {
      _loaded = true;
    }
  }

  String? _doctorName;

  Future<void> _load() async {
    MedicalEvent? e;
    try {
      e = await ref.read(eventProvider(widget.eventId!).future);
    } catch (error) {
      Log.error('Lab report load failed', error);
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (e == null) return;
      final report = LabReport.of(e);
      _date = e.occurredAt;
      _dateTouched = true;
      _lab.text = report.lab ?? '';
      _doctor.text = report.orderedBy ?? '';
      _doctorId = e.doctorId;
      _doctorName = report.orderedBy;
      if (e.costMinor != null) _cost.text = formatMoneyInput(e.costMinor!);
      if (report.tests.isNotEmpty) {
        for (final r in _rows) {
          r.dispose();
        }
        _rows
          ..clear()
          ..addAll(report.tests.map(_TestRow.of));
      }
    });
  }

  @override
  void dispose() {
    _lab.dispose();
    _doctor.dispose();
    _cost.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    // Picked files are plain temporary copies: never leave them behind.
    _photos.forEach(discardPicked);
    if (_pickedPdf) _cleanUpPicked();
    super.dispose();
  }

  Future<void> _scan(ImageSource source) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? path;
    try {
      path = await ref.read(photoPickerProvider)(source);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.photoFailed)));
      return;
    }
    if (path == null) return;
    if (!mounted) {
      discardPicked(path);
      return;
    }
    // Kept with the report, whatever the phone reads from it.
    setState(() {
      _photos.add(path!);
      _reading = true;
      _scanned = null;
    });
    LabScan scan;
    try {
      final text = await ref.read(ocrServiceProvider).recognise(path);
      scan = ref.read(labReportParserProvider).parse(text);
    } catch (error) {
      Log.error('Lab report scan failed', error);
      if (mounted) {
        setState(() => _reading = false);
        messenger.showSnackBar(SnackBar(content: Text(l.labScanFailed)));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _scanned = scan.tests.length;
      if (scan.tests.isNotEmpty) {
        final blanks = _rows.where((r) => r.isBlank).toList();
        for (final r in blanks) {
          _rows.remove(r);
          r.dispose();
        }
        _rows.addAll(scan.tests.map(_TestRow.candidate));
      }
      if (scan.date != null && !_dateTouched) _date = scan.date!;
      if (scan.lab != null && _lab.text.trim().isEmpty) _lab.text = scan.lab!;
      if (scan.orderedBy != null && _doctor.text.trim().isEmpty) {
        _doctor.text = scan.orderedBy!;
      }
    });
  }

  Future<void> _addPhotos(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).photoFailed;
    List<String> picked;
    try {
      picked = source == ImageSource.gallery
          ? await ref.read(multiPhotoPickerProvider)()
          : [?await ref.read(photoPickerProvider)(source)];
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    if (!mounted) {
      picked.forEach(discardPicked);
      return;
    }
    setState(() => _photos.addAll(picked));
  }

  Future<void> _addPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).photoFailed;
    String? path;
    try {
      path = await ref.read(labPdfPickerProvider)();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    if (path == null) return;
    _pickedPdf = true;
    if (!mounted) return;
    setState(() => _pdfs.add(path!));
  }

  void _addRow() => setState(() => _rows.add(_TestRow()));

  void _removeRow(int i) {
    setState(() {
      _rows.removeAt(i).dispose();
      if (_rows.isEmpty) _rows.add(_TestRow());
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l = AppLocalizations.of(context);
    final filled = _rows.where((r) => !r.isBlank).toList();
    final tests = [for (final r in filled) r.toTest()];
    int? costMinor;
    var costInvalid = false;
    if (_cost.text.trim().isNotEmpty) {
      costMinor = parseMoneyMinor(_cost.text);
      costInvalid = costMinor == null;
    }
    setState(() {
      _submitted = true;
      _costInvalid = costInvalid;
    });
    if (tests.isEmpty || tests.contains(null) || costInvalid) return;

    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final report = LabReport(
      lab: text(_lab),
      orderedBy: text(_doctor),
      tests: tests.cast<LabTest>(),
    );
    setState(() => _submitting = true);
    final db = ref.read(databaseProvider);
    final store = _photos.isEmpty && _pdfs.isEmpty
        ? null
        : ref.read(attachmentStoreProvider);
    try {
      // Copied in (encrypted) first; the plain copies go when this closes.
      final photos = [for (final path in _photos) await store!.import(path)];
      final pdfs = [for (final path in _pdfs) await store!.import(path)];
      final data = jsonEncode(report.toData());
      if (_editing) {
        await db.updateEvent(
          widget.eventId!,
          occurredAt: _date,
          dataJson: data,
          costMinor: costMinor,
          currency: costMinor == null ? null : 'EGP',
          doctorId: _doctorId,
          photos: photos,
          pdfs: pdfs,
        );
      } else {
        await db.addEvent(
          profileId: widget.profileId,
          type: LabFields.type,
          occurredAt: _date,
          dataJson: data,
          costMinor: costMinor,
          currency: costMinor == null ? null : 'EGP',
          doctorId: _doctorId,
          photos: photos,
          pdfs: pdfs,
        );
      }
    } catch (error) {
      Log.error('Lab report save failed', error);
      try {
        await store?.prune(await db.liveAttachmentPaths());
      } catch (_) {
        // Left for the next save or delete to clean up.
      }
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      }
      return;
    }
    if (!mounted) return;
    context.go(
      _editing
          ? '/family/${widget.profileId}/record/${widget.eventId}'
          : '/family/${widget.profileId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final simple = ref.watch(simpleModeProvider);
    final doctors = ref.watch(doctorsProvider).value ?? const <Doctor>[];
    final busy = _submitting || _reading;
    final noTests = _submitted && _rows.every((r) => r.isBlank);
    return Scaffold(
      appBar: AppBar(title: Text(l.recordLab)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                _ScanCard(
                  reading: _reading,
                  found: _scanned,
                  onScan: busy ? null : _scan,
                ),
                const SizedBox(height: 20),
                InkWell(
                  key: const ValueKey('lab-date'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                    );
                    if (picked != null) {
                      setState(() {
                        _date = picked;
                        _dateTouched = true;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: l.recordDate),
                    child: Text(DateFormat.yMMMd(locale).format(_date)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('lab-name'),
                  controller: _lab,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l.fieldLab),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('lab-doctor'),
                  controller: _doctor,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.fieldOrderedBy,
                    suffixIcon: doctors.isEmpty
                        ? null
                        : PopupMenuButton<Doctor>(
                            key: const ValueKey('lab-doctor-pick'),
                            tooltip: l.chooseDoctor,
                            icon: const Icon(Icons.contacts_outlined),
                            onSelected: (d) => setState(() {
                              _doctorName = d.name;
                              _doctor.text = d.name;
                              _doctorId = d.id;
                            }),
                            itemBuilder: (_) => [
                              for (final d in doctors)
                                PopupMenuItem(
                                  value: d,
                                  child: Text(
                                    [d.name, ?d.specialty].join(' · '),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l.labResultsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const LabInfoNote(),
                const SizedBox(height: 12),
                for (final (i, row) in _rows.indexed) ...[
                  _TestCard(
                    key: ObjectKey(row),
                    index: i,
                    row: row,
                    submitted: _submitted,
                    onChanged: () => setState(() {}),
                    onRemove: busy ? null : () => _removeRow(i),
                  ),
                  const SizedBox(height: 12),
                ],
                if (noTests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l.labNeedOneTest,
                      key: const ValueKey('lab-need-test'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('lab-add-test'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: busy ? null : _addRow,
                  icon: const Icon(Icons.add),
                  label: Text(l.labAddTest),
                ),
                // Fewer boxes in Simple Mode; the cost can be added later.
                if (!simple || _cost.text.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('field-cost'),
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l.recordCost,
                      suffixText: l.currencyEgp,
                      errorText: _costInvalid ? l.fieldInvalid : null,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _Files(
                  photos: _photos,
                  pdfs: _pdfs,
                  onAddPhotos: busy ? null : _addPhotos,
                  onAddPdf: busy ? null : _addPdf,
                  onRemovePhoto: busy
                      ? null
                      : (i) =>
                            setState(() => discardPicked(_photos.removeAt(i))),
                  onRemovePdf: busy
                      ? null
                      : (i) => setState(() => _pdfs.removeAt(i)),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  key: const ValueKey('record-save'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed: busy ? null : _submit,
                  child: Text(l.familySave),
                ),
              ],
            ),
    );
  }
}

/// Reading the results from a photo of the paper, on the phone.
class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.reading,
    required this.found,
    required this.onScan,
  });

  final bool reading;
  final int? found;
  final ValueChanged<ImageSource>? onScan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const tall = Size(0, 52);
    return Card(
      color: UsraColors.primaryTint,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.labScanTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(l.labScanHelp),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('lab-scan-camera'),
                    style: FilledButton.styleFrom(minimumSize: tall),
                    onPressed: onScan == null
                        ? null
                        : () => onScan!(ImageSource.camera),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(l.labScanCamera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('lab-scan-gallery'),
                    style: OutlinedButton.styleFrom(minimumSize: tall),
                    onPressed: onScan == null
                        ? null
                        : () => onScan!(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l.labScanGallery),
                  ),
                ),
              ],
            ),
            if (reading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.labScanReading)),
                ],
              ),
            ],
            if (found != null) ...[
              const SizedBox(height: 12),
              Text(
                found == 0 ? l.labScanNothing : l.labScanFound(found!),
                key: const ValueKey('lab-scan-result'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One result: test name (with common names offered), value, unit and the
/// range printed on the paper, and the flag that range gives.
class _TestCard extends StatelessWidget {
  const _TestCard({
    super.key,
    required this.index,
    required this.row,
    required this.submitted,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _TestRow row;
  final bool submitted;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  InputDecoration _decoration(
    BuildContext context,
    LabField field,
    String label, {
    String? hint,
    String? error,
  }) {
    final unsure = row.unsure.contains(field);
    final l = AppLocalizations.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      // Marked with words and an icon, not only a colour.
      helperText: unsure ? l.labCheckThis : null,
      helperStyle: unsure
          ? TextStyle(color: Severity.headsUp.foreground)
          : null,
      filled: unsure,
      fillColor: unsure ? Severity.headsUp.background : null,
      suffixIcon: unsure
          ? Icon(
              Icons.help_outline,
              key: ValueKey('lab-unsure-${field.name}-$index'),
              color: Severity.headsUp.foreground,
            )
          : null,
    );
  }

  void _edited(LabField field) {
    row.unsure.remove(field);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final blank = row.isBlank;
    final test = row.toTest();
    final nameMissing = submitted && !blank && row.name.text.trim().isEmpty;
    final valueMissing = submitted && !blank && row.value.text.trim().isEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.labTestNumber(index + 1),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey('lab-remove-test-$index'),
                  tooltip: l.labRemoveTest,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RawAutocomplete<KnownLabTest>(
                    textEditingController: row.name,
                    focusNode: row.focus,
                    displayStringForOption: (t) => t.nameIn(language),
                    optionsBuilder: (value) {
                      final typed = labTestKey(value.text);
                      if (typed.isEmpty) return const [];
                      final found = <KnownLabTest>{};
                      for (final (key, test) in labTestNames) {
                        if (key.contains(typed)) found.add(test);
                        if (found.length == 6) break;
                      }
                      return found;
                    },
                    onSelected: (_) => _edited(LabField.name),
                    fieldViewBuilder: (context, controller, focus, submit) =>
                        TextField(
                          key: ValueKey('lab-test-name-$index'),
                          controller: controller,
                          focusNode: focus,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _edited(LabField.name),
                          decoration: _decoration(
                            context,
                            LabField.name,
                            l.labTestName,
                            error: nameMissing ? l.fieldRequired : null,
                          ),
                        ),
                    optionsViewBuilder: (context, select, options) => Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 280,
                            maxWidth: 360,
                          ),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final t in options)
                                ListTile(
                                  key: ValueKey('lab-suggest-${t.id}'),
                                  title: Text(t.nameIn(language)),
                                  subtitle: language == 'ar' && t.ar != t.en
                                      ? Text(t.en)
                                      : null,
                                  onTap: () => select(t),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: ValueKey('lab-test-value-$index'),
                          controller: row.value,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _edited(LabField.value),
                          decoration: _decoration(
                            context,
                            LabField.value,
                            l.labTestValue,
                            error: valueMissing ? l.fieldRequired : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: ValueKey('lab-test-unit-$index'),
                          controller: row.unit,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _edited(LabField.unit),
                          decoration: _decoration(
                            context,
                            LabField.unit,
                            l.labTestUnit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: ValueKey('lab-test-range-$index'),
                    controller: row.range,
                    onChanged: (_) => _edited(LabField.range),
                    decoration: _decoration(
                      context,
                      LabField.range,
                      l.labTestRange,
                      hint: l.labTestRangeHint,
                    ),
                  ),
                  if (test != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LabFlagChip(
                        key: ValueKey('lab-test-flag-$index'),
                        flag: test.flag,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photos and PDFs of the paper, picked but not yet saved.
class _Files extends StatelessWidget {
  const _Files({
    required this.photos,
    required this.pdfs,
    required this.onAddPhotos,
    required this.onAddPdf,
    required this.onRemovePhoto,
    required this.onRemovePdf,
  });

  final List<String> photos;
  final List<String> pdfs;
  final ValueChanged<ImageSource>? onAddPhotos;
  final VoidCallback? onAddPdf;
  final ValueChanged<int>? onRemovePhoto;
  final ValueChanged<int>? onRemovePdf;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const tall = Size(0, 52);
    const thumb = 88.0;
    final pixels = (thumb * MediaQuery.devicePixelRatioOf(context)).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.recordPhotos, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (photos.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, path) in photos.indexed)
                Stack(
                  key: ValueKey('record-photo-$i'),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: PhotoImage(
                        image: FileImage(File(path)),
                        width: thumb,
                        height: thumb,
                        fit: BoxFit.cover,
                        cacheWidth: pixels,
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: IconButton.filledTonal(
                        key: ValueKey('record-photo-remove-$i'),
                        tooltip: l.photoRemove,
                        visualDensity: VisualDensity.compact,
                        onPressed: onRemovePhoto == null
                            ? null
                            : () => onRemovePhoto!(i),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        for (final (i, path) in pdfs.indexed)
          ListTile(
            key: ValueKey('lab-pdf-$i'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.picture_as_pdf_outlined,
              color: UsraColors.primary,
            ),
            title: Text(p.basename(path), overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              key: ValueKey('lab-pdf-remove-$i'),
              tooltip: l.labRemovePdf,
              onPressed: onRemovePdf == null ? null : () => onRemovePdf!(i),
              icon: const Icon(Icons.close),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('record-photo-camera'),
                style: OutlinedButton.styleFrom(minimumSize: tall),
                onPressed: onAddPhotos == null
                    ? null
                    : () => onAddPhotos!(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l.photoCamera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('record-photo-gallery'),
                style: OutlinedButton.styleFrom(minimumSize: tall),
                onPressed: onAddPhotos == null
                    ? null
                    : () => onAddPhotos!(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l.photoGallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('lab-attach-pdf'),
          style: OutlinedButton.styleFrom(minimumSize: tall),
          onPressed: onAddPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l.labAttachPdf),
        ),
      ],
    );
  }
}
