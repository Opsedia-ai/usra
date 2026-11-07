import 'package:flutter/material.dart';

import '../../core/modules/feature_module.dart';
import '../../l10n/app_localizations.dart';
import 'add_sheet.dart';

/// The raised middle button of the bottom bar.
class AddModule extends FeatureModule {
  const AddModule();

  @override
  String get id => 'add';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/add',
      icon: Icons.add,
      label: (c) => AppLocalizations.of(c).navAdd,
      order: 17,
      action: showAddSheet,
    ),
  ];
}
