import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/security/sensitive_clipboard.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider;
import 'insurance_info.dart';
import 'insurance_section.dart' show ExpiryLine;
import 'watermark.dart';
import 'insurance_providers.dart';

/// One insurance card: its photos, number and expiry, ready to send.
class InsuranceCardScreen extends ConsumerWidget {
  const InsuranceCardScreen({
    super.key,
    required this.profileId,
    required this.cardId,
  });

  final String profileId;
  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(insuranceCardProvider(cardId));
    final c = card.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.label ?? ''),
        actions: [
          if (c != null) ...[
            IconButton(
              tooltip: l.insuranceEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.go('/family/$profileId/insurance/$cardId/edit'),
            ),
          ],
        ],
      ),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (c) {
          if (c == null) return Center(child: Text(l.insuranceNotFound));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final (label, path) in [
                (l.insuranceFront, c.frontPhoto),
                (l.insuranceBack, c.backPhoto),
              ])
                if (path != null) ...[
                  _Photo(
                    label: label,
                    image: ref.watch(cardPhotoStoreProvider).image(path),
                  ),
                  const SizedBox(height: 12),
                ],
              _Details(card: c),
              const SizedBox(height: 24),
              // The page's one main action.
              _ShareButton(profileId: profileId, card: c),
              const SizedBox(height: UsraSpacing.s3),
              Center(
                child: TextButton(
                  key: const ValueKey('insurance-delete'),
                  onPressed: () => _confirmDelete(context, ref, c),
                  child: Text(l.insuranceDeleteCard),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InsuranceCard card,
  ) async {
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.insuranceDeleteConfirm(card.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.familyCancel),
          ),
          FilledButton(
            key: const ValueKey('insurance-delete-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.insuranceDelete),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final db = ref.read(databaseProvider);
    final photos = ref.read(cardPhotoStoreProvider);
    await db.softDeleteInsuranceCard(card.id);
    try {
      await photos.prune(await db.liveInsurancePhotos());
    } catch (_) {
      // Left for the next save or delete to clean up.
    }
    if (context.mounted) context.go('/family/$profileId');
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.label, required this.image});

  final String label;
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final photo = PhotoImage(image: image, semanticLabel: label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: UsraType.label.copyWith(
            color: context.usra.inkMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          // Full screen, to hold the phone up to a receptionist.
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialog) => Dialog.fullscreen(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialog),
                child: InteractiveViewer(child: Center(child: photo)),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(UsraRadius.card),
            child: photo,
          ),
        ),
      ],
    );
  }
}

/// What was saved on the card, one row each, as in the other polished
/// lists: the card's name always, then the insurer, the member number (with
/// a short copy action), the expiry and the notes when there are any.
class _Details extends ConsumerWidget {
  const _Details({required this.card});

  final InsuranceCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final number = card.memberNumber;
    return UsraListCard(
      children: [
        _Field(label: l.insuranceCard, value: Text(card.label)),
        if (card.insurer case final insurer?)
          _Field(label: l.insuranceInsurer, value: Text(insurer)),
        if (number != null)
          _Field(
            label: l.insuranceMemberNumber,
            // Numbers read left to right even in an Arabic sentence.
            value: SelectableText(
              number,
              key: const ValueKey('insurance-number'),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
            ),
            trailing: TextButton(
              key: const ValueKey('insurance-copy'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final copied = await ref
                    .read(sensitiveClipboardProvider)
                    .copy(number);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      copied ? l.insuranceNumberCopied : l.insuranceCopyFailed,
                    ),
                  ),
                );
              },
              // Short on screen; a screen reader hears what it copies.
              child: Text(
                l.insuranceCopyShort,
                semanticsLabel: l.insuranceCopyNumber,
              ),
            ),
          ),
        if (card.expiresOn != null)
          _Field(
            label: l.insuranceExpiry,
            value: ExpiryLine(expiresOn: card.expiresOn),
          ),
        if (card.notes case final notes?)
          _Field(label: l.insuranceNotes, value: Text(notes)),
      ],
    );
  }
}

