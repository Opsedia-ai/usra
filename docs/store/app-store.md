# App Store listing

Primary language: **Arabic**. Second localization: **English (U.S.)**.
Primary category: **Medical**. Secondary: **Health & Fitness**.
Seller: **Opsedia** (organisation account, see `docs/decisions.md`).
Price: **Free**. In-app purchases: **None** in a build with no accounts, as the beta is unless the lawyer's answer arrives first. With the paywall on: **1-year pass and Lifetime**.

Counts are `characters / limit` (keywords: `bytes / limit`); check with
`python3 tools/store/check_lengths.py`.

The full description, the screenshots and the "not a medical device" line match the
Play listing so both stores say the same thing.

## العربية

### Name (20/30)

```text
أسرة: ملف صحة العيلة
```

### Subtitle (28/30)

```text
سجلات وأدوية وتطعيمات العيلة
```

### Promotional text (124/170)

```text
كل صحة العيلة على موبايلك، والسجلات والصور متشفرة: ملف لكل فرد، تذكير بالأدوية، تطعيمات الأطفال، ونسخة احتياطية في إيدك إنت.
```

### Keywords (96/100 bytes)

```text
روشتة,دواء,تطعيمات,تحاليل,حمل,اطفال,تأمين,دكتور,منبه
```

### Description

Same text as the Play full description (Arabic), `google-play.md`.

### What's New (93/4000)

```text
أول نسخة من أسرة: ملف صحي لكل فرد في العيلة، أدوية بمواعيدها، تطعيمات، ونسخة احتياطية متشفرة.
```

## English (U.S.)

### Name (24/30)

```text
Usra: Family Health File
```

### Subtitle (29/30)

```text
Records, medicines & vaccines
```

### Promotional text (157/170)

```text
The whole family's health on your phone, records and photos encrypted: a file for each person, medicine reminders, children's vaccines and a backup you keep.
```

### Keywords (92/100 bytes)

```text
medical records,medicine reminder,pill,vaccine,pregnancy,baby,growth,doctor,insurance,arabic
```

### Description

Same text as the Play full description (English), `google-play.md`.

### What's New (109/4000)

```text
The first version of Usra: a health file for each person, medicine reminders, vaccines and encrypted backups.
```

## App Review notes (App Store Connect → App Review Information)

```text
Usra stores everything on the device: records in an encrypted database, photos encrypted in the app's private storage (excluded from iCloud backup). There is no account or sign-in, so no demo account is needed. Camera and photo access are asked only when the user photographs an insurance card, a report or a medicine box; text is read on the device with Google ML Kit. Notifications are medicine reminders the user sets. Usra does not use HealthKit and keeps no health data in iCloud (its database and photo folders are excluded from device backup): backups are an encrypted file the user shares to a place they choose, or that the app saves to a folder the user picks, opened with a recovery key only the user holds. Automatic backup refuses folders in iCloud Drive and is checked again before each backup. Usra does not diagnose, treat or calculate doses; follow-up suggestions are informational and cite their sources.
```

For a build with accounts and the paywall, use this instead:

```text
Usra stores all health data on the device: records in an encrypted database, photos encrypted in the app's private storage (excluded from iCloud backup). People can look around and read the guides with no account. Saving the first record, adding family, backing up or paying asks for Sign in with Apple or Google, and what was typed stays on the form. The account holds only what the login needs (name and email from the provider, language, device information) and carries the founding-member seat, pass and later paid features across phones; health records never go to it. A signed-in phone keeps working offline. The account can be deleted in More > Account. Demo account: [DEMO ACCOUNT: add before submission]. The first 5,000 signed-in users to save a record are founding members and get the app free for life, assigned by our server with no code typed by the user. After that, adding new records needs a 1-year pass or Lifetime, bought with in-app purchase after a 14-day free trial. When a trial or pass ends, people can still read, export, back up and delete their records and use the emergency card, and medicine reminders keep ringing. Camera and photo access are asked only when the user photographs an insurance card, a report or a medicine box; text is read on the device with Google ML Kit. Notifications are medicine reminders the user sets. Usra does not use HealthKit and keeps no health data in iCloud (its database and photo folders are excluded from device backup): backups are an encrypted file the user shares to a place they choose, or that the app saves to a folder the user picks, opened with a recovery key only the user holds. Automatic backup refuses folders in iCloud Drive and is checked again before each backup. Usra does not diagnose, treat or calculate doses; follow-up suggestions are informational and cite their sources.
```
