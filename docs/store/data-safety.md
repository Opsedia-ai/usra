# Data safety, privacy labels and health declarations

Answers for Usra v1 (local-only), taken from the code as of this branch. Re-check
this file whenever a permission, SDK or network call is added; the M6 cloud features
(accounts, sync, AI Doctor, cloud OCR) will change most answers (see the last section).

## What the app actually does (source of the answers)

| Capability | Where in the code | Data leaves the phone? |
| --- | --- | --- |
| Encrypted database (SQLite3 Multiple Ciphers), key in Keystore / Keychain | `core/database/`, `flutter_secure_storage` | No |
| Photos of cards, reports, medicine boxes, stored in app storage | `core/files/photo_store.dart`, `image_picker` | No |
| Text recognition on photos (Latin script) | `core/ocr/`, `google_mlkit_text_recognition` (bundled model) | Photos and text: no. Google ML Kit may send its own anonymous usage and diagnostics data, see below |
| Medicine reminders, Taken / Snooze buttons | `features/medicines/`, `flutter_local_notifications` | No |
| Home-screen widget with today's doses | `features/medicines/dose_widget.dart`, `home_widget` | No (shown on the home screen) |
| Encrypted backup file, shared by the user to a place they choose | `core/backup/`, `share_plus`, `file_picker` | Only where the user sends it, encrypted; we never receive it |
| Call / WhatsApp a doctor, open links | `features/doctors/`, `url_launcher` | Opens the other app; nothing sent by Usra |
| App version shown in About | `package_info_plus` | No |
| Accounts, analytics, crash reporting, ads, payments | none in v1 | – |

Android OS backup and device-to-device transfer are switched off for all app data
(`android:allowBackup="false"`, `res/xml/data_extraction_rules.xml`), and nothing is
written to iCloud (Apple 5.1.3).

### Permissions

Android, `app/src/main/AndroidManifest.xml`:

| Permission | Why |
| --- | --- |
| `POST_NOTIFICATIONS` | Medicine reminders (asked from the Medicines tab, Android 13+) |
| `SCHEDULE_EXACT_ALARM` | Reminders on the minute (user grants it in system settings, Android 12+). Not `USE_EXACT_ALARM`, so no Play exact-alarm declaration is needed |
| `RECEIVE_BOOT_COMPLETED` | Re-arm reminders and the widget after a restart |
| `VIBRATE` (from flutter_local_notifications) | Reminder vibration |

No camera or storage permission: `image_picker` uses the system camera app and the
Android photo picker, `file_picker` the system file picker.

**To verify on the release build** (other session, M5 release build): the merged
manifest (`build/app/intermediates/merged_manifests/release/.../AndroidManifest.xml`).
ML Kit pulls in Google's `datatransport` libraries, which normally add `INTERNET` and
`ACCESS_NETWORK_STATE`. If they are there, the ML Kit row below applies; if not, the
answer for Android is simply "No data collected".

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

The answers below therefore declare ML Kit's diagnostics. If Google's page says that
the bundled text-recognition model sends nothing, drop those rows.

## Google Play: Data safety form

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** (only because of ML Kit diagnostics; otherwise No) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (ML Kit sends over HTTPS) |
| Do you provide a way for users to request that their data be deleted? | **No** account or server copy exists. Explain in the policy: deleting the app deletes all data; ML Kit data is anonymous and held by Google |

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
  transfer, not collection or sharing by the developer.
- **Personal info, Financial info (spending totals), Contacts (doctors' numbers typed in
  by the user), Location, Messages, App activity, Web browsing**: not collected.

## Google Play: other App content declarations

| Declaration | Answer |
| --- | --- |
| Privacy policy | Hosted URL of `docs/legal/privacy-policy.en.md` (and `.ar.md`); must match `privacyPolicyUrl` in the app |
| Ads | No ads |
| App access | All functionality available without special access (no login) |
| Target audience | 18 and over. The app is for adults managing their family's records; it is not designed for children, so it stays out of the Families programme |
| Content rating (IARC) | Reference / medical information, no violence, no user-to-user interaction, no purchases. Expected: Everyone / PEGI 3 |
| Data safety | As above |
| Government app | No |
| Financial features | None |
| **Health apps** | See below |
| Health Connect | Not used |
| Exact alarm (`USE_EXACT_ALARM`) | Not used (we use `SCHEDULE_EXACT_ALARM`) |

