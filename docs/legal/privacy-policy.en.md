# Usra Privacy Policy

> **DRAFT – needs legal review** before publishing: Egypt Personal Data Protection
> Law No. 151 of 2020 and its Executive Regulations; Saudi Personal Data Protection
> Law (SDAIA) and SFDA rules for health software; UAE Federal Decree-Law No. 45 of
> 2021 (PDPL) and Federal Law No. 2 of 2019 on ICT in health fields. Placeholders are
> in [square brackets].

Version: draft 0.1 · Last updated: [date of publication]

Usra (أسرة) is made by [Opsedia legal name], [registered address] ("Opsedia", "we").
This policy explains what happens to information in the Usra app. The short version:
**the family's health information stays on your phone: records in an encrypted
database, photos in the app's private storage. We do not receive it, we have no
account for you, and there are no ads or tracking.**

## 1. Information you put in Usra

You can record, for yourself and for family members you look after: names, dates of
birth, sex, blood type, allergies and conditions; visits, tests, scans, surgeries and
vaccines; medicines and their times; children's growth, milestones and baby log;
pregnancy details; doctors and their phone numbers; insurance cards; health spending;
and photos of cards, reports and medicine boxes.

This is health information, which the law treats as sensitive. **It is stored only on
your device.** Records are kept in a database encrypted with a key held in your
phone's secure storage (Android Keystore / iOS Keychain). Photos are kept as files in
the app's private storage, which other apps cannot open; they are never put in your
gallery or in iCloud or Android device backups. Photos are not yet encrypted
separately from the phone's own protection. Opsedia has no copy and cannot see any of it.

When you add information about another person (a child, a parent, your spouse), you
confirm you are their parent or guardian, or that they agreed to it.

## 2. What the app does with it, on your phone

- **Camera and photos.** Only when you choose to photograph or pick a picture of an
  insurance card, a report or a medicine box. Photos are saved inside the app's own
  storage, not in your gallery.
- **Reading text from photos.** Done on the phone with Google ML Kit. The photo and
  the text are not sent anywhere. A photo taken only to read a medicine's name is not
  kept; a photo you save with a medicine is kept with it.
- **Reminders.** Medicine reminders are local notifications scheduled on the phone.
  Their text, including the person's name as you entered it and the medicine name, can appear on
  your lock screen, and today's doses (first names and medicine names) can appear on
  the home-screen widget if you add it. You can change this in your phone's
  notification settings or remove the widget.
- **Suggestions.** Follow-up suggestions, growth charts and vaccine dates are worked
  out on the phone from what you recorded, using published guidelines named in the app.

## 3. Backups

Usra does not back your data up to our servers, to iCloud or to Android's automatic
backup: Usra's database and photos are excluded from iCloud and iTunes device
backups, and Android backup and device transfer are switched off for Usra. Instead, you can make a **backup file**,
encrypted on the phone, and save or send it where you choose (for example Google
Drive, Files or WhatsApp to yourself). That place is run by its own provider under
its own privacy policy.

You can also turn on **automatic backup**, which saves this same encrypted file in a
folder you choose when you open Usra and a backup is due, and keeps the last three. It
needs no account and sends nothing to us. If that folder belongs to another provider,
the file goes to that provider under its own privacy policy. If the folder is on your
phone, a lost phone means those backups are lost too. Usra won't use a folder in iCloud
Drive for automatic backup. If you save a backup yourself with the share sheet, the
phone may offer iCloud Drive among the places you can choose; that choice is yours and
that copy is then handled by Apple.

The backup can only be opened with your **recovery key**, which is shown to you and
kept on your phone. We never have it: if you lose the key and the phone, nobody,
including us, can open the backup.

## 4. Information that leaves your phone

- **Google ML Kit diagnostics.** The text-recognition library from Google may send
  Google technical information such as the device model, OS version, app version, a
  random installation identifier (not linked to your name or account) and performance
  figures, to measure and improve the library. It does not include your photos, the text read from them or your health
  records. See Google's ML Kit data disclosure: [link].
- **Things you choose to open or share.** Calling or messaging a doctor opens your
  phone or WhatsApp app; sharing an insurance card, a record or a backup file uses
  your phone's share sheet. What you send then goes to the app and person you chose.
