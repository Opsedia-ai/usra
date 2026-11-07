import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';

/// Dr. Usra's poses, from the founder's art in assets/branding/dr_usra/.
enum DrUsraPose { welcome, explaining, emptyState, celebrating, resting }

/// Dr. Usra (دكتور أسرة). Never shown on emergency or warning screens.
class DrUsra extends StatelessWidget {
  const DrUsra({
    super.key,
    this.pose = DrUsraPose.welcome,
    this.size = 160,
    this.semanticLabel,
  });

  final DrUsraPose pose;
  final double size;

  /// Replaces the pose's own description.
  final String? semanticLabel;

  static String assetFor(DrUsraPose pose) => switch (pose) {
    DrUsraPose.welcome => 'assets/branding/dr_usra/dr-usra-welcome.svg',
    DrUsraPose.explaining => 'assets/branding/dr_usra/dr-usra-explaining.svg',
    DrUsraPose.emptyState => 'assets/branding/dr_usra/dr-usra-empty-state.svg',
    DrUsraPose.celebrating => 'assets/branding/dr_usra/dr-usra-celebrating.svg',
    DrUsraPose.resting => 'assets/branding/dr_usra/dr-usra-resting.svg',
  };

  String? _label(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (l == null) return null;
    return switch (pose) {
      DrUsraPose.welcome => l.drUsraWelcome,
      DrUsraPose.explaining => l.drUsraExplaining,
      DrUsraPose.emptyState => l.drUsraEmptyState,
      DrUsraPose.celebrating => l.drUsraCelebrating,
      DrUsraPose.resting => l.drUsraResting,
    };
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? _label(context),
    image: true,
    excludeSemantics: true,
    child: SvgPicture.asset(assetFor(pose), width: size, height: size),
  );
}
