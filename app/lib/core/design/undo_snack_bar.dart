import 'package:flutter/material.dart';

/// How long a message with Undo stays: ten seconds, the longest Material
/// allows. At six, a parent reading the words before reaching for Undo often
/// tapped empty space after it had gone, and the mark stayed (end-to-end test
/// #1). With a screen reader on, Flutter keeps it until it is dismissed.
const undoSnackDuration = Duration(seconds: 10);

/// Every message with Undo: the words, an Undo that runs [onUndo] once, and
/// [undoSnackDuration] before it goes so it never sits over the screen's own
/// buttons.
SnackBar undoSnackBar({
  Key? key,
  required Widget content,
  required String label,
  required VoidCallback onUndo,
  Key? actionKey,
}) => SnackBar(
  key: key,
  content: content,
  duration: undoSnackDuration,
  persist: false,
  action: SnackBarAction(key: actionKey, label: label, onPressed: onUndo),
);
