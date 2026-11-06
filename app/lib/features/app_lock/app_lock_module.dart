import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/dr_usra.dart';
import '../../core/design/tokens.dart';
import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../../core/security/app_lock.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_providers.dart';
import '../backup/backup_screen.dart';
import '../family/family_screen.dart';
import 'lock_screen.dart';
import 'pin_pad.dart';

/// The app lock's first-run offer and its settings. The lock screen itself
/// is [AppLockGate], around the whole app.
class AppLockModule extends FeatureModule {
  const AppLockModule();

  @override
  String get id => 'app_lock';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: appLockSettingsPath,
      builder: (_, _) => const AppLockSettingsScreen(),
    ),
  ];

  @override
  List<RouteBase> get fullScreenRoutes => [
    GoRoute(
      path: appLockOfferPath,
      builder: (_, s) =>
          AppLockOfferScreen(from: s.uri.queryParameters['from']),
    ),
  ];
}

/// Asks for the PIN (or fingerprint / face) before turning the lock off or
/// changing the PIN. True when it was the owner.
Future<bool> confirmItsYou(BuildContext context) async =>
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _VerifyScreen(),
      ),
    ) ??
    false;

/// Choosing a new PIN (twice), then fingerprint or face. True when saved.
Future<bool> setUpPin(BuildContext context) async =>
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PinSetupScreen(),
      ),
    ) ??
    false;

/// Turning the lock on: a forgotten PIN means wiping the app, so without
/// a backup of existing records it suggests making one first. True when
/// the lock was turned on.
Future<bool> turnOnLock(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final noBackup =
      ref.read(keyValueStoreProvider).getInt(PrefKeys.lastBackupAt) == null &&
      ref.read(autoBackupProvider).settings.lastAt == null;
  var hasRecords = false;
  if (noBackup) {
    try {
      hasRecords = (await ref.read(profilesProvider.future)).isNotEmpty;
    } catch (_) {
      hasRecords = true;
    }
  }
  if (!context.mounted) return false;
  if (hasRecords) {
    final backupFirst = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.lockBackupFirstTitle),
        content: Text(l.lockBackupFirstBody),
        actions: [
          TextButton(
            key: const ValueKey('lock-backup-skip'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.lockBackupFirstSkip),
          ),
          FilledButton(
            key: const ValueKey('lock-backup-make'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.lockBackupFirstMake),
          ),
        ],
      ),
    );
    if (!context.mounted || backupFirst == null) return false;
    if (backupFirst) {
      context.go(backupPath);
      return false;
    }
  }
  return setUpPin(context);
}

class _VerifyScreen extends ConsumerStatefulWidget {
  const _VerifyScreen();

