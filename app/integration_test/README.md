# On-device tests

Run on an iOS simulator (or a phone) with the demo family in an in-memory
database: nothing touches the app's real records.

```bash
xcrun simctl list devices booted              # the simulator's id
cd app
flutter test integration_test/journeys_test.dart -d <device-id>
```

`journeys_test.dart` runs the four top tasks from Home, tapping like a
person (`test/ui/journeys.dart`); CI runs the same journeys as widget tests.

`screen_tour_test.dart` saves a screenshot of every main screen to
`build/screenshots/`, for UX reviews. It needs the driver, which receives
the images:

```bash
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screen_tour_test.dart -d <device-id> \
  --dart-define=TOUR_LOCALE=ar --dart-define=TOUR_TEXT_SCALE=1.0
```

`TOUR_LOCALE` is `ar` or `en`; `TOUR_TEXT_SCALE` is the phone text size
(1.6 is about iOS's largest Dynamic Type setting outside accessibility
sizes).

On Apple Silicon, ML Kit has no simulator slice: run
`tools/ios/mlkit_simulator.sh` after `pod install` before building for the
simulator (and delete `app/ios/Pods` before a device build).
