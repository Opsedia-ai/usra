# UI quality checks

Every check opens real screens of the app with the same made-up family
(`lib/demo/demo_family.dart`: a grandmother in Simple Mode, a pregnant
mother, a father, a toddler with a fever, a three-month-old) at a fixed date
(`demoNow` in `ui_harness.dart`), so results never depend on the day.

| File | What fails it |
| --- | --- |
| `accessibility_test.dart` | A tap target under 48×48 (Android) or 44×44 (iOS), something tappable with no label, text under WCAG AA contrast. 16 main screens, Arabic and English. |
| `text_scale_test.dart` | Any layout error (overflow stripes, a row that can't fit) at text size 2.0 on the 16 main screens, Arabic and English, scrolled to the bottom. |
| `journeys_test.dart` | The four top tasks (record a vaccine, add a medicine from a prescription photo, find the emergency card, mark a dose taken) stop working from Home, or take more taps than `journeys.dart` allows. |
| `goldens/key_screens_golden_test.dart` | 10 key screens look different from the images in `goldens/images/` (Arabic, English, Arabic at 1.6× text). |

A new main screen goes in `mainScreens` (`ui_harness.dart`); all checks
pick it up.

```bash
flutter test test/ui --exclude-tags golden   # everything but goldens
flutter test --tags golden                    # goldens (compared on Linux only)
```

## Goldens

Text renders slightly differently on each OS, so the images are made and
compared on Linux, in CI's `goldens` job (pinned `ubuntu-24.04` and Flutter
3.47.9). On macOS and Windows the comparison is skipped.

Real fonts are loaded so the images are readable: Amiri (the app's PDF font)
for Arabic and Latin text, plus Material icons. Text whose style has no font
family (button labels) still draws as boxes; layout changes show anyway.

When a change to a key screen is intended:

1. Add the `update-goldens` label to the PR. The `goldens` job writes new
   images instead of comparing and uploads them as the `goldens-<sha>`
   artifact.
2. Download it, look at every image, and copy them into
   `test/ui/goldens/images/`:
   ```bash
   gh run download <run-id> -n goldens-<sha> -D app/test/ui/goldens/images
   ```
3. Commit, and remove the label. While it is on the job never compares, so
   it fails on purpose with a reminder.

With Docker, the same works locally:

```bash
docker run --rm -v "$PWD":/app -w /app/app ghcr.io/cirruslabs/flutter:3.47.9 \
  flutter test --tags golden --update-goldens
```

When the comparison fails, the job uploads `golden-failures-<sha>` with the
expected, actual and difference image of each screen.
