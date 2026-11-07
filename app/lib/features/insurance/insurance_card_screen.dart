import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/security/sensitive_clipboard.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider;
import 'insurance_info.dart';
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
            IconButton(
              key: const ValueKey('insurance-delete'),
              tooltip: l.insuranceDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, c),
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
              _ShareButton(profileId: profileId, card: c),
              if (c.memberNumber case final number?) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('insurance-copy'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(UsraSizes.touchTarget),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final copied = await ref
                        .read(sensitiveClipboardProvider)
                        .copy(number);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          copied
                              ? l.insuranceNumberCopied
                              : l.insuranceCopyFailed,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(l.insuranceCopyNumber),
                ),
              ],
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
        Text(label, style: Theme.of(context).textTheme.labelLarge),
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
            borderRadius: BorderRadius.circular(12),
            child: photo,
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.card});

  final InsuranceCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.expiresOn != null) ExpiryChip(expiresOn: card.expiresOn),
        for (final (label, value) in [
          (l.insuranceInsurer, card.insurer),
          (l.insuranceMemberNumber, card.memberNumber),
          (l.insuranceNotes, card.notes),
        ])
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelLarge?.copyWith(
                      color: context.usra.inkMuted,
                    ),
                  ),
                  SelectableText(value, style: text.titleLarge),
                ],
              ),
            ),
      ],
    );
  }
}

class _ShareButton extends ConsumerWidget {
  const _ShareButton({required this.profileId, required this.card});

  final String profileId;
  final InsuranceCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final person = ref.watch(profileProvider(profileId)).value?.displayName;
    return FilledButton.icon(
      key: const ValueKey('insurance-share'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        backgroundColor: Severity.good.foregroundOf(context),
      ),
      // Wait for the name: the message is useless without it.
      onPressed: person == null ? null : () => _share(context, ref, person),
      icon: const Icon(Icons.share_outlined),
      label: Text(l.insuranceShare),
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    String person,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).shareFailed;
    final box = context.findRenderObject() as RenderBox?;
    try {
      await shareStoredPhotos(
        ref,
        ref.read(cardPhotoStoreProvider),
        [?card.frontPhoto, ?card.backPhoto],
        text: insuranceShareText(person, card),
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}
