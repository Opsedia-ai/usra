# Releasing Usra on Google Play

Android only for now. The iOS icon and launch screen are generated, but the iOS app has not been built or signed yet.

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

## 4. Upload to internal testing

1. Play Console → the Usra app → **Testing → Internal testing → Create new release**.
2. First release only: accept Play App Signing (Google generates the app signing key).
3. Upload `app-release.aab`, add release notes (Arabic first), **Save → Review release → Start rollout to Internal testing**.
4. Add testers under **Testers** (an email list) and share the opt-in link.

Before the first production release the store listing, content rating, Data safety form and privacy policy have to be filled in; that is tracked separately.

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

The debug Android build (`build-android`) runs on a PR only when it changes `app/android/`, `app/ios/`, `app/pubspec.yaml`/`pubspec.lock`, `tools/ci/` or the workflow itself; Dart-only and docs PRs run just the tests. Add the `android-build` label to force it. Main pushes skip the debug build because the release bundle job compiles the same code. A new push to a PR cancels that PR's older run.
