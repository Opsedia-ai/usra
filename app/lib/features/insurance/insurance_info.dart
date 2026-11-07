import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/util/dates.dart';
import '../../l10n/app_localizations.dart';

/// Expiry is stored as UTC midnight; this is that calendar day, locally.
DateTime? expiryDay(DateTime? expiresOn) =>
    expiresOn == null ? null : storedDay(expiresOn);

/// How urgent a card's expiry is on [today]: expired is urgent, within 30
/// days is a heads-up, otherwise just information. Null if no expiry date.
Severity? expirySeverity(DateTime? expiresOn, DateTime today) {
  final day = expiryDay(expiresOn);
  if (day == null) return null;
  final now = DateTime(today.year, today.month, today.day);
  if (day.isBefore(now)) return Severity.urgent;
  // Calendar days, so a daylight-saving change can't shift the boundary.
  final daysLeft = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  return daysLeft <= 30 ? Severity.headsUp : Severity.info;
}

/// The short message sent with the card photos. Always Arabic, since it
/// goes to a clinic receptionist, not to the person using the app.
String insuranceShareText(String personName, InsuranceCard card) {
  final l = lookupAppLocalizations(const Locale('ar'));
  return [
    l.insuranceShareHeader(personName),
    '${l.insuranceCard}: ${card.label}',
    if (card.insurer != null) '${l.insuranceInsurer}: ${card.insurer}',
    if (card.memberNumber != null)
      '${l.insuranceMemberNumber}: ${card.memberNumber}',
  ].join('\n');
}

/// "Expired", "Expires soon" or "Valid until", coloured by urgency.
class ExpiryChip extends StatelessWidget {
  const ExpiryChip({super.key, required this.expiresOn});

  final DateTime? expiresOn;

  @override
  Widget build(BuildContext context) {
    final severity = expirySeverity(expiresOn, DateTime.now());
    if (severity == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).format(expiryDay(expiresOn)!);
    return StatusChip(
      severity: severity,
      label: switch (severity) {
        Severity.urgent => l.insuranceExpired(date),
        Severity.headsUp => l.insuranceExpiresSoon(date),
        _ => l.insuranceValidUntil(date),
      },
    );
  }
}
