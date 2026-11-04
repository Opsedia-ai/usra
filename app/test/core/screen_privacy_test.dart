import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/screen_privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the cover and FLAG_SECURE go to the native side', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenPrivacy.channel, (call) async {
          calls.add('${call.method} ${call.arguments}');
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ScreenPrivacy.channel, null),
    );
    final privacy = ScreenPrivacy();
    await privacy.coverUntilReady(true);
    await privacy.uncover();
    await privacy.hold();
    await privacy.hold();
    await privacy.release();
    // Still one sensitive screen open: nothing sent.
    await privacy.blockAll(true);
    await privacy.release();
    await privacy.blockAll(false);
    expect(calls, [
      'coverUntilReady true',
      'uncover null',
      'setSecure true',
      'setSecure false',
    ]);
  });

  test(
    'without the native side (iOS screenshots, tests) nothing fails',
    () async {
      final privacy = ScreenPrivacy();
      await privacy.hold();
      await privacy.coverUntilReady(true);
      await privacy.uncover();
      expect(privacy.secure, isTrue);
    },
  );
}
