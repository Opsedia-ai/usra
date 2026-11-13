import 'package:flutter/material.dart';

/// The app's AlertDialog. A filled button is as wide as it can be, so the
/// actions don't fit on one line and stack: then the main action (listed
/// last) goes on top and Cancel sits centred under it, rather than alone at
/// the edge above it (QA L7). Its 16 corners come from the theme.
class UsraAlertDialog extends AlertDialog {
  const UsraAlertDialog({
    super.key,
    super.icon,
    super.title,
    super.content,
    super.actions,
    super.scrollable,
  }) : super(
         actionsOverflowDirection: VerticalDirection.up,
         actionsOverflowAlignment: OverflowBarAlignment.center,
         actionsOverflowButtonSpacing: 8,
       );
}
