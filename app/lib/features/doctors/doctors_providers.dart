import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

final doctorsProvider = StreamProvider<List<Doctor>>(
  (ref) => ref.watch(databaseProvider).watchDoctors(),
);

final doctorProvider = StreamProvider.family<Doctor?, String>(
  (ref, id) => ref.watch(databaseProvider).watchDoctor(id),
);

final doctorVisitsProvider = StreamProvider.family<List<DoctorVisit>, String>(
  (ref, id) => ref.watch(databaseProvider).watchDoctorVisits(id),
);
