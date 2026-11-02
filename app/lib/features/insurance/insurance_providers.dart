import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

final insuranceCardsProvider =
    StreamProvider.family<List<InsuranceCard>, String>(
      (ref, profileId) =>
          ref.watch(databaseProvider).watchInsuranceCards(profileId),
    );

final insuranceCardProvider = StreamProvider.family<InsuranceCard?, String>(
  (ref, id) => ref.watch(databaseProvider).watchInsuranceCard(id),
);
