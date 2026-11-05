import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/files/photo_crypto.dart';
import 'package:usra/core/security/app_lock.dart';
import 'package:usra/core/security/data_wipe.dart';
import 'package:usra/core/security/sensitive_clipboard.dart';

import '../support/fake_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Directory root;
  late Directory temp;
  late List<String> calls;
  var failPrefs = false;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_wipe_test');
    root = Directory(p.join(dir.path, 'support'))..createSync();
    temp = Directory(p.join(dir.path, 'cache'))..createSync();
    calls = [];
    failPrefs = false;
    FlutterSecureStorage.setMockInitialValues({
      'usra.db.key.v1': 'db',
      'usra.photos.key.v1': 'photos',
      'usra.backup.recovery_key.v1': 'recovery',
      'usra.app_lock.v1': 'lock',
      'usra.account.u1.device_key.private.v1': 'private',
      'usra.account.session.v1': 'session',
    });
    // The app's data, as a phone has it.
    File(p.join(root.path, 'usra.sqlite')).writeAsBytesSync([1]);
    File(p.join(root.path, 'usra.sqlite-journal')).writeAsBytesSync([1]);
    File(p.join(root.path, 'dose_actions.jsonl')).writeAsStringSync('{}');
    File(p.join(root.path, 'insurance_cards', 'c.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([2]);
    Directory(p.join(root.path, 'restore-aside', 'attachments'))
        .createSync(recursive: true);
    File(p.join(temp.path, 'usra-backup-2026-11-05.usra'))
        .writeAsBytesSync([3]);
    File(p.join(temp.path, 'usra-share', 'a.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([4]);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  DataWiper wiper() => DataWiper(
    root: root,
    temporary: temp,
    secureStorage: const [FlutterSecureStorage()],
    clearPreferences: () async {
      calls.add('prefs');
      if (failPrefs) throw StateError('prefs');
    },
    cancelNotifications: () async => calls.add('notifications'),
    clearWidget: () async => calls.add('widget'),
  );

  test('deletes every key, file, setting, reminder and the widget', () async {
    expect(await wiper().wipe(), isTrue);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect(root.listSync(), isEmpty);
    expect(temp.listSync(), isEmpty);
    expect(calls, containsAll(['prefs', 'notifications', 'widget']));
  });

  test('also empties the other scratch folders (iOS tmp/)', () async {
    final tmp = Directory(p.join(dir.path, 'tmp'))..createSync();
    final pickedPhoto = File(p.join(tmp.path, 'image_picker_1.jpg'))
      ..writeAsBytesSync([9]);
    final wiper = DataWiper(
      root: root,
      temporary: temp,
      extraTemporary: [tmp],
      secureStorage: const [FlutterSecureStorage()],
      clearPreferences: () async {},
    );
    expect(await wiper.wipe(), isTrue);
    expect(pickedPhoto.existsSync(), isFalse);
    expect(tmp.listSync(), isEmpty);
  });

  test('every key the app writes is on the list', () {
    // Each Keystore / Keychain name in lib/ must be deleted by a wipe.
    final names = <String>{};
    final pattern = RegExp(r"""'(usra\.[a-z_.0-9]+)'""");
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (!text.contains('FlutterSecureStorage') &&
          !text.contains('accountKeyPrefix')) {
        continue;
      }
      names.addAll(pattern.allMatches(text).map((m) => m.group(1)!));
    }
    for (final name in names) {
      expect(
        appSecureKeys.contains(name) || name.startsWith(appSecureKeyPrefix),
        isTrue,
        reason: name,
      );
    }
    expect(names, containsAll(appSecureKeys));
  });

  test('a wipe cut short runs again at the next start, before anything '
      'opens', () async {
    // The app died right after writing the marker.
    File(p.join(root.path, DataWiper.markerName))
        .writeAsStringSync('{"attempt":1}');
    expect(await wiper().resumeIfInterrupted(), isTrue);
    expect(root.listSync(), isEmpty);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    // Nothing to do next time.
    expect(await wiper().resumeIfInterrupted(), isFalse);
  });

  test('a settings or reminder step that fails is reported, but never '
      'wipes again at the next start', () async {
    failPrefs = true;
    expect(await wiper().wipe(), isFalse);
    expect(root.listSync(), isEmpty);
    expect(await wiper().interrupted, isFalse);
  });

  test('files that can\'t be deleted are tried again at the next start, a '
      'few times at most', () async {
    // A cached file the wipe can't remove: its folder is read-only.
    final stuck = Directory(p.join(temp.path, 'stuck'))..createSync();
    File(p.join(stuck.path, 'x')).writeAsStringSync('x');
    Process.runSync('chmod', ['555', stuck.path]);
    addTearDown(() => Process.runSync('chmod', ['755', stuck.path]));
    expect(await wiper().wipe(), isFalse);
    // The rest still went.
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect(root.listSync().map((e) => p.basename(e.path)), [
      DataWiper.markerName,
    ]);
    expect(await wiper().resumeIfInterrupted(), isTrue);
    expect(await wiper().interrupted, isTrue);
    // Third try: given up, so it never wipes on every start.
    expect(await wiper().resumeIfInterrupted(), isTrue);
    expect(await wiper().interrupted, isFalse);
    expect(await wiper().resumeIfInterrupted(), isFalse);
  });

  test('after a wipe with no new photo key, nothing is sealed with the old '
      'one', () {
    final keys = PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey()));
    keys.markUnavailable(PhotoKeyProblem.unreadable);
    expect(keys.cipher, isNull);
    expect(() => keys.require, throwsA(isA<PhotoKeyUnavailableException>()));
  });

  group('erase after too many wrong PINs', () {
    Future<AppLock> lockWithPin(FakeClocks clocks) async {
      final lock = AppLock.off(
        hasher: fastHasher,
        clock: clocks.wall,
        ticks: clocks.ticks,
        uptime: clocks,
      );
      await lock.enable('482915');
      return lock;
    }

    Future<void> wrong(AppLock lock, FakeClocks clocks) async {
      clocks.pass(lock.waitRemaining);
      expect(await lock.checkPin('000001'), PinCheck.wrong);
    }

    test('off by default: wrong PINs only make the wait longer', () async {
      final clocks = FakeClocks();
      final lock = await lockWithPin(clocks);
      var wiped = 0;
      lock.onTooManyFailures = () async => wiped++;
      expect(lock.wipeOnFailures, isFalse);
      expect(lock.triesBeforeWipe, isNull);
      for (var i = 0; i < 12; i++) {
        await wrong(lock, clocks);
      }
      expect(wiped, 0);
    });

    test('on: the 10th wrong PIN in a row wipes, not the 9th', () async {
      final clocks = FakeClocks();
      final lock = await lockWithPin(clocks);
      var wiped = 0;
      lock.onTooManyFailures = () async => wiped++;
      await lock.setWipeOnFailures(true);
      expect(lock.triesBeforeWipe, wipeAfterFailures);
      for (var i = 0; i < 9; i++) {
        await wrong(lock, clocks);
      }
      expect(lock.triesBeforeWipe, 1);
      expect(wiped, 0);
      await wrong(lock, clocks);
      expect(wiped, 1);
    });

    test('the right PIN starts the count again', () async {
      final clocks = FakeClocks();
      final lock = await lockWithPin(clocks);
      var wiped = 0;
      lock.onTooManyFailures = () async => wiped++;
      await lock.setWipeOnFailures(true);
      for (var i = 0; i < 9; i++) {
        await wrong(lock, clocks);
      }
      clocks.pass(lock.waitRemaining);
      expect(await lock.checkPin('482915'), PinCheck.ok);
      expect(lock.triesBeforeWipe, wipeAfterFailures);
      await wrong(lock, clocks);
      expect(wiped, 0);
    });

    test('the setting is kept with the lock and survives a restart', () async {
      final store = MemoryLockStore();
      final clocks = FakeClocks();
      final lock = AppLock.off(store: store, hasher: fastHasher);
      await lock.enable('482915');
      await lock.setWipeOnFailures(true);
      final again = await AppLock.open(
        store: store,
        hasher: fastHasher,
        clock: clocks.wall,
      );
      expect(again.wipeOnFailures, isTrue);
    });

    test('after a wipe the lock is gone and nothing held runs', () async {
      final store = MemoryLockStore();
      final lock = AppLock.off(store: store, hasher: fastHasher);
      await lock.enable('482915');
      lock.lock();
      var ran = false;
      lock.runWhenUnlocked(() => ran = true);
      await lock.forgetAfterWipe();
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
      expect(store.value, isNull);
      await lock.enable('482915');
      lock.lock();
      expect(await lock.checkPin('482915'), PinCheck.ok);
      expect(ran, isFalse);
    });
  });

  group('sensitive clipboard', () {
    const channel = MethodChannel('usra/clipboard-test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? clip;

    setUp(() {
      clip = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clip = (call.arguments as Map)['text'] as String?;
          case 'Clipboard.getData':
            return clip == null ? null : {'text': clip};
        }
        return null;
      });
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('if the phone\'s copy fails, nothing goes on the clipboard '
        'unmarked', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'denied');
      });
      final copied = await SensitiveClipboard(methodChannel: channel)
          .copy('482915 730264');
      expect(copied, isFalse);
      expect(clip, isNull);
    });

    test(
      'goes to the native side, marked sensitive, when there is one',
      () async {
        final sent = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          sent.add(call);
          return null;
        });
        await SensitiveClipboard(methodChannel: channel).copy('482915 730264');
        expect(sent.single.method, 'copySensitive');
        expect(sent.single.arguments, '482915 730264');
        expect(clip, isNull);
      },
    );

    const lifetime = Duration(milliseconds: 100);

    test('without it, is cleared after its time if still ours', () async {
      final board = SensitiveClipboard(
        methodChannel: channel,
        lifetime: lifetime,
      );
      await board.copy('482915 730264');
      expect(clip, '482915 730264');
      await Future<void>.delayed(lifetime * 2);
      expect(clip, '');
    });

    test('something copied since is left alone', () async {
      final board = SensitiveClipboard(
        methodChannel: channel,
        lifetime: lifetime,
      );
      await board.copy('482915 730264');
      clip = 'a shopping list';
      await Future<void>.delayed(lifetime * 2);
      expect(clip, 'a shopping list');
    });

    test('the app waits a minute', () {
      expect(sensitiveClipboardLifetime, const Duration(seconds: 60));
    });
  });
}
