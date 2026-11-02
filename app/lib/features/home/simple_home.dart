import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/dr_usra.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart';

/// Home in Simple Mode: a greeting and four big buttons, nothing else.
/// See design/screens/SimpleMode.dc.html.
class SimpleHome extends ConsumerWidget {
  const SimpleHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    // The person marked as using Simple Mode is the one holding the phone.
    final me = people.where((p) => p.simpleMode).firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        if (ref.watch(databaseRecoveredProvider)) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Severity.actSoon.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l.recoveryNotice,
              style: text.bodyLarge?.copyWith(
                color: Severity.actSoon.foreground,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
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
        _BigButton(
          key: const ValueKey('simple-medicines'),
          icon: Icons.medication_outlined,
          label: l.simpleMedicines,
          badge: l.comingSoon,
          style: _Look.muted,
          onPressed: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l.simpleMedicinesSoon))),
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
          onPressed: () => _openEmergency(context, l, people, me),
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

enum _Look { primary, outlined, emergency, muted }

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.style,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String label;
  final _Look style;
  final VoidCallback onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (style) {
      _Look.primary => (UsraColors.primary, Colors.white),
      _Look.emergency => (UsraColors.emergency, Colors.white),
      _Look.outlined => (UsraColors.surface, UsraColors.primary),
      _Look.muted => (UsraColors.surface, UsraColors.textMuted),
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: style == _Look.outlined
          ? const BorderSide(color: UsraColors.primary, width: 2)
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
                        // Below the label so it still fits with very large text.
                        if (badge != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Severity.headsUp.background,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: text.bodyMedium?.copyWith(
                                color: Severity.headsUp.foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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
