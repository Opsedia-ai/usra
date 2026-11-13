import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/dr_usra.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../app_lock/app_lock_module.dart';
import '../backup/backup_notices.dart';
import '../children/vaccines_screen.dart' show HomeVaccines;
import '../family/family_screen.dart';
import '../../core/preferences.dart' show simpleModeProvider;
import '../../core/security/app_lock.dart' show appLockProvider;
import '../family/person_status.dart' show TodayRefresh;
import '../medicines/medicine_text.dart' show formatDoseTime, medicineTitle;
import '../medicines/medicines_providers.dart'
    show clockProvider, todayDosesProvider;
import '../medicines/today_screen.dart' show DoseCard, DoseGroup, doseGroupOf;

/// Home in Simple Mode: a greeting, the next vaccine visit of any young
/// child, and four big buttons.
/// See design/screens/SimpleMode.dc.html.
class SimpleHome extends ConsumerWidget {
  const SimpleHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final family = ref.watch(profilesProvider);
    final people = family.value ?? const <Profile>[];
    // The person marked as using Simple Mode is the one holding the phone.
    final me = people.where((p) => p.simpleMode).firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const BackupNotices(simple: true),
        const AppLockHomeNotice(),
        Row(
          children: [
            DrUsra(size: 72, semanticLabel: l.homeGreeting),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  me == null
                      ? l.simpleHello
                      : l.simpleHelloName(me.displayName),
                  key: const ValueKey('simple-greeting'),
                  style: text.headlineSmall,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SimpleDoses(person: me),
        const SizedBox(height: 24),
        // A grandchild's next vaccine visit, when there's one.
        const HomeVaccines(),
        _BigButton(
          key: const ValueKey('simple-medicines'),
          icon: Icons.medication_outlined,
          label: l.simpleMedicines,
          style: _Look.primary,
          onPressed: () => context.go('/medicines'),
        ),
        const SizedBox(height: 16),
        _BigButton(
          key: const ValueKey('simple-call-doctor'),
          icon: Icons.call,
          label: l.simpleCallDoctor,
          // One filled navy button per screen: My medicines. This one keeps
          // its full size with a strong 2 px navy edge.
          style: _Look.outlined,
          onPressed: () => context.go('/doctors'),
        ),
        const SizedBox(height: 16),
        _BigButton(
          key: const ValueKey('simple-family'),
          icon: Icons.groups_outlined,
          label: l.simpleFamily,
          style: _Look.outlined,
          onPressed: () => context.go('/family'),
        ),
        const SizedBox(height: 16),
        _BigButton(
          key: const ValueKey('simple-emergency'),
          icon: Icons.emergency_outlined,
          label: l.simpleEmergency,
          style: _Look.emergency,
          // Not before the family has loaded, or it would look empty.
          onPressed: family.hasValue
              ? () => _openEmergency(context, l, people, me)
              : () {},
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            key: const ValueKey('simple-settings'),
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
            label: Text(l.navSettings),
          ),
        ),
        Center(
          child: TextButton(
            key: const ValueKey('simple-exit'),
            onPressed: () => leaveSimpleMode(context, ref),
            child: Text(
              ref.watch(appLockProvider).enabled
                  ? l.simpleExitWithPin
                  : l.simpleExit,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// Straight to the card when it's clear whose; otherwise ask.
  Future<void> _openEmergency(
    BuildContext context,
    AppLocalizations l,
    List<Profile> people,
    Profile? me,
  ) async {
    final only = me ?? (people.length == 1 ? people.single : null);
    if (only != null) {
      context.go('/family/${only.id}/emergency');
      return;
    }
    if (people.isEmpty) {
      context.go('/family');
      return;
    }
    final picked = await showModalBottomSheet<Profile>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l.simplePickPerson,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            for (final p in people)
              ListTile(
                key: ValueKey('simple-emergency-${p.id}'),
                leading: const Icon(Icons.badge_outlined),
                title: Text(p.displayName),
                onTap: () => Navigator.of(sheet).pop(p),
              ),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) {
      context.go('/family/${picked.id}/emergency');
    }
  }
}

/// Leaving Simple Mode asks first, so it can't happen by a stray tap: the PIN
/// (or fingerprint) when there's a lock, otherwise a plain question. True when
/// the app left it.
Future<bool> leaveSimpleMode(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final bool yes;
  if (ref.read(appLockProvider).enabled) {
    yes = await confirmItsYou(context);
  } else {
    yes =
        await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            key: const ValueKey('simple-exit-confirm'),
            content: Text(l.simpleExitConfirm),
            actions: [
              TextButton(
                key: const ValueKey('simple-exit-stay'),
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(l.simpleExitStay),
              ),
              FilledButton(
                key: const ValueKey('simple-exit-go'),
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(l.simpleExitGo),
              ),
            ],
          ),
        ) ??
        false;
  }
  if (!yes) return false;
  try {
    await ref.read(simpleModeProvider.notifier).set(false);
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
    }
    return false;
  }
}

