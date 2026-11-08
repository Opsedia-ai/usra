import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../l10n/app_localizations.dart';

/// "Read it from a photo": what it does, a camera and a gallery button,
/// "Reading…" while the phone reads, then what it found. Shared by the
/// prescription form and the vaccine checklist. [keyPrefix] names the
/// widgets for tests ("rx-scan" → `rx-scan-camera`, `rx-scan-result`).
class DocumentScanCard extends StatelessWidget {
  const DocumentScanCard({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.help,
    required this.readingText,
    required this.reading,
    required this.onScan,
    this.messages = const [],
  });

  final String keyPrefix;
  final String title;
  final String help;
  final String readingText;
  final bool reading;

  /// What the last photo gave, one line each; the first is in bold.
  final List<String> messages;
  final ValueChanged<ImageSource>? onScan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const tall = Size(0, 56);
    final scan = reading ? null : onScan;
    return Card(
      color: context.usra.primarySoft,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(help),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: ValueKey('$keyPrefix-camera'),
                  style: FilledButton.styleFrom(minimumSize: tall),
                  onPressed: scan == null
                      ? null
                      : () => scan(ImageSource.camera),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(l.labScanCamera),
                ),
                OutlinedButton.icon(
                  key: ValueKey('$keyPrefix-gallery'),
                  style: OutlinedButton.styleFrom(minimumSize: tall),
                  onPressed: scan == null
                      ? null
                      : () => scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l.labScanGallery),
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
                  Expanded(child: Text(readingText)),
                ],
              ),
            ],
            for (final (i, m) in messages.indexed) ...[
              const SizedBox(height: 10),
              Text(
                m,
                key: ValueKey('$keyPrefix-result${i == 0 ? '' : '-$i'}'),
                style: i == 0
                    ? const TextStyle(fontWeight: FontWeight.w600)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A box's look: marked (words, icon, colour) while the phone isn't sure
/// of it, with a button to say it was checked against the paper.
InputDecoration unsureDecoration(
  BuildContext context, {
  required String label,
  required bool unsure,
  required String checkKey,
  required VoidCallback onChecked,
  String? hint,
  String? error,
}) {
  final l = AppLocalizations.of(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    helperText: unsure ? l.labCheckThis : null,
    helperMaxLines: 2,
    helperStyle: unsure
        ? TextStyle(color: Severity.headsUp.foregroundOf(context))
        : null,
    filled: unsure,
    fillColor: unsure ? Severity.headsUp.backgroundOf(context) : null,
    suffixIcon: unsure
        ? IconButton(
            key: ValueKey(checkKey),
            tooltip: l.labCheckedIt,
            onPressed: onChecked,
            icon: Icon(
              Icons.task_alt,
              color: Severity.headsUp.foregroundOf(context),
            ),
          )
        : null,
  );
}

/// The photo just read, to check the suggestions against: pinch to zoom,
/// or open it full screen. [path] is the picker's plain temporary copy,
/// still on the phone only.
class ScanPhotoView extends StatelessWidget {
  const ScanPhotoView({
    super.key,
    required this.path,
    required this.semanticLabel,
    required this.keyPrefix,
  });

  final String path;
  final String semanticLabel;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final image = FileImage(File(path));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox(
                height: 240,
                child: InteractiveViewer(
                  key: ValueKey('$keyPrefix-photo'),
                  maxScale: 6,
                  child: Center(
                    child: PhotoImage(
                      image: image,
                      semanticLabel: semanticLabel,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: ValueKey('$keyPrefix-photo-full'),
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    body: InteractiveViewer(
                      maxScale: 8,
                      child: Center(
                        child: PhotoImage(
                          image: image,
                          semanticLabel: semanticLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.fullscreen),
              label: Text(l.labPhotoFullScreen),
            ),
          ),
        ],
      ),
    );
  }
}