/// One saved field: its name, muted and small, over its value.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.trailing});

  final String label;
  final Widget value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final minHeight =
        Theme.of(context).listTileTheme.minTileHeight ?? listRowMinHeight;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UsraSpacing.s4,
          vertical: UsraSpacing.s2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: UsraType.label.copyWith(
                      color: c.inkMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  DefaultTextStyle.merge(
                    style: UsraType.body.copyWith(
                      color: c.ink,
                      height: 24 / 16,
                      fontWeight: FontWeight.w500,
                    ),
                    child: value,
                  ),
                ],
              ),
            ),
            if (trailing case final t?) ...[
              const SizedBox(width: UsraSpacing.s3),
              t,
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends ConsumerStatefulWidget {
  const _ShareButton({required this.profileId, required this.card});

  final String profileId;
  final InsuranceCard card;

  @override
  ConsumerState<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends ConsumerState<_ShareButton> {
  /// Marking a photo takes a moment; a second share would delete the first's
  /// files from under it.
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final person = ref
        .watch(profileProvider(widget.profileId))
        .value
        ?.displayName;
    return FilledButton.icon(
      key: const ValueKey('insurance-share'),
      style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
      // Wait for the name: the message is useless without it.
      onPressed: person == null || _busy ? null : () => _share(person),
      icon: const Icon(Icons.share_outlined),
      label: Text(l.insuranceShare),
    );
  }

  Future<void> _share(String person) async {
    final card = widget.card;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failed = l.shareFailed;
    final box = context.findRenderObject() as RenderBox?;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).format(nowOf(context));
    // No insurer: only the date. The card's own name may be a private
    // nickname ("Work 2") and shouldn't go on a picture sent to someone.
    final mark = card.insurer == null
        ? date
        : l.insuranceWatermark(card.insurer!, date);
    final store = ref.read(cardPhotoStoreProvider);
    final watermark = ref.read(photoWatermarkerProvider);
    final photos = [?card.frontPhoto, ?card.backPhoto];
    setState(() => _busy = true);
    try {
      final go = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ShareSheet(
          hasPhoto: photos.isNotEmpty,
          // Exactly what will be sent, marked the same way.
          previews: [
            for (final path in photos)
              store.read(path).then((bytes) => watermark(bytes, mark)),
          ],
        ),
      );
      if (go != true || !mounted) return;
      await shareStoredPhotos(
        ref,
        store,
        photos,
        text: insuranceShareText(person, card),
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        alreadyWarned: true,
        transform: (bytes) => watermark(bytes, mark),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Says what sending a card means, and shows it with the mark it will carry.
class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.hasPhoto, required this.previews});

  final bool hasPhoto;
  final List<Future<Uint8List>> previews;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: FutureBuilder<List<Uint8List>>(
        future: Future.wait(previews),
        builder: (context, snapshot) {
          // A photo that can't be marked isn't sent.
          final failed = snapshot.hasError;
          final ready = snapshot.hasData;
          return SingleChildScrollView(
            key: const ValueKey('insurance-share-sheet'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasPhoto
                      ? l.insuranceShareWarning
                      : l.insuranceShareWarningNoPhoto,
                  key: const ValueKey('insurance-share-warning'),
                  style: UsraType.body.copyWith(color: context.usra.ink),
                ),
                const SizedBox(height: UsraSpacing.s3),
                if (failed)
                  Text(
                    l.shareFailed,
                    key: const ValueKey('insurance-share-unmarkable'),
                    style: UsraType.body.copyWith(color: context.usra.ink),
                  )
                else if (!ready)
                  const Center(child: CircularProgressIndicator())
                else
                  for (final bytes in snapshot.data!) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        bytes,
                        key: const ValueKey('insurance-watermark-preview'),
                        height: 200,
                        fit: BoxFit.contain,
                        semanticLabel: l.insuranceCard,
                        errorBuilder: (_, _, _) => const SizedBox(height: 48),
                      ),
                    ),
                    const SizedBox(height: UsraSpacing.s2),
                  ],
                const SizedBox(height: UsraSpacing.s2),
                FilledButton(
                  key: const ValueKey('insurance-share-go'),
                  onPressed: ready ? () => Navigator.pop(context, true) : null,
                  child: Text(l.shareWarningGo),
                ),
                const SizedBox(height: UsraSpacing.s2),
                OutlinedButton(
                  key: const ValueKey('insurance-share-cancel'),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l.shareWarningCancel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
