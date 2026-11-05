import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';

final episodesProvider = StreamProvider.family<List<SickEpisode>, String>(
  (ref, profileId) => ref.watch(databaseProvider).watchEpisodes(profileId),
);

final episodeProvider = StreamProvider.family<SickEpisode?, String>(
  (ref, id) => ref.watch(databaseProvider).watchEpisode(id),
);

final readingsProvider =
    StreamProvider.family<List<TemperatureReading>, String>(
      (ref, episodeId) => ref.watch(databaseProvider).watchReadings(episodeId),
    );

final givenMedicinesProvider =
    StreamProvider.family<List<GivenMedicine>, String>(
      (ref, episodeId) =>
          ref.watch(databaseProvider).watchGivenMedicines(episodeId),
    );
