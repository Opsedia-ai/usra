import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/files/photo_store.dart';
import '../../core/log.dart';
import '../../core/ocr/medicine_name_extractor.dart';
import '../../core/ocr/ocr_service.dart';
import '../../l10n/app_localizations.dart';

/// Photographs a medicine box, reads it on the phone and pops with the
/// [MedicineSuggestion] the person confirmed (name, maybe strength), or
/// null if they leave. The photo itself isn't kept.
///
/// Open it with `context.push<MedicineSuggestion>(ScanMedicineScreen.path)`.
class ScanMedicineScreen extends ConsumerStatefulWidget {
  const ScanMedicineScreen({super.key});

  static const path = '/scan/medicine';

  @override
  ConsumerState<ScanMedicineScreen> createState() => _ScanMedicineScreenState();
}

class _ScanMedicineScreenState extends ConsumerState<ScanMedicineScreen> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  String? _photo;
  OcrResult? _text;
  List<MedicineSuggestion> _suggestions = const [];
  bool _reading = false;
  bool _failed = false;
  bool _nameMissing = false;

  /// The fields hold a suggestion the person hasn't edited, so a new photo
  /// may replace it.
  bool _filledIn = false;

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    if (_photo != null) discardPicked(_photo!);
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final l = AppLocalizations.of(context);
    String? path;
    try {
      path = await ref.read(photoPickerProvider)(source);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.photoFailed)));
      }
      return;
    }
    if (path == null || !mounted) return;
    if (_photo != null) discardPicked(_photo!);
    setState(() {
      _photo = path;
      _text = null;
      _suggestions = const [];
      _reading = true;
      _failed = false;
    });
    try {
      final text = await ref.read(ocrServiceProvider).recognise(path);
      final extractor = await ref.read(medicineNameExtractorProvider.future);
      if (!mounted || _photo != path) return;
      final suggestions = extractor.suggest(text);
      setState(() {
        _text = text;
        _suggestions = suggestions;
        _reading = false;
      });
      if (_filledIn || _name.text.trim().isEmpty) {
        if (suggestions.isEmpty) {
          _name.clear();
          _strength.clear();
          _filledIn = false;
        } else {
          _choose(suggestions.first);
        }
      }
    } catch (e) {
      Log.error('Medicine scan failed', e);
      if (!mounted || _photo != path) return;
      setState(() {
        _reading = false;
        _failed = true;
      });
    }
  }

  void _choose(MedicineSuggestion s) => setState(() {
    _name.text = s.name;
    _strength.text = s.strength ?? '';
    _nameMissing = false;
    _filledIn = true;
  });

  void _use() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final strength = _strength.text.trim();
    // How sure the reading is goes along with it, so the form can highlight
    // it. What the person typed themselves isn't in doubt.
    final readName = _suggestions.where(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
    );
    final readStrength = _suggestions.where((s) => s.strength == strength);
    context.pop(
      MedicineSuggestion(
        name: name,
        strength: strength.isEmpty ? null : strength,
        nameSure: readName.every((s) => s.nameSure),
        strengthSure:
            strength.isNotEmpty && readStrength.every((s) => s.strengthSure),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Keeps the recogniser open while this screen is up.
    ref.watch(ocrServiceProvider);
    final chosen = _name.text.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: Text(l.scanMedicineTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_photo == null) ...[
            Text(l.scanMedicineIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
          ],
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${l.scanMedicineLimits} ${l.scanMedicinePrivacy}',
                      key: const ValueKey('scan-limits'),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_photo != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: _ReadPhoto(
                file: File(_photo!),
                text: _text,
                highlighted: {
                  for (final s in _suggestions)
                    if (s.name.toLowerCase() == chosen && s.box != null) s.box!,
                },
                semanticLabel: l.scanMedicinePhoto,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('scan-camera'),
                onPressed: _reading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(
                  _photo == null ? l.photoCamera : l.scanMedicineRetake,
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('scan-gallery'),
                onPressed: _reading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l.photoGallery),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_reading)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(l.scanMedicineReading),
              ],
            )
          else if (_failed)
            Text(
              l.scanMedicineFailed,
              key: const ValueKey('scan-failed'),
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (_text != null && _suggestions.isEmpty)
            Text(l.scanMedicineNoneFound, key: const ValueKey('scan-none'))
          else if (_suggestions.isNotEmpty) ...[
            Text(l.scanMedicineSuggestions, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, s) in _suggestions.indexed)
                  ChoiceChip(
                    key: ValueKey('scan-suggestion-$i'),
                    // Medicine names are Latin: keep them left-to-right.
                    label: Text(s.label, textDirection: TextDirection.ltr),
                    selected:
                        s.name.toLowerCase() == chosen &&
                        (s.strength ?? '') == _strength.text.trim(),
                    onSelected: (_) => _choose(s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('scan-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {
              _nameMissing = false;
              _filledIn = false;
            }),
            decoration: InputDecoration(
              labelText: l.scanMedicineName,
              errorText: _nameMissing ? l.fieldRequired : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('scan-strength'),
            controller: _strength,
            onChanged: (_) => setState(() => _filledIn = false),
            decoration: InputDecoration(labelText: l.scanMedicineStrength),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.scanMedicineCheck, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('scan-use'),
            onPressed: _reading ? null : _use,
            child: Text(l.scanMedicineUse),
          ),
        ],
      ),
    );
  }
}