  @override
  ConsumerState<_VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<_VerifyScreen> {
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

  Future<void> _biometrics() async {
    final ok = await _lock.checkBiometrics(
      AppLocalizations.of(context).lockBiometricReason,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.lockVerifyTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lock.biometricsEnabled) ...[
                FilledButton.icon(
                  key: const ValueKey('verify-biometrics'),
                  onPressed: _biometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l.lockUseBiometrics),
                ),
                const SizedBox(height: 16),
              ],
              PinEntry(
                title: l.lockSetupCurrentPin,
                onOk: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Step { choose, confirm, biometrics }

/// New PIN, the same again, then (when the phone has it) fingerprint or
/// face. Turns the lock on, or changes the PIN when it's already on.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  late final AppLock _lock = ref.read(appLockProvider);
  var _step = _Step.choose;
  String? _first;
  bool _mismatch = false;
  bool _trivial = false;
  bool _busy = false;

  Future<void> _entered(String pin) async {
    switch (_step) {
      case _Step.choose:
        if (isTrivialPin(pin)) {
          setState(() {
            _mismatch = false;
            _trivial = true;
          });
          return;
        }
        setState(() {
          _first = pin;
          _mismatch = false;
          _trivial = false;
          _step = _Step.confirm;
        });
      case _Step.confirm:
        if (pin != _first) {
          setState(() {
            _first = null;
            _mismatch = true;
            _step = _Step.choose;
          });
          return;
        }
        if (_lock.enabled) return _save(changing: true);
        setState(() => _busy = true);
        final biometrics = await _lock.biometrics.available();
        if (!mounted) return;
        if (biometrics) {
          setState(() {
            _busy = false;
            _step = _Step.biometrics;
          });
        } else {
          await _save();
        }
      case _Step.biometrics:
        break;
    }
  }

  Future<void> _useBiometrics() async {
    final ok = await _lock.authenticate(
      AppLocalizations.of(context).lockBiometricReason,
    );
    await _save(biometrics: ok);
  }

  Future<void> _save({bool biometrics = false, bool changing = false}) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (changing) {
        await _lock.changePin(_first!);
      } else {
        await _lock.enable(_first!, biometrics: biometrics);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.lockSetupDone)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final simple = ref.watch(simpleModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAppLock)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _step == _Step.biometrics
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.fingerprint,
                      size: 72,
                      color: UsraColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.lockSetupBiometricsTitle,
                      style: text.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.lockSetupBiometricsBody,
                      style: text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('setup-biometrics-yes'),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(simple ? 64 : 52),
                      ),
                      onPressed: _busy ? null : _useBiometrics,
                      child: Text(l.lockSetupBiometricsYes),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('setup-biometrics-no'),
                      onPressed: _busy ? null : _save,
                      child: Text(l.lockOfferSkip),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _step == _Step.choose
                          ? l.lockSetupNewPin
                          : l.lockSetupConfirmPin,
                      key: const ValueKey('setup-step'),
                      style: text.titleLarge,
                    ),
                    SizedBox(
                      height: 40,
                      child: _mismatch || _trivial
                          ? Text(
                              _mismatch
                                  ? l.lockSetupMismatch
                                  : l.lockSetupTrivial,
                              key: ValueKey(
                                _mismatch ? 'setup-mismatch' : 'setup-trivial',
                              ),
                              style: text.bodyMedium?.copyWith(
                                color: UsraColors.emergency,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : null,
                    ),
                    PinPad(
                      key: ValueKey(_step),
                      onSubmit: _entered,
                      busy: _busy,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.lockSetupWriteDown,
                      style: text.bodySmall?.copyWith(
                        color: UsraColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Shown once after the first-run tour: turn the lock on, or skip.
class AppLockOfferScreen extends ConsumerWidget {
  const AppLockOfferScreen({super.key, this.from});

  /// Where to go next.
  final String? from;

  Future<void> _done(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(keyValueStoreProvider)
          .setBool(PrefKeys.appLockOffered, true);
    } catch (_) {
      // Only means it's offered again next time.
    }
    if (!context.mounted) return;
    final next = from;
    context.go(
      next == null || next.startsWith(appLockOfferPath) ? '/home' : next,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final simple = ref.watch(simpleModeProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DrUsra(
                      pose: DrUsraPose.caring,
                      size: (box.maxHeight * 0.3).clamp(96.0, 180.0),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      header: true,
                      child: Text(
                        l.lockOfferTitle,
                        key: const ValueKey('app-lock-offer'),
                        style: simple
                            ? text.headlineMedium
                            : text.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.lockOfferBody,
                      style: simple ? text.titleLarge : text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const ValueKey('app-lock-offer-yes'),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(simple ? 64 : 52),
                      ),
                      onPressed: () async {
                        if (await turnOnLock(context, ref) && context.mounted) {
                          await _done(context, ref);
                        }
                      },
                      icon: const Icon(Icons.lock_outline),
                      label: Text(l.lockOfferYes),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('app-lock-offer-skip'),
                      style: TextButton.styleFrom(
                        minimumSize: Size.fromHeight(simple ? 64 : 48),
                      ),
                      onPressed: () => _done(context, ref),
                      child: Text(l.lockOfferSkip),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.lockOfferLater,
                      style: text.bodySmall?.copyWith(
                        color: UsraColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Turn the lock on or off, change the PIN, fingerprint or face, how soon
/// it locks again, and the emergency card on the lock screen.
class AppLockSettingsScreen extends ConsumerStatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  ConsumerState<AppLockSettingsScreen> createState() =>
      _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends ConsumerState<AppLockSettingsScreen> {
  late final AppLock _lock = ref.read(appLockProvider);
  late final Future<bool> _biometrics = _lock.biometrics.available();

  Future<void> _guard(Future<void> Function() change) async {
    try {
      await change();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
      );
    }
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      await turnOnLock(context, ref);
      return;
    }
    if (!await confirmItsYou(context)) return;
    await _guard(_lock.disable);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).lockOffDone)),
    );
  }

  Future<void> _changePin() async {
    if (await confirmItsYou(context) && mounted) await setUpPin(context);
  }

  /// Anything that makes the lock easier to get past needs the PIN, so a
  /// moment with the phone unlocked can't weaken it for later.
  Future<bool> _loosen() => confirmItsYou(context);

  Future<void> _setBiometrics(bool on) async {
    if (on) {
      final reason = AppLocalizations.of(context).lockBiometricReason;
      if (!await _loosen() || !await _lock.authenticate(reason)) return;
    }
    await _guard(() => _lock.setBiometrics(on));
  }

  Future<void> _setTimeout(LockTimeout timeout) async {
    if (timeout.duration > _lock.timeout.duration && !await _loosen()) return;
    await _guard(() => _lock.setTimeout(timeout));
  }

  /// Turning it on is tightening, but can't be undone by mistake, so it
  /// warns first; turning it off is loosening, so it needs the PIN.
  Future<void> _setWipe(bool on) async {
    if (on) {
      final l = AppLocalizations.of(context);
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.delete_forever_outlined,
            color: UsraColors.emergency,
          ),
          title: Text(l.lockWipeConfirmTitle),
          content: SingleChildScrollView(child: Text(l.lockWipeConfirmBody)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.lockWipeCancel),
            ),
            FilledButton(
              key: const ValueKey('app-lock-wipe-yes'),
              style: FilledButton.styleFrom(
                backgroundColor: UsraColors.emergency,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.lockWipeConfirmYes),
            ),
          ],
        ),
      );
      if (yes != true) return;
    } else if (!await _loosen()) {
      return;
    }
    await _guard(() => _lock.setWipeOnFailures(on));
  }

  Future<void> _setEmergency(String profileId, bool on) async {
    if (on && !await _loosen()) return;
    await _guard(() => _lock.setEmergencyProfile(profileId, on));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _lock,
      builder: (context, _) {
        final on = _lock.enabled;
        return Scaffold(
          appBar: AppBar(title: Text(l.settingsAppLock)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const ValueKey('app-lock-switch'),
                      value: on,
                      onChanged: _toggle,
                      secondary: const Icon(Icons.lock_outline),
                      title: Text(l.lockSettingsSwitch),
                      subtitle: Text(
                        on ? l.settingsAppLockOn : l.settingsAppLockOff,
                      ),
                    ),
                    if (on) ...[
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('app-lock-change'),
                        leading: const Icon(Icons.pin_outlined),
                        title: Text(l.lockSettingsChangePin),
                        onTap: _changePin,
                      ),
                      FutureBuilder<bool>(
                        future: _biometrics,
                        builder: (context, available) =>
                            available.data == true || _lock.biometricsEnabled
                            ? Column(
                                children: [
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    key: const ValueKey('app-lock-biometrics'),
                                    value: _lock.biometricsEnabled,
                                    onChanged: _setBiometrics,
                                    secondary: const Icon(Icons.fingerprint),
                                    title: Text(l.lockSettingsBiometrics),
                                    subtitle: Text(
                                      l.lockSettingsBiometricsHint,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
              if (on) ...[
                const SizedBox(height: 20),
                Text(l.lockSettingsTimeout, style: text.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<LockTimeout>(
                  key: const ValueKey('app-lock-timeout'),
                  segments: [
                    ButtonSegment(
                      value: LockTimeout.immediately,
                      label: Text(l.lockTimeoutImmediately),
                    ),
                    ButtonSegment(
                      value: LockTimeout.oneMinute,
                      label: Text(l.lockTimeoutOneMinute),
                    ),
                    ButtonSegment(
                      value: LockTimeout.fiveMinutes,
                      label: Text(l.lockTimeoutFiveMinutes),
                    ),
                  ],
                  selected: {_lock.timeout},
                  onSelectionChanged: (s) => _setTimeout(s.first),
                ),
                const SizedBox(height: 20),
                Card(
                  key: const ValueKey('app-lock-emergency'),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.emergency_outlined,
                          color: UsraColors.emergency,
                        ),
                        title: Text(l.lockSettingsEmergency),
                        subtitle: Text(l.lockSettingsEmergencyHint),
                      ),
                      for (final p
                          in ref.watch(profilesProvider).value ?? const [])
                        CheckboxListTile(
                          key: ValueKey('app-lock-emergency-${p.id}'),
                          value: _lock.emergencyProfiles.contains(p.id),
                          onChanged: (v) => _setEmergency(p.id, v ?? false),
                          title: Text(p.displayName),
                          subtitle: Text(l.lockEmergencyFor),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: SwitchListTile(
                    key: const ValueKey('app-lock-wipe'),
                    value: _lock.wipeOnFailures,
                    onChanged: _setWipe,
                    secondary: const Icon(
                      Icons.delete_forever_outlined,
                      color: UsraColors.emergency,
                    ),
                    title: Text(l.lockSettingsWipe),
                    subtitle: Text(l.lockSettingsWipeHint),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(l.lockForgotTitle, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(
                l.lockForgotBody,
                style: text.bodyMedium?.copyWith(color: UsraColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
