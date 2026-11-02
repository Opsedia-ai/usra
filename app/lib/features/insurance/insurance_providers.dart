import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

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

/// Picks a photo and returns its temporary path, or null if cancelled.
/// Overridden in tests.
final photoPickerProvider = Provider<Future<String?> Function(ImageSource)>(
  (ref) => (source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      // A card is readable at this size and stays a few hundred KB.
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    return photo?.path;
  },
);

/// Opens the system share sheet. Overridden in tests.
final shareProvider = Provider<Future<void> Function(ShareParams)>(
  (ref) =>
      (params) => SharePlus.instance.share(params),
);
