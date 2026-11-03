import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/follow_ups/follow_up.dart';
import '../../core/providers.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/member_screen.dart' show timelineProvider;
import 'dismissals.dart';

/// Today, for follow-up due dates; refreshed at midnight so an app left
/// open doesn't keep yesterday's severities. Overridden in tests.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(midnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});

/// Every follow-up rule the registered modules contribute.
final followUpRulesProvider = Provider<List<FollowUpRule>>(
  (ref) => ref.watch(moduleRegistryProvider).followUpRules,
);

/// A follow-up with the person it's for.
typedef PersonFollowUp = ({Profile profile, FollowUp followUp});

List<PersonFollowUp> _visibleFor(
  Ref ref,
  Profile profile,
  List<MedicalEvent> events,
) {
  final dismissed = ref.watch(dismissedFollowUpsProvider);
  return [
    for (final f in followUpsFor(
      FollowUpSubject(profile, events),
      ref.watch(todayProvider),
      ref.watch(followUpRulesProvider),
    ))
      if (!dismissed.contains(f.cycleKey)) (profile: profile, followUp: f),
  ];
}

/// The whole family's follow-ups not hidden this cycle, soonest first.
final familyFollowUpsProvider = Provider<AsyncValue<List<PersonFollowUp>>>((
  ref,
) {
  final profiles = ref.watch(profilesProvider);
  if (profiles is! AsyncData<List<Profile>>) {
    return profiles.whenData((_) => const []);
  }
  final all = <PersonFollowUp>[];
  for (final p in profiles.value) {
    final events = ref.watch(timelineProvider(p.id));
    if (events is! AsyncData<List<MedicalEvent>>) {
      return events.whenData((_) => const []);
    }
    all.addAll(_visibleFor(ref, p, events.value));
  }
  return AsyncData(
    all..sort((a, b) => a.followUp.dueOn.compareTo(b.followUp.dueOn)),
  );
});

/// One person's follow-ups not hidden this cycle, soonest first.
final personFollowUpsProvider =
    Provider.family<AsyncValue<List<PersonFollowUp>>, String>((ref, id) {
      final family = ref.watch(familyFollowUpsProvider);
      return family.whenData(
        (all) => [
          for (final f in all)
            if (f.profile.id == id) f,
        ],
      );
    });
