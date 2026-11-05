import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/app_lock.dart';
import 'lab_report_parser.dart';

/// Picks a PDF (a lab's emailed report) and returns the path of the
/// picker's temporary copy, or null if cancelled. Overridden in tests.
final labPdfPickerProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => (await whileInOtherApp(
        () => FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        ),
      ))?.path,
);

/// Deletes the file picker's temporary copies (a picked PDF is stored
/// encrypted; its plain copy mustn't stay in the cache). Overridden in
/// tests.
final pickedFilesCleanupProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      // Nothing picked, or the platform keeps none.
    }
  },
);

final labReportParserProvider = Provider<LabReportParser>(
  (ref) => const LabReportParser(),
);