- **App stores.** Google Play and the App Store handle downloads and updates and may
  give us anonymous, aggregated statistics (installs, crashes reported by the store).

We do not use analytics, advertising or tracking SDKs, we do not sell data, and we
never use health information for advertising.

## 5. Legal basis

Because the health records stay on your device under your control, Opsedia does not
collect or process them. Where the law treats us as handling personal data (for
example the diagnostics in section 4, or a message you send us), we rely on our
legitimate interest in keeping the app working and secure, or on your consent where
the law requires it. [Legal review: confirm the basis under each country's law and
whether registration or a licence is needed, e.g. Egypt PDPC.]

## 6. Keeping and deleting

Your records stay on the phone until you delete them in the app or uninstall Usra,
which deletes the database and the photos. **More › Delete all my data** erases
everything Usra keeps on the phone at once: records, photos, the keys that lock them
(the database key too, so nothing is left in the iPhone Keychain), the recovery key
saved on the phone, the app lock, reminders, the widget and settings, and signs you out
of your account if you have one. If you turn it on, the app lock can do the same after
10 wrong PINs in a row. On iPhone, the phone may keep the unused
database key in its Keychain after Usra is removed; it cannot open anything, because
the database it belonged to is gone. Backup files you made stay where
you saved them until you delete them there.

## 7. Your rights

Under the data-protection laws of Egypt, Saudi Arabia and the UAE you may have the
right to know, access, correct, delete or move personal data and to withdraw consent.
In Usra you can do all of this yourself: view, edit and delete any record, and export
everything as a backup file. For anything we hold (section 4), contact us below.

## 8. Children

Usra is meant for adults managing their family's health. It is not designed for
children to use on their own. Information about children is entered by their parent
or guardian.

## 9. Security

The database is encrypted with a random 256-bit key (SQLite3 Multiple Ciphers) kept
in the phone's secure storage. Photos are kept in the app's private storage, protected
by the phone's own storage encryption and app sandbox; encrypting them separately is
planned. Backup files, photos included, are encrypted with XChaCha20-Poly1305 using a
key derived from your recovery key (Argon2id). Neither key is ever sent to us. Protect
your phone with a screen lock: anyone who can unlock your phone can open Usra.
Usra checks, on the phone only, for signs that it is rooted or jailbroken and warns
you once if so; nothing about it is sent anywhere. A recovery key you copy is cleared
from the clipboard after a minute.

## 10. Later optional cloud features (not in the current version)

> This section describes features **planned** for a later version. They will be
> **optional and off by default**, and this policy will be updated, and your consent
> asked in the app, before any of them starts.

- **Account with Google or Apple**: you would sign in with your Google or Apple
  account. Google would send us your name, email address, profile photo link and an
  account ID. Apple would send us your email address (or a relay address, if you
  choose to hide yours) and an account ID. We would store these with your language and
  device information to run the account. We would not get your Google or Apple
  password. You would be able to delete the account from inside the app, which also
  ends the Sign in with Apple link; you can remove Usra from your Google account in
  your Google account settings. The account screen would say this before you sign in,
  with a link to this policy, and signing in would mean you agree to it.
- **Sync between family phones**, end-to-end encrypted: records would be encrypted on
  your phone before upload, so our servers store only data we cannot read. If you join
  a family, its owner would see your email address so they can check it's you.
- **AI Doctor**: if you choose to use it, a de-identified summary (no names, phone
  numbers, dates of birth, notes or photos), which you can preview first, would be
  sent to an AI service to produce informational findings. Credits may be bought in
  the app.
- **Cloud text reading**: if on-phone reading fails (for example Arabic or
  handwriting), you could choose to send one photo for reading in the cloud. It would
  be deleted after reading.
- **Purchases** of credits or a subscription through the app stores and a payment
  service provider.

Where these services run, which providers process the data, and any transfer outside
your country will be listed here before launch. [Legal review: cross-border transfer
rules, Egypt PDPL licence, KSA SFDA review for AI features.]

## 11. Changes

If we change this policy, we will update the date above and, for important changes,
tell you in the app before they apply.

## 12. Contact

[Opsedia legal name] · [address] · [privacy@ e-mail] · [data protection officer, if required]
