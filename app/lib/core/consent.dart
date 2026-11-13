import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

/// The privacy policy version the consent screen asks agreement to, as the
/// published policy states it (https://opsedia.ai/usra/en/privacy, "Version").
///
/// Change it whenever the published privacy policy or terms change in a way
/// people must agree to again: everyone is then asked again before the app
/// opens. Egypt's PDPL 151/2020 treats health data as sensitive, so it needs
/// explicit consent before any is saved.
const consentPolicyVersion = '1.0';

/// Where the consent screen is.
const consentPath = '/consent';

/// "Delete all my data", the one page open without consent: someone who
/// doesn't agree to an updated policy can still erase everything. Matches
/// `deleteDataPath` (a test checks).
const consentDeletePath = '/settings/delete-all';

/// Where consent is saved. Overridden in `main.dart` with the same shared
/// preferences as [keyValueStoreProvider], so "Delete all my data" clears it
/// and the next first run asks again. The default, used by tests, already
/// holds consent to this version, like the tours already seen in
/// [keyValueStoreProvider]; tests of the consent screen pass their own store.
final consentStoreProvider = Provider<KeyValueStore>(
  (ref) => MemoryKeyValueStore({
    PrefKeys.consentVersion: consentPolicyVersion,
    PrefKeys.consentAt: '2026-11-13T00:00:00.000Z',
  }),
);

/// Whether the consent screen must be shown: nothing agreed on this phone
/// yet, or agreement to an older policy version.
final consentNeededProvider = NotifierProvider<ConsentController, bool>(
  ConsentController.new,
);

class ConsentController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(consentStoreProvider).getString(PrefKeys.consentVersion) !=
      consentPolicyVersion;

  /// The version agreed to before this one, if any: the screen then says the
  /// policy changed.
  String? get previousVersion =>
      ref.read(consentStoreProvider).getString(PrefKeys.consentVersion);

  /// Saves the policy version and the time (UTC) of agreement. The time is
  /// saved first, so a version on record always has its time with it. If
  /// saving fails the screen stays and says so.
  Future<void> agree(DateTime now) async {
    final store = ref.read(consentStoreProvider);
    await store.setString(PrefKeys.consentAt, now.toUtc().toIso8601String());
    await store.setString(PrefKeys.consentVersion, consentPolicyVersion);
    state = false;
  }
}
