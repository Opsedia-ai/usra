import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

/// Blocks screenshots and screen recording (Android `FLAG_SECURE`) while
/// [secure]: always when "Block screenshots" is on, and while a sensitive
/// screen such as the recovery key is open.
///
/// The recent-apps switcher is covered natively whatever this says
/// (`MainActivity.kt`, `SceneDelegate.swift`): the launch screen goes over
/// the app when it leaves the foreground and comes off when it's back,
/// or, after [coverUntilReady], only once [uncover] is called. iOS can't
/// block screenshots, so there `setSecure` does nothing.
class ScreenPrivacy {
  ScreenPrivacy([this._channel = channel]);

  static const channel = MethodChannel('usra/screen_privacy');

  final MethodChannel _channel;
  var _always = false;
  var _screens = 0;
  bool? _applied;

  bool get secure => _always || _screens > 0;

  /// The "Block screenshots" setting.
  Future<void> blockAll(bool on) {
    _always = on;
    return _apply();
  }

  /// A sensitive screen opened; pair with [release].
  Future<void> hold() {
    _screens++;
    return _apply();
  }

  Future<void> release() {
    if (_screens > 0) _screens--;
    return _apply();
  }

  /// For the app lock: while on, the cover stays after the app comes back
  /// until [uncover], so nothing shows before the lock screen is drawn
  /// (natively it gives up after 3 seconds).
  Future<void> coverUntilReady(bool on) => _call('coverUntilReady', on);

  /// The lock screen is drawn, or there's no need for one.
  Future<void> uncover() => _call('uncover');

  Future<void> _call(String method, [Object? argument]) async {
    try {
      await _channel.invokeMethod<void>(method, argument);
    } on MissingPluginException {
      // Tests, or a platform without a cover.
    }
  }

  Future<void> _apply() async {
    final on = secure;
    if (on == _applied) return;
    _applied = on;
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } on MissingPluginException {
      // iOS, tests: nothing to set.
    } on PlatformException {
      // No window yet; the next change sets it.
      _applied = null;
    }
  }
}

/// Follows the "Block screenshots" setting from the start; [UsraApp]
/// watches it so it's created with the app.
final screenPrivacyProvider = Provider<ScreenPrivacy>((ref) {
  final privacy = ScreenPrivacy();
  ref.listen(
    blockScreenshotsProvider,
    (_, on) => privacy.blockAll(on),
    fireImmediately: true,
  );
  return privacy;
});

/// Keeps [child] out of screenshots and screen recordings while it's on
/// screen, whatever the "Block screenshots" setting says.
class SecureScreen extends ConsumerStatefulWidget {
  const SecureScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends ConsumerState<SecureScreen> {
  late final ScreenPrivacy _privacy = ref.read(screenPrivacyProvider);

  @override
  void initState() {
    super.initState();
    _privacy.hold();
  }

  @override
  void dispose() {
    _privacy.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
