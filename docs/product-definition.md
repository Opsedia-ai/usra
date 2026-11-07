# Usra — Product Definition

Nov 6, 2026 · @Aya Nasser · Updated Nov 7, 2026 with the founder's decisions (see the [PRD](prd-v1.md))

## Vision

Usra (أسرة) is the family's health file: one calm Arabic-first app on the phone that keeps every family member's records, medicines, vaccines and insurance cards, and reminds the family what to do next.

**Positioning line:** For families in Egypt who keep health papers in a drawer and doctors' instructions in their heads, Usra is a private family health file on the phone. Unlike WhatsApp chats and the photo gallery, it keeps everything per person, reminds you on time, and never sends your health data to a server.

**Taglines:** ملف صحة العيلة (Egypt) · ملف صحة الأسرة (Gulf) · The family's health file.

## Problem

Egyptian families pay for most of their health care themselves and keep its record on paper, spread across private clinics. In 2023, 57.2% of Egypt's health spending was out of pocket (World Bank, cited in the MENA research).

- **Records get lost.** Prescriptions, scans and vaccination cards are paper; no clinic shares a file with another.
- **Nobody remembers what the doctor said.** Follow-ups, refills and doses depend on one person's memory.
- **Care is shared.** Adult children manage parents' pills and visits; two parents share the children's vaccines.
- **Several insurance cards per person.** Syndicate (نقابة), employer and private cover sit side by side.
- **Spending is invisible.** Families can't say what health cost them this month or year.
- **Most apps don't fit.** They are English-first, need an account, or send health data to a server.

## Target users

Usra v1 is designed for the whole family equally: the Home screen shows the family, and each person's file adapts to their age and sex.

| Persona | Who | Main jobs in Usra | Mode it unlocks |
| --- | --- | --- | --- |
| Family organiser | Parent, 28–45, runs the family's health on one phone | Add everyone, log visits, keep insurance cards, see spending | Full app |
| Parent of a young child | Mother or father of a child under 5 | Vaccines, growth, fevers, children's medicines | Infant Mode (under 2, extended to 5) |
| Pregnant woman | Adult woman with an active pregnancy | Due date, weekly checks, scans, danger signs | Pregnancy Mode (female profiles only) |
| Caregiver | Adult child caring for a parent | Parent's pills, refills, specialists, missed-dose alerts | Caregiver alerts (v2 sync) |
| Elder | Grandparent, 65+, often Arabic-only | Today's pills, "I took it", call the caregiver | Simple Mode |

Every profile records sex (male or female), for adults and children alike. It decides:

