import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../log.dart';
import '../preferences.dart';

/// Signs that the phone is rooted (Android) or jailbroken (iOS), checked
/// on the phone only (security plan S8). Nothing is sent anywhere.
///
/// Usra only warns, once, and never blocks: many budget phones in Egypt
/// come rooted, and the family's records matter more than our policy. On
/// such a phone other apps can read Usra's files and screen, so the
/// warning says so plainly.
///
/// The checks are plain heuristics in `MainActivity.kt` and
/// `AppDelegate.swift` (an `su` binary, Magisk, test-keys builds; Cydia,
/// Sileo, `/var/jb`, a broken sandbox, injected tweak libraries) rather
/// than an SDK: the open-source ones (RootBeer, DTTJailbreakDetection via
/// flutter_jailbreak_detection) add little over these and are barely
/// maintained, and the commercial ones (freeRASP and the like) are heavy
/// and report to their vendor. A determined user can hide root from any
/// of them; for a warning that's fine. Paid cloud APIs will use Play
/// Integrity / App Attest instead (S8, later).
abstract class DeviceIntegrity {
  /// What was found; empty when nothing was.
  Future<List<String>> signs();
}

class PlatformDeviceIntegrity implements DeviceIntegrity {
  const PlatformDeviceIntegrity();

  static const channel = MethodChannel('usra/integrity');

  @override
  Future<List<String>> signs() async {
    try {
      final found = await channel.invokeListMethod<String>('signs');
      return found ?? const [];
    } on MissingPluginException {
      return const [];
    } catch (e) {
      Log.error('Integrity check failed', e);
      return const [];
    }
  }
}

final deviceIntegrityProvider = Provider<DeviceIntegrity>(
  (ref) => const PlatformDeviceIntegrity(),
);

/// Whether to show the rooted / jailbroken warning now: something was
/// found and it hasn't been shown on this install yet.
Future<bool> rootWarningDue(
  DeviceIntegrity integrity,
  KeyValueStore prefs,
) async {
  if (prefs.getBool(PrefKeys.rootWarningShown) == true) return false;
  return (await integrity.signs()).isNotEmpty;
}
