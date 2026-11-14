# Data safety, privacy labels and health declarations

Answers for the Usra v1 build with no accounts, as the beta is unless the lawyer's answer
arrives first, taken from the
code as of this branch. Re-check this file whenever a permission, SDK or network call is
added; accounts and the paywall, and later the v2 features, change most answers (see the
last section).

## What the app actually does (source of the answers)

| Capability | Where in the code | Data leaves the phone? |
| --- | --- | --- |
| Encrypted database (SQLite3 Multiple Ciphers), key in Keystore / Keychain | `core/database/`, `flutter_secure_storage` | No |
| Photos of cards, reports, medicine boxes: **encrypted files** (XChaCha20-Poly1305, key in Keystore / Keychain) in the app's private storage | `core/files/photo_store.dart`, `core/files/photo_crypto.dart` | No |
| Taking / picking those photos | `image_picker` | No |
| Text recognition on photos (Latin script) | `core/ocr/`, `google_mlkit_text_recognition` (bundled model) | Photos and text: no. Google ML Kit may send its own diagnostics with a random per-installation ID, see below |
| Medicine reminders, Taken / Snooze buttons | `features/medicines/`, `flutter_local_notifications` | No |
| Home-screen widget with today's doses (times and how many doses only, never names) | `features/medicines/dose_widget.dart`, `home_widget` | No (shown on the home screen) |
| Reminder notifications (neutral text by default; the person's name as entered and the medicine name can show on the lock screen if discreet mode is off) | `features/medicines/local_notification_scheduler.dart` | No |
| Encrypted backup file, shared by the user to a place they choose | `core/backup/`, `share_plus`, `file_picker` | Only where the user sends it, encrypted; we never receive it |
| Automatic encrypted backup to a folder the user picks once (optional, off by default; never iCloud Drive) | `core/backup/`, `features/backup/`, Storage Access Framework on Android, security-scoped bookmark on iOS; no new permissions | Only to that folder, encrypted, with no network call by Usra; we never receive it |
| Vaccination record and doctor summary PDFs, made on the phone and shared by the user (not encrypted: readable by whoever receives them; a warning says so first) | `features/reports/`, `pdf`, `share_plus` | Only where the user sends it; we never receive it. The file is deleted from the phone after sharing |
| Call / WhatsApp a doctor, open links | `features/doctors/`, `url_launcher` | Opens the other app; nothing sent by Usra |
| App version shown in About | `package_info_plus` | No |
| Analytics, crash reporting, ads | none in any v1 build | – |
| Accounts, payments | none in a build with no accounts. Accounts only if a build sets `SUPABASE_URL`, and payments only once the paywall is on (see the last section) | – |

> **TODO:** `aboutPrivacyOnPhone` (ARB en/ar) still says only that photos are in the app's
> private storage. Update it to say they're encrypted, to match the privacy policy and store texts.

Android OS backup and device-to-device transfer are switched off for all app data
(`android:allowBackup="false"`, `res/xml/data_extraction_rules.xml`). On iOS the
database folder (`usra.sqlite`, its `-wal`/`-shm`, and the photo folders inside it) is
marked `isExcludedFromBackup` at every start (`excludeDatabaseFromBackup` in
`core/database/connection.dart`, called from `main.dart`), and each photo folder again
when a photo is saved, so no health data goes to iCloud or iTunes backups (Apple 5.1.3).

### Permissions

Android, `app/src/main/AndroidManifest.xml`:

| Permission | Why |
| --- | --- |
| `POST_NOTIFICATIONS` | Medicine reminders (asked from the Medicines tab, Android 13+) |
| `SCHEDULE_EXACT_ALARM` | Reminders on the minute (user grants it in system settings, Android 12+). Not `USE_EXACT_ALARM`, so no Play exact-alarm declaration is needed |
| `RECEIVE_BOOT_COMPLETED` | Re-arm reminders and the widget after a restart (also declared by WorkManager) |
| `USE_BIOMETRIC` | App lock with fingerprint or face (`local_auth`) |

Added by libraries in the merged manifest (checked on 13 Nov 2026 from each plugin's
manifest and the Maven manifests of their Android dependencies, not yet from a built
APK, because the release build was broken that day):

| Permission | From | Play Console |
| --- | --- | --- |
| `VIBRATE` | flutter_local_notifications | Nothing to declare |
| `INTERNET` | google_sign_in_android, ML Kit's `datatransport` | Nothing to declare. In every build, accounts off too, so it says nothing about what is sent |
| `ACCESS_NETWORK_STATE` | ML Kit's `datatransport`, WorkManager | Nothing to declare |
| `WAKE_LOCK`, `FOREGROUND_SERVICE` | WorkManager (`androidx.work`, through home_widget) | Nothing to declare: no `FOREGROUND_SERVICE_<TYPE>` permission and no service with a `foregroundServiceType`, so Play's foreground service declaration doesn't apply |

Not in the manifest, so no declaration and nothing to remove: `CAMERA`,
`READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_EXTERNAL_STORAGE`,
`USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `QUERY_ALL_PACKAGES`, any
`FOREGROUND_SERVICE_<TYPE>`, location, contacts. `image_picker` uses the system
camera app and the Android photo picker (Play's Photo and Video Permissions policy is
met), `file_picker` the system file picker. Package visibility uses a `<queries>` list
of three intents (process text, dial, https), not `QUERY_ALL_PACKAGES`.

**ML Kit sends diagnostics, so the ML Kit rows below apply.** `com.google.mlkit:common`
18.11.0 and `vision-common` 17.3.0 depend on `transport-backend-cct` and
`transport-runtime` (Google's `datatransport`), which add the `INTERNET` and
`ACCESS_NETWORK_STATE` permissions and their upload services to the merged manifest.
A build with accounts always collects more (see the last section).

Re-check on the first release bundle: `bundletool dump manifest --bundle app-release.aab`
and compare with the two tables above. Any new permission means a new review of this file.

iOS, `ios/Runner/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
(both say photos and text read from them stay on the phone). Notification permission is
asked at runtime. No HealthKit, no location, no contacts, no tracking (no
`NSUserTrackingUsageDescription`, no IDFA).

### Third-party SDK: Google ML Kit

Google's disclosure pages (re-read before submitting, they change):
<https://developers.google.com/ml-kit/android-data-disclosure> and the iOS equivalent.
They state that ML Kit APIs may send Google device information (model, OS version),
app information (package name, app version), a per-installation identifier, API
configuration and performance metrics, to measure and improve the SDK. Images and
recognised text are processed on the device and not sent.

The answers below therefore declare ML Kit's diagnostics **and its per-installation
identifier**, the same way on Play and Apple. It is random, not linked to the user's
identity and not used for tracking, but it is an identifier, so no text calls this
data "anonymous". If Google's page says that the bundled text-recognition model sends
nothing, drop those rows in both forms.

## Google Play: Data safety form

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** (only because of ML Kit diagnostics; otherwise No) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (ML Kit sends over HTTPS) |
| Do you provide a way for users to request that their data be deleted? | With accounts: **Yes**, see the last section. Without them: **No** account or server copy exists. Explain in the policy: More › Delete all my data (or deleting the app) deletes all data on the phone; ML Kit data is held by Google, keyed by a random install ID we cannot look up |

Data types (everything else: not collected, not shared):

| Category → type | Collected | Shared | Ephemeral | Required | Purpose |
| --- | --- | --- | --- | --- | --- |
| App info and performance → Diagnostics | Yes (ML Kit) | No | No | Required | Analytics (SDK performance) |
| Device or other IDs → Device or other IDs | Yes (ML Kit per-installation ID) | No | No | Required | Analytics |

Not collected, with the reason (keep for the reviewer and for our own audits):

- **Health and fitness → Health info**: records, medicines, growth, pregnancy data stay
  in the encrypted database on the phone. Processing only on the device is not
  "collection" in Play's definition.
- **Photos and videos**: stored only on the phone.
- **Files and docs**: the backup file is created on the phone and sent only where the
  user chooses with the system share sheet; Play counts that as a user-initiated
  transfer, not collection or sharing by the developer. Automatic backup writes the same
  encrypted file to a folder the user picked with the system picker. Usra makes no network
  call for it, but if the folder belongs to a cloud provider, that provider's app uploads it.
- **Personal info, Financial info (spending totals), Contacts (doctors' numbers typed in
  by the user), Location, Messages, App activity, Web browsing**: not collected.

## Google Play: other App content declarations

| Declaration | Answer |
| --- | --- |
| Privacy policy | <https://opsedia.ai/usra/en/privacy> (Arabic: <https://opsedia.ai/usra/ar/privacy>), from `docs/legal/privacy-policy.en.md` and `.ar.md`. The app opens the same pages when built with `USRA_WEBSITE=https://opsedia.ai/usra` (`docs/release.md`) |
| Account deletion URL | Not needed in a build with no accounts (answer "No" to "Does your app allow users to create an account?"). Needed before any build with accounts ships, and the page doesn't exist yet |
| Ads | No ads |
| App access | All functionality available without special access. With accounts: no login is needed until the paywall (subscribing or redeeming a code) |
| Target audience | 18 and over. The app is for adults managing their family's records; it is not designed for children, so it stays out of the Families programme |
| Content rating (IARC) | Reference / medical information, no violence, no user-to-user interaction, no purchases (with the paywall on: in-app purchases). Expected: Everyone / PEGI 3 |
| Data safety | As above |
| Government app | No |
| Financial features | None |
| **Health apps** | See below |
| Health Connect | Not used |
| Exact alarm (`USE_EXACT_ALARM`) | Not used (we use `SCHEDULE_EXACT_ALARM`, which the person grants and which needs no declaration) |
| Full-screen intent, foreground services, photo and video permissions | Not used, nothing to declare (see Permissions above) |
| Developer account type | **Organization.** Play requires it for health apps: "developers providing the following services must register as an Organization: … Health apps, such as Medical apps" (Play Console Requirements, answer 10788890). Needs Opsedia's D-U-N-S number |

### Health apps declaration (Play Console → App content → Health apps)

Pick the features the app has (labels as they appear in the Console; confirm before submitting):

- **Medical** → Medication and treatment management (medicines, reminders)
- **Medical** → Medical records / Health records management (family records, attachments)
- **Medical** → Disease and condition management (follow-ups after visits, conditions on the emergency card)
- **Medical** → Reproductive and sexual health (pregnancy mode)
- **Medical** → Medical reference and education (vaccine schedule, growth standards, milestones, with sources)
- Not selected: clinical decision support, emergency and first aid service, health research, physical therapy, activity/fitness, nutrition, period tracking, sleep, mental health.

Statements to have ready (the Console may ask):

- Usra is **not a medical device** and is not cleared by any regulator (EDA, SFDA, JFDA, FDA, CE). It does not diagnose, treat, calculate doses or interpret results.
- Growth charts use WHO Child Growth Standards; vaccine schedule follows the Egyptian
  Ministry of Health schedule; follow-up suggestions cite their source in the app.
- The in-app disclaimer is on the More tab, on the Privacy and terms screen and in the store description.

## Apple: App Privacy ("nutrition label")

| Question | Answer |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **Yes**, only because of ML Kit (if Google's iOS page confirms it; otherwise **No, Data Not Collected**) |
| Data types | **Diagnostics → Performance Data**, **Diagnostics → Other Diagnostic Data**, **Identifiers → Device ID** (ML Kit's per-installation ID; matches Play's "Device or other IDs") |
| Linked to the user's identity? | No |
| Used for tracking? | No |
| Purposes | Analytics (third party's SDK measurement) |

Health & Fitness, Photos, User Content, Contact Info, Identifiers → User ID, IDFA
(advertising), Location, Purchases, Financial Info: **not collected**, for the same
reasons as Play.

### Privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy` and `ios/DoseWidget/PrivacyInfo.xcprivacy` declare
`NSPrivacyTracking = false`, no tracking domains, no collected data, and UserDefaults with
reasons `CA92.1` (the app's own settings, through `shared_preferences`) and `1C8F.1` (the
app group shared with the dose widget). Plugins and SDKs ship their own manifests, which
Xcode merges into the privacy report. When accounts ship, add the name, email and user ID
the sign-in collects (see the accounts section above).

## Apple: medical and health review points

| Point | How Usra meets it |
| --- | --- |
| 1.4.1 Physical harm, medical apps | No diagnosis or measurement claims; disclaimer in the app and description; sources shown for suggestions |
| 1.4.2 Drug dosage calculators | None. OCR returns a name and strength only, never a dose |
| 5.1.1 Data collection and storage | No account (with accounts: required from the first saved record, with in-app deletion, see the last section); privacy policy linked in App Store Connect and in the app (More → About & privacy) |
| 5.1.1(ix) Highly regulated field | Submitted by Opsedia as an organisation |
| 5.1.3 Health and health research | No HealthKit; database and photo folders excluded from iCloud backup; automatic backup refuses iCloud Drive folders; no data used for ads or sold. For legal review: the manual share sheet is the system's and lets a person choose iCloud Drive for the encrypted file themselves |
| Age rating questionnaire | "Medical or Treatment Information": **Infrequent/Mild**. Expected rating 9+ / 12+ depending on the new questionnaire |
| Regulated medical device question (EU) | **No** |

## When accounts, the paywall and later features ship

These change the answers above and need a new review before release.

### Accounts and the paywall (v1, off in the beta)

No real family signs in until an Egyptian lawyer has answered the questions in
[`docs/login-setup.md`](../login-setup.md), step 6.

- **Google and Apple accounts (Supabase Auth, Google Sign-In SDK)**: not needed until the
  paywall. Only builds with `SUPABASE_URL` and sign-in client IDs show them. They also
  hold a member number and subscription status (`docs/prd-v1.md`, F23), which aren't built yet.
  - Play: Personal info → Name, Email address, User IDs; Device or other IDs. Collected,
    not shared, for App functionality and Account management. Account creation method:
    OAuth.
  - Apple: Contact Info → Name, Email Address; Identifiers → User ID. Linked to the user,
    for App Functionality, not used for tracking. Apple sign-in sends the email or a relay
    address only; Google also sends the name and a profile photo link, which Supabase Auth
    keeps with the user.
  - Sign in with Apple sits beside Google (guideline 4.8).
  - Deleting the account works in the app, and revokes Sign in with Apple through Apple's
    API (5.1.1(v), TN3194). Play also needs a web page for deletion requests. That page
    doesn't exist yet.
  - No SMS is sent, and no phone number is collected for sign-in.
  - The sign-in SDKs are in every build, but do nothing and make no network calls until
    someone taps a button.
  - Android: `google_sign_in_android` adds the `INTERNET` permission to every release
    build, including builds with accounts off. It doesn't change what's sent, but don't
    answer that a build has no network permission.
- **Monthly and Yearly subscriptions and Lifetime (RevenueCat, store billing)**: Purchase history.

### v2 and later

- **Push notifications**: device push token (Device or other IDs).
- **End-to-end encrypted sync**: ciphertext only; still declare "Health info" collected
  if any readable metadata leaves the phone; otherwise document why ciphertext is not
  collection.
- **Dr. Usra AI** (shown as "coming soon" in v1, with no network call): de-identified health snapshot sent to an AI provider after the user
  previews it: Health info collected and shared with a processor, purpose App
  functionality; KSA gate (SFDA MDS-G27) and Egypt PDPL transfer licence.
- **Cloud photo reading**: photo of a prescription sent with consent: Photos collected,
  ephemeral.
