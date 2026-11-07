import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/dr_usra.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_notices.dart';
import '../children/vaccines_screen.dart' show HomeVaccines;
import '../family/family_screen.dart';

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
          style: _Look.primary,
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
      borderRadius: BorderRadius.circular(22),
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
                            fontWeight: FontWeight.w700,
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
