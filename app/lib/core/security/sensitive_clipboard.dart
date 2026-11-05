import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../log.dart';

/// How long a copied secret (the recovery key) stays on the clipboard.
const sensitiveClipboardLifetime = Duration(seconds: 60);

/// Copies secrets so they don't linger (security plan S7).
///
/// Natively (`usra/clipboard`):
/// - Android marks the clip sensitive (`EXTRA_IS_SENSITIVE`), so Android
///   13+ doesn't show it in the "copied" preview and keyboards don't keep
///   it in their clipboard history, then clears it after
///   [sensitiveClipboardLifetime] if it's still ours (checked the next
///   time the app has focus, since Android 10+ hides the clipboard from
///   apps in the background).
/// - iOS puts it on the pasteboard local-only (no Universal Clipboard to
///   the family's Mac or iPad) with an expiry, so iOS removes it itself.
///
/// Without the native side (tests, other platforms) it falls back to
/// Flutter's clipboard and clears it after the same time if it still holds
/// the secret.
class SensitiveClipboard {
  SensitiveClipboard({
    this.methodChannel = channel,
    this.lifetime = sensitiveClipboardLifetime,
  });

  static const channel = MethodChannel('usra/clipboard');

  final MethodChannel methodChannel;
  final Duration lifetime;
  Timer? _fallbackClear;

  /// True when copied. When the phone's own copy fails, nothing is copied
  /// at all rather than the secret going on the clipboard unmarked.
  Future<bool> copy(String text) async {
    _fallbackClear?.cancel();
    try {
      await methodChannel.invokeMethod<void>('copySensitive', text);
      return true;
    } on MissingPluginException {
      // Tests, desktop: Flutter's clipboard below.
    } on PlatformException catch (e) {
      Log.error('Sensitive copy failed', e);
      return false;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _fallbackClear = Timer(lifetime, () => _clearIfStill(text));
    return true;
  }

  Future<void> _clearIfStill(String text) async {
    try {
      final now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (e) {
      Log.error('Clipboard clear failed', e);
    }
  }

  void dispose() => _fallbackClear?.cancel();
}

final sensitiveClipboardProvider = Provider<SensitiveClipboard>((ref) {
  final clipboard = SensitiveClipboard();
  ref.onDispose(clipboard.dispose);
  return clipboard;
});
