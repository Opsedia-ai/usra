import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../log.dart';
import '../preferences.dart';
import '../routing/app_router.dart';
import 'app_lock.dart';
import 'device_integrity.dart';

/// Shows the rooted / jailbroken phone warning once per install ([S8],
/// see [DeviceIntegrity]), when the app is unlocked and the first-run tour
/// is done. Never blocks anything.
class RootWarning extends ConsumerStatefulWidget {
  const RootWarning({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RootWarning> createState() => _RootWarningState();
}

class _RootWarningState extends ConsumerState<RootWarning> {
  late final AppLock _lock = ref.read(appLockProvider);
  var _done = false;
  var _checking = false;

  @override
  void initState() {
    super.initState();
    _lock.addListener(_maybeShow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    _lock.removeListener(_maybeShow);
    super.dispose();
  }

  Future<void> _maybeShow() async {
    if (_done || _checking || !mounted) return;
    if (_lock.locked ||
        ref.read(tutorialProvider) ||
        ref.read(onboardingProvider)) {
      return;
    }
    _checking = true;
    try {
      final prefs = ref.read(keyValueStoreProvider);
      if (!await rootWarningDue(ref.read(deviceIntegrityProvider), prefs)) {
        _done = true;
        return;
      }
      if (!mounted || _lock.locked) return;
      final navigator = ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (navigator == null || !navigator.mounted) return;
      _done = true;
      try {
        await prefs.setBool(PrefKeys.rootWarningShown, true);
      } catch (e) {
        Log.error('Root warning save failed', e);
      }
      if (!navigator.mounted) return;
      await showDialog<void>(
        context: navigator,
        builder: (context) {
          final l = AppLocalizations.of(context);
          return AlertDialog(
            key: const ValueKey('root-warning'),
            icon: const Icon(Icons.gpp_maybe_outlined),
            title: Text(l.rootWarningTitle),
            content: SingleChildScrollView(child: Text(l.rootWarningBody)),
            actions: [
              FilledButton(
                key: const ValueKey('root-warning-ok'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.rootWarningOk),
              ),
            ],
          );
        },
      );
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The tour ending is one of the moments to look again.
    ref.listen(tutorialProvider, (_, showing) {
      if (!showing) _maybeShow();
    });
    ref.listen(onboardingProvider, (_, pending) {
      if (!pending) _maybeShow();
    });
    return widget.child;
  }
}
