import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';

import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/list_row.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../l10n/app_localizations.dart';
import 'insurance_info.dart';
import '../medicines/medicines_providers.dart' show clockProvider;
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
        Semantics(
          header: true,
          child: Text(
            l.insuranceTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: UsraSpacing.s2),
        ...cards.when(
          loading: () => [const LinearProgressIndicator()],
          error: (e, _) => [Text('$e')],
          data: (list) => [
            if (list.isNotEmpty) ...[
              UsraListCard(
                children: [
                  for (final c in list)
                    _CardTile(profileId: profileId, card: c),
                ],
              ),
              const SizedBox(height: UsraSpacing.s3),
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
    final insurer = card.insurer;
    return UsraListRow(
      key: ValueKey('insurance-${card.id}'),
      onTap: () => context.push('/family/$profileId/insurance/${card.id}'),
      leading: const IconBox(icon: Icons.credit_card),
      title: card.label,
      emphasized: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (insurer != null)
            Text(
              insurer,
              style: UsraType.label.copyWith(
                color: context.usra.inkMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          if (card.expiresOn != null) ExpiryLine(expiresOn: card.expiresOn),
        ],
      ),
    );
  }
}

/// "Expired", "Expires soon" or "Valid until": an amber dot and the words
/// when it needs renewing, otherwise plain muted text. An expired card isn't
/// an emergency, so never red.
class ExpiryLine extends ConsumerWidget {
  const ExpiryLine({super.key, required this.expiresOn});

  final DateTime? expiresOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final severity = expirySeverity(expiresOn, ref.watch(clockProvider)());
    if (severity == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).format(expiryDay(expiresOn)!);
    return switch (severity) {
      Severity.urgent => StatusDotText(
        key: const ValueKey('insurance-expiry'),
        label: l.insuranceExpired(date),
      ),
      Severity.headsUp => StatusDotText(
        key: const ValueKey('insurance-expiry'),
        label: l.insuranceExpiresSoon(date),
      ),
      _ => Text(
        l.insuranceValidUntil(date),
        key: const ValueKey('insurance-expiry'),
        style: UsraType.label.copyWith(
          color: context.usra.inkMuted,
          fontWeight: FontWeight.w400,
        ),
      ),
    };
  }
}
