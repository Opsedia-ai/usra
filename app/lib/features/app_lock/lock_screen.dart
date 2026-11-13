import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/preferences.dart';
import '../../core/screen_privacy.dart';
import '../../core/security/app_lock.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../family/emergency_card_screen.dart';
import '../family/family_screen.dart';
import 'pin_pad.dart';
import '../../core/design/dialog.dart';

/// Covers the whole app while it's locked, so nothing behind it shows or
/// takes taps, and locks again after the chosen time in the background.
/// The app stays built underneath, so it's where it was after unlocking.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late final AppLock _lock = ref.read(appLockProvider);
  late final ScreenPrivacy _privacy = ref.read(screenPrivacyProvider);
  bool? _nativeHold;
  late final AppLifecycleListener _life;
  final _navigator = GlobalKey<NavigatorState>();

  /// Hides the app from the moment it starts to leave the screen until the
  /// lock has decided on coming back, so the records never flash up first.
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    // Registered before the app's router, so back presses reach it first.
    WidgetsBinding.instance.addObserver(this);
    _life = AppLifecycleListener(onStateChange: _lifecycle);
    _lock.addListener(_changed);
    _holdNativeCover();
  }

  @override
  void dispose() {
    _lock.removeListener(_changed);
    _life.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _lifecycle(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
        // Also the notification shade and the Face ID prompt: covered, but
        // the background clock only starts once the app is really away.
        _cover(true);
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _cover(true);
        _lock.movedToBackground();
      case AppLifecycleState.resumed:
        await _lock.movedToForeground();
        _cover(false);
        _uncoverNativeWhenDrawn();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _cover(bool on) {
    final covered = on && _lock.enabled && !_lock.locked;
    if (covered == _covered || !mounted) return;
    setState(() => _covered = covered);
  }

  void _changed() {
    // No keyboard left up over the lock screen.
    if (_lock.locked) FocusManager.instance.primaryFocus?.unfocus();
    _holdNativeCover();
    setState(() {});
  }

  /// With the lock on, the native app-switcher cover (S3) stays after the
  /// app comes back until the lock has decided and that frame is drawn, so
  /// the records never flash up before the lock screen.
  void _holdNativeCover() {
    final on = _lock.enabled;
    if (on == _nativeHold) return;
    _nativeHold = on;
    unawaited(_privacy.coverUntilReady(on));
  }

  void _uncoverNativeWhenDrawn() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_privacy.uncover());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// While locked, back leaves the emergency card, and never reaches the
  /// pages behind the lock.
  @override
  Future<bool> didPopRoute() async {
    if (!_lock.locked) return false;
    final navigator = _navigator.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      // On the lock screen itself, back leaves the app as usual.
      unawaited(SystemNavigator.pop());
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lock.locked;
    final hidden = locked || _covered;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Out of sight, out of reach of taps, screen readers, and keyboard
        // or D-pad focus.
        ExcludeFocus(
          excluding: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: TickerMode(
              enabled: !hidden,
              child: Offstage(offstage: hidden, child: widget.child),
            ),
          ),
        ),
        if (_covered && !locked)
          ColoredBox(
            key: ValueKey('lock-cover'),
            color: context.usra.bg,
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: context.usra.primary,
              ),
            ),
          ),
        if (locked)
          Navigator(
            key: _navigator,
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const LockScreen()),
          ),
      ],
    );
  }
}

/// PIN pad, with fingerprint or face first when turned on.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  late final AppLock _lock = ref.read(appLockProvider);

  @override
  void initState() {
    super.initState();
    if (_lock.biometricsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _biometrics();
      });
    }
  }

  Future<void> _biometrics() =>
      _lock.checkBiometrics(AppLocalizations.of(context).lockBiometricReason);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final simple = ref.watch(simpleModeProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: context.usra.primary),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(
                    l.lockTitle,
                    key: const ValueKey('lock-screen'),
                    style: simple ? text.headlineMedium : text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                if (_lock.biometricsEnabled) ...[
                  FilledButton.icon(
                    key: const ValueKey('lock-biometrics'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(simple ? 64 : 52),
                    ),
                    onPressed: _biometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l.lockUseBiometrics),
                  ),
                  const SizedBox(height: 16),
                ],
                PinEntry(title: l.lockEnterPin, onOk: () {}),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('lock-forgot'),
                  onPressed: () => showForgotPin(context),
                  child: Text(l.lockForgot),
                ),
                if (_lock.emergencyOnLockScreen) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('lock-emergency'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.usra.urgent,
                      side: BorderSide(color: context.usra.urgent),
                      minimumSize: Size.fromHeight(simple ? 64 : 52),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LockedEmergencyPicker(),
                      ),
                    ),
                    icon: const Icon(Icons.emergency_outlined),
                    label: Text(l.lockEmergency),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [PinPad] checked against the saved PIN, counting wrong tries and