/// The next doses, each with its own button and the Medicines tab's rules, then
/// the one after; or a plain line when none are left today.
class _SimpleDoses extends ConsumerStatefulWidget {
  const _SimpleDoses({required this.person});

  /// Whose phone this is; null shows the whole family's.
  final Profile? person;

  @override
  ConsumerState<_SimpleDoses> createState() => _SimpleDosesState();
}

class _SimpleDosesState extends ConsumerState<_SimpleDoses>
    with TodayRefresh<_SimpleDoses> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final doses = ref.watch(todayDosesProvider).value;
    // Says nothing until it knows: "none left" has to be true.
    if (doses == null) return const SizedBox.shrink();
    final person = widget.person;
    final open = [
      for (final d in doses)
        if (!d.isDone && (person == null || d.regimen.person.id == person.id))
          d,
    ];
    if (open.isEmpty) {
      return Text(
        l.simpleNoDoses,
        key: const ValueKey('simple-no-doses'),
        style: text.titleLarge,
      );
    }
    // What's missed or due now, each with its own button. Only when there's
    // none does the next time come forward. A dose missed this morning can't
    // hide the one that's due.
    final clock = ref.watch(clockProvider)();
    final due = [
      for (final d in open)
        if (doseGroupOf(d, clock) != DoseGroup.later) d,
    ];
    final now = due.isNotEmpty
        ? due
        : [
            for (final d in open)
              if (d.at == open.first.at) d,
          ];
    final then = open.where((d) => !now.contains(d)).firstOrNull;
    return Column(
      key: const ValueKey('simple-doses'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: UsraSpacing.s2,
      children: [
        Text(l.simpleNextDose, style: text.titleLarge),
        for (final d in now)
          DoseCard(
            key: ValueKey(
              'simple-dose-${d.regimen.medicine.id}-'
              '${d.at.millisecondsSinceEpoch}',
            ),
            dose: d,
            // The page has its own 20 margins: as wide as the big buttons.
            gutter: false,
          ),
        if (then != null)
          Text(
            person == null
                ? l.simpleThenDoseFor(
                    medicineTitle(then.regimen.medicine),
                    then.regimen.person.displayName,
                    formatDoseTime(context, then.at),
                  )
                : l.simpleThenDose(
                    medicineTitle(then.regimen.medicine),
                    formatDoseTime(context, then.at),
                  ),
            key: const ValueKey('simple-then'),
            style: text.titleMedium,
          ),
      ],
    );
  }
}

enum _Look { primary, outlined, emergency }

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.style,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final _Look style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (style) {
      _Look.primary => (context.usra.primary, context.usra.onPrimary),
      _Look.emergency => (context.usra.urgent, context.usra.onUrgent),
      _Look.outlined => (context.usra.surface, context.usra.primary),
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(UsraRadius.card),
      side: style == _Look.outlined
          ? BorderSide(color: context.usra.primary, width: 2)
          : BorderSide.none,
    );
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: Material(
        color: background,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: simpleTapTarget + 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 32, color: foreground),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: text.titleLarge?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