- WHO growth standards and percentiles, which are separate tables for boys and girls
- Pregnancy Mode, offered only on female profiles
- Age- and sex-based screening follow-ups (for example women's screenings)
- Egyptian Arabic wording about that person (خدته / خدتها, بابا / ماما); text addressed to the user follows the sex given in "About you"
- The default avatar

## Value proposition and alternatives

Usra wins by covering the whole family, ringing on time and keeping data private, where every alternative does only one of these.

| Alternative | What families use it for | Where it falls short | Usra's answer |
| --- | --- | --- | --- |
| Paper folder, drawer | Prescriptions, scans, vaccine cards | Lost, unsearchable, not with you at the clinic | Photo of every paper, per person, searchable |
| WhatsApp chats and gallery | Photos sent to self or family | Mixed with everything else; no reminders | Records sorted by person and type, reminders that ring |
| Jojo (child health records) | Children's vaccines, medicines, labs | Children only, iOS only, iCloud backup | Whole family incl. grandparents and pregnancy; Android + iOS; encrypted backup |
| Sehhaty (KSA) | Government records, vaccines, appointments | Public sector only; KSA only | Complements it: private visits, costs, insurance cards |
| Pill-reminder apps | Medicine alarms | No records, no family, English-first | Reminders tied to the person's file and caregiver alerts |

**Promise in one line:** صحة العيلة كلها في مكان واحد، على موبايلك إنت. The whole family's health in one place, on your own phone.

## Product principles

1. **Phone first, private by default.** Health data stays on the phone, encrypted. Nothing leaves without the user's tap.
2. **Calm and minimal.** One main action per screen, few elements, soft colour; the next thing to do comes first.
3. **Arabic first.** Egyptian Arabic, right-to-left, Arabic digits; English as the second language.
4. **Built for grandparents.** Large type, big targets, Simple Mode, nothing hidden behind a swipe or long-press.
5. **One model, many record types.** One event model and one reminder engine power every module.
6. **Cite, never diagnose.** Every suggestion names its source and ends with "ask your doctor".

## Brand

- **Name:** Usra (أسرة, "family"). On the launcher: أسرة on Arabic phones, Usra on English phones. Trademark and store-name checks still open.
- **Store name:** أسرة: ملف صحة العيلة · Usra: Family Health File.
- **Character:** Dr. Usra (دكتور أسرة), a house-shaped character with a heart, 5 poses. Guides the tour and empty states; never appears on emergency or warning screens.
- **Voice:** a kind, calm family friend who knows medicine but never plays doctor. Short sentences, Egyptian Arabic, no medical jargon, no alarm unless it is urgent.
- **Mood words:** calm, minimal.

## Visual identity

Usra uses the Twilight palette (navy and orchid) in light and dark mode, with Baloo Bhaijaan 2 for titles and IBM Plex Sans Arabic for everything people read closely. Mock-ups of both are on the Usra brand board.

### Colour tokens

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Primary | #26415E | #83A6CE | Buttons, links, selected tab |
| On primary | #FFFFFF | #0B1B32 | Text on buttons |
| Heading | #0D1E4C | #EAF0F7 | Titles, app bar |
| Background | #F7F4F8 | #0B1B32 | Screen background |
| Card | #FFFFFF | #0D1E4C | Cards, sheets |
| Accent | #C48CB3 | #C48CB3 | Highlights, the Add button, Dr. Usra's heart |
| Soft accent | #E5C9D7 | #26415E | Chip and tag backgrounds |
| Second highlight | #83A6CE | #83A6CE | Charts, secondary tags |
| Text | #0B1B32 | #EAF0F7 | Body text |

Contrast: white on primary 10.5:1, body text 15.8:1 (light) and 15.0:1 (dark). Orchid on the light background is 2.5:1, so it is used for fills and icons only, with navy text on top.

Severity colours stay separate from the brand: blue info · green good · yellow heads-up · orange act soon · red urgent.

**Typography:** two faces, both SIL Open Font License, Arabic and Latin, bundled in the app so they work offline.

- Titles, Dr. Usra and the tour: Baloo Bhaijaan 2 (Ek Type, variable 400–800). Rounded and warm.
- Body text, medicine names, doses, dates and numbers: IBM Plex Sans Arabic (7 weights, 100–700). Clear at small sizes.
- Body 16 px, Simple Mode 20 px; both follow the phone's font size.

**Person colours:** each profile shows a boy, girl, man or woman avatar, coloured by sex: soft blue #83A6CE for males, orchid #C48CB3 for females. The colour is never the only cue: the name and avatar always show too.

**Mood:** calm and minimal; generous white space, rounded corners, one accent per screen.

## Business model and markets

The first 5,000 signed-in users to save a record are founding members and use Usra free for life; after that, adding new records is paid (a 1-year pass or Lifetime), switched on automatically by a remote setting. When a trial or pass ends, people can still read, export, back up and delete their records and use the emergency card, and medicine reminders keep ringing.

| Phase | Revenue | Rule |
| --- | --- | --- |
| 1 · Founding members | None. Member numbers 1–5,000 free for life | One pool across all countries, counted by member number in Supabase; a seat is taken when a signed-in user saves their first record; sign-in optional and offered as "Save your free-for-life spot", once an Egyptian lawyer has answered; limit changeable without an app update |
| 2 · Subscription | 1-year pass (499 EGP, 99.99 SAR, 11 JOD) or Lifetime (1,249 EGP, 249.99 SAR, 37.99 JOD), each a single payment, after a 14-day free trial, from member number 5,001 | Store billing only, through RevenueCat (no card, Fawry or Paymob for unlocking the app); promo codes via Apple offer codes and Google Play promo codes |
| 3 · Dr. Usra AI | Included in the subscription or as credits (to decide) | Shown as "coming soon" in v1; behind regulatory gates (SFDA MDS-G27 in KSA, Egypt PDPL transfer licence) |
| 4 · Partners | Clinic partnerships: labelled sponsored listings, appointment reminders | Matched by city and specialty only, never by health data (Apple 5.1.3, Google Play user data policy) |

**Markets in order:** beta and first public launch in Egypt only; then Saudi Arabia (as a complement to Sehhaty) and Jordan; the user picks the country first, which sets the vaccine schedule, emergency number and currency. UAE later.

**Publisher:** Opsedia, as an organisation account (Apple 5.1.1(ix)).

**Never:** selling data, ads targeted with health data, health data in iCloud.

## What Usra is not

- **Not a medical device.** It does not diagnose, treat or calculate doses (Apple 1.4.2). It records what the doctor wrote.
- **Not a doctor.** Warning signs and follow-ups are cited information that end with "contact a doctor" or "call 123".
- **Not a cloud service in v1.** Optional sign-in with Google or Apple holds only name, email and membership; no server copy of health data, photos or backups.
- **Not an ad platform.** No ads SDKs, no tracking, no data sales.
- **Not a booking or telemedicine app.** Clinic booking comes only through partners in a later phase.