/// showing the wait after too many. [onOk] runs when it matched.
class PinEntry extends ConsumerStatefulWidget {
  const PinEntry({super.key, required this.title, required this.onOk});

  final String title;
  final VoidCallback onOk;

  @override
  ConsumerState<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends ConsumerState<PinEntry> {
  late final AppLock _lock = ref.read(appLockProvider);
  bool _busy = false;
  PinCheck? _result;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _countDown();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Redraws every second while a wait runs (it survives restarts).
  void _countDown() {
    _tick?.cancel();
    if (_lock.waitRemaining == Duration.zero) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_lock.waitRemaining == Duration.zero) t.cancel();
      setState(() {});
    });
  }

  Future<void> _check(String pin) async {
    setState(() => _busy = true);
    var result = PinCheck.unavailable;
    try {
      result = await _lock.checkPin(pin);
    } catch (_) {
      // Shown as "try again"; the pad is usable again either way.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _result = result;
        });
      }
    }
    if (!mounted) return;
    if (result == PinCheck.ok) {
      widget.onOk();
    } else {
      _countDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final wait = _lock.waitRemaining;
    var message = wait > Duration.zero
        ? l.lockWait(localizedDigitsIn(context, _minutesSeconds(wait)))
        : switch (_result) {
            PinCheck.wrong || PinCheck.blocked => l.lockWrongPin,
            PinCheck.unavailable => l.lockUnavailable,
            _ => _lock.unreadable ? l.lockUnavailable : null,
          };
    // "Erase after 10 wrong PINs" is on: say how close it is.
    final left = _lock.triesBeforeWipe;
    if (left != null && _lock.failures > 0) {
      final warning = l.lockTriesBeforeWipe(left);
      message = message == null ? warning : '$message\n$warning';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: text.titleMedium),
        const SizedBox(height: 4),
        SizedBox(
          height: left != null && _lock.failures > 0 ? 64 : 40,
          child: message == null
              ? null
              : Text(
                  message,
                  key: const ValueKey('pin-message'),
                  style: text.bodyMedium?.copyWith(
                    color: context.usra.attention,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
        PinPad(onSubmit: _check, busy: _busy, enabled: wait == Duration.zero),
      ],
    );
  }
}

String _minutesSeconds(Duration d) {
  final seconds = d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// There's no way around the PIN; this says how to start again instead.
Future<void> showForgotPin(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => UsraAlertDialog(
      title: Text(l.lockForgotTitle),
      content: SingleChildScrollView(
        child: Text(l.lockForgotBody, key: const ValueKey('lock-forgot-body')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.pinOk),
        ),
      ],
    ),
  );
}

/// Only reachable when the person turned it on, and lists only the people
/// they chose: whose card to show, then the card itself, with nothing that
/// leads further into the app.
class LockedEmergencyPicker extends ConsumerWidget {
  const LockedEmergencyPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final allowed = ref.read(appLockProvider).emergencyProfiles;
    final profiles = ref
        .watch(profilesProvider)
        .value
        ?.where((p) => allowed.contains(p.id))
        .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.usra.urgent,
        foregroundColor: context.usra.onUrgent,
        titleTextStyle: UsraType.title.copyWith(color: context.usra.onUrgent),
        title: Text(l.lockEmergencyPick),
      ),
      body: profiles == null
          ? const Center(child: CircularProgressIndicator())
          : profiles.isEmpty
          ? Center(child: Text(l.lockEmergencyNone))
          : ListView(
              children: [
                for (final p in profiles)
                  ListTile(
                    key: ValueKey('lock-emergency-${p.id}'),
                    minTileHeight: 64,
                    leading: const Icon(Icons.person_outline),
                    title: Text(p.displayName),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmergencyCardScreen(
                          profileId: p.id,
                          editable: false,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
