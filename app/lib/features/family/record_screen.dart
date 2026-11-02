import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/records/record_type.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import 'member_screen.dart';
import 'record_display.dart';

/// One record: every field, and its photos to zoom into, send or delete.
class RecordScreen extends ConsumerWidget {
  const RecordScreen({
    super.key,
    required this.profileId,
    required this.eventId,
  });

  final String profileId;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final event = ref.watch(eventProvider(eventId));
    final photos = ref.watch(attachmentsProvider(eventId)).value ?? const [];
    final e = event.value;
    final type = e == null
        ? null
        : ref.watch(moduleRegistryProvider).recordTypes[e.type];
    return Scaffold(
      appBar: AppBar(
        title: Text(e == null ? '' : type?.labelOf(context) ?? e.type),
        actions: [
          if (e != null) ...[
            IconButton(
              key: const ValueKey('record-share'),
              tooltip: l.recordShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _share(context, ref, e, type, photos),
            ),
            IconButton(
              key: const ValueKey('record-delete'),
              tooltip: l.recordDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (e) {
          if (e == null) return Center(child: Text(l.recordNotFound));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final (label, value) in _lines(context, e, type))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Line(label: label, value: value),
                ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l.recordPhotos,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _Thumbnails(photos: photos),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Label and value of everything filled in, in the type's field order.
  static List<(String, String)> _lines(
    BuildContext context,
    MedicalEvent e,
    RecordTypeDefinition? type,
  ) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final data = decodeRecordData(e.dataJson);
    final currency = e.currency;
    return [
      (l.recordDate, DateFormat.yMMMd(locale).format(e.occurredAt)),
      for (final f in type?.fields ?? const <FieldSpec>[])
        if (data[f.key] case final v?)
          (f.labelOf(context), displayFieldValue(context, f, v)),
      if (e.costMinor != null)
        (
          l.recordCost,
          formatMoney(
            e.costMinor!,
            locale: locale,
            currency: currency == null || currency == 'EGP'
                ? l.currencyEgp
                : currency,
          ),
        ),
    ];
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    MedicalEvent e,
    RecordTypeDefinition? type,
    List<Attachment> photos,
  ) {
    final title = type?.labelOf(context) ?? e.type;
    final text = [
      title,
      for (final (label, value) in _lines(context, e, type)) '$label: $value',
    ].join('\n');
    return sharePhotos(context, ref, photos, text: text);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final yes = await _confirm(
      context,
      l.recordDeleteConfirm,
      l.recordDelete,
      'record-delete-confirm',
    );
    if (yes != true) return;
    final db = ref.read(databaseProvider);
    await db.softDeleteEvent(eventId);
    await _prunePhotos(ref);
    if (context.mounted) context.go('/family/$profileId');
  }
}

/// Opens the share sheet with [photos] that are still on the phone.
Future<void> sharePhotos(
  BuildContext context,
  WidgetRef ref,
  List<Attachment> photos, {
  String? text,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).shareFailed;
  final box = context.findRenderObject() as RenderBox?;
  final store = ref.read(attachmentStoreProvider);
  final files = [
    for (final a in photos)
      if (store.fileOf(a.path).existsSync())
        XFile(store.fileOf(a.path).path, mimeType: photoMimeOf(a.path)),
  ];
  try {
    await ref.read(shareProvider)(
      ShareParams(
        text: text,
        files: files.isEmpty ? null : files,
        // iPad needs to know where to anchor the share sheet.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

Future<bool?> _confirm(
  BuildContext context,
  String message,
  String action,
  String key,
) {
  final cancel = AppLocalizations.of(context).familyCancel;
  return showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(cancel),
        ),
        FilledButton(
          key: ValueKey(key),
          style: FilledButton.styleFrom(backgroundColor: UsraColors.emergency),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Deletes photo files no live record uses any more.
Future<void> _prunePhotos(WidgetRef ref) async {
  try {
    final db = ref.read(databaseProvider);
    await ref
        .read(attachmentStoreProvider)
        .prune(await db.liveAttachmentPaths());
  } catch (_) {
    // Left for the next save or delete to clean up.
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelLarge?.copyWith(color: UsraColors.textMuted),
        ),
        SelectableText(value, style: text.titleMedium),
      ],
    );
  }
}

class _Thumbnails extends ConsumerWidget {
  const _Thumbnails({required this.photos});

  final List<Attachment> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final store = ref.watch(attachmentStoreProvider);
    final pixels = (120 * MediaQuery.devicePixelRatioOf(context)).round();
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (i, a) in photos.indexed)
          InkWell(
            key: ValueKey('record-thumb-$i'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) =>
                    _PhotoViewer(eventId: a.eventId, initialIndex: i),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: PhotoImage(
                file: store.fileOf(a.path),
                fit: BoxFit.cover,
                cacheWidth: pixels,
                semanticLabel: l.photoPosition(i + 1, photos.length),
              ),
            ),
          ),
      ],
    );
  }
}

/// A record's photos full screen: swipe between them, pinch to zoom.
class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({required this.eventId, required this.initialIndex});

  final String eventId;
  final int initialIndex;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete(Attachment photo) async {
    final l = AppLocalizations.of(context);
    final yes = await _confirm(
      context,
      l.photoDeleteConfirm,
      l.photoDelete,
      'photo-delete-confirm',
    );
    if (yes != true || !mounted) return;
    await ref.read(databaseProvider).softDeleteAttachment(photo.id);
    await _prunePhotos(ref);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final photos =
        ref.watch(attachmentsProvider(widget.eventId)).value ?? const [];
    final store = ref.watch(attachmentStoreProvider);
    final index = photos.isEmpty ? 0 : _index.clamp(0, photos.length - 1);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: photos.isEmpty
            ? null
            : Text(l.photoPosition(index + 1, photos.length)),
        actions: [
          if (photos.isNotEmpty) ...[
            IconButton(
              key: const ValueKey('photo-share'),
              tooltip: l.photoShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => sharePhotos(context, ref, [photos[index]]),
            ),
            IconButton(
              key: const ValueKey('photo-delete'),
              tooltip: l.photoDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(photos[index]),
            ),
          ],
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: PhotoImage(
              file: store.fileOf(photos[i].path),
              semanticLabel: l.photoPosition(i + 1, photos.length),
            ),
          ),
        ),
      ),
    );
  }
}
