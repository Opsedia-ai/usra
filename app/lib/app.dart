import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/theme.dart';
import 'core/preferences.dart';
import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'features/app_lock/lock_screen.dart';
import 'l10n/app_localizations.dart';

/// Simple Mode grows text up to this, so screens still fit when the phone's
/// own text size is already at 2×. A phone set larger keeps its own size.
const maxSimpleTextScale = 2.6;

class UsraApp extends ConsumerWidget {
  const UsraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simple = ref.watch(simpleModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildUsraTheme(simple: simple),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      // Always wrapped, so switching modes or locking doesn't rebuild the
      // page stack. The lock covers every page, deep links included.
      builder: (context, child) =>
          _textScale(context, AppLockGate(child: child!), simple: simple),
    );
  }
}

/// In Simple Mode, grows text by [simpleTextScale] on top of the phone's
/// own text size, up to [maxSimpleTextScale], but never below the phone's.
Widget _textScale(BuildContext context, Widget child, {required bool simple}) {
  final media = MediaQuery.of(context);
  final system = media.textScaler.scale(16) / 16;
  final grown = (system * simpleTextScale).clamp(
    simpleTextScale,
    maxSimpleTextScale,
  );
  return MediaQuery(
    data: simple && grown > system
        ? media.copyWith(textScaler: TextScaler.linear(grown))
        : media,
    child: child,
  );
}
