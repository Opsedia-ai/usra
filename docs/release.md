# Releasing Usra on Google Play

Android only for now. The iOS app (with the dose widget extension) builds unsigned in CI (`build-ios`) and runs on the simulator, but has not been signed or run on a phone yet.

## What is set up

| | |
| --- | --- |
| Application ID | `com.opsedia.usra` (permanent once uploaded) |
| Name on the launcher | أسرة (Arabic phones), Usra (English phones) |
| Version | `version:` in `app/pubspec.yaml`: `1.2.3+N` gives versionName `1.2.3`, versionCode `N` |
| SDK levels | minSdk 24, targetSdk 36 (`app/android/app/build.gradle.kts`) |
| Shrinking | R8 and resource shrinking on release builds; extra rules in `app/android/app/proguard-rules.pro` |
| Obfuscation | Dart code built with `--obfuscate --split-debug-info`; native symbol tables in the bundle (`debugSymbolLevel = SYMBOL_TABLE`) |
| Network | No cleartext HTTP: `usesCleartextTraffic="false"` and `res/xml/network_security_config.xml` (system CAs only) |
| Signing | Upload key from `app/android/key.properties` or `USRA_UPLOAD_*` env vars; debug key otherwise |
| Icon and splash | `app/assets/branding/`, from `tools/branding/render_icons.py` |

## Toolchain versions

Release builds are made with these exact versions. CI uses the same Flutter, so a build that passes CI is a build you can reproduce.

| Tool | Version | Where it is set |
| --- | --- | --- |
| Flutter | 3.50.0 (Dart 3.14.0) | `FLUTTER_VERSION` in `.github/workflows/app-ci.yml` and `test-build.yml` |
| Android Gradle Plugin | 9.3.1 | `app/android/settings.gradle.kts` |
| Kotlin Gradle Plugin | 2.4.20 | `app/android/settings.gradle.kts` |
| Gradle | 9.5.0 (checksum pinned) | `app/android/gradle/wrapper/gradle-wrapper.properties` |
| Java | 17 (Temurin in CI) | `actions/setup-java` in the workflows |
| CocoaPods | 1.17.0 | last line of `app/ios/Podfile.lock` |
| Xcode | the `macos-latest` runner's default | not pinned |

Flutter 3.50.0 refuses Android Gradle Plugin versions below 9.1.1, Kotlin below 2.4.10 and Gradle below 9.3.1, and warns below 9.3.1, 2.4.20 and 9.5.0. The versions above are the ones Flutter 3.50.0's own app template uses, so there are no warnings.

Locally, use the same Flutter: `flutter --version` should say 3.50.0. To switch, install 3.50.0 with your version manager (`fvm install 3.50.0`), or run `git fetch --tags && git checkout 3.50.0` inside a git clone of Flutter; a Homebrew Flutter follows Homebrew's version instead. Flutter 3.50 marks `package:flutter/material.dart` as deprecated; `app/analysis_options.yaml` hides those notices until the move to `material_ui`.

**Upgrading Flutter.** Change `FLUTTER_VERSION` in both workflows on purpose, in its own PR: read the new release's Android minimums (`DependencyVersionChecker.kt` in `flutter_tools`, or the error a release build prints), bump the versions above to match its app template, label the PR `release-build` so the release bundle builds, and update this table.

## 1. Create the upload key (once)

Play App Signing keeps the real app signing key; we only hold an **upload key**. If it is lost, Play support can reset it, but keep it backed up in the team password manager.

