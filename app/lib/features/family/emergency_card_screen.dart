import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/call_buttons.dart';
import 'family_screen.dart';
import 'member_screen.dart';

/// Ambulance number shown on the emergency card. Egypt first; the app is
/// Egypt-only until the UAE and KSA launches.
const ambulanceNumber = '123';

/// What a paramedic or ER nurse needs first, in large high-contrast text:
/// blood type, allergies, chronic conditions and past surgeries.
class EmergencyCardScreen extends ConsumerWidget {
  const EmergencyCardScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final timeline = ref.watch(timelineProvider(profileId));
    return Scaffold(
      backgroundColor: UsraColors.surface,
      appBar: AppBar(
        backgroundColor: UsraColors.emergency,
        foregroundColor: Colors.white,
        title: Text(l.emergencyTitle),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          if (p == null) return Center(child: Text(l.profileNotFound));
          final surgeries = [
            for (final e in timeline.value ?? const <MedicalEvent>[])
              if (e.type == 'surgery') e,
          ];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _NameBlock(profile: p),
              const SizedBox(height: 20),
              _Fact(
                key: const ValueKey('emergency-blood'),
                label: l.profileBloodType,
                value: p.bloodType,
                emptyText: l.emergencyUnknown,
                big: true,
              ),
              _Fact(
                key: const ValueKey('emergency-allergies'),
                label: l.profileAllergies,
                value: p.allergies,
                emptyText: l.emergencyNoneRecorded,
                severity: p.allergies == null ? null : Severity.urgent,
              ),
              _Fact(
                key: const ValueKey('emergency-conditions'),
                label: l.profileConditions,
                value: p.conditions,
                emptyText: l.emergencyNoneRecorded,
              ),
              _Fact(
                key: const ValueKey('emergency-surgeries'),
                label: l.emergencySurgeries,
                value: surgeries.isEmpty
                    ? null
                    : surgeries.map((e) => _surgeryLine(e)).join('\n'),
                emptyText: l.emergencyNoneRecorded,
              ),
              if (p.bloodType == null || p.allergies == null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  key: const ValueKey('emergency-complete'),
                  onPressed: () => context.go('/family/$profileId/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l.emergencyComplete),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('emergency-ambulance'),
                style: FilledButton.styleFrom(
                  backgroundColor: UsraColors.emergency,
                  minimumSize: const Size.fromHeight(64),
                  textStyle: Theme.of(context).textTheme.titleLarge,
                ),
                onPressed: () => openContact(
                  context,
                  Uri(scheme: 'tel', path: ambulanceNumber),
                ),
                icon: const Icon(Icons.call, size: 28),
                label: Text(l.emergencyCallAmbulance(ambulanceNumber)),
              ),
              const SizedBox(height: 16),
              Text(
                l.notMedicalDevice,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  /// "Appendix removal · 2019", from the surgery record's procedure field.
  static String _surgeryLine(MedicalEvent e) {
    Object? procedure;
    try {
      final data = jsonDecode(e.dataJson);
      if (data is Map) procedure = data['procedure'];
    } catch (_) {}
    return [?procedure?.toString(), '${e.occurredAt.year}'].join(' · ');
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final age = ageInYears(profile.birthDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(profile.displayName, style: text.headlineMedium),
        if (age != null)
          Text(
            l.ageYears(age),
            style: text.titleMedium?.copyWith(color: UsraColors.textMuted),
          ),
      ],
    );
  }
}

/// One labelled fact, in large type. Missing facts are shown, not hidden,
/// so a reader knows they were not recorded rather than absent.
class _Fact extends StatelessWidget {
  const _Fact({
    super.key,
    required this.label,
    required this.value,
    required this.emptyText,
    this.severity,
    this.big = false,
  });

  final String label;
  final String? value;
  final String emptyText;
  final Severity? severity;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final missing = value == null;
    final color = severity?.foreground ?? UsraColors.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: severity?.background ?? UsraColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.titleSmall?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(
            value ?? emptyText,
            style: (big ? text.displaySmall : text.titleLarge)?.copyWith(
              color: missing ? UsraColors.textMuted : color,
              fontWeight: missing ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
