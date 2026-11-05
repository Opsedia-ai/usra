# Usability test plan: five family sessions

Nov 5, 2026 · follows the UX audit (PR "UX audit and UI quality checks")

Arabic version below: [خطة اختبار الاستخدام](#خطة-اختبار-الاستخدام-خمس-جلسات-مع-عائلات).

## Why

The UX audit found problems by inspection. Only real families show which of
them matter: whether a grandmother finds her pills, whether a tired parent
records a fever at 3 a.m., whether the Egyptian Arabic reads naturally. Five
sessions find most of the serious problems; we fix them and test again.

## Who

Five sessions, each with one household member (a second may watch and help,
as at home):

| # | Person | Why |
| --- | --- | --- |
| 1 | Grandparent, 65+, uses WhatsApp but little else; Simple Mode | Elders are the hardest test of text size, wording and tap targets |
| 2 | Adult child who manages a parent's medicines | Caregiver tasks across two people |
| 3 | Mother of a baby under one | Vaccines, baby log, growth; often one hand free |
| 4 | Pregnant woman (or her partner) | Pregnancy tracker, labs |
| 5 | Parent of a toddler, recruited outside Cairo, with an older Android phone | Small screen, slower phone, different dialect |

At least two sessions on Android and two on iPhone; at least one person who
reads English better than Arabic. Nobody from the team's families.

## Setup

- A test phone with Usra installed from a debug build started with the demo
  family (`flutter run --dart-define=USRA_DEMO=true`, see `app/lib/demo/`).
  Never the person's own phone or records: no real health data is collected.
- Phone text size and language as the person uses at home (ask, and set it
  before starting).
- Screen recording on the test phone; audio only of the session, never faces,
  and only with consent (below).
- 45 minutes: 5 consent, 5 warm-up, 25 tasks, 10 wrap-up.
- Two people: a facilitator (talks) and a note-taker (silent, fills the
  observation sheet).
- A printed prescription (a made-up one with the doctor's handwriting), for
  task 3.

## Consent (read aloud, then sign)

> We are testing the app, not you. Nothing you do is wrong: if something is
> hard, that is the app's fault and exactly what we need to find.
>
> The phone has a made-up family in it. Please don't type anything real about
> you or your family.
>
> With your permission we record the phone's screen and the sound in the
> room, not your face. Only the Usra team listens to it, to take notes, and
> we delete it within 30 days. We write about what people did, never names.
>
> You can stop at any moment, skip any task, or ask us to delete the
> recording, with no reason needed. You get [the thank-you] either way.

Tick-boxes, each separately: ☐ I agree to take part ☐ I agree to the screen
and sound recording ☐ The team may quote what I said, without my name.

For a grandparent, the family member present can read it with them; the
person themselves agrees.

## Facilitator rules

- Say the task, hand over the phone, then stay quiet. Ask "what are you
  looking for?" or "what do you expect to happen?", never "try the button at
  the top".
- Ask them to think aloud: "say what you're thinking, even 'I don't know'".
- Help only after 3 minutes stuck or if they ask twice; mark it as an assist.
- Do not explain the app before the tasks: the first look is the data.

## Tasks

Read each from a card, in everyday words, not app words. Start every task
from the Home tab.

| # | Task card (say it like this) | Success | For |
| --- | --- | --- | --- |
| 1 | "Your mother was taken to the emergency room. The doctor asks her blood type and allergies. Show him." | Opens Teta Fatma's emergency card | All |
| 2 | "It's 9 in the morning. Teta took her pressure pill. Mark it." | Marks Concor taken for today | 1, 2 |
| 3 | "Youssef's doctor wrote this prescription (hand the paper). Put it in the app so you get reminders." | Saves a prescription for Youssef with at least one medicine and the photo | 2, 3, 5 |
| 4 | "Youssef got his 18-month vaccine yesterday at the health office. Record it." | Marks a due 18-month dose given, with yesterday's date | 3, 5 |
| 5 | "Youssef has a fever. You just measured 38.6 under the arm and gave him Cetal. Write it down. When can he have the next dose?" | Adds the reading and the medicine; reads the next-dose time | 3, 5 |
| 6 | "How many weeks pregnant is Mona, and when is her next check?" | Says 22 weeks; finds the next check | 4 |
| 7 | "Which of Mona's blood results were out of range?" | Says hemoglobin was low | 4 |
| 8 | "How much did the family spend on doctors this month?" | Reads the month's total | 2, 4 |
| 9 | "Make the app easier to read for Teta." | Turns on Simple Mode (or larger text) | 1, 2 |
| 10 | Free: "Show me something you'd use this app for." | (none: observe) | All |

## What to watch

- **Finding things:** where they look first (tab, Home, a person); wrong tabs
  opened; scrolling past the target.
- **Reading:** words they read aloud wrongly or ask about ("يعني إيه
  متابعة؟"); English words in Arabic text; numbers and units read in the
  wrong order.
- **Tapping:** missed taps, taps on things that aren't buttons, double taps,
  fingers covering the text, needing two hands.
- **Trust and fear:** hesitation before Save or Delete, worry about losing
  data or "breaking" it, reactions to colours (red/amber), to Dr. Usra, to
  the lock.
- **Elders:** text they lean in to read, glasses, whether the four big Home
  buttons are enough, whether they find the way back.
- **Tired parents:** one-handed use, how long a fever entry takes, whether
  they'd do this at night.

## Observation sheet (one per session)

Session # ___ · Date ___ · Phone: Android / iPhone, model ___ · Text size ___
· Language: AR / EN · Simple Mode: on / off · Facilitator ___ · Notes ___

| Task | Done? (yes / with help / no) | Time (min:s) | Wrong turns (where) | Words that confused | Quote | Severity (1 cosmetic … 4 blocks the task) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 Emergency card | | | | | | |
| 2 Dose taken | | | | | | |
| 3 Prescription | | | | | | |
| 4 Vaccine | | | | | | |
| 5 Fever | | | | | | |
| 6 Pregnancy | | | | | | |
| 7 Lab results | | | | | | |
| 8 Spending | | | | | | |
| 9 Easier to read | | | | | | |
| 10 Free | | | | | | |

**Wrap-up questions** (write the answers word for word):

1. What was the hardest part? 2. Was anything said in a way you wouldn't
say it? 3. Would you keep your family's records in this? Why or why not?
4. On a scale of 1 to 5, how easy was it overall? (Single Ease Question,
per task if time allows.)

## After the five sessions

Within a week: put every problem seen by two or more people on the board
(Area: App or Design & docs), ranked by severity × number of people; compare
with the UX audit's findings; fix the severity 3–4 ones; run five more
sessions on the fixes.

---

# خطة اختبار الاستخدام: خمس جلسات مع عائلات

٥ نوفمبر ٢٠٢٦ · بعد مراجعة تجربة الاستخدام (UX audit)

## ليه

المراجعة لقت مشاكل بالنظر. العائلات الحقيقية بس هي اللي هتورّينا أنهي مشاكل
مهمة فعلاً: تيتة هتلاقي دواها؟ أب أو أم تعبانين هيعرفوا يسجلوا السخونية الساعة
٣ الفجر؟ الكلام المصري واضح وطبيعي؟ خمس جلسات بتكشف أغلب المشاكل الكبيرة؛
نصلّحها ونختبر تاني.

## مين

خمس جلسات، كل جلسة مع فرد واحد من البيت (ممكن حد تاني يتفرج ويساعد زي ما بيحصل
في البيت):

| # | الشخص | ليه |
| --- | --- | --- |
| ١ | جد أو جدة فوق ٦٥، بيستخدم واتساب وبس تقريباً؛ الوضع البسيط | الكبار أصعب اختبار لحجم الخط والكلام وحجم الزراير |
| ٢ | ابن أو بنت بيتابع أدوية أبوه أو أمه | مهام الرعاية لشخصين |
| ٣ | أم لطفل أقل من سنة | التطعيمات، سجل البيبي، النمو؛ غالباً إيد واحدة فاضية |
| ٤ | ست حامل (أو جوزها) | متابعة الحمل، التحاليل |
| ٥ | أب أو أم لطفل صغير من برّه القاهرة، بموبايل أندرويد قديم | شاشة صغيرة، موبايل أبطأ، لهجة مختلفة |

جلستين على الأقل أندرويد واتنين آيفون، وواحد على الأقل بيقرا إنجليزي أحسن من
عربي. ومن غير أي حد من عائلات الفريق.

## التجهيز

- موبايل اختبار عليه أسرة من نسخة تجريبية فيها العيلة التجريبية
  (`flutter run --dart-define=USRA_DEMO=true`). أبداً مش موبايل الشخص ولا
  بياناته: مفيش أي بيانات صحية حقيقية بتتجمع.
- حجم الخط واللغة زي ما الشخص بيستخدمهم في البيت (اسأل وظبطهم قبل البداية).
- تسجيل شاشة موبايل الاختبار؛ صوت الجلسة بس، من غير وشوش، وبموافقة (تحت).
- ٤٥ دقيقة: ٥ موافقة، ٥ تعارف، ٢٥ مهام، ١٠ ختام.
- اتنين من الفريق: واحد بيدير الجلسة (بيتكلم) وواحد بيكتب الملاحظات (ساكت،
  بيملا ورقة الملاحظة).
- روشتة مطبوعة (متألفة، بخط دكتور)، للمهمة ٣.

## الموافقة (تتقري بصوت عالي وبعدين توقيع)

> إحنا بنجرّب التطبيق، مش بنجرّبك إنت. مفيش حاجة تعملها غلط: لو حاجة صعبة،
> يبقى العيب في التطبيق، وده بالظبط اللي محتاجين نعرفه.
>
> الموبايل فيه عيلة متألفة. من فضلك ماتكتبش أي حاجة حقيقية عنك أو عن عيلتك.
>
> بإذنك هنسجل شاشة الموبايل والصوت في الأوضة، مش وشك. فريق أسرة بس هو اللي
> هيسمعه عشان ياخد ملاحظات، وهنمسحه خلال ٣٠ يوم. بنكتب عن اللي الناس عملوه،
> أبداً مش أساميهم.
>
> تقدر توقف في أي لحظة، أو تسيب أي مهمة، أو تطلب نمسح التسجيل، من غير ما
> تقول السبب. وهتاخد [الهدية] في كل الأحوال.

مربعات، كل واحد لوحده: ☐ موافق أشارك ☐ موافق على تسجيل الشاشة والصوت ☐ الفريق
يقدر ينقل كلامي من غير اسمي.

للجد أو الجدة، فرد العيلة الموجود يقدر يقرا معاهم؛ بس الموافقة من الشخص نفسه.

## قواعد اللي بيدير الجلسة

- قول المهمة، اديله الموبايل، واسكت. اسأل "بتدور على إيه؟" أو "متوقع يحصل
  إيه؟"، أبداً مش "جرب الزرار اللي فوق".
- اطلب منه يفكر بصوت عالي: "قول اللي في دماغك، حتى لو 'مش عارف'".
- ساعد بس بعد ٣ دقايق واقف أو لو طلب مرتين؛ واكتبها "بمساعدة".
- ماتشرحش التطبيق قبل المهام: أول نظرة هي المعلومة.

## المهام

تتقري من كارت، بكلام عادي مش كلام التطبيق. كل مهمة تبدأ من الرئيسية.

| # | كارت المهمة (قولها كده) | تعتبر نجحت لو | لمين |
| --- | --- | --- | --- |
| ١ | "مامتك راحت الطوارئ. الدكتور بيسأل فصيلة دمها وعندها حساسية من إيه. ورّيه." | فتح بطاقة الطوارئ بتاعة تيتة فاطمة | الكل |
| ٢ | "الساعة ٩ الصبح. تيتة خدت حباية الضغط. علّم عليها." | علّم إن Concor اتاخد النهارده | ١، ٢ |
| ٣ | "دكتور يوسف كتب الروشتة دي (ادّيله الورقة). حطها في التطبيق عشان يفكّرك." | حفظ روشتة ليوسف فيها دوا واحد على الأقل وصورتها | ٢، ٣، ٥ |
| ٤ | "يوسف خد تطعيم الـ١٨ شهر امبارح في مكتب الصحة. سجّله." | علّم جرعة ١٨ شهر إنها اتاخدت بتاريخ امبارح | ٣، ٥ |
| ٥ | "يوسف سخن. لسه قايسها ٣٨٫٦ تحت الباط وادّيته سيتال. اكتب ده. الجرعة الجاية إمتى؟" | سجّل القراءة والدوا؛ قرا ميعاد الجرعة الجاية | ٣، ٥ |
| ٦ | "منى حامل في الأسبوع الكام، والمتابعة الجاية إمتى؟" | قال ٢٢ أسبوع؛ لقى المتابعة الجاية | ٤ |
| ٧ | "أنهي تحاليل منى كانت برّه الطبيعي؟" | قال الهيموجلوبين واطي | ٤ |
| ٨ | "العيلة صرفت كام على الدكاترة الشهر ده؟" | قرا مجموع الشهر | ٢، ٤ |
| ٩ | "خلّي التطبيق أسهل في القراية لتيتة." | شغّل الوضع البسيط (أو كبّر الخط) | ١، ٢ |
| ١٠ | حر: "ورّيني حاجة ممكن تستخدم التطبيق فيها." | (مفيش: اتفرج بس) | الكل |

## تتفرج على إيه

- **الوصول للحاجة:** بيدور فين الأول (تاب، الرئيسية، شخص)؛ تابات غلط اتفتحت؛
  عدّى على الحاجة وهو بيسكرول.
- **القراية:** كلام قراه غلط أو سأل عليه ("يعني إيه متابعة؟")؛ كلام إنجليزي
  وسط العربي؛ أرقام ووحدات اتقرت بالعكس.
- **اللمس:** لمسات ماجاتش، لمس حاجات مش زراير، لمستين، صوابع مغطية الكلام،
  محتاج إيدين.
- **الثقة والخوف:** تردد قبل حفظ أو مسح، خوف إن البيانات تضيع أو "يبوّظ"
  حاجة، رد فعله على الألوان (أحمر/برتقاني)، على دكتور أسرة، على القفل.
- **الكبار:** كلام بيقرّب عشان يقراه، النضارة، الأربع زراير الكبار في الرئيسية
  كفاية ولا لأ، بيعرف يرجع ولا لأ.
- **الأهالي التعبانين:** استخدام بإيد واحدة، تسجيل السخونية بياخد قد إيه،
  هيعمل كده بالليل ولا لأ.

## ورقة الملاحظة (واحدة لكل جلسة)

جلسة رقم ___ · التاريخ ___ · الموبايل: أندرويد / آيفون، موديل ___ · حجم الخط ___
· اللغة: عربي / إنجليزي · الوضع البسيط: شغال / مقفول · اللي أدار ___ · ملاحظات ___

| المهمة | خلصت؟ (أيوه / بمساعدة / لأ) | الوقت (دقيقة:ثانية) | لفّ فين | كلام لخبطه | جملة قالها | الخطورة (١ شكلي … ٤ وقف المهمة) |
| --- | --- | --- | --- | --- | --- | --- |
| ١ بطاقة الطوارئ | | | | | | |
| ٢ جرعة اتاخدت | | | | | | |
| ٣ روشتة | | | | | | |
| ٤ تطعيم | | | | | | |
| ٥ سخونية | | | | | | |
| ٦ الحمل | | | | | | |
| ٧ التحاليل | | | | | | |
| ٨ المصاريف | | | | | | |
| ٩ أسهل في القراية | | | | | | |
| ١٠ حر | | | | | | |

**أسئلة الختام** (اكتب الإجابة زي ما اتقالت):

١. إيه أصعب حاجة؟ ٢. فيه كلام اتقال بطريقة إنت ماتقولهاش؟ ٣. تحط سجلات عيلتك
في ده؟ ليه آه أو ليه لأ؟ ٤. من ١ لـ٥، كان سهل قد إيه؟ (لكل مهمة لو فيه وقت.)

## بعد الخمس جلسات

خلال أسبوع: كل مشكلة شافها اتنين أو أكتر تتحط على البورد (App أو Design &
docs)، مترتبة بالخطورة × عدد الناس؛ نقارنها بنتايج المراجعة؛ نصلّح اللي
خطورتها ٣–٤؛ ونعمل خمس جلسات تانية على التصليحات.
