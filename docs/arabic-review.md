# Arabic wording to review

Every Arabic string added or changed in the app since the accepted design started being built on 7 November 2026: 305 new and 70 changed. The English column shows what each one should mean.

## What to look for

1. Natural Egyptian colloquial, as a parent would say it.
2. New text is neutral, because the app can't yet address the user by their sex. Mark strings that read awkwardly because of this.
3. Words that could mislead, such as "مقفول" for a setting that's off.
4. "ل" joined to names that start with "ال".
5. Mixed or wrong digits.

Medical strings in this list also go to the doctor, through `docs/medical-review-changes.md`.

## Questions from the build

- Are "مش شغّال / مش شغّالة" natural for a setting that's off? In `rootWarningTitle` it could read as broken.
- Is "قفل التطبيق اتلغى" right for `lockOffDone`?
- `reminderOffTitle` (التنبيهات مقفولة) and `aboutPrivacyReminders` (اتقفلت) are unchanged. Are they fine?

## Strings

| Key | | Arabic | English |
|---|---|---|---|
| `aboutTitle` | Changed | الخصوصية والشروط | Privacy and terms |
| `aboutHint` | Changed | البيانات بتتحفظ إزاي، ونسخة التطبيق | How your data is kept, and the app version |
| `aboutPrivacyOptionalAccount` | Changed | حفظ السجلات محتاج تسجيل دخول، ومفيش إعلانات ولا تتبع. بنحتفظ بإيميلك ورقم تعريف للحساب ومعاهم اللغة ومعلومات الجهاز علشان الحساب يشتغل، وكمان اسمك ولينك صورة حسابك لو الدخول بـ Google. ومش بنستلم سجلاتك الصحية. وعمرنا ما بنبيع ولا بنشارك بيانات حد. | Saving records needs a sign-in, and there are no ads and no tracking. We keep your email, account ID, language and device information to run the account, plus your name and profile photo link if you use Google. We never receive your health records. We never sell or share anyone's data. |
| `aboutPrivacyReminders` | Changed | التذكير بيتظبط على الموبايل ده. من الأول بيظهر فيه كلام عام من غير أسامي. ولو "تنبيهات من غير أسامي" اتقفلت، أسامي الأشخاص وأسامي الأدوية ممكن تظهر على شاشة القفل. الويدجت مفيهوش أسامي، مواعيد وعدد جرعات بس. | Reminders are set on this phone. From the start they show general text with no names. If "Discreet notifications" is turned off, people's names and medicine names can show on the lock screen. The home-screen widget has no names, only times and how many doses. |
| `familyNew` | Changed | فرد جديد | New person |
| `profileRelationship` | New | صلة القرابة | Relationship |
| `relationshipMine` | New | {relationship, select, son{ابني} daughter{بنتي} husband{جوزي} wife{مراتي} father{بابا} mother{ماما} brother{أخويا} sister{أختي} grandfather{جدو} grandmother{تيتة} other{حد تاني}} | {relationship, select, son{My son} daughter{My daughter} husband{My husband} wife{My wife} father{My father} mother{My mother} brother{My brother} sister{My sister} grandfather{My grandfather} grandmother{My grandmother} other{Someone else}} |
| `relationshipYours` | New | {relationship, select, son{ابنك} daughter{بنتك} husband{جوزك} wife{مراتك} father{باباك} mother{مامتك} brother{أخوك} sister{أختك} grandfather{جدك} grandmother{تيتتك} other{}} | {relationship, select, son{Your son} daughter{Your daughter} husband{Your husband} wife{Your wife} father{Your father} mother{Your mother} brother{Your brother} sister{Your sister} grandfather{Your grandfather} grandmother{Your grandmother} other{}} |
| `profileEmergencyPhone` | New | رقم للطوارئ | Emergency number |
| `profileEmergencyPhoneHint` | New | اختياري. بيظهر في كارت الطوارئ، وعلى قفل أسرة لو الكارت متاح هناك. | Optional. Shown on the emergency card, and on Usra's lock screen if the card is available there. |
| `profileEmergencyInvalid` | New | ده مش رقم تليفون. | That isn't a phone number. |
| `profileEmergencyName` | New | صاحب الرقم | Whose number |
| `profileEmergencyNameHint` | New | اختياري. مثلًا: آية، مامته. | Optional. For example: Aya, his mother. |
| `emergencyContactNoName` | New | رقم للطوارئ | Emergency number |
| `emergencyCallNumber` | New | اتصل برقم الطوارئ: {phone} | Call the emergency number: {phone} |
| `emergencyCallContact` | New | اتصل بـ {name}: {phone} | Call {name}: {phone} |
| `emergencyTitle` | Changed | كارت الطوارئ | Emergency card |
| `growthWithinRange` | Changed | جوه المعدل المرجعي للسن ده (المئين {percentile}). | Within the reference range for this age (percentile {percentile}). |
| `recordDelete` | Changed | مسح | Delete |
| `recordClearDate` | New | شيل التاريخ | Remove the date |
| `drUsraWelcome` | New | دكتور أسرة بيسلّم عليك | Dr. Usra waving |
| `drUsraExplaining` | New | دكتور أسرة بيشرح | Dr. Usra explaining |
| `drUsraEmptyState` | New | دكتور أسرة ماسك علامة زائد | Dr. Usra holding a plus |
| `drUsraCelebrating` | New | دكتور أسرة فرحان | Dr. Usra celebrating |
| `drUsraResting` | New | دكتور أسرة بيرتاح | Dr. Usra resting |
| `settingsTheme` | New | شكل التطبيق | Appearance |
| `settingsThemeSystem` | New | زي الموبايل | Same as phone |
| `settingsThemeLight` | New | فاتح | Light |
| `settingsThemeDark` | New | غامق | Dark |
| `tutorialPrivacyBody` | Changed | كل حاجة متسجّلة على الموبايل ده ومتشفّرة، من غير حساب. | Everything is saved on this phone, encrypted. No account needed. |
| `tutorialPrivacyBodyAccount` | New | السجلات متسجّلة على الموبايل ده ومتشفّرة، والحساب مش بيشيلها. | Records are saved on this phone, encrypted. The account doesn't hold them. |
| `scanMedicineStrength` | Changed | التركيز (اختياري) | Strength (optional) |
| `doseSkip` | Changed | ماتاخدش | Not taken |
| `doseSkipped` | Changed | ماتاخدش | Not taken |
| `doseSnooze` | Changed | أجّل ١٠ دقايق | Snooze 10 min |
| `doseUndo` | Changed | تراجع | Undo |
| `doseReminderBody` | Changed | {sex, select, female{دوس اتاخد بعد ما تاخده} other{دوس اتاخد بعد ما ياخده}} | {sex, select, other{Tap Taken once it's done}} |
| `medicineMoveAction` | New | نقل لشخص تاني | Move to another person |
| `medicineMoveTitle` | New | نقل الدوا | Move medicine |
| `medicineMoveNow` | New | دلوقتي عند {name} | Now with {name} |
| `medicineMoveTo` | New | ينتقل لمين؟ | Move it to who? |
| `medicineMoveWhatTitle` | New | هينقل مع الدوا | Moves with the medicine |
| `medicineMoveWhat` | New | المواعيد والتذكير والجرعات المسجلة والصور. | Times, reminders, recorded doses and photos. |
| `medicineMoveStaysTitle` | New | هيفضل عند {name} | Stays with {name} |
| `medicineMoveStaysPrescription` | New | الروشتة، بتاريخها وصورها. الدوا هيتشال من قايمتها. | The prescription, with its date and photos. The medicine comes off its list. |
| `medicineMoveStaysSickDays` | New | الجرعات المتسجلة في أيام التعب، باسم الدوا. | Doses recorded in sick days, by the medicine's name. |
| `medicineMoveStopsNextDose` | New | تذكير الجرعة الجاية في يوم التعب هيتوقف. | The next-dose reminder in the sick day stops. |
| `medicineMoveReminder` | New | بعد النقل التذكير هيبقى ل{to}، مش ل{from}. | After the move, reminders are for {to}, not {from}. |
| `medicineMoveChoose` | New | اختار الشخص الأول | Choose a person first |
| `medicineMoveConfirm` | New | نقل ل{name} | Move to {name} |
| `medicineMoveKeep` | New | يفضل عند {name} | Keep with {name} |
| `medicineMoveDone` | New | الدوا اتنقل ل{name}. | Medicine moved to {name}. |
| `medicineAmountHint` | Changed | زي ما الدكتور كتب | As the doctor wrote it |
| `medicineEveryNInvalid` | Changed | اكتب رقم من ٢ لـ ٦٠ | Enter a number from 2 to 60 |
| `backupIntro` | Changed | النسخة الاحتياطية ملف واحد متشفّر فيه كل سجلات العيلة وصورها، وبيتحفظ على Google Drive أو في الملفات أو على واتساب. فتحه على موبايل جديد محتاج مفتاح الاسترجاع. | A backup is one encrypted file with all the family's records and photos. Save it to Google Drive or Files, or send it to yourself on WhatsApp. To open it on a new phone you'll need your recovery key. |
| `backupNever` | Changed | لسه مفيش نسخة احتياطية | No backup yet |
| `backupNow` | Changed | نسخة احتياطية دلوقتي | Back up now |
| `recoveryKeyIntro` | Changed | ده مفتاح الاسترجاع. مكانه ورقة في مكان أمين بعيد عن الموبايل. فتح النسخ الاحتياطية على موبايل جديد محتاجه. | This is your recovery key. Write it on paper and keep it somewhere safe, away from this phone. You'll need it to open your backups on a new phone. |
| `recoveryKeyShowIntro` | Changed | ده المفتاح اللي بيفتح النسخ الاحتياطية. لازم يكون زي اللي مكتوب على الورقة. | This is the key that opens your backups. Check it matches the one you wrote down. |
| `recoveryKeyWrittenDown` | Changed (13 Nov: read as an instruction, not a next step) | كتبته، كمّل | I wrote it down, continue |
| `recoveryKeyConfirmIntro` | Changed | علشان نتأكد إنه مكتوب صح: المجموعتين دول من الورقة. | To be sure it's written correctly, type these two groups from your paper. |
| `recoveryKeyShowAgain` | Changed | عرض المفتاح تاني | Show the key again |
| `recoveryKeyCopy` | Changed | نسخ المفتاح | Copy the key |
| `rootWarningTitle` | Changed | حماية الموبايل ده مش شغّالة | This phone's protections are switched off |
| `databaseOpenFailed` | New | أسرة مقدرتش تفتح سجلاتك دلوقتي. سجلاتك لسه موجودة ومتمسحتش. اتأكد إن الموبايل فيه مساحة فاضية، وبعدين جرّب تاني أو اقفل الموبايل وافتحه. لو المشكلة فضلت، كلمنا قبل ما تمسح التطبيق. | Usra can't open your records right now. Your records are still here and nothing was deleted. Check that your phone has free storage, then try again or restart your phone. If this keeps happening, contact us before deleting the app. |
| `databaseSupportLabel` | New | للمساعدة والدعم: | Help and support: |
| `databaseSupportAddress` | New | aya@opsedia.ai | aya@opsedia.ai |
| `databaseStartFresh` | New | ابدأ من جديد | Start fresh |
| `databaseStartFreshHint` | New | آخر حل، لو مفيش نسخة احتياطية والمشكلة مش بتروح. ده بيمسح كل حاجة أسرة شايلاها على الموبايل ده. | A last resort, if there's no backup and this won't go away. It deletes everything Usra keeps on this phone. |
| `databaseStartFreshIntro` | New | سجلاتك مش بتتفتح، وممكن تكون لسه موجودة على الموبايل. لو عندك نسخة احتياطية، ارجع وجرّب استرجاعها الأول. لو كلّمتنا الأول ممكن نساعد. | Your records won't open, but they may still be on this phone. If you have a backup, go back and try restoring it first. Writing to us first may help too. |
| `restoreTitle` | Changed | استرجاع من نسخة احتياطية | Restore from a backup |
| `restoreHint` | Changed | كل اللي على الموبايل ده هيتبدل | Replaces everything on this phone |
| `recoveryKeyRowHint` | New | مكتوب على الورقة | Written on your paper |
| `restoreKeyHelp` | New | ٦ مجموعات، كل مجموعة ٦ أرقام. | 6 groups of 6 digits. |
| `restoreCancel` | New | رجوع من غير تغيير | Go back with no changes |
| `restoreIntro` | Changed | ملف النسخة الاحتياطية بينتهي بـ ‎.usra‎ وبيبقى على Drive أو في الملفات أو واتساب. بعد الملف، مفتاح الاسترجاع. | Choose your backup file (it ends in .usra) from Drive, Files or WhatsApp, then type your recovery key. |
| `restorePick` | Changed | اختيار ملف النسخة | Choose the backup file |
| `restoreOpen` | Changed | فتح النسخة | Open the backup |
| `restoreReplace` | Changed | استرجاع واستبدال | Restore and replace |
| `pregnancyWeek` | Changed | {weeks, plural, =0{أقل من أسبوع} =1{أسبوع} =2{أسبوعين} few{{weeks} أسابيع} other{{weeks} أسبوع}} و{days, plural, =0{٠ يوم} =1{يوم} =2{يومين} few{{days} أيام} other{{days} يوم}} | {weeks, plural, =0{Less than a week} =1{1 week} other{{weeks} weeks}}, {days, plural, =0{0 days} =1{1 day} other{{days} days}} |
| `pregDangerSign` | Changed | {sign, select, bleeding{نزيف من المهبل} headache{صداع جامد} vision{زغللة في النظر} fits{تشنجات أو إغماء} pain{وجع جامد في البطن} fever{سخونية} water{نزول مية من المهبل} movement{حركة البيبي قلّت عن العادي أو وقفت} swelling{تورّم في الوش أو الإيدين} breathing{صعوبة في التنفس} other{}} | {sign, select, bleeding{Bleeding from the vagina} headache{Severe headache} vision{Blurred vision} fits{Fits or fainting} pain{Severe pain in the belly} fever{Fever} water{Water leaking from the vagina} movement{The baby moving less than usual, or not at all} swelling{Swelling of the face or hands} breathing{Difficulty breathing} other{}} |
| `accountSettingsHint` | Changed | سجلاتك فاضلة على الموبايل ده | Your records stay on this phone |
| `accountPrivacy` | Changed | سجلات العيلة الصحية فاضلة على الموبايل ده. الحساب مش بيرفعها. | Your family's health records stay on this phone. An account doesn't upload them. |
| `accountSignInIntro` | Changed | تقدر تتفرج وتقرا الأدلة من غير حساب. حفظ السجلات وإضافة العيلة والنسخ الاحتياطي محتاجين تسجيل دخول. | You can look around and read the guides with no account. Saving records, adding family and backing up need a sign-in. |
| `accountSignInConsent` | Changed | تسجيل الدخول معناه موافقة إننا نحتفظ بالبيانات دي علشان الحساب يشتغل، زي ما سياسة الخصوصية بتقول. | By signing in, you agree that we keep this to run your account, as the privacy policy says. |
| `accountSignInData` | New | Google بيبعتلنا اسمك وإيميلك ولينك صورة حسابك ورقم تعريف للحساب، وApple بتبعتلنا إيميلك (أو عنوان بديل لو الإيميل متخبي) ورقم تعريف للحساب. بنخزن ده مع اللغة ومعلومات الجهاز علشان الحساب يشتغل. | Google shares your name, email, profile photo link and an account ID with us; Apple shares your email (or a replacement address if you hide yours) and an account ID. We store these with your language and device information to run the account. |
| `accountGateTitle` | New | حفظ سجلاتك | Save your records |
| `accountGateBody` | New | حفظ السجلات محتاج تسجيل دخول. اللي اتكتب بيفضل في الصفحة. | Saving records needs a sign-in. What was typed stays on the page. |
| `accountGateBackupBody` | New | النسخة الاحتياطية محتاجة تسجيل دخول. | Backing up needs a sign-in. |
| `accountGateKeepsTitle` | New | الحساب بيحتفظ بـ | The account keeps |
| `accountGateRecordsStay` | New | السجلات والصور بتفضل على موبايلك ومتشفرة. | Records and photos stay on your phone, encrypted. |
| `accountReadPrivacy` | Changed | عن الخصوصية | Read about privacy |
| `accountSignedIn` | Changed | الدخول على الحساب شغّال | Signed in |
| `accountSignOut` | Changed | خروج من الحساب | Sign out |
| `accountSignOutConfirm` | Changed | خروج من الحساب؟ السجلات فاضلة على الموبايل. | Sign out? Your records stay on this phone. |
| `accountDelete` | Changed | مسح الحساب | Delete account |
| `accountDeleteConfirm` | Changed | مسح الحساب؟ الحساب والأجهزة والرصيد هيتمسحوا من السيرفرات بتاعتنا. السجلات اللي على الموبايل ده هتفضل زي ما هي. | Delete your account? Your account, devices and credits are erased from our servers. The records on this phone stay here. |
| `lockForgotBody` | Changed | عشان سجلات عيلتك تفضل سر، مفيش حاجة تعدّي الرقم السري، ولا حتى إحنا.  عشان تبدأ من جديد: ١. امسح بيانات أسرة. على أندرويد: إعدادات الموبايل › التطبيقات › أسرة › التخزين › مسح البيانات. على الآيفون: امسح أسرة ونزّلها تاني. ده بيمسح كل حاجة أسرة شايلاها على الموبايل ده. ٢. افتح أسرة ورجّع آخر نسخة احتياطية بمفتاح الاسترجاع («عندي نسخة احتياطية» في أول شاشة).  من غير نسخة احتياطية ومفتاحها، السجلات مش هترجع. | To keep your family's records private, nothing can skip the PIN, not even us.  To start again: 1. Remove Usra's data. On Android: phone Settings › Apps › Usra › Storage › Clear data. On iPhone: delete Usra and install it again. This deletes everything Usra keeps on this phone. 2. Open Usra and restore your latest backup with your recovery key ("I have a backup" on the first screen).  Without a backup and its recovery key, the records can't be brought back. |
| `pinLengthHint` | Changed | ٦ أرقام | 6 numbers |
| `pinEntered` | Changed | اتكتب {count} من ٦ أرقام | {count} of 6 numbers typed |
| `lockSetupNewPin` | Changed | اختار رقم سري من ٦ أرقام | Choose a 6-number PIN |
| `settingsAppLockOff` | Changed | مش شغّال: أي حد معاه الموبايل يقدر يفتح أسرة | Off: anyone with the phone can open Usra |
| `lockSettingsBiometricsHint` | Changed | أي حد بصمته أو وشه متسجلين على الموبايل ده يقدر يفتح أسرة، حتى لو من العيلة. لو في حد تاني بيستخدم الموبايل، سيبها مش شغّالة واستخدم الرقم السري بس. | Anyone whose fingerprint or face is set up on this phone can open Usra, family members too. If others use this phone, keep this off and use the PIN only. |
| `lockTimeoutFiveMinutes` | Changed | ٥ دقايق | 5 minutes |
| `lockSettingsEmergency` | Changed | كارت الطوارئ على قفل أسرة | Emergency card on Usra's lock screen |
| `lockSettingsEmergencyHint` | Changed | فصيلة الدم والحساسية والأمراض والعمليات والأدوية الحالية ورقم الطوارئ وصاحبه للناس اللي هتختارهم هنا، أي حد ماسك الموبايل وأسرة مفتوحة يقدر يشوفها من غير الرقم السري. ده قفل أسرة، مش قفل الموبايل: للموبايل المقفول استخدم Medical ID بتاع الموبايل نفسه. | The blood type, allergies, conditions, surgeries, current medicines and emergency number and whose it is of the people you choose here can be seen without the PIN by anyone holding the phone with Usra open. This is Usra's lock screen, not the phone's: for a locked phone, use the phone's own Medical ID. |
| `lockOffDone` | Changed | قفل التطبيق اتلغى | App lock is off |
| `lockEmergencyFor` | Changed | يظهر على قفل أسرة | Show on Usra's lock screen |
| `lockBackupFirstTitle` | Changed | لازم نسخة احتياطية الأول | A backup comes first |
| `lockBackupFirstBody` | Changed | لو الرقم السري اتنسى، الطريقة الوحيدة هي مسح بيانات أسرة واسترجاع نسخة احتياطية بمفتاح الاسترجاع بتاعها. ولسه مفيش نسخة احتياطية، ومن غيرها السجلات بتضيع.  أول ما النسخة الاحتياطية تتعمل، القفل يقدر يشتغل. | If the PIN is forgotten, the only way back in is to remove Usra's data and restore a backup with its recovery key. There's no backup yet, and without one the records are lost.  Once a backup is made, the lock can go on. |
| `lockNothingYetTitle` | New | العيلة الأول | Family first |
| `lockNothingYetBody` | New | القفل محتاج نسخة احتياطية، ولسه مفيش حاجة تتحفظ. لما حد من العيلة يتضاف وتتعمل نسخة احتياطية، القفل يقدر يشتغل. | The lock needs a backup, and there's nothing to back up yet. Once someone is added to the family and a backup is made, the lock can go on. |
| `lockOnNoBackupBody` | New | القفل شغال بس لسه مفيش نسخة احتياطية. لو الرقم السري اتنسى، السجلات هتضيع. | The lock is on, but there's no backup yet. If the PIN is forgotten, the records are lost. |
| `doseReminderDiscreetTitle` | Changed | ميعاد الدوا | Your medicine time |
| `widgetDoseDue` | New | ميعاد جرعة | Dose due |
| `widgetDoseCount` | New | {count, plural, =2{جرعتين} few{{digits} جرعات} other{{digits} جرعة}} | {count, plural, other{{digits} doses due}} |
| `settingsDiscreetHint` | Changed | التنبيهات بتقول "ميعاد الدوا" بس، من غير اسم الشخص ولا اسم الدوا. لو كذا جرعة قريبين من بعض، افتح أسرة عشان تعلّم عليهم. | Reminders say "Your medicine time", without the person's or the medicine's name. When several doses are close together, open Usra to mark them. |
| `settingsBlockScreenshotsHint` | Changed | مفيش سكرين شوت ولا تسجيل للشاشة في التطبيق كله. مفتاح الاسترجاع محمي على طول. سيبها مش شغّالة لو عايز تصوّر كارت الطوارئ. | No screenshots or screen recording anywhere in the app. The recovery key is always protected. Leave off to screenshot the emergency card. |
| `doseReminderDiscreetTimeBody` | New | جرعة {time} | The {time} dose |
| `doseReminderDiscreetSeveralBody` | New | فيه أكتر من جرعة ميعادها دلوقتي. افتح أسرة عشان تشوف أنهي دوا | More than one dose is due around now. Open Usra to see which |
| `vaccineRouteHexavalentHint` | Changed | حقنة سداسي واحدة بدل الخماسي وسولك عند شهرين و٤ و٦ شهور، وجرعة منشطة سداسي عند سنة ونص. نقط شلل الأطفال والدرن والكبدي ب عند الولادة والثلاثي الفيروسي زي ما هما. | One hexavalent shot instead of pentavalent + IPV at 2, 4 and 6 months, and a hexavalent booster at 18 months. Oral polio drops, BCG, hepatitis B at birth and MMR stay the same. |
| `prescriptionDoseHint` | Changed | زي ما مكتوبة في الروشتة بالظبط | Exactly as written on the prescription |
| `prescriptionTimesHint` | Changed | اتأكد إن المواعيد زي ما الدكتور كتب. | Check the times match what the doctor wrote. |
| `reportSummaryDisclaimer` | Changed | ده ملخص من اللي العيلة سجلته بتطبيق أسرة، مش رأي طبي. راجعوه على الروشتات والتقارير الأصلية. | This summary is what the family recorded with the Usra app, not a medical opinion. Check it against the original prescriptions and reports. |
| `sickDayPersonUnwell` | New | {sex, select, male{{name} تعبان} female{{name} تعبانة} other{{name}: يوم تعب}} | {sex, select, male{{name} is unwell} female{{name} is unwell} other{{name} is unwell}} |
| `sickDayPersonWasUnwell` | New | {sex, select, male{{name} كان تعبان} female{{name} كانت تعبانة} other{{name}: يوم تعب}} | {sex, select, male{{name} was unwell} female{{name} was unwell} other{{name} was unwell}} |
| `sickDaySinceToday` | New | من النهارده {time} | Since today {time} |
| `sickDaySinceYesterday` | New | من امبارح {time} | Since yesterday {time} |
| `sickDayLatestReading` | New | آخر قراءة | Latest reading |
| `sickDayFeverLogged` | New | سخونية متسجلة: {duration} | Fever logged: {duration} |
| `sickDayFeverUnderHour` | New | أقل من ساعة | under an hour |
| `sickDayFeverHours` | New | {count, plural, =1{ساعة} =2{ساعتين} few{{shown} ساعات} other{{shown} ساعة}} | {count, plural, =1{1 hour} other{{shown} hours}} |
| `sickDayFeverDays` | New | {count, plural, =1{يوم} =2{يومين} few{{shown} أيام} other{{shown} يوم}} | {count, plural, =1{1 day} other{{shown} days}} |
| `sickDayRecordedGiven` | New | مسجل: {what} – {time} | Recorded: {what} – {time} |
| `sickDayChartSemantics` | New | القراءات من {start} لحد {end}: {values}. الخط المتقطع عند {fever}، من عندها تبقى سخونية. | Readings from {start} to {end}: {values}. The dashed line is at {fever}, where a fever starts. |
| `sickDayChartThen` | New |  ثم  | , then  |
| `sickDayAddReadingShort` | New | قراءة حرارة | Add reading |
| `sickDayGivenShort` | New | دوا اتاخد | Medicine given |
| `sickDayAllReadings` | New | كل القراءات | All readings |
| `sickDayNoSymptoms` | New | لسه مفيش أعراض متسجلة. | No symptoms logged yet. |
| `sickDayCallDoctorNamed` | New | كلّم {name} | Call {name} |
| `sickDayBack` | New | رجوع | Back |
| `backupAutoHint` | Changed | لما أسرة تتفتح ويكون ميعاد النسخة جه، بتتحفظ نسخة متشفرة في فولدر من اختيارك، مش iCloud. | When you open Usra and a backup is due, it saves an encrypted copy in a folder you choose, never iCloud. |
| `backupAutoChooseFolder` | Changed | اختيار فولدر | Choose a folder |
| `backupSendCopy` | Changed | نسخة لمكان تاني | Send a copy somewhere else |
| `backupAutoDriveHint` | Changed | ممكن Google Drive ميظهرش وإنت بتختار الفولدر، وأسرة مش بتطلب إذن تدخل على الدرايف بتاعك. علشان تحتفظ بنسخة على الدرايف، دوس "نسخة لمكان تاني" واختار Drive. | Google Drive may not appear when you choose a folder, and Usra doesn't ask for access to your Drive. To keep a copy in Drive, tap "Send a copy somewhere else" and choose Drive. |
| `backupAutoUnreadableTitle` | Changed | النسخ التلقائي مش شغّال | Automatic backup is off |
| `navRecords` | New | السجلات | Records |
| `navAdd` | New | إضافة | Add |
| `homeMorning` | New | صباح الخير | Good morning |
| `homeEvening` | New | مساء الخير | Good evening |
| `homeNothingNeeded` | New | مفيش حاجة مطلوبة | Nothing needed |
| `homeNeedsAttentionOne` | New | محتاج انتباهك | needs your attention |
| `homeNeedsAttentionMany` | New | محتاجين انتباهك | need your attention |
| `homeNamesJoin` | New | و | and |
| `homeFamily` | New | العيلة | Family |
| `homeAllFamily` | New | كل العيلة ({count}) | All family ({count}) |
| `homeUpcoming` | New | الجاي النهارده | Next today |
| `homeNewPerson` | New | فرد جديد | New person |
| `homeEmergency` | New | طوارئ | Emergency |
| `homeBackupAgoDays` | New | {days, plural, =0{آخر نسخة احتياطية النهارده} =1{آخر نسخة احتياطية من يوم} =2{آخر نسخة احتياطية من يومين} few{آخر نسخة احتياطية من {shown} أيام} many{آخر نسخة احتياطية من {shown} يوم} other{آخر نسخة احتياطية من {shown} يوم}} | {days, plural, =0{Last backup today} =1{Last backup 1 day ago} other{Last backup {shown} days ago}} |
| `homeDoseLogged` | New | اتسجل: {medicine} لـ{person} | Logged: {medicine} for {person} |
| `statusSick` | New | تعبان | Unwell |
| `statusVaccineOverdue` | New | تطعيم متأخر | Vaccine overdue |
| `statusDoseMissed` | New | دوا فات | Dose missed |
| `statusDoseNext` | New | دوا {time} | Dose {time} |
| `familyAllTitle` | New | كل العيلة | All family |
| `familyCount` | New | {count, plural, =1{فرد واحد} =2{فردين} few{{shown} أفراد} other{{shown} فرد}} | {count, plural, =1{1 person} other{{shown} people}} |
| `addSheetTitle` | New | هنضيف إيه؟ | What would you like to add? |
| `addSheetFor` | New | لمين؟ | For |
| `addSheetPickPerson` | New | اختيار الشخص الأول | Choose a person first |
| `addSheetNoPeople` | New | أول حاجة: فرد من العيلة | Add a family member first |
| `addMedicine` | New | دوا | Medicine |
| `addVaccine` | New | تطعيم | Vaccine |
| `addVisit` | New | زيارة | Visit |
| `addLab` | New | تحليل | Lab test |
| `addScan` | New | أشعة | Scan |
| `addFever` | New | سخونية | Fever |
| `addGrowth` | New | وزن وطول | Weight and height |
| `addInsurance` | New | كارت تأمين | Insurance card |
| `addSurgery` | New | عملية | Surgery |
| `addPhotoTitle` | New | صورة علبة دوا | Photo of a medicine box |
| `addPhotoHint` | New | بنقرا على الموبايل الكلام المطبوع بالإنجليزي بس، والاسم والتركيز لازم يتأكدوا. | Read on the phone: printed English only, and the name and strength still need checking. |
| `profileMoreDetails` | New | تفاصيل أكتر | More details |
| `profileSaveNamed` | New | حفظ {name} | Save {name} |
| `recordsTitle` | New | السجلات | Records |
| `recordsAll` | New | الكل | All |
| `recordsEmpty` | New | لسه مفيش سجلات. دوس إضافة وسجّل أول زيارة أو تحليل. | No records yet. Tap Add to log a first visit or test. |
| `recordsAdd` | New | سجل جديد | New record |
| `moreFamily` | New | كل العيلة | All family |
| `moreGroupFamily` | New | العيلة | Family |
| `moreGroupSafety` | New | الأمان | Safety |
| `moreGroupApp` | New | التطبيق | App |
| `accountKeepsQuestion` | New | الحساب بيحتفظ بإيه؟ | What does the account keep? |
| `accountKeeps` | New | الإيميل ورقم تعريف للحساب واللغة ومعلومات الجهاز، وكمان الاسم ولينك صورة الحساب لو الدخول بـ Google. السجلات والصور مش عليه. | Your email, an account ID, language and device information, plus your name and profile photo link if you use Google. Records and photos are not on it. |
| `accountDeleteNote` | New | مسح الحساب مش بيمسح السجلات اللي على الموبايل. مسحها من الخصوصية. | Deleting the account doesn't delete the records on this phone. You can delete those from Privacy. |
| `privacyEncryptedQ` | New | إيه اللي متشفر؟ | What's encrypted? |
| `privacyEncryptedA` | New | قاعدة البيانات والصور والنسخ الاحتياطية. | The database, the photos and the backups. |
| `privacyCanSeeQ` | New | نقدر نشوف سجلاتك؟ | Can we see your records? |
| `privacyCanSeeA` | New | لأ. السجلات والصور بتفضل على موبايلك. | No. Records and photos stay on your phone. |
| `privacyBackupQ` | New | النسخة الاحتياطية فيها إيه؟ | What's in a backup? |
| `privacyBackupA` | New | السجلات والصور، متشفرة بمفتاح الاسترجاع. | Your records and photos, encrypted with your recovery key. |
| `privacyPinQ` | New | لو الرقم السري اتنسي؟ | What if the PIN is forgotten? |
| `privacyPinA` | New | مفيش حاجة تعدّيه، ولا حتى إحنا. بيانات أسرة على الموبايل بتتمسح، وبترجع من النسخة الاحتياطية بمفتاح الاسترجاع. من غير نسخة، السجلات بتضيع. | Nothing gets past it, not even us. Usra's data on the phone is erased, then restored from a backup with the recovery key. With no backup, the records are lost. |
| `privacyDeleteQ` | New | لو البيانات اتمسحت؟ | What if the data is deleted? |
| `privacyDeleteA` | New | بتتمسح من الموبايل. النسخ اللي اتحفظت في فولدر أو على واتساب بتفضل لحد ما تتمسح من هناك. | It's erased from the phone. Backups saved in a folder or on WhatsApp stay until they're deleted there. |
| `lockSetupBackupReady` | New | الرقم السري محتاج نسخة احتياطية الأول، وفيه نسخة، فجاهز. | A PIN needs a backup first. There is one, so you can go ahead. |
| `statusSickFemale` | New | تعبانة | Unwell |
| `emergencyPickPerson` | New | كارت مين؟ | Whose card? |
| `homeLoadError` | New | مش قادرين نقرا البيانات دلوقتي. اقفل التطبيق وافتحه تاني. | Can't read your data right now. Close the app and open it again. |
| `homeGreetingNamed` | New | {greeting} يا {name} | {greeting}, {name} |
| `welcomeHeadline` | New | صحة العيلة كلها في مكان واحد | The whole family's health in one place |
| `welcomePrivacyLine` | New | ملف لكل فرد وتذكير بالدوا. بياناتك على موبايلك ومتشفرة، وإحنا مش بنشوفها. | A file for each person and medicine reminders. Your data stays on your phone, encrypted, and we can't see it. |
| `welcomeStart` | New | يلا نبدأ | Let's start |
| `welcomeHaveBackup` | New | عندي نسخة احتياطية | I have a backup |
| `welcomeDisclaimer` | New | أسرة مش جهاز طبي ومش بديل عن الدكتور. | Usra is not a medical device and doesn't replace a doctor. |
| `welcomePrivacy` | New | الخصوصية | Privacy |
| `welcomeTerms` | New | الشروط | Terms |
| `welcomeLanguageOther` | New | English | العربية |
| `onboardingStep` | New | خطوة {current} من {total} | Step {current} of {total} |
| `onboardingBack` | New | رجوع | Back |
| `countryTitle` | New | البلد | Country |
| `countryHint` | New | علشان جدول التطعيمات ورقم الإسعاف يبقوا صح. | So the vaccine schedule and the ambulance number are right. |
| `countryEgypt` | New | مصر | Egypt |
| `countryEgyptDetail` | New | وزارة الصحة والسكان – الإسعاف ١٢٣ | Ministry of Health and Population – Ambulance 123 |
| `countrySaudi` | New | السعودية | Saudi Arabia |
| `countryJordan` | New | الأردن | Jordan |
| `countrySoon` | New | قريب | Coming soon |
| `aboutYouTitle` | New | أول ملف في عيلتك | The first file in your family |
| `aboutYouHint` | New | ده ملفك، وممكن يتعدّل بعدين. | This one is yours, and it can be changed later. |
| `aboutYouSex` | New | النوع | Sex |
| `aboutYouSexHint` | New | علشان منحنيات النمو والحمل. | For growth charts and pregnancy. |
| `aboutYouBirthDateHint` | New | علشان الاقتراحات اللي بتعتمد على السن. | For suggestions that depend on age. |
| `aboutYouBirthDateFuture` | New | تاريخ الميلاد مينفعش يكون في المستقبل. | A date of birth can't be in the future. |
| `aboutYouDone` | New | يلا بينا | Let's go |
| `personAddFor` | New | إضافة ل{name} | Add for {name} |
| `personVaccineWasDue` | New | كان ميعادها {date}. اسأل الدكتور إمتى تتاخد. | It was due on {date}. Ask the doctor when to give it. |
| `personDoctorSummary` | New | ملخص للدكتور | Doctor summary |
| `personInsuranceOpen` | New | افتح الكارت | Open card |
| `personVaccineLog` | New | اتاخدت؟ سجّلها | Given? Log it |
| `personVaccineSource` | New | المرجع: جدول التطعيمات في مصر، {route} – اتراجع {date} | Reference: Egypt's vaccine schedule, {route} – checked {date} |
| `personVaccineSourceOptional` | New | المرجع: الجداول المعتادة عند دكاترة الأطفال في مصر – اتراجع {date} | Reference: pediatricians' usual schedules in Egypt – checked {date} |
| `personNextDose` | New | الجرعة الجاية – {time} | Next dose – {time} |
| `personDoseWasAt` | New | كان ميعادها {time} | Was due at {time} |
| `personRecordedTitle` | New | اللي العيلة سجّلته | Recorded by the family |
| `personTimelineTitle` | New | كل السجلات | All records |
| `personTileGrowth` | New | النمو | Growth |
| `personTileVisits` | New | الزيارات والتحاليل | Visits and labs |
| `personTileInsurance` | New | التأمين | Insurance |
| `personTileDocuments` | New | الورق والصور | Documents and photos |
| `personVaccinesSummary` | New | {done} من {total} – جدول مصر | {done} of {total} – Egypt schedule |
| `personGrowthWeight` | New | {value} كجم – {date} | {value} kg – {date} |
| `personGrowthHeight` | New | {value} سم – {date} | {value} cm – {date} |
| `personLatestOn` | New | آخرها {date} | Latest {date} |
| `personInsuranceCount` | New | {count, plural, =0{لسه مفيش} =1{كارت واحد} =2{كارتين} few{{shown} كروت} other{{shown} كارت}} | {count, plural, =0{None yet} =1{1 card} other{{shown} cards}} |
| `personMedicinesCount` | New | {count, plural, =0{مفيش أدوية حالية} =1{دوا واحد} =2{دوايين} few{{shown} أدوية} other{{shown} دوا}} | {count, plural, =0{None current} =1{1 current} other{{shown} current}} |
| `personFollowUpsCount` | New | {count, plural, =0{مفيش دلوقتي} =1{متابعة واحدة} =2{متابعتين} few{{shown} متابعات} other{{shown} متابعة}} | {count, plural, =0{None for now} =1{1 follow-up} other{{shown} follow-ups}} |
| `personDocumentsCount` | New | {count, plural, =0{لسه مفيش} =1{سجل واحد فيه صور} =2{سجلين فيهم صور} few{{shown} سجلات فيها صور} other{{shown} سجل فيه صور}} | {count, plural, =0{None yet} =1{1 record with photos} other{{shown} records with photos}} |
| `personVisitsEmpty` | New | لسه مفيش زيارات أو تحاليل متسجلة. | No visits or lab results recorded yet. |
| `personDocumentsEmpty` | New | لسه مفيش سجلات فيها صور. | No records with photos yet. |
| `personAgeYears` | New | {count, plural, =1{سنة} =2{سنتين} few{{shown} سنين} other{{shown} سنة}} | {count, plural, =1{1 year} other{{shown} years}} |
| `personAgeMonths` | New | {count, plural, =0{أقل من شهر} =1{شهر} =2{شهرين} few{{shown} شهور} other{{shown} شهر}} | {count, plural, =0{Under 1 month} =1{1 month} other{{shown} months}} |
| `emergencyAmbulanceShort` | New | الإسعاف {number} | Ambulance {number} |
| `emergencyOtherLanguage` | New | English | عربي |
| `emergencyMedicines` | New | أدوية حالية | Current medicines |
| `emergencyAsTyped` | New | ده اللي العيلة سجّلته، زي ما اتكتب. | This is what the family recorded, as they typed it. |
| `emergencyLockTitle` | New | إظهاره على قفل أسرة | Show on Usra's lock screen |
| `emergencyLockHint` | New | أي حد ماسك الموبايل وأسرة مفتوحة يقدر يشوفه | Anyone holding the phone can see it once Usra is open |
| `emergencyMedicalIdHint` | New | قفل أسرة بيظهر بس بعد ما الموبايل نفسه يتفتح. عشان المسعف يقدر يقرا المعلومات دي والموبايل مقفول، سجّلها كمان في Medical ID أو معلومات الطوارئ في إعدادات الموبايل. | Usra's lock screen only appears once the phone itself is unlocked. So a paramedic can read this on a locked phone, also add it to the phone's own Medical ID or emergency information, in the phone's settings. |
| `lockEmergencyConfirmTitle` | New | يظهر كارت {name} على قفل أسرة؟ | Show {name}'s card on Usra's lock screen? |
| `lockEmergencyConfirmBody` | New | أي حد ماسك الموبايل وأسرة مفتوحة هيقدر يشوف فصيلة الدم والحساسية والأمراض والعمليات والأدوية الحالية ورقم الطوارئ وصاحبه من غير الرقم السري. ده قفل أسرة، مش قفل الموبايل. | Anyone holding the phone with Usra open will be able to see the blood type, allergies, conditions, surgeries, current medicines and emergency number and whose it is without the PIN. This is Usra's lock screen, not the phone's. |
| `lockEmergencyConfirmYes` | New | أيوه، يظهر | Yes, show it |
| `insuranceCopyNumber` | New | انسخ رقم العضوية | Copy member number |
| `insuranceCopyFailed` | New | مقدرناش ننسخ الرقم | Couldn't copy the number |
| `insuranceNumberCopied` | New | رقم العضوية اتنسخ | Member number copied |
| `doseGroupMissed` | New | فاتت | Missed |
| `doseGroupNow` | New | دلوقتي | Now |
| `doseGroupDone` | New | اتسجلت | Logged |
| `dayPartMorning` | New | الصبح | Morning |
| `dayPartNoon` | New | الضهر | Noon |
| `dayPartAfternoon` | New | العصر | Afternoon |
| `dayPartNight` | New | بالليل | Night |
| `doseSnoozeShort` | New | بعد ١٠ دقايق | In 10 min |
| `doseTakenEarly` | New | اتاخد بدري | Taken early |
| `doseSnoozedUntil` | New | متأجل لحد {time} | Snoozed until {time} |
| `doseLoggedEarly` | New | اتسجل بدري: {medicine} لـ{person} | Logged early: {medicine} for {person} |
| `doseLoggedNotTaken` | New | اتسجل إنه ماتاخدش: {medicine} لـ{person} | Logged as not taken: {medicine} for {person} |
| `doseLoggedSnoozed` | New | هنفكّرك بعد ١٠ دقايق: {medicine} لـ{person} | Reminder in 10 minutes: {medicine} for {person} |
| `medicinesAll` | New | كل الأدوية | All medicines |
| `medicinesFilterAll` | New | الكل | All |
| `medicinesTodayEmptyFor` | New | مفيش أدوية لـ{name} النهارده. | No medicines for {name} today. |
| `medicineFor` | New | الدوا ده ل{name} | This medicine is for {name} |
| `medicineForChange` | New | غيّر | Change |
| `medicineForPick` | New | الدوا ده لمين؟ | Who is this medicine for? |
| `medicineSaveFor` | New | احفظ ل{name} | Save for {name} |
| `medicineSaveForRemind` | New | احفظ ل{name} وفكّرني | Save for {name} and remind me |
| `medicineSavedFor` | New | اتحفظ: {medicine} لـ{name} | Saved: {medicine} for {name} |
| `medicineScanOption` | New | اقرا الاسم من صورة العلبة | Read the name from a box photo |
| `medicineScanOptionBody` | New | هتراجع الاسم والتركيز قبل الحفظ | You'll check the name and strength before saving |
| `medicineScanRead` | New | اتقرا من صورة العلبة | Read from the box photo |
| `medicineScanReview` | New | راجع البيانات على العلبة قبل الحفظ | Check the details on the box before saving |
| `medicineScanConfirm` | New | راجعت الاسم والتركيز على العلبة | I checked the name and strength on the box |
| `medicineScanConfirmNeeded` | New | علّم هنا بعد ما تراجع الاسم والتركيز | Tick this once you've checked the name and strength |
| `medicineUnsureValue` | New | مش متأكدين من القراية، راجعها على العلبة | We're not sure of this reading. Check it on the box |
| `medicineFreqOnce` | New | مرة في اليوم | Once a day |
| `medicineFreqTwice` | New | مرتين | Twice |
| `medicineFreqThrice` | New | ٣ مرات | 3 times |
| `medicineFreqAsNeeded` | New | لما يحتاج | When needed |
| `medicineAddAnotherTime` | New | ميعاد تاني | Another time |
| `medicineChangeTime` | New | غيّر {time} | Change {time} |
| `medicineOngoing` | New | على طول | Ongoing |
| `medicineUntilDate` | New | لحد يوم معين | Until a date |
| `medicineLastDay` | New | آخر يوم | Last day |
| `medicineMoreDetails` | New | تفاصيل أكتر | More details |
| `medicineLessDetails` | New | تفاصيل أقل | Fewer details |
| `medicineClose` | New | اقفل | Close |
| `vaccinesTitleOf` | New | تطعيمات {name} | {name}'s vaccines |
| `vaccineProgressLine` | New | {done} من {total} جرعة اتاخدت | {done} of {total} doses given |
| `vaccineNewTitle` | New | تطعيم جديد | New vaccine |
| `vaccineDoneGroup` | New | اللي خلص | Done |
| `vaccineDoneGroupLast` | New | اتاخدت كلها – آخرها {date} | All given – the last on {date} |
| `vaccineGroupCount` | New | {done} من {total} | {done} of {total} |
| `vaccineTickAll` | New | تحديد الكل | Tick all |
| `vaccineSetupSkipNow` | New | تخطي التطعيمات دلوقتي | Skip vaccines for now |
| `fieldVaccinePlace` | New | فين؟ | Where? |
| `vaccineCardPhoto` | New | صورة كارت التطعيم | Photo of the vaccine card |
| `vaccineWhich` | New | أنهي تطعيم؟ | Which vaccine? |
| `vaccineOtherChoice` | New | تطعيم تاني | Another vaccine |
| `vaccineWhoFor` | New | لمين؟ | For whom? |
| `vaccineSavedFor` | New | اتحفظ: {vaccine} لـ{name} | Saved: {vaccine} for {name} |
| `vaccineChoiceOverdue` | New | {dose} – متأخر | {dose} – overdue |
| `growthTitleOf` | New | نمو {name} | {name}'s growth |
| `growthNew` | New | قياس جديد | New measurement |
| `growthTabWeight` | New | الوزن | Weight |
| `growthTabHeight` | New | الطول | Height |
| `growthTabHead` | New | محيط الراس | Head |
| `growthUnitKg` | New | كجم | kg |
| `growthUnitCm` | New | سم | cm |
| `growthHistoryTitle` | New | القياسات | Measurements |
| `growthLegendOwn` | New | قياسات {name} | {name}'s measurements |
| `growthLegendReference` | New | المعدل المرجعي | Reference range |
| `growthLastOn` | New | آخر قياس {date} | Last measured {date} |
| `growthTabOutside` | New | برّه المدى المعتاد | Outside the usual range |
| `pregnancyAddRecord` | New | سجّلي زيارة أو تحليل | Add a visit or test |
| `pregnancyNextTitle` | New | الجاي | Coming up |
| `pregnancyPastTitle` | New | اللي فات | Earlier |
| `pregnancySupplementsTitle` | New | الأدوية والمكمّلات النهارده | Medicines and supplements today |
| `pregnancySupplementsEmpty` | New | مفيش حاجة متسجلة للنهارده. | Nothing recorded for today. |
| `pregnancySupplementsAdd` | New | ضيفي دوا أو مكمّل | Add a medicine or supplement |
| `reportSummaryNotOpinion` | New | ده ملخص من اللي العيلة سجلته، مش رأي طبي. | This summary is what the family recorded, not a medical opinion. |
| `followUpsThisWeek` | New | النهارده والأسبوع ده | Today and this week |
| `followUpsLater` | New | بعد كده | Later |
| `followUpsAll` | New | كل المتابعات | All follow-ups |
| `insuranceWatermark` | New | {name} – {date} | {name} – {date} |
| `insuranceShareWarning` | New | قبل ما تبعت: الكارت فيه بيانات شخصية، واللي هيستلمه ممكن يبعته لغيره. هنكتب على الصورة التاريخ واسم شركة التأمين لو متسجل. | Before you send it: the card holds personal details, and whoever gets it could pass it on. We'll write the date and the insurer's name, if saved, across the picture. |
| `insuranceShareWarningNoPhoto` | New | قبل ما تبعت: رقم العضوية بيانات شخصية، واللي هيستلمه ممكن يبعته لغيره. | Before you send it: the member number is personal, and whoever gets it could pass it on. |
| `simpleNextDose` | New | الدوا الجاي | Next medicine |
| `simpleThenDose` | New | وبعده: {medicine} الساعة {time} | Then: {medicine} at {time} |
| `simpleNoDoses` | New | مفيش جرعات فاضلة النهارده. | No doses left today. |
| `simpleExit` | New | خروج من الوضع البسيط | Leave Simple Mode |
| `simpleExitWithPin` | New | خروج من الوضع البسيط (بالرقم السري) | Leave Simple Mode (with the PIN) |
| `simpleExitConfirm` | New | تخرج من الوضع البسيط؟ | Leave Simple Mode? |
| `simpleExitStay` | New | خليك فيه | Stay |
| `simpleExitGo` | New | اخرج | Leave |
| `countrySoonNote` | New | السعودية والأردن هيفتحوا لما جداولهم وأرقام الإسعاف يتراجعوا. | Saudi Arabia and Jordan will open once their schedules and ambulance numbers are checked. |
| `homeSetupIntro` | New | خطوات ممكن تبدأ بيها. مفيش حاجة منهم إجبارية. | Some places to start. None of them is required. |
| `homeSetupFamily` | New | فرد من العيلة | A family member |
| `homeSetupFamilyHint` | New | الاسم والنوع وتاريخ الميلاد وصلة القرابة | Name, sex, date of birth and relationship |
| `homeSetupReminders` | New | التذكير بالدوا والتطعيمات | Medicine and vaccine reminders |
| `homeSetupRemindersHint` | New | الإذن بيتطلب وقتها بس | Permission is only asked for then |
| `homeSetupEmergency` | New | كارت الطوارئ | Emergency card |
| `homeSetupEmergencyHint` | New | فصيلة الدم والحساسية ورقم للطوارئ | Blood type, allergies and an emergency number |
| `homeSetupLockNote` | New | بعد أول نسخة احتياطية هنقترح قفل أسرة برقم سري. | After the first backup we'll suggest locking Usra with a PIN. |
| `homeSetupHide` | New | إخفاء | Hide |
| `simpleThenDoseFor` | New | وبعده: {medicine} لـ{name} الساعة {time} | Then: {medicine} for {name} at {time} |

## Visual polish, November 2026

Wording from the polish the founder approved on 13 Nov 2026 (`docs/design/polish-2026-11/`). The words follow the mock-ups. None of these changes medical meaning. Anything that would have done so was left as it was and listed for the doctor in the PR.

| Key | | Arabic | English |
|---|---|---|---|
| `backupNoneTitle` | New | لسه مفيش نسخة احتياطية | No backup yet |
| `backupDueNever` | Changed | لو الموبايل ضاع، السجلات بتضيع معاه. النسخة متشفرة وبتتحفظ برّه الموبايل | If this phone is lost, the records go with it. The backup is encrypted and kept off the phone |
| `vaccineGivableNowCount` | New | {count} ممكن تتاخد دلوقتي | {count} can be given now |
| `sickDayNoReadingsYet` | New | مفيش قراءات لسه | No readings yet |
| `sickDaysPastHere` | New | أيام التعب اللي فاتت هتظهر هنا | Past sick days will show here |
| `warnEmergencyShort` | New | اطلب الإسعاف فورًا لو ظهر | Call an ambulance at once if you see |
| `sickDayAllSigns` | New | كل العلامات وإمتى نكلم الدكتور | All the signs, and when to call the doctor |
| `backupNeverShort` | New | لسه مفيش نسخة | No backup yet |
| `settingsStateOn` | New | شغّال | On |
| `settingsStateOff` | New | مش شغّال | Off |
| `settingsDiscreetHintShort` | New | التنبيه يقول "ميعاد الدوا" بس | Reminders just say "Your medicine time" |
| `settingsBlockScreenshotsHintShort` | New | مفيش سكرين شوت ولا تسجيل للشاشة في التطبيق | No screenshots or screen recording in the app |
| More: money row | Changed | المصاريف (was الفلوس, now uses `memberSpending`) | Spending (was Money) |
| More: family row | Changed | adds `familyCount` under كل العيلة, e.g. فردين | adds the number of people |
| `vaccineMarkPastAsk` | New | girl: خدت كل اللي فات؟ علّمها مرة واحدة · boy: خد كل اللي فات؟ علّمها مرة واحدة · other: كل اللي فات اتاخد؟ علّمه مرة واحدة | Had everything due so far? Mark it all at once |
| `vaccineGivableNowHeading` | New | ممكن تتاخد دلوقتي – {count} | Can be given now – {count} |
| `vaccineWasDueAt` | New | كان ميعادها {age} | Was due {age} |
| `vaccineLogShort` | New | تسجيل | Log |
| `vaccineDoctorDecides` | New | الدكتور يحدد إمتى تتاخد. | The doctor decides when they are given. |
| `vaccineAndMore` | New | و{count} كمان (وواحدة كمان، واتنين كمان) | and {count} more |
| `vaccineThenInOrder` | New | بعدها {count} جرعة بالترتيب (جرعة واحدة، جرعتين، جرعات) | then {count} doses in order |
| `vaccineMissingDosesTitle` | New | {count} جرعة تطعيم ناقصة (جرعة تطعيم ناقصة، جرعتين تطعيم ناقصين، جرعات تطعيم ناقصة) | {count} vaccine doses missing |
| `sickDayReadingShort` | New | قراءة | Reading |

## Bug fixes, 13 November 2026

From the fixes for the two-year-old test report (`docs/test-reports/2026-11-12-two-year-old.md`). Medical strings here are also in `docs/medical-review-changes.md`.

| Key | | Arabic | English |
|---|---|---|---|
| `sickDayHighestReading` | New | أعلى قراءة: {reading} – {time} | Highest reading: {reading} – {time} |
| `sickDayFeverSpan` | New, replaces `sickDayFeverLogged` | سخونية متسجلة من {from} لـ {to} (was سخونية متسجلة: {duration}, e.g. ٤ ساعات) | Fever readings from {from} to {to} (was Fever logged: {duration}) |
| `sickDayFeverOnce` | New | سخونية متسجلة: {time} | Fever reading: {time} |
| `sickDayFeverUnderHour`, `sickDayFeverHours`, `sickDayFeverDays` | Removed | أقل من ساعة، {n} ساعة، {n} يوم | no longer shown |

## Text that follows the person's sex (item I), 13 November 2026

Danger signs (`warnSign`), symptoms (`symptomName`) and CDC milestones (`milestone`) now follow the person's sex, the same way `vaccineMarkPastAsk` does: `female` for a girl or woman, `male` for a boy or man, `other` when sex isn't recorded. Only the grammar changes. The boy's text is the wording reviewed before and is unchanged. The English doesn't change. Strings not listed here (seizure, skin colour, fever days and so on) are the same for everyone.

For a person whose sex isn't recorded, danger signs and symptoms use a neutral form (السن، الحرارة، نعاس شديد). Milestones keep the boy's wording, because a neutral version of 48 milestones would mean rewriting them, not changing grammar. The milestone label in a saved record's details (`children_module.dart`) has no person to read, so it also keeps the boy's wording.

| Key | Case | Boy (unchanged) | Girl | Sex not recorded |
|---|---|---|---|---|
| `warnSign` | `breathing` | صعوبة في النفس، أو بيتنفس بسرعة جدًا، أو نفسه مقطوع | صعوبة في النفس، أو بتتنفس بسرعة جدًا، أو نفسها مقطوع | صعوبة في النفس، أو نفَس سريع جدًا، أو النفس مقطوع |
| `warnSign` | `drowsy` | نعسان جدًا أو صعب يصحى، أو مش بيرد زي عادته | نعسانة جدًا أو صعب تصحى، أو مش بترد زي عادتها | نعاس شديد أو صعوبة في الصحيان، أو مفيش رد زي العادة |
| `warnSign` | `stiffNeck` | تيبس في الرقبة، أو النور بيضايق عينه | تيبس في الرقبة، أو النور بيضايق عينها | تيبس في الرقبة، أو النور بيضايق العين |
| `warnSign` | `confused` | مش مركز أو متلخبط، أو متضايق جدًا ومش بيبطل عياط | مش مركزة أو متلخبطة، أو متضايقة جدًا ومش بتبطل عياط | قلة تركيز أو لخبطة، أو ضيق شديد وعياط مش بيقف |
| `warnSign` | `under3Months` | سنه أقل من ٣ شهور وحرارته ٣٨ °م (١٠٠٫٤ °ف) أو أكتر | سنها أقل من ٣ شهور وحرارتها ٣٨ °م (١٠٠٫٤ °ف) أو أكتر | السن أقل من ٣ شهور والحرارة ٣٨ °م (١٠٠٫٤ °ف) أو أكتر |
| `warnSign` | `months3to6` | سنه من ٣ لـ ٦ شهور وحرارته ٣٩ °م (١٠٢٫٢ °ف) أو أكتر | سنها من ٣ لـ ٦ شهور وحرارتها ٣٩ °م (١٠٢٫٢ °ف) أو أكتر | السن من ٣ لـ ٦ شهور والحرارة ٣٩ °م (١٠٢٫٢ °ف) أو أكتر |
| `warnSign` | `longUnder2` | سنه أقل من سنتين والسخونية بقالها أكتر من ٢٤ ساعة | سنها أقل من سنتين والسخونية بقالها أكتر من ٢٤ ساعة | السن أقل من سنتين والسخونية بقالها أكتر من ٢٤ ساعة |
| `warnSign` | `longChild` | سنه سنتين أو أكتر والسخونية بقالها أكتر من ٣ أيام | سنها سنتين أو أكتر والسخونية بقالها أكتر من ٣ أيام | السن سنتين أو أكتر والسخونية بقالها أكتر من ٣ أيام |
| `warnSign` | `dehydration` | علامات جفاف: حفاضات ناشفة أو بيعمل حمام أقل، مفيش دموع، عينين غايرة، بُق ناشف | علامات جفاف: حفاضات ناشفة أو بتعمل حمام أقل، مفيش دموع، عينين غايرة، بُق ناشف | علامات جفاف: حفاضات ناشفة أو حمام أقل، مفيش دموع، عينين غايرة، بُق ناشف |
| `warnSign` | `notDrinking` | مش بيشرب أو مش بيرضع، أو مش زي عادته خالص | مش بتشرب أو مش بترضع، أو مش زي عادتها خالص | مفيش شرب أو مفيش رضاعة، أو مش زي العادة خالص |
| `warnSign` | `vomitsEverything` | بيرجّع أي حاجة ياخدها، أو مش بيبطل ترجيع | بترجّع أي حاجة تاخدها، أو مش بتبطل ترجيع | ترجيع لأي حاجة بتتاخد، أو ترجيع مش بيقف |
| `warnSign` | `armpitUnder3Months` | سنه أقل من ٣ شهور والحرارة تحت الباط ٣٧٫٥ °م (٩٩٫٥ °ف) أو أكتر | سنها أقل من ٣ شهور والحرارة تحت الباط ٣٧٫٥ °م (٩٩٫٥ °ف) أو أكتر | السن أقل من ٣ شهور والحرارة تحت الباط ٣٧٫٥ °م (٩٩٫٥ °ف) أو أكتر |
| `warnSign` | `lowUnder3Months` | سنه أقل من ٣ شهور وحرارته أقل من ٣٦ °م (٩٦٫٨ °ف) | سنها أقل من ٣ شهور وحرارتها أقل من ٣٦ °م (٩٦٫٨ °ف) | السن أقل من ٣ شهور والحرارة أقل من ٣٦ °م (٩٦٫٨ °ف) |
| `symptomName` | `poorFeeding` | بياكل أو بيشرب أقل | بتاكل أو بتشرب أقل | أكل أو شرب أقل |
| `symptomName` | `dehydration` | حفاضات ناشفة أو بيعمل حمام أقل أو مفيش دموع | حفاضات ناشفة أو بتعمل حمام أقل أو مفيش دموع | حفاضات ناشفة أو حمام أقل أو مفيش دموع |
| `symptomName` | `drowsy` | نعسان جدًا أو صعب يصحى | نعسانة جدًا أو صعب تصحى | نعاس شديد أو صعوبة في الصحيان |
| `milestone` | `m2_social` | بيضحك لما تكلمه أو تضحكله | بتضحك لما تكلمها أو تضحكلها | same as boy |
| `milestone` | `m2_language` | بيطلّع أصوات غير العياط | بتطلّع أصوات غير العياط | same as boy |
| `milestone` | `m2_cognitive` | بيتابعك بعينه وانت بتتحرك | بتتابعك بعينها وانت بتتحرك | same as boy |
| `milestone` | `m2_movement` | بيرفع راسه وهو نايم على بطنه | بترفع راسها وهي نايمة على بطنها | same as boy |
| `milestone` | `m4_social` | بيضحك من نفسه عشان يلفت انتباهك | بتضحك من نفسها عشان تلفت انتباهك | same as boy |
| `milestone` | `m4_language` | بيناغي بأصوات زي «أووو» و«آآه» | بتناغي بأصوات زي «أووو» و«آآه» | same as boy |
| `milestone` | `m4_cognitive` | بيبص على إيديه باهتمام | بتبص على إيديها باهتمام | same as boy |
| `milestone` | `m4_movement` | بيثبّت راسه لوحده وانت شايله | بتثبّت راسها لوحدها وانت شايلها | same as boy |
| `milestone` | `m6_social` | بيعرف الناس اللي متعود عليهم | بتعرف الناس اللي متعودة عليهم | same as boy |
| `milestone` | `m6_language` | بيرد عليك بأصوات لما تكلمه | بترد عليك بأصوات لما تكلمها | same as boy |
| `milestone` | `m6_cognitive` | بيمد إيده يمسك اللعبة اللي عايزها | بتمد إيدها تمسك اللعبة اللي عايزاها | same as boy |
| `milestone` | `m6_movement` | بيتقلب من بطنه لضهره | بتتقلب من بطنها لضهرها | same as boy |
| `milestone` | `m9_social` | بيبص لما تنده اسمه | بتبص لما تنده اسمها | same as boy |
| `milestone` | `m9_language` | بيقول أصوات زي «ماماما» و«بابابا» | بتقول أصوات زي «ماماما» و«بابابا» | same as boy |
| `milestone` | `m9_cognitive` | بيدور على الحاجة لما تقع من قدامه | بتدور على الحاجة لما تقع من قدامها | same as boy |
| `milestone` | `m9_movement` | بيقعد من غير سند | بتقعد من غير سند | same as boy |
| `milestone` | `m12_social` | بيلعب معاك ألعاب زي التسقيف | بتلعب معاك ألعاب زي التسقيف | same as boy |
| `milestone` | `m12_language` | بيعمل «باي باي» بإيده | بتعمل «باي باي» بإيدها | same as boy |
| `milestone` | `m12_cognitive` | بيدور على الحاجة اللي شافك بتخبيها | بتدور على الحاجة اللي شافتك بتخبيها | same as boy |
| `milestone` | `m12_movement` | بيسند على حاجة ويقف | بتسند على حاجة وتقف | same as boy |
| `milestone` | `m15_social` | بيوريك حاجة بيحبها | بتوريك حاجة بتحبها | same as boy |
| `milestone` | `m15_language` | بيحاول يقول كلمة أو اتنين غير «ماما» و«بابا» | بتحاول تقول كلمة أو اتنين غير «ماما» و«بابا» | same as boy |
| `milestone` | `m15_cognitive` | بيرص حاجتين صغيرين على بعض على الأقل | بترص حاجتين صغيرين على بعض على الأقل | same as boy |
| `milestone` | `m15_movement` | بيمشي كام خطوة لوحده | بتمشي كام خطوة لوحدها | same as boy |
| `milestone` | `m18_social` | بيشاور عشان يوريك حاجة لفتت نظره | بتشاور عشان توريك حاجة لفتت نظرها | same as boy |
| `milestone` | `m18_language` | بيحاول يقول ٣ كلمات أو أكتر غير «ماما» و«بابا» | بتحاول تقول ٣ كلمات أو أكتر غير «ماما» و«بابا» | same as boy |
| `milestone` | `m18_cognitive` | بيقلدك وانت بتعمل شغل البيت، زي الكنس | بتقلدك وانت بتعمل شغل البيت، زي الكنس | same as boy |
| `milestone` | `m18_movement` | بيمشي من غير ما يسند على حد أو حاجة | بتمشي من غير ما تسند على حد أو حاجة | same as boy |
| `milestone` | `m24_social` | بياخد باله لما حد يتعور أو يزعل | بتاخد بالها لما حد يتعور أو يزعل | same as boy |
| `milestone` | `m24_language` | بيقول كلمتين مع بعض على الأقل، زي «عايز لبن» | بتقول كلمتين مع بعض على الأقل، زي «عايزة لبن» | same as boy |
| `milestone` | `m24_cognitive` | بيحاول يشغّل الزراير أو المفاتيح في اللعب | بتحاول تشغّل الزراير أو المفاتيح في اللعب | same as boy |
| `milestone` | `m24_movement` | بيشوط الكورة | بتشوط الكورة | same as boy |
| `milestone` | `m30_social` | بيلعب جنب الأطفال التانيين وساعات معاهم | بتلعب جنب الأطفال التانيين وساعات معاهم | same as boy |
| `milestone` | `m30_language` | بيقول حوالي ٥٠ كلمة | بتقول حوالي ٥٠ كلمة | same as boy |
| `milestone` | `m30_cognitive` | بيلعب تمثيل، زي إنه يأكّل العروسة | بتلعب تمثيل، زي إنها تأكّل العروسة | same as boy |
| `milestone` | `m30_movement` | بينط من على الأرض برجليه الاتنين | بتنط من على الأرض برجليها الاتنين | same as boy |
| `milestone` | `m36_social` | بياخد باله من الأطفال التانيين ويلعب معاهم | بتاخد بالها من الأطفال التانيين وتلعب معاهم | same as boy |
| `milestone` | `m36_language` | بيتكلم معاك ويرد عليك مرتين على الأقل في نفس الكلام | بتتكلم معاك وترد عليك مرتين على الأقل في نفس الكلام | same as boy |
| `milestone` | `m36_cognitive` | بيرسم دايرة لما توريه إزاي | بترسم دايرة لما توريها إزاي | same as boy |
| `milestone` | `m36_movement` | بيلبس شوية من هدومه لوحده | بتلبس شوية من هدومها لوحدها | same as boy |
| `milestone` | `m48_social` | بيطبطب على اللي متعور أو زعلان | بتطبطب على اللي متعور أو زعلان | same as boy |
| `milestone` | `m48_language` | بيقول جمل فيها ٤ كلمات أو أكتر | بتقول جمل فيها ٤ كلمات أو أكتر | same as boy |
| `milestone` | `m48_cognitive` | بيعرف يسمي كام لون | بتعرف تسمي كام لون | same as boy |
| `milestone` | `m48_movement` | بيمسك الكورة الكبيرة أغلب الوقت | بتمسك الكورة الكبيرة أغلب الوقت | same as boy |
| `milestone` | `m60_social` | بيلتزم بقواعد اللعب ويستنى دوره | بتلتزم بقواعد اللعب وتستنى دورها | same as boy |
| `milestone` | `m60_language` | بيحكي حكاية سمعها أو ألّفها فيها حدثين على الأقل | بتحكي حكاية سمعتها أو ألّفتها فيها حدثين على الأقل | same as boy |
| `milestone` | `m60_cognitive` | بيعد لحد ١٠ | بتعد لحد ١٠ | same as boy |
| `milestone` | `m60_movement` | بينط على رجل واحدة | بتنط على رجل واحدة | same as boy |

## Consent screen, November 2026

The consent screen asked before any health data is saved (Egypt PDPL 151/2020). It follows the live privacy policy, version 1.0 (https://opsedia.ai/usra/en/privacy), section 1. All the text is neutral, so it suits a man or a woman. `consentPointDoctor` is a disclaimer, so it also goes to the doctor.

| Key | | Arabic | English |
|---|---|---|---|
| `consentTitle` | New | قبل ما نبدأ | Before you start |
| `consentHint` | New | أسرة بتحفظ معلومات صحية، فمحتاجين موافقتك الأول. | Usra keeps health information, so it needs your agreement first. |
| `consentUpdated` | New | سياسة الخصوصية اتغيّرت. محتاجين موافقتك تاني قبل ما نكمّل. | The privacy policy has changed. Usra needs your agreement again before going on. |
| `consentPointLocal` | New | بيانات عيلتك الصحية بتفضل على الموبايل ده ومتشفرة، وإحنا مش بنشوفها. | Your family's health data stays on this phone, encrypted. We can't see it. |
| `consentPointGuardian` | New | معلومات أفراد العيلة بتتضاف بصفتك وليّ أمرهم، أو بموافقتهم. | You add family members' information as their parent or guardian, or with their agreement. |
| `consentPointDoctor` | New | أسرة مش بتشخّص ولا بتعالج. الرأي دايماً للدكتور. | Usra doesn't diagnose or treat. Always check with a doctor. |
| `consentPrivacyLink` | New | سياسة الخصوصية | Privacy policy |
| `consentTermsLink` | New | شروط الاستخدام | Terms of use |
| `consentVersion` | New | سياسة الخصوصية، إصدار {version} | Privacy policy version {version} |
| `consentCheckbox` | New | قريت سياسة الخصوصية والشروط، وأوافق إن أسرة تحفظ بيانات عيلتي الصحية على الموبايل ده. | I've read the privacy policy and the terms, and I agree to Usra keeping my family's health data on this phone. |
| `consentAgree` | New | أوافق | I agree |
| `consentSaveFailed` | New | الموافقة متحفظتش. جرّب تاني. | Your agreement couldn't be saved. Try again. |
| `consentDecline` | New | مش موافق؟ امسح كل بياناتي | Don't agree? Delete all my data |

Questions: `consentSaveFailed` uses جرّب and `consentDecline` uses مش موافق, which are the masculine forms the app already uses (as in `settingsDeleteAll`). Should they be neutral? Is "الرأي دايماً للدكتور" a natural way to say "always check with a doctor"?

### Insurance card page (visual QA, 13 Nov)

| Key | | Arabic | English |
|---|---|---|---|
| `insuranceCopyShort` | New | انسخ | Copy |
| `insuranceDeleteCard` | New | امسح الكارت | Delete card |

`insuranceCopyShort` is the short action on the member-number row. A screen reader still hears `insuranceCopyNumber` (انسخ رقم العضوية). `insuranceDeleteCard` replaces the trash icon in the header with a text button at the end of the page. Both use the masculine imperative, as `insuranceDelete` (امسح) already does.

### Mark everything due so far as given (founder's decision, 13 Nov 2026)

One button, on the Vaccines page and in the vaccine setup checklist, marks every dose due by the child's age as given, optional (private, paid) vaccines included and ticked by default. The button keeps `vaccineMarkPastAsk`, unchanged; the setup checklist now uses it too instead of `vaccineMarkPast`.

| Key | | Arabic | English |
|---|---|---|---|
| `vaccineMarkPastAge` | New | عندها {age} دلوقتي. / عنده {age} دلوقتي. / السن دلوقتي: {age}. | She is {age} now. / He is {age} now. / Age now: {age}. |
| `vaccineMarkPastBody` | Changed | {count} جرعة إجبارية لحد السن ده هيتعلّم عليها إنها اتاخدت، كل واحدة في ميعادها على الجدول، مش النهارده. (=0: مفيش جرعات إجبارية فاضلة لحد السن ده. =1: جرعة إجبارية واحدة لحد السن ده هيتعلّم عليها إنها اتاخدت، في ميعادها على الجدول، مش النهارده. =2: جرعتين إجباريتين لحد السن ده هيتعلّم عليهم إنهم اتاخدوا، كل واحدة في ميعادها على الجدول، مش النهارده.) | {count} required doses due up to this age will be marked as given, each on its date on the schedule, not today. (=0: No required dose is left to mark up to this age.) |
| `vaccineMarkPastSafety` | New (moved out of `vaccineMarkPastBody`, words unchanged) | راجع كارت التطعيم الأول: الكارت ودكتور الطفل هما المرجع. تقدر ترجع فيها، أو تشيل العلامة من أي جرعة بعدين. | Check the vaccination card first: the card and the child's doctor are the reference. You can undo this, or untick any dose later. |
| `vaccineMarkPastOptional` | Changed | ومعاها الاختيارية اللي ميعادها جه لحد السن ده، كل واحدة في ميعادها: {names} ({count} جرعة) | Also the optional ones due by this age, each on its date: {names} ({count} doses) |
| `vaccineMarkPastOptionalHint` | New | الاختيارية هي التطعيمات الخاصة اللي بفلوس. شيل العلامة لو ماخدتهاش. / لو ماخدهاش. / لو الطفل ماخدهاش. | The optional ones are the private, paid vaccines. Untick if she didn't / he didn't / the child didn't have them. |
| `vaccineMarkPast` | Removed | علّم على كل اللي فات إنه اتاخد | Mark everything due so far as given |
| `vaccineUpTo` | Removed | لحد سن {months} شهر | up to {months} months |

Before, `vaccineMarkPastBody` said "{count} required doses {up to 18 months} will be marked…" and `vaccineMarkPastOptional` said "ومعاها الاختياري اللي ماشيين عليه ({count})" (only the optional vaccines the family had chosen, unticked).

Questions: is "اللي بفلوس" natural for "paid", or is "بفلوس في الخاص" clearer? `vaccineMarkPastOptionalHint` addresses the reader with "شيل" (masculine), as `vaccineMarkPastSafety` already does with "راجع".

## Separator, November 2026 (QA H2)

The middle dot "·" between parts of a line looked like the Arabic zero "٠" beside Arabic-Indic digits: "١٣ نوفمبر ٢٠٢٦ · ٣٥٠ ج.م" read as "٣٥٠٠", and "عند الولادة · ٠ من ٣" as "٠٠ من ٣". Every such line now uses a spaced en dash " – ", in both languages. The same change applies to lines the app builds in code (names, dates, amounts, record titles), through one shared constant, `partSeparator` in `app/lib/core/util/separator.dart`. Lists of times, such as the hours of a dose every 8 hours, use the comma "، " instead, because a dash between two times reads as a range. Only the separator changed; no words changed.

| Key | | Arabic | English |
|---|---|---|---|
| `sickDayHighestReading` | Changed | أعلى قراءة: {reading} – {time} | Highest reading: {reading} – {time} |
| `sickDayRecordedGiven` | Changed | مسجل: {what} – {time} | Recorded: {what} – {time} |
| `countryEgyptDetail` | Changed | وزارة الصحة والسكان – الإسعاف ١٢٣ | Ministry of Health and Population – Ambulance 123 |
| `personVaccineSource` | Changed | المرجع: جدول التطعيمات في مصر، {route} – اتراجع {date} | Reference: Egypt's vaccine schedule, {route} – checked {date} |
| `personVaccineSourceOptional` | Changed | المرجع: الجداول المعتادة عند دكاترة الأطفال في مصر – اتراجع {date} | Reference: pediatricians' usual schedules in Egypt – checked {date} |
| `personNextDose` | Changed | الجرعة الجاية – {time} | Next dose – {time} |
| `personVaccinesSummary` | Changed | {done} من {total} – جدول مصر | {done} of {total} – Egypt schedule |
| `personGrowthWeight` | Changed | {value} كجم – {date} | {value} kg – {date} |
| `personGrowthHeight` | Changed | {value} سم – {date} | {value} cm – {date} |
| `vaccineDoneGroupLast` | Changed | اتاخدت كلها – آخرها {date} | All given – the last on {date} |
| `vaccineChoiceOverdue` | Changed | {dose} – متأخرة | {dose} – overdue |
| `insuranceWatermark` | Changed | {name} – {date} | {name} – {date} |
| `vaccineCatchUp` | Changed | جرعة تعويضية – ميعادها {date} | Catch-up – due {date} |
| `vaccineOptionalWasDue` | Changed | اختياري – كان ميعادها {date} | Optional – was due {date} |
| `vaccineGivableNowHeading` | Changed | ممكن تتاخد دلوقتي – {count} | Can be given now – {count} |

Question: does " – " read naturally to you between parts, for example "الجرعة الجاية – ٨:٠٠ م"? The Arabic comma "، " was the other option.

## Mascot introduction, 13 November 2026 (founder decision)

The mascot no longer calls itself a doctor, so it doesn't blur the "not a medical device" line.

| Key | Arabic | English |
|---|---|---|
| `homeGreeting` | أهلاً! أنا دليلك في أسرة | Hello! I'm your guide in Usra |
| `tutorialWelcomeTitle` | أهلاً، أنا دليلك في أسرة | Hi, I'm your guide in Usra |

## Keyboard Done, 13 November 2026 (end-to-end test #9)

iPhone number pads have no return key, so the pad stayed over Save. A thin bar with "تم" now sits on the number pad on iPhones and closes it.

| Key | | Arabic | English |
|---|---|---|---|
| `keyboardDone` | New | تم | Done |

## Wording by sex, 13 November 2026 (end-to-end tests #10, #11)

| Key | | Arabic | English |
|---|---|---|---|
| `homeNeedsAttentionOne` | Changed | {sex}: محتاجة انتباهك (girl, woman) / محتاج انتباهك (boy, man, not recorded) | needs your attention |
| `vaccineOverdueCount` | Changed (2 only) | جرعتين متأخرتين (was متأخرين) | 2 doses overdue |
| `vaccineMissingCount` | Changed (2 only) | جرعتين ناقصتين (was ناقصين) | 2 doses missing |
| `vaccineMissingDosesTitle` | Changed (2 only) | جرعتين تطعيم ناقصتين (was ناقصين) | 2 vaccine doses missing |
| `devIntro` | Changed | to a mother: علّمي على اللي بنتك/ابنك بتعمله/بيعمله، واختاري اليوم اللي لاحظتيه فيه أول مرة. To anyone else: علّم … واختار … لاحظته … (was always علّم على اللي طفلك بيعمله) | Tick what your child does, with the day you first noticed it. |
| `milestone` m18_cognitive | Changed | بيقلد / بتقلد شغل البيت اللي بتعملوه، زي الكنس (was بيقلدك وانت بتعمل شغل البيت) | Copies you doing chores, like sweeping (unchanged) |

Questions:
1. "جرعتين متأخرين" agreed with the doses, not the child, and is common in Egyptian speech; the end-to-end test read it as masculine about a girl. The feminine dual "متأخرتين / ناقصتين" follows the rule that جرعة takes feminine agreement. Which reads better to you?
2. `devIntro` uses the reader's sex from About you. A reader whose sex isn't known reads the masculine form, as elsewhere.
3. Other milestones still address the parent as a man: m2_cognitive "وانت بتتحرك", m4_movement "وانت شايله / شايلها". Should these change too? They are medical text, so they go to the doctor as well.

## Small text fixes, 13 November 2026 (end-to-end tests #12, #14–#17, #19)

- Full stops: text the app writes in Arabic digits turned every "." into the Arabic decimal sign "٫", which looks like a comma, so sentences in the "mark everything" dialog ended in commas. Only a point between two digits becomes "٫" now (#17).
- Greeting: صباح الخير until 1 pm, then مساء الخير; in English "Good afternoon" from 1 to 5 pm (#12).
- Growth rows in a person's timeline and Records read "قياس نمو – ١٢ كجم – ٨٦ سم" instead of "قياس نمو – ١٢" (#15).
- The version on the privacy page is kept left to right, "النسخة 0.1.0+1" (#19).

| Key | | Arabic | English |
|---|---|---|---|
| `homeAfternoon` | New | مساء الخير | Good afternoon |
| `recordFor` | New | السجل ده ل{name} | This record is for {name} |

`recordFor` sits under the title of every record form (visit, lab, scan, growth, surgery) so it's clear whose record it is (#16), like the medicine form's "الدوا ده ل{name}". Question: is "السجل ده لحسن" natural, or would "ده لحسن" alone read better under a title like "زيارة دكتور"?

## One label for adding a person, 13 November 2026 (end-to-end test #20)

Home's button said "فرد جديد" and the family page's "ضيف شخص". Home now uses `familyAdd` ("ضيف شخص") too; `homeNewPerson` is no longer shown. No string changed. The new-person form's title stays "فرد جديد" (`familyNew`). Question: should the title also say "ضيف شخص", or is a noun right for a title?
