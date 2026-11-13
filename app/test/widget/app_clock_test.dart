import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/follow_ups/follow_ups_providers.dart';
import 'package:usra/features/insurance/insurance_section.dart' show ExpiryLine;
import 'package:usra/l10n/app_localizations.dart';

import '../support/screen_harness.dart';

/// Screens decide "today" from the app's clock, not the phone's (bug 13), so
/// they agree with each other around midnight and can be tested on a date.
void main() {
  // Years from the real date, so neither the phone's clock nor the fixed one
  // can land on the same side by chance.
  final fixed = DateTime(2019, 6, 15, 10);

  Widget app(Widget child, {DateTime? now}) => ProviderScope(
    overrides: [if (now != null) clockProvider.overrideWithValue(() => now)],
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('insurance expiry is read against the app clock', (tester) async {
    // Expired by the phone's clock, still months away by the fixed one.
    final expires = DateTime.utc(2020, 1, 1);
    await tester.pumpWidget(app(ExpiryLine(expiresOn: expires), now: fixed));
    await tester.pumpAndSettle();
    expect(find.textContaining('ساري لحد'), findsOneWidget);
    expect(find.textContaining('انتهى'), findsNothing);

    // Two days later than the fixed clock, it's within a month: expires soon.
    await tester.pumpWidget(
      app(ExpiryLine(expiresOn: DateTime.utc(2019, 6, 17)), now: fixed),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('بينتهي'), findsOneWidget);
  });

  testWidgets('without a scope, nowOf falls back to the phone', (tester) async {
    late DateTime read;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          read = nowOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(read.difference(DateTime.now()).inMinutes.abs(), lessThan(1));
  });

  test('follow-ups take today from the app clock', () {
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => fixed)],
    );
    addTearDown(container.dispose);
    expect(container.read(todayProvider), fixed);
  });

  testWidgets('a new record is dated today by the app clock', (tester) async {
    final h = ScreenHarness()
      ..overrides = [clockProvider.overrideWithValue(() => fixed)];
    addTearDown(h.dispose);
    final id = await tester.runAsync(() => h.db.addProfile('بنتي'));
    await h.open(tester, '/family/$id/add/visit');
    final shown = DateFormat.yMMMd('ar').format(DateTime(2019, 6, 15));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('field-occurredAt')),
        matching: find.text(shown),
      ),
      findsOneWidget,
    );
  });
}
