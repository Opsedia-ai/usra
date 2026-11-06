# App Store listing

Primary language: **Arabic**. Second localization: **English (U.S.)**.
Primary category: **Medical**. Secondary: **Health & Fitness**.
Seller: **Opsedia** (organisation account, see `docs/decisions.md`).
Price: **Free**. In-app purchases: **None** (v1).

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

### Promotional text (117/170)

```text
كل صحة العيلة على موبايلك، والسجلات متشفرة: ملف لكل فرد، تذكير بالأدوية، تطعيمات الأطفال، ونسخة احتياطية في إيدك إنت.
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

### Promotional text (146/170)

```text
The whole family's health on your phone, records encrypted: a file for each person, medicine reminders, children's vaccines and a backup you keep.
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
Usra stores everything on the device: records in an encrypted database, photos in the app's private storage (excluded from iCloud backup). There is no account or sign-in, so no demo account is needed. Camera and photo access are asked only when the user photographs an insurance card, a report or a medicine box; text is read on the device with Google ML Kit. Notifications are medicine reminders the user sets. Usra does not use HealthKit and keeps no health data in iCloud (its database and photo folders are excluded from device backup): backups are an encrypted file the user shares to a place they choose, opened with a recovery key only the user holds. Usra does not diagnose, treat or calculate doses; follow-up suggestions are informational and cite their sources.
```

For a build with accounts, use this instead:

```text
Usra stores all health data on the device: records in an encrypted database, photos in the app's private storage (excluded from iCloud backup). An account is optional and every feature works without one, so no demo account is needed. Sign in with Apple and Google are in More > Account, and the account can be deleted there. Camera and photo access are asked only when the user photographs an insurance card, a report or a medicine box; text is read on the device with Google ML Kit. Notifications are medicine reminders the user sets. Usra does not use HealthKit and keeps no health data in iCloud (its database and photo folders are excluded from device backup): backups are an encrypted file the user shares to a place they choose, opened with a recovery key only the user holds. Usra does not diagnose, treat or calculate doses; follow-up suggestions are informational and cite their sources.
```
