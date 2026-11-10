# Phone test checklist

For the first test build on real phones. Tick each line, and for anything wrong, note the phone, what you did and what happened, with a screenshot if you can.

## Before you start

- **Android:** install the APK from the "Test build" workflow (Actions tab). Allow installing from this source when asked. Each new test APK has a different signature, so installing the next one means uninstalling this one first, which deletes its data. Make a backup first if you want to keep it.
- **iPhone:** needs Xcode signing on your Mac or the Apple Developer account; see the PR that added this file.
- Use made-up family data, not real health records. Login is off in this build, so no account is needed.
- Note the phone model, Android or iOS version, and whether battery saver is on.

## 1. First run

- [ ] Welcome, language and country, About you (date of birth required), then Home
- [ ] Saudi Arabia and Jordan show "قريب" and can't be picked
- [ ] Home shows the optional cards
- [ ] Switching to English and back works, and Arabic numbers stay Arabic

## 2. Family

- [ ] Add 3 or more people, including a baby, a grandparent and yourself, with relationship and emergency number
- [ ] Home lays them out well, and with 5 or more they swipe
- [ ] Each person's page opens and shows the right things for their age

## 3. Medicines and reminders (the most important part)

- [ ] Add a medicine with 2 times a day, set the first a few minutes ahead
- [ ] The reminder rings on time with the screen locked
- [ ] Discreet mode on: the notification shows no name or medicine
- [ ] "اتاخد" from the notification marks the right dose
- [ ] Two people with doses at the same time: only Snooze shows, and the app lets you mark each one
- [ ] Reminders still ring after restarting the phone
- [ ] Android: reminders still ring with battery saver on (Xiaomi, Oppo, Samsung especially)
- [ ] A missed dose shows as missed after an hour
- [ ] Move a medicine to another person: reminders now name the new person

## 4. Photo reading

- [ ] Photograph a printed medicine box: name and strength come out, and nothing saves until you confirm
- [ ] Photograph a printed prescription with several medicines
- [ ] Photograph a child's vaccine card: each dose needs confirming, and unsure ones are marked
- [ ] Photos never appear in the phone's gallery

## 5. Records, vaccines, growth, pregnancy

- [ ] Add a visit, a lab result and a weight, then correct and delete one
- [ ] Vaccines: log an overdue dose from its card
- [ ] Growth shows "جوه المعدل المرجعي" with the source
- [ ] Pregnancy shows weeks in Arabic numbers, danger signs and the ambulance button

## 6. Emergency and sick day

- [ ] Emergency card opens from Home and shows the right person
- [ ] Calling the emergency number opens the dialer with the right number (don't place the call)
- [ ] Start a sick day and add readings

## 7. Backup and lock

- [ ] Make a backup, save the recovery key, then type the requested groups
- [ ] Turning on the PIN is refused before a backup, and works after
- [ ] Lock the app, then unlock with PIN and with fingerprint or face
- [ ] Uninstall, reinstall, and restore the backup with the recovery key: everything returns, including photos
- [ ] Automatic weekly backup to a chosen folder (and Google Drive on Android if possible)

## 8. Widget

- [ ] Add the home-screen widget: it shows times and counts, never names
- [ ] "اتاخد" on the widget marks the dose

## 9. Accessibility and text size

- [ ] Largest text size: nothing is cut off on Home, a person's page, Medicines and the Add sheet
- [ ] TalkBack or VoiceOver reads Home and the Add sheet in a sensible order
- [ ] Dark mode looks right

## 10. Simple Mode

- [ ] Turn it on for a grandparent: next dose, "اتاخد", call and ambulance buttons
- [ ] Leaving Simple Mode asks for the PIN when there is one

## After testing

Send the notes and screenshots back, and they'll go into fixes and `docs/risks.md`.
