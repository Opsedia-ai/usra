import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_providers.dart';

/// Starts a due automatic backup when the app comes to the front.
///
/// Only then: iOS can also start the app in the background for a reminder's
/// Taken button, possibly locked, when no backup should run.
class AutoBackupTrigger extends ConsumerStatefulWidget {
  const AutoBackupTrigger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoBackupTrigger> createState() => _AutoBackupTriggerState();
}

class _AutoBackupTriggerState extends ConsumerState<AutoBackupTrigger>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    binding.addPostFrameCallback((_) {
      if (mounted && binding.lifecycleState == AppLifecycleState.resumed) {
        ref.read(autoBackupProvider.notifier).runIfDue();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(autoBackupProvider.notifier).runIfDue();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
