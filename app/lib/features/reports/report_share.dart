import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/files/photo_store.dart';
import '../../core/log.dart';
import '../../core/preferences.dart';
import '../../core/security/share_warning.dart';
import '../../l10n/app_localizations.dart';
import 'report.dart';

/// Loads the PDF fonts once (about 840 KB to read and parse), then reuses
/// them; a failed load is tried again next time. Overridden in tests.
final reportFontsProvider = Provider<Future<ReportFonts> Function()>((ref) {
  Future<ReportFonts>? loaded;
  return () async {
    try {
      return await (loaded ??= ReportFonts.load());
    } catch (_) {
      loaded = null;
      rethrow;
    }
  };
});

/// File names say what the file is, never whose: the name shows in the
/// chat or folder it's sent to, and in the phone's cache until deleted.
const vaccinationRecordFile = 'usra-vaccination-record.pdf';
const doctorSummaryFile = 'usra-doctor-summary.pdf';

/// Makes the PDF of [build]'s report on the phone and shares it. Warns
/// first that it leaves the app's protection ([confirmShareOutside]). The
/// file is written to the share folder of [SharedPhotoCache] and deleted
/// when the sheet returns (and, if the app is killed first, at the next
/// start and by the wipe). [build] returns null when there's nothing to
/// make (the person was deleted, or has no birth date): [missing] is shown
/// then. True once the share sheet was opened.
Future<bool> shareReportPdf(
  WidgetRef ref, {
  required String fileName,
  required FutureOr<Report?> Function() build,
  String? missing,
  Rect? origin,
}) async {
  // Read now: the screen may be gone once the PDF is made.
  final (cache, share, prefs, fonts) = (
    ref.read(sharedPhotoCacheProvider),
    ref.read(shareProvider),
    ref.read(keyValueStoreProvider),
    ref.read(reportFontsProvider),
  );
  final context = ref.context;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = AppLocalizations.of(context).reportFailed;
  if (!context.mounted || !await confirmShareOutside(context, prefs)) {
    return false;
  }
  final Uint8List bytes;
  try {
    final report = await build();
    if (report == null) {
      messenger?.showSnackBar(SnackBar(content: Text(missing ?? failed)));
      return false;
    }
    bytes = await renderReportPdf(report, await fonts());
  } catch (e) {
    Log.error('Report PDF failed', e);
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
    return false;
  }
  try {
    await cache.clear();
    final file = await cache.writeOut(fileName, bytes, 'application/pdf');
    await share(ShareParams(files: [file], sharePositionOrigin: origin));
    return true;
  } catch (e) {
    Log.error('Report share failed', e);
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
    return false;
  } finally {
    unawaited(cache.clearAfterShare());
  }
}