### Health apps declaration (Play Console → App content → Health apps)

Pick the features the app has (labels as they appear in the Console; confirm before submitting):

- **Medical** → Medication and treatment management (medicines, reminders)
- **Medical** → Medical records / Health records management (family records, attachments)
- **Medical** → Disease and condition management (follow-ups after visits, conditions on the emergency card)
- **Medical** → Reproductive and sexual health (pregnancy mode)
- **Medical** → Medical reference and education (vaccine schedule, growth standards, milestones, with sources)
- Not selected: clinical decision support, emergency and first aid service, health research, physical therapy, activity/fitness, nutrition, period tracking, sleep, mental health.

Statements to have ready (the Console may ask):

- Usra is **not a medical device** and is not cleared by any regulator (EDA, SFDA, MOHAP, FDA, CE). It does not diagnose, treat, calculate doses or interpret results.
- Growth charts use WHO Child Growth Standards; vaccine schedule follows the Egyptian
  Ministry of Health schedule; follow-up suggestions cite their source in the app.
- The in-app disclaimer is on the More tab, on the About & privacy screen and in the store description.

## Apple: App Privacy ("nutrition label")

| Question | Answer |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **Yes**, only because of ML Kit (if Google's iOS page confirms it; otherwise **No, Data Not Collected**) |
| Data types | **Diagnostics → Performance Data** and **Other Diagnostic Data** |
| Linked to the user's identity? | No |
| Used for tracking? | No |
| Purposes | Analytics (third party's SDK measurement) |

Health & Fitness, Photos, User Content, Contact Info, Identifiers (IDFA), Location,
Purchases, Financial Info: **not collected**, for the same reasons as Play.

### Privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy` does not exist yet. Plugins ship their own; the
app target still needs one declaring `NSPrivacyTracking = false`, no tracking domains,
and the required-reason APIs it uses directly (UserDefaults through
`shared_preferences`: `CA92.1`; file timestamps if any). Follow-up for the iOS release
build, not in this change.

## Apple: medical and health review points

| Point | How Usra meets it |
| --- | --- |
| 1.4.1 Physical harm, medical apps | No diagnosis or measurement claims; disclaimer in the app and description; sources shown for suggestions |
| 1.4.2 Drug dosage calculators | None. OCR returns a name and strength only, never a dose |
| 5.1.1 Data collection and storage | No account; privacy policy linked in App Store Connect and in the app (More → About & privacy) |
| 5.1.1(ix) Highly regulated field | Submitted by Opsedia as an organisation |
| 5.1.3 Health and health research | No HealthKit; no health data in iCloud; no data used for ads or sold |
| Age rating questionnaire | "Medical or Treatment Information": **Infrequent/Mild**. Expected rating 9+ / 12+ depending on the new questionnaire |
| Regulated medical device question (EU) | **No** |

## When M6 cloud features ship

These change the answers above and need a new review before release:

- **Phone-number accounts (Supabase Auth)**: Personal info → Phone number; Device or
  other IDs; account deletion inside the app and on the web (Play and Apple 5.1.1(v)).
- **Push notifications**: device push token (Device or other IDs).
- **End-to-end encrypted sync**: ciphertext only; still declare "Health info" collected
  if any readable metadata leaves the phone; otherwise document why ciphertext is not
  collection.
- **AI Doctor**: de-identified health snapshot sent to an AI provider after the user
  previews it: Health info collected and shared with a processor, purpose App
  functionality; KSA gate (SFDA MDS-G27) and Egypt PDPL transfer licence.
- **Cloud OCR fallback**: photo of a prescription sent with consent: Photos collected,
  ephemeral.
- **Credits / subscription (RevenueCat, store billing)**: Purchase history.
