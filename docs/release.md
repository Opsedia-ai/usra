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

`key.properties` wins over the environment. `storeFile` may be absolute or relative to `app/android/`.

Without either, the build prints `Usra: no upload key … signing release with the debug key` and still succeeds. That bundle installs on a device but **Play rejects it**.

## 3. Build

Bump the build number in `app/pubspec.yaml` first (every upload needs a higher versionCode), then:

```bash
cd app && flutter build appbundle --release
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

`.github/workflows/app-ci.yml` builds a debug-signed release bundle on every push to `main` (job `build-android-release`), so R8 or signing breakage shows up before release day. Add the `release-build` label to a PR to run it there too. It does not upload anything or use the upload key.

## Regenerating the icon and splash

```bash
python3 -m venv /tmp/usra-icons && /tmp/usra-icons/bin/pip install pillow svg.path
/tmp/usra-icons/bin/python tools/branding/render_icons.py
cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

The generators also rewrite `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, `ios/Runner.xcodeproj/project.pbxproj` and `ios/Runner/Info.plist` (and add unused iPad PNGs). Keep the regenerated PNGs and revert those files with `git checkout`, deleting any PNG the old `Contents.json` doesn't list.
