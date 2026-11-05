import 'package:clock/clock.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import 'infant_log.dart';

/// Feeds, sleep and diapers for a baby under one, one tap each, with the
/// day added up. A diary for the family and the pediatrician.
class InfantLogScreen extends ConsumerWidget {
  const InfantLogScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final timeline = ref.watch(timelineProvider(profileId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.infantLogTitle),
        leading: BackButton(onPressed: () => context.go('/family/$profileId')),
      ),
      body: switch ((profile, timeline)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('$error')),
        (AsyncValue(value: final p?), AsyncValue(value: final events?)) =>
          isUnderOne(p.birthDate, clock.now())
              ? _Body(profile: p, events: events)
              : Center(child: Text(l.infantLogUnderOneOnly)),
        (AsyncData(value: null), _) => Center(child: Text(l.profileNotFound)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.profile, required this.events});

  final Profile profile;
  final List<MedicalEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final now = clock.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final today = entriesOn(events, now);

    Widget tap(String key, IconData icon, String label, VoidCallback onTap) =>
        SizedBox(
          width: 104,
          child: FilledButton.tonal(
            key: ValueKey('log-$key'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: onTap,
            child: Column(
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(profile.displayName, style: text.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            tap('breast', Icons.child_care, l.logBreast, () {
              _add(context, ref, InfantLog.feed, {InfantLog.kind: 'breast'});
            }),
            tap('bottle', Icons.local_drink_outlined, l.logBottle, () async {
              final ml = await _pick(context, l.logBottleAmount, const [
                30,
                60,
                90,
                120,
                150,
                180,
              ], (v) => l.logMl(v));
              if (ml == null || !context.mounted) return;
              _add(context, ref, InfantLog.feed, {
                InfantLog.kind: 'bottle',
                if (ml > 0) InfantLog.amountMl: ml,
              });
            }),
            tap('solids', Icons.rice_bowl_outlined, l.logSolids, () {
              _add(context, ref, InfantLog.feed, {InfantLog.kind: 'solids'});
            }),
            tap('sleep', Icons.bedtime_outlined, l.logSleep, () async {
              final minutes = await _pick(context, l.logSleepHowLong, const [
                30,
                60,
                90,
                120,
                180,
                240,
              ], (v) => _duration(l, v));
              if (minutes == null || minutes == 0 || !context.mounted) return;
              _add(context, ref, InfantLog.sleep, {InfantLog.minutes: minutes});
            }),
            tap('wet', Icons.water_drop_outlined, l.logWet, () {
              _add(context, ref, InfantLog.diaper, {InfantLog.kind: 'wet'});
            }),
            tap('dirty', Icons.baby_changing_station_outlined, l.logDirty, () {
              _add(context, ref, InfantLog.diaper, {InfantLog.kind: 'dirty'});
            }),
          ],
        ),
        const SizedBox(height: 20),
        _SummaryCard(
          key: const ValueKey('log-summary-today'),
          title: l.logToday,
          summary: summarizeDay(events, now),
        ),
        const SizedBox(height: 8),
        _SummaryCard(
          key: const ValueKey('log-summary-yesterday'),
          title: l.logYesterday,
          summary: summarizeDay(events, yesterday),
        ),
        const SizedBox(height: 16),
        for (final e in today) _EntryTile(event: e),
        const SizedBox(height: 16),
        Text(
          l.logDisclaimer,
          style: text.bodySmall?.copyWith(color: UsraColors.textMuted),
        ),
      ],
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    String type,
    Map<String, Object?> data,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);
    try {
      final id = await db.addEvent(
        profileId: profile.id,
        type: type,
        occurredAt: clock.now(),
        dataJson: jsonEncode(data),
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l.logSaved),
            action: SnackBarAction(
              label: l.followUpUndo,
              onPressed: () => _delete(messenger, db, id, l.saveFailed),
            ),
          ),
        );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
    }
  }

  /// A choice of [values]; 0 is "don't know". Null when dismissed.
  static Future<int?> _pick(
    BuildContext context,
    String title,
    List<int> values,
    String Function(int) label,
  ) {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final v in values)
                    ActionChip(
                      key: ValueKey('pick-$v'),
                      label: Text(label(v)),
                      onPressed: () => Navigator.pop(sheet, v),
                    ),
                  ActionChip(
                    key: const ValueKey('pick-0'),
                    label: Text(l.logSkip),
                    onPressed: () => Navigator.pop(sheet, 0),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _delete(
  ScaffoldMessengerState messenger,
  AppDatabase db,
  String id,
  String failed,
) async {
  try {
    await db.softDeleteEvent(id);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

String _duration(AppLocalizations l, int minutes) =>
    l.logDuration(minutes ~/ 60, minutes % 60);

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({super.key, required this.title, required this.summary});

  final String title;
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final s = summary;
    final empty = s.feeds == 0 && s.sleepMinutes == 0 && s.wet + s.dirty == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: 6),
            if (empty)
              Text(l.logEmptyDay)
            else ...[
              Text(l.logSummaryFeeds(s.feeds, s.breast, s.bottle, s.solids)),
              if (s.bottleMl > 0) Text(l.logSummaryBottleMl(s.bottleMl)),
              Text(l.logSummarySleep(_duration(l, s.sleepMinutes))),
              Text(l.logSummaryDiapers(s.wet, s.dirty)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.event});

  final MedicalEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final data = decodeRecordData(event.dataJson);
    final kind = data[InfantLog.kind];
    final (icon, label) = switch ((event.type, kind)) {
      (InfantLog.feed, 'breast') => (Icons.child_care, l.logBreast),
      (InfantLog.feed, 'bottle') => (
        Icons.local_drink_outlined,
        switch (data[InfantLog.amountMl]) {
          final num ml when ml > 0 => '${l.logBottle} · ${l.logMl(ml.round())}',
          _ => l.logBottle,
        },
      ),
      (InfantLog.feed, _) => (Icons.rice_bowl_outlined, l.logSolids),
      (InfantLog.sleep, _) => (
        Icons.bedtime_outlined,
        switch (data[InfantLog.minutes]) {
          final num m when m > 0 =>
            '${l.logSleep} · ${_duration(l, m.round())}',
          _ => l.logSleep,
        },
      ),
      (_, 'wet') => (Icons.water_drop_outlined, l.diaperWet),
      (_, 'dirty') => (Icons.baby_changing_station_outlined, l.diaperDirty),
      _ => (Icons.baby_changing_station_outlined, l.diaperBoth),
    };
    return ListTile(
      key: ValueKey('log-entry-${event.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: UsraColors.primary),
      title: Text(label),
      subtitle: Text(DateFormat.jm(locale).format(event.occurredAt.toLocal())),
      trailing: IconButton(
        tooltip: l.logDelete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _delete(
          ScaffoldMessenger.of(context),
          ref.read(databaseProvider),
          event.id,
          l.saveFailed,
        ),
      ),
    );
  }
}