/// The photo with every line that was read outlined, and the chosen name
/// filled in.
class _ReadPhoto extends StatefulWidget {
  const _ReadPhoto({
    required this.file,
    required this.text,
    required this.highlighted,
    required this.semanticLabel,
  });

  final File file;
  final OcrResult? text;
  final Set<Rect> highlighted;
  final String semanticLabel;

  @override
  State<_ReadPhoto> createState() => _ReadPhotoState();
}

class _ReadPhotoState extends State<_ReadPhoto> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    (info, _) {
      if (!mounted) return;
      setState(
        () => _size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ),
      );
    },
    onError: (_, _) {
      // Unreadable photo: shown as a broken image, without outlines.
    },
  );
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_ReadPhoto old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _size = null;
      _resolve();
    }
  }

  // The outlines are in the photo's pixels, so its size is needed to place
  // them.
  void _resolve() {
    _stream?.removeListener(_listener);
    _stream = FileImage(
      widget.file,
    ).resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final text = widget.text;
    if (size == null || text == null) {
      return PhotoImage(
        image: FileImage(widget.file),
        height: 240,
        semanticLabel: widget.semanticLabel,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return FittedBox(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoImage(
              image: FileImage(widget.file),
              fit: BoxFit.fill,
              semanticLabel: widget.semanticLabel,
            ),
            CustomPaint(
              painter: _LinesPainter(
                lines: [for (final line in text.lines) line.box],
                highlighted: widget.highlighted,
                // Thick enough to see once the photo is scaled down.
                stroke: size.longestSide / 300,
                outline: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter({
    required this.lines,
    required this.highlighted,
    required this.stroke,
    required this.outline,
  });

  final List<Rect> lines;
  final Set<Rect> highlighted;
  final double stroke;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = outline.withValues(alpha: 0.6);
    final fill = Paint()..color = outline.withValues(alpha: 0.3);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 2
      ..color = outline;
    for (final r in lines) {
      final box = r.inflate(stroke * 2);
      if (highlighted.contains(r)) {
        canvas.drawRect(box, fill);
        canvas.drawRect(box, edge);
      } else {
        canvas.drawRect(box, line);
      }
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) =>
      old.lines != lines ||
      old.highlighted.length != highlighted.length ||
      !old.highlighted.containsAll(highlighted) ||
      old.stroke != stroke ||
      old.outline != outline;
}
