import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'insurance_info.dart';
import 'insurance_providers.dart';

/// A person's insurance cards, shown on their page.
class InsuranceSection extends ConsumerWidget {
  const InsuranceSection({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cards = ref.watch(insuranceCardsProvider(profileId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.insuranceTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...cards.when(
          loading: () => [const LinearProgressIndicator()],
          error: (e, _) => [Text('$e')],
          data: (list) => [
            for (final c in list) ...[
              _CardTile(profileId: profileId, card: c),
              const SizedBox(height: 8),
            ],
          ],
        ),
        OutlinedButton.icon(
          key: const ValueKey('insurance-add'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: () => context.push('/family/$profileId/insurance/new'),
          icon: const Icon(Icons.add_card_outlined),
          label: Text(l.insuranceAdd),
        ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.profileId, required this.card});

  final String profileId;
  final InsuranceCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: ValueKey('insurance-${card.id}'),
        onTap: () => context.push('/family/$profileId/insurance/${card.id}'),
        leading: CircleAvatar(
          backgroundColor: context.usra.primarySoft,
          child: Icon(Icons.credit_card, color: context.usra.primary),
        ),
        title: Text(card.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.insurer != null) Text(card.insurer!),
            if (card.expiresOn != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ExpiryChip(expiresOn: card.expiresOn),
              ),
          ],
        ),
      ),
    );
  }
}
