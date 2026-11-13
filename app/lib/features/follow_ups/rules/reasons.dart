import 'package:flutter/widgets.dart';

import '../../../core/follow_ups/follow_up.dart';
import '../../../l10n/app_localizations.dart';
import '../conditions.dart';
import '../../../core/util/separator.dart';

/// Reason parts joined into one line.
String joinReasons(Iterable<String?> parts) =>
    parts.whereType<String>().where((p) => p.isNotEmpty).join(partSeparator);

String conditionName(AppLocalizations l, Condition condition) =>
    switch (condition) {
      Condition.diabetes => l.conditionDiabetes,
      Condition.hypertension => l.conditionHypertension,
      Condition.heart => l.conditionHeart,
      Condition.highCholesterol => l.conditionHighCholesterol,
      Condition.kidney => l.conditionKidney,
    };

/// "لأن عندها سكر": Arabic follows the person's sex.
String becauseCondition(BuildContext c, String? sex, Condition condition) {
  final l = AppLocalizations.of(c);
  return l.fuBecauseCondition(sex ?? 'other', conditionName(l, condition));
}

/// "Last one 8 months ago", or "none recorded yet".
String lastDone(BuildContext c, DateTime? last, DateTime today) {
  final l = AppLocalizations.of(c);
  if (last == null) return l.fuNeverRecorded;
  final days = dayOf(today).difference(dayOf(last)).inDays;
  return l.fuLastDoneMonths((days / 30.4375).floor().clamp(0, 999));
}
