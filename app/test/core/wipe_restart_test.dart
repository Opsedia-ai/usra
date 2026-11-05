import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/security/data_wipe.dart';
import 'package:usra/features/account/account_providers.dart';
import 'package:usra/features/account/auth_gateway.dart';
import 'package:usra/features/account/device_identity.dart';
import 'package:usra/features/settings/wipe_restart.dart';

import '../support/fake_auth_gateway.dart';

/// The in-process "Delete all my data" restart, with the database, files
/// and keys replaced by a log of what ran.
void main() {
  late FakeAuthGateway gateway;
  late MemoryDeviceIdentityStore ids;
  late ProviderContainer? app;
  late List<String> steps;
  late bool wipeOk;
  late bool reopenFails;
  late bool failedShown;
  WipeOutcome? reopenedWith;

  ProviderContainer container() => ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(gateway),
      accountReinstallCheckProvider.overrideWithValue(() async {}),
      deviceIdentityStoreProvider.overrideWithValue(ids),
    ],
  );

  setUp(() {
    gateway = FakeAuthGateway(signedIn: const AccountUser(id: 'u1'));
    ids = MemoryDeviceIdentityStore();
    app = container();
    steps = [];
    wipeOk = true;
    reopenFails = false;
    failedShown = false;
    reopenedWith = null;
  });

  WipeRestart restart({Duration timeout = const Duration(seconds: 1)}) =>
      WipeRestart(
        current: () => app,
        setCurrent: (c) => app = c,
        gatewayOf: (c) => c.read(authGatewayProvider),
        signOut: (c) async {
          steps.add('sign-out');
          await c.read(accountProvider.future);
          await c.read(accountProvider.notifier).signOut();
        },
        close: (old) async {
          steps.add('close');
          old.dispose();
        },
        wipe: () async {
          steps.add('wipe');
          if (!wipeOk) throw StateError('disk');
          return true;
        },
        reopen: (outcome) async {
          steps.add('reopen');
          if (reopenFails) throw StateError('keystore');
          reopenedWith = outcome;
          app = container();
        },
        onReopenFailed: () => failedShown = true,
        signOutTimeout: timeout,
      );

  test('signs out, wipes and opens again signed out', () async {
    await ids.saveDeviceId('u1', 'd1');
    await restart()();
    // The normal sign-out ran: this phone's device row went too.
    expect(gateway.revokedDevices, ['d1']);
    expect(steps, ['sign-out', 'close', 'wipe', 'reopen']);
    expect(reopenedWith, WipeOutcome.done);
    expect(gateway.localForgets, 2);
    expect(gateway.refreshResumed, 1);
    expect(await app!.read(accountProvider.future), isA<AccountSignedOut>());
  });

  test('a sign-out stuck on a slow network still leaves the account '
      'signed out after the restart', () async {
    gateway.holdSignOut = Completer<void>();
    await restart(timeout: const Duration(milliseconds: 50))();
    // The server sign-out never answered, but the local session went.
    expect(gateway.signedIn, isNull);
    expect(reopenedWith, WipeOutcome.done);
    expect(await app!.read(accountProvider.future), isA<AccountSignedOut>());
    gateway.holdSignOut!.complete();
  });

  test('a wipe that throws still opens the app again, saying so', () async {
    wipeOk = false;
    await restart()();
    expect(steps.last, 'reopen');
    expect(reopenedWith, WipeOutcome.incomplete);
    expect(app, isNotNull);
  });

  test(
    'if the app can\'t open again it says so, and can be tried again',
    () async {
      reopenFails = true;
      final run = restart();
      await run();
      expect(failedShown, isTrue);
      expect(app, isNull);
      // Not stuck "running": nothing left to wipe without an app, but the
      // guard is released.
      app = container();
      reopenFails = false;
      await run();
      expect(reopenedWith, WipeOutcome.done);
    },
  );

  test('a second request while one runs is ignored', () async {
    gateway.holdSignOut = Completer<void>();
    final run = restart();
    final first = run();
    await run();
    gateway.holdSignOut!.complete();
    await first;
    expect(steps.where((s) => s == 'wipe'), hasLength(1));
  });
}
