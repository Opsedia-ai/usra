import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/util/periods.dart';

/// How many periods the bar chart shows, the shown one last.
const spendingTrendLength = 6;

/// The period on screen (by its start) and whose spending it is.
typedef SpendingView = ({
  SpendingPeriod period,
  DateTime start,
  String? profileId,
});

/// Totals of the last [spendingTrendLength] periods, ending with the shown one.
final spendingTrendProvider = StreamProvider.autoDispose
    .family<List<int>, SpendingView>((ref, v) {
      return ref
          .watch(databaseProvider)
          .watchSpendingTotals(
            v.period.boundsEndingAt(v.start, spendingTrendLength),
            profileId: v.profileId,
          );
    });

/// The shown period's spending split one way.
final spendingSplitProvider = StreamProvider.autoDispose
    .family<List<SpendingSlice>, (SpendingGroup, SpendingView)>((ref, key) {
      final (group, v) = key;
      return ref
          .watch(databaseProvider)
          .watchSpendingBy(
            group,
            from: v.start,
            to: v.period.shift(v.start, 1),
            profileId: v.profileId,
          );
    });