```bash
keytool -genkeypair -v -keystore ~/keys/usra-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Never commit the keystore or `key.properties`; `app/android/.gitignore` ignores `key.properties`, `*.jks` and `*.keystore`.

## 2. Point the build at it

Either copy the example and fill it in:

```bash
cp app/android/key.properties.example app/android/key.properties
```

or export the same values (for CI, from secrets):

| `key.properties` | Environment variable |
| --- | --- |
| `storeFile` | `USRA_UPLOAD_STORE_FILE` |
| `storePassword` | `USRA_UPLOAD_STORE_PASSWORD` |
| `keyAlias` | `USRA_UPLOAD_KEY_ALIAS` |
| `keyPassword` | `USRA_UPLOAD_KEY_PASSWORD` |

`key.properties` wins over the environment; a blank value in it (`storePassword=`) counts as missing, so the env var is used. `storeFile` may be absolute or relative to `app/android/`.

Without either, a release build prints `Usra: no upload key … signing release with the debug key` and still succeeds. That bundle installs on a device but **Play rejects it**. To make a missing key an error instead, set `USRA_REQUIRE_UPLOAD_KEY=true`: always do this for a real release and in any CI job that uploads to Play, so a renamed or missing secret fails the build instead of producing a debug-signed bundle.

## 3. Build

Bump the build number in `app/pubspec.yaml` first (every upload needs a higher versionCode), then:

```bash
cd app && USRA_REQUIRE_UPLOAD_KEY=true flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/$(sed -n 's/^version: *//p' pubspec.yaml)
```

`--obfuscate` renames Dart classes and functions in the shipped `libapp.so`; `--split-debug-info` writes the symbols needed to read stack traces from that build to `app/build/symbols/<version>/`. **Keep that folder for every uploaded build**, privately (the team drive or password manager's file storage, not the repo, not a public release). Without it, crash stack traces from that version can't be read. To decode one:

```bash
flutter symbolize -i crash.txt -d app/build/symbols/<version>/app.android-arm64.symbols
```

The bundle is `app/build/app/outputs/bundle/release/app-release.aab`. Check it was signed with the upload key, not the debug key:

```bash
keytool -printcert -jarfile app/build/app/outputs/bundle/release/app-release.aab
```

The owner should be your upload key, not `CN=Android Debug`.

To try the release build on a phone before uploading:

```bash
cd app && flutter build apk --release && flutter install --release
```

Check in it: reminders fire (including after a reboot), the home-screen widget updates, scanning a prescription reads text, and a backup restores. These are the parts that depend on R8 keeping plugin classes.

### The two release files

| | Command (from `app/`) | Output |
| --- | --- | --- |
| Android, for Play | `USRA_REQUIRE_UPLOAD_KEY=true flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/<version>` | `build/app/outputs/bundle/release/app-release.aab` |
| Android, debug-signed (CI, trying it out) | the same without `USRA_REQUIRE_UPLOAD_KEY` | the same file, signed with the debug key; Play rejects it |
| iOS, unsigned (what CI proves) | `flutter build ios --release --no-codesign` | `build/ios/iphoneos/Runner.app` |
| iOS, for the App Store | `flutter build ipa --release --obfuscate --split-debug-info=build/symbols/<version>` | `build/ios/ipa/*.ipa` |

The iOS App Store build needs the Apple Developer account's signing set up in Xcode (team, bundle IDs for `Runner` and the `DoseWidget` extension, the App Group `group.com.opsedia.usra` registered for both; see `app/ios/DoseWidget/README.md`). That has not been done yet, so no `.ipa` has been made. Before an iOS build, `cd ios && pod install` must leave `Podfile.lock` unchanged; CI fails if it does not.

## 4. Upload to internal testing

1. Play Console → the Usra app → **Testing → Internal testing → Create new release**.
2. First release only: accept Play App Signing (Google generates the app signing key).
3. Upload `app-release.aab`, add release notes (Arabic first), **Save → Review release → Start rollout to Internal testing**.
4. Add testers under **Testers** (an email list) and share the opt-in link.

Before the first production release the store listing, content rating, Data safety form and privacy policy have to be filled in; that is tracked separately.

## Rolling back a release that changed the database schema

Rollback is **fix forward**: ship a new build with a higher version code,
never an older one. If an older build does open a newer database (sideload,
or a rollback in a store track), Drift calls `onUpgrade` with
`from > to`; our migrations only act on `from < N`, so the older build
opens the database as it is, keeps the newer tables and columns it doesn't
know, and sets `user_version` back to its own version. The next update then
runs the newer migrations again, which is why they must be safe to repeat
(`createTable` is `IF NOT EXISTS`; added columns go through
`_addColumnIfMissing`). `test/core/sick_days_test.dart` checks this for v8
(a v7 build opens a v8 database, then the v8 build opens it again with its
data). Backups made on a newer schema are refused by an older build.

## CI

`.github/workflows/app-ci.yml` builds a debug-signed, obfuscated release bundle (job `build-android-release`) on pushes to `main` that touch `app/**` or the workflow file, so R8, obfuscation or signing breakage shows up before release day. Add the `release-build` label to a PR to run it there too. It does not upload the bundle or use the upload key. Its Dart symbols are kept as a workflow artifact for 7 days, for debugging CI builds only.

## Regenerating the icon and splash

```bash
python3 -m venv /tmp/usra-icons && /tmp/usra-icons/bin/pip install pillow svg.path
/tmp/usra-icons/bin/python tools/branding/render_icons.py
cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

The generators also rewrite `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, `ios/Runner.xcodeproj/project.pbxproj` and `ios/Runner/Info.plist` (and add unused iPad PNGs). Keep the regenerated PNGs and revert those files with `git checkout`, deleting any PNG the old `Contents.json` doesn't list.

### Saving CI minutes

The debug Android build (`build-android`) runs on a PR only when it changes `app/android/`, `app/ios/`, `app/pubspec.yaml`/`pubspec.lock`, `tools/ci/` or the workflow itself; Dart-only and docs PRs run just the tests. Add the `android-build` label to force it. Main pushes skip the debug build because the release bundle job compiles the same code. The unsigned iOS release build (`build-ios`, macOS runner) runs on PRs that change `app/ios/`, `app/pubspec.yaml`/`pubspec.lock` or the workflow, on PRs labelled `ios-build`, and on main pushes; it caches CocoaPods by `Podfile.lock` and fails if `pod install` changes committed files. A new push to a PR cancels that PR's older run.
