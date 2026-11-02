import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/theme.dart';
import 'core/preferences.dart';
import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'l10n/app_localizations.dart';

/// Simple Mode never makes text bigger than this, so screens still fit
/// when the phone's own text size is already at 2×.
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
      builder: simple ? _biggerText : null,
    );
  }
}

/// Grows text by [simpleTextScale] on top of the phone's own text size.
Widget _biggerText(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  final system = media.textScaler.scale(16) / 16;
  final scale = (system * simpleTextScale).clamp(
    simpleTextScale,
    maxSimpleTextScale,
  );
  return MediaQuery(
    data: media.copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
}
