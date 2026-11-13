import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/preferences.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_providers.dart' show lastBackupProvider;
import '../medicines/medicines_providers.dart'
    show reminderAccessProvider, reminderSchedulerProvider;
import '../medicines/reminder_permission.dart';

/// Set once someone hides the cards.
const homeSetupHiddenKey = PrefKeys.homeSetupHidden;

/// A new family's next steps, each only until it's done, and none required.
/// Each permission is asked for when its card is tapped, not before.
class HomeSetupCards extends ConsumerStatefulWidget {
  const HomeSetupCards({super.key, required this.people});

  final List<Profile> people;

  @override
  ConsumerState<HomeSetupCards> createState() => _HomeSetupCardsState();
}

class _HomeSetupCardsState extends ConsumerState<HomeSetupCards> {
  late var _hidden =
      ref.read(keyValueStoreProvider).getBool(homeSetupHiddenKey) ?? false;

  /// Coming back from the phone's settings, the answer may have changed.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(reminderAccessProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// The phone's prompt the first time; after a "no", the phone's Settings,
  /// since it won't ask again. The card says which.
  Future<void> _askForReminders() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final prefs = ref.read(keyValueStoreProvider);
    try {
      await allowReminders(scheduler, prefs, exactAlarms: false);
    } catch (_) {
      // No notifications on this phone: the card stays.
    }
    if (mounted) ref.invalidate(reminderAccessProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || widget.people.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final owner = widget.people.first;
    final access = ref.watch(reminderAccessProvider).value;
    final noReminders = access?.notifications == false;
    final remindersBlocked =
        access != null &&
        notificationsBlocked(access, ref.read(keyValueStoreProvider));
    final noEmergency =
        owner.bloodType == null &&
        owner.allergies == null &&
        owner.emergencyPhone == null;
    final cards = <Widget>[
      if (widget.people.length < 2)
        _SetupCard(
          key: const ValueKey('setup-family'),
          icon: Icons.person_add_alt_1,
          title: l.homeSetupFamily,
          hint: l.homeSetupFamilyHint,
          onTap: () => context.push('/family/new'),
        ),
      if (noReminders)
        _SetupCard(
          key: const ValueKey('setup-reminders'),
          icon: Icons.notifications_outlined,
          title: l.homeSetupReminders,
          hint: remindersBlocked
              ? l.homeSetupRemindersBlocked
              : l.homeSetupRemindersHint,
          onTap: _askForReminders,
        ),
      if (noEmergency)
        _SetupCard(
          key: const ValueKey('setup-emergency'),
          icon: Icons.emergency_outlined,
          title: l.homeSetupEmergency,
          hint: l.homeSetupEmergencyHint,
          onTap: () => context.push('/family/${owner.id}/emergency'),
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('home-setup'),
      padding: const EdgeInsets.only(bottom: UsraSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: UsraSpacing.s2,
        children: [
          Text(
            l.homeSetupIntro,
            style: UsraType.body.copyWith(color: context.usra.ink),
          ),
          ...cards,
          if (ref.watch(lastBackupProvider) == null)
            Text(
              l.homeSetupLockNote,
              style: UsraType.label.copyWith(color: context.usra.inkMuted),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('setup-hide'),
              onPressed: () {
                setState(() => _hidden = true);
                ref
                    .read(keyValueStoreProvider)
                    .setBool(homeSetupHiddenKey, true);
              },
              child: Text(l.homeSetupHide),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(UsraSpacing.s3),
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(icon, color: c.primary)),
              const SizedBox(width: UsraSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: UsraType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hint,
                      style: UsraType.label.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(Icons.chevron_right, color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
