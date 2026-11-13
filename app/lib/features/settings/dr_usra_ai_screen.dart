import 'package:flutter/material.dart';

import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/design/usra_mark.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../family/emergency_card_screen.dart' show ambulanceNumber;

const drUsraAiPath = '/settings/dr-usra-ai';

/// Dr. Usra AI, planned (founder, 13 Nov 2026): what it will help with and
/// its limits. Informational only. Nothing here works yet: no AI call, no
/// network, no sign-up, no buttons. See "Dr. Usra AI (planned)" in
/// `docs/decisions.md` before building any of it.
class DrUsraAiScreen extends StatelessWidget {
  const DrUsraAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final features = [
      (Icons.document_scanner_outlined, l.drAiPhotoTitle, l.drAiPhotoBody),
      (Icons.science_outlined, l.drAiLabTitle, l.drAiLabBody),
      (Icons.event_note_outlined, l.drAiVisitTitle, l.drAiVisitBody),
      (Icons.chat_bubble_outline, l.drAiAskTitle, l.drAiAskBody),
      (Icons.mic_none, l.drAiVoiceTitle, l.drAiVoiceBody),
      (Icons.medication_outlined, l.drAiMedicineTitle, l.drAiMedicineBody),
      (Icons.badge_outlined, l.drAiInsuranceTitle, l.drAiInsuranceBody),
      (Icons.calendar_view_week_outlined, l.drAiWeeklyTitle, l.drAiWeeklyBody),
      (Icons.record_voice_over_outlined, l.drAiSimpleTitle, l.drAiSimpleBody),
    ];
    final limits = [
      (Icons.lightbulb_outline, l.drAiLimitHelps),
      (Icons.block, l.drAiLimitNever),
      (Icons.medical_services_outlined, l.drAiLimitDoctor),
      (
        Icons.call_outlined,
        l.drAiLimitEmergency(localizedDigitsIn(context, ambulanceNumber)),
      ),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        key: const ValueKey('dr-ai-page'),
        padding: const EdgeInsets.all(20),
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: UsraMark(size: UsraMark.hero),
          ),
          const SizedBox(height: UsraSpacing.s3),
          Semantics(
            header: true,
            child: Text(
              l.drAiTitle,
              style: UsraType.title.copyWith(color: c.heading),
            ),
          ),
          const SizedBox(height: UsraSpacing.s2),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: ComingSoonPill(),
          ),
          const SizedBox(height: UsraSpacing.s2),
          Text(
            l.drAiIntro,
            key: const ValueKey('dr-ai-intro'),
            style: UsraType.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: UsraSpacing.s4),
          UsraGroupLabel(l.drAiFeaturesHeading),
          UsraListCard(
            key: const ValueKey('dr-ai-features'),
            children: [
              for (final (icon, title, body) in features)
                UsraListRow(
                  icon: icon,
                  iconTint: IconTint.neutral,
                  title: title,
                  subtitleText: body,
                ),
            ],
          ),
          const SizedBox(height: UsraSpacing.s4),
          UsraGroupLabel(l.drAiLimitsHeading),
          UsraListCard(
            key: const ValueKey('dr-ai-limits'),
            children: [
              for (final (icon, text) in limits)
                UsraListRow(icon: icon, title: text),
            ],
          ),
          const SizedBox(height: UsraSpacing.s5),
          Text(
            l.drAiOptional,
            key: const ValueKey('dr-ai-optional'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The small neutral "Coming soon" label beside Dr. Usra AI. Not a status
/// colour: it only says the feature isn't here yet.
class ComingSoonPill extends StatelessWidget {
  const ComingSoonPill({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    return Container(
      key: const ValueKey('dr-ai-soon'),
      padding: const EdgeInsets.symmetric(
        horizontal: UsraSpacing.s2,
        vertical: 2,
      ),
      decoration: ShapeDecoration(
        color: c.surfaceSoft,
        shape: StadiumBorder(side: BorderSide(color: c.line)),
      ),
      child: Text(
        AppLocalizations.of(context).drAiSoon,
        style: UsraType.label.copyWith(
          color: c.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
