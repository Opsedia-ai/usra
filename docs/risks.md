# Usra risks

Last updated: 7 November 2026. Update this when a risk changes, closes or appears.

**Level** is a judgment of how much harm it could do if it happens and how close it is, not a measurement:

- **High:** could harm a family, lose their data, or block launch.
- **Medium:** could cause a store rejection, real rework or lost trust.
- **Low:** worth watching.

**Owner:** Founder means a decision or action only the founder can take. Build means work in the repo.

## Legal and privacy

| ID | Risk | What could happen | Level | Where it stands | Owner |
|---|---|---|---|---|---|
| L1 | The lawyer's answer isn't recorded | We treat login as cleared when the answer may have conditions. No real family may sign in until it's read | High | The founder has the answer; the text isn't in the repo | Founder |
| L2 | Server backups hold health data | Even encrypted, they may count as sensitive personal data and need a licence or cross-border permit | High | Planned only; blocked by `docs/server-backup-plan.md` | Founder, lawyer |
| L3 | VPS data centre location | The location may not be acceptable. Hostinger's plan page doesn't list locations | Medium | Check before buying | Founder |
| L4 | Deleted backups stay in Hostinger's weekly backups | A deleted account's file stays until those roll off, so the privacy policy could be untrue | Medium | Retention period unknown | Founder |
| L5 | Privacy promises stop being true | "Your family's health stays on this phone", the policy, terms and store forms must change when accounts and server backups ship | Medium | Listed in the plan and `docs/login-setup.md` | Build, lawyer |
| L6 | `accountPrivacy` text mentions future sync | The app promises something v1 doesn't do | Low | Open | Build |
| L7 | Account data list differs between PRD and privacy draft | The draft also lists language, device information, profile photo link and account ID | Low | Open in the PRD | Founder, lawyer |
| L8 | Saudi Arabia and Jordan need separate advice | Launching there relies on Egyptian advice that doesn't apply | Medium | Egypt first; both still disabled | Founder |
| L9 | Trademark and drug list licences | The "Usra" name or a drug list can't be used as planned | Medium | Searches and terms still open | Founder |

## Store review

| ID | Risk | What could happen | Level | Where it stands | Owner |
|---|---|---|---|---|---|
| S1 | Required sign-in (Apple 5.1.1(v)) | Apple may reject a login wall if it doesn't see significant account-based features | Medium | Decided. Review notes and a demo account are needed; fallback is optional sign-in until the paywall | Build |
| S2 | A code that unlocks paid features (Apple 3.1.1) | Treated like a licence key and rejected | Medium | The family copy's code must only open a file | Build |
| S3 | Health data reaches iCloud (Apple 5.1.3) | Widget snapshot with names could reach iCloud device backup | High | Done: no names in any mode, and older snapshots are refused and deleted | Build |
| S4 | Dose advice (Apple 1.4.2) | Dose calculators or checks cause rejection and harm | High | Not in v1. The Dr. Usra card must not promise them | Build |
| S5 | Sign in with Apple and account deletion | Rejected if Google is offered without Apple, or an account can't be deleted in the app | Medium | Planned; check with required sign-in | Build |
| S6 | Google Play's deletion web page doesn't exist | Play requires one for account deletion | Medium | Open in `docs/login-setup.md` | Build |
| S7 | Apple offer codes and one-time purchases | Offer codes may not cover them, and code redemption may need iOS 16.3 against the app's iOS 15.5 target | Medium | Open in the PRD | Build |
| S8 | Widget still holds a medicine ID when it shows Taken | No name, but the ID shows when the medicine was added and may reach device backup | Low | Removing it means dropping Taken or a token scheme; not decided | Founder |
| S9 | Old widget snapshot on iOS | One with names stays until the app next opens, if no widget is placed | Low | Known; goes on first open | Build |

## Data loss

| ID | Risk | What could happen | Level | Where it stands | Owner |
|---|---|---|---|---|---|
| D1 | Forgotten PIN with no backup | All records lost | High | The PIN now needs a backup first (merged). Not tested on a real phone | Build |
| D2 | Lost recovery key | Backups can't be opened, and we can't help | High | By design. The plan asks people to type part of the key before the first upload | Build |
| D3 | Damaged database | The family was stuck on an "unavailable" screen with no way to Restore | High | Decided: Restore, support address, warned start-fresh. Being built | Build |
| D4 | Start-fresh wipes records by mistake | Someone taps it when a retry or restore would have worked | Medium | Needs a clear warning naming what is lost | Build |
| D5 | Family with no backup loses a phone | Everything is gone | High | Server backup planned; folder backup available | Build |
| D6 | Near-empty backup replaces a good one | A later restore brings back almost nothing | Medium | Guard exists for folder backups; must also cover the server | Build |
| D7 | Records-only restore has missing photos | Restore fails or looks broken | Medium | Planned | Build |
| D8 | Records-only server backup misses photos | People assume photos are safe and lose them | Medium | The screen must say so | Build |
| D9 | The VPS is lost or fails | No server copy until it's back. Hostinger's backups are weekly | Medium | Phones hold the main copy; the screen shows the last upload date | Build |
| D10 | Damage deeper in the database file | The app opens but its data fails to load, and the Restore screen doesn't appear, because it only catches failure when the file opens | Medium | Founder's decision, 7 November: no check at every start, to keep starts fast. Accepted risk; look again if it shows up in the beta | Founder |
| D11 | Restore can save a new database key over an unreadable one | The one exception to the old rule, when someone chooses to replace everything. The key is saved only after the restored data opens | Medium | Merged; needs a real-phone test | Build |

## Medical safety

| ID | Risk | What could happen | Level | Where it stands | Owner |
|---|---|---|---|---|---|
| M1 | Medical wording changes after review, or a specialty is missed | Text added after the review goes out unchecked. The PRD asks for a paediatrician and an obstetrician | Medium | On 7 November the founder said the doctor accepted the app's full wording. Their name, specialty and review date still need recording. Text changed afterwards is listed in `docs/medical-review-changes.md` and goes back to them | Founder |
| M2 | Same-ingredient line and suggested hours between doses | Seen as dose advice, or wrong | High | Family types and accepts the hours. Needs review | Founder, doctor |
| M3 | False reassurance | A status such as "fine" could calm a family when someone is sick | High | Home and Fever rebuilt; doctor sets the wording | Doctor |
| M4 | Wrong person's dose or record | A dose is marked or a record saved under the wrong person | High | Person is shown in forms. Discreet Taken shows only when no other dose is due within an hour | Build |
| M5 | Discreet reminders without Taken | Clustered 8:00 doses get Snooze only, so a dose is more likely to be forgotten or marked late | Medium | Founder's choice, to watch in the beta | Founder |
| M6 | Moving a record goes wrong | Reminders or photos end up under the wrong person | High | Decided; being built with a confirmation naming both people | Build |
| M7 | Photo reading mistakes | A misread name or strength becomes a reminder. v1 reads printed Latin only | High | Person must confirm. PR 12 needs re-checking | Build |
| M8 | Emergency card out of reach | A responder can't reach Usra's own screen on a locked phone | Medium | People should also use the phone's Medical ID | Build |
| M9 | Ambulance number and schedules outside Egypt | A wrong number or schedule in an emergency | High | Saudi Arabia and Jordan disabled until wired | Build |
| M10 | Moving a prescribed medicine | It leaves the prescription's list, and moving back doesn't restore that link or sick-day links | Medium | In PR 43. Moving a whole prescription may be better; not decided | Founder |
| M11 | Pregnancy calling | The drawing's call-my-doctor button isn't built, because a pregnancy has no link to a doctor. The ambulance button stays | Medium | Question for the doctor | Doctor, Build |

## Not yet tested

| ID | Risk | What could happen | Level | Where it stands | Owner |
|---|---|---|---|---|---|
| T1 | Nothing has run on a real phone | Problems appear only on devices | High | The founder has test phones | Founder, Build |
| T2 | Notifications on devices | Reminders don't ring, especially on Android brands that kill alarms | High | Not tried | Build |
| T3 | Fresh install | First run fails for a new user. The simulator run didn't happen | High | Not run | Build |
| T4 | Real restore | A backup can't be restored on another phone when it matters | High | Not tried | Build |
| T5 | Phone calls and screen reader | Emergency calls or VoiceOver and TalkBack don't work | High | Not tried | Build |
| T6 | Google Drive backup | Automatic backup to Drive may not work, so it isn't promised | Medium | Needs an Android phone | Build |
| T7 | Photo reading on iOS simulator | ML Kit can't run there, so simulator checks stub it out | Medium | Needs a real iPhone | Build |
| T8 | Arabic wording unreviewed | Wrong or awkward text, including new backup and consent wording | Medium | The founder has a reader; review not done | Founder |

## Product and design

| ID | Risk | What could happen | Level | Where it stands | Owner |
|---|---|---|---|---|---|
| P1 | Front end isn't finished | Only the main screens match the accepted design, and the rest looks different | Medium | Build order agreed | Build |
| P2 | App behind the canvas | The canvas now has every screen in the accepted style, but most aren't built, so the two differ | Medium | Drawn on 7 November; being built in order | Build |
| P3 | Addressing the user by sex | Wrong grammar; about 224 Arabic strings flagged by a rough count | Medium | Decided; audit not done | Build |
| P4 | Required sign-in loses people | People leave at the first save, or have no internet at that moment | Medium | Must keep what they typed; signed-in phones work offline | Build |
| P5 | Family copy isn't live | The copy goes out of date, and doses don't show on the parent's phone until v2 sync | Medium | Proposal awaiting the founder | Founder |
| P6 | Family link with a server | Needs a family table and health data on a server, adding legal risk and cost | Medium | Not recommended for v1 | Founder |
| P7 | Hide My Email | A relay address becomes a separate account, which can split a seat | Low | Known | Build |
| P8 | Seat on deleted account | Unclear what happens to a seat when its account is deleted | Medium | Open in the PRD | Founder |
| P9 | Paywall with no internet | Unclear how checks behave, which could wrongly block adding records | Medium | Open in the PRD | Founder, Build |
| P10 | Dr. Usra card promises too much | Items imply medical advice, and most would send health data to an AI | Medium | Founder chose the list (13 Nov 2026); informational coming-soon page only, with its limits; wording with the doctor (`docs/medical-review-changes.md`); see "Dr. Usra AI (planned)" in `docs/decisions.md` | Founder |
| P11 | Simple Mode lock offer | It shows only after a backup, and Simple Mode never prompts for one, so most of these users won't see it | Medium | Known | Founder |
| P12 | Relationship wording after a restore | Words like "بنتك" depend on who uses the phone, so another relative may see the wrong one | Low | Known | Founder |
| P13 | Lock screen emergency number | People already chosen for the lock screen show a number added later without being asked again. The form says so | Medium | Lawyer to check, since it's a third person's number | Founder, lawyer |
| P14 | Insurance share mark is new and untested | A mark that's hard to read gives little protection, and Arabic drawn on an image hasn't been seen on a real phone. It holds the insurer and date, not who the card is for | Medium | Built in PR 55; needs a real-phone check and the lawyer's view | Build, lawyer |
| P15 | Drawings show things the app doesn't | Hospitals, typed follow-ups, spending export and comparison, Simple Mode box photo, member number and more have nothing behind them | Medium | Listed; to build or remove from the drawings | Founder, Build |

## Cost and running the server

| ID | Risk | What could happen | Level | Where it stands | Owner |
|---|---|---|---|---|---|
| C1 | Disk tight at 5,000 users | About 60 GB of 100 GB on an unmeasured 6 MB estimate | Medium | Measure first; keep only the latest backup if needed | Build |
| C2 | 50,000 users don't fit | About 300 GB even with the latest backup only, against 100 GB | Low | Bigger plan or separate storage then | Founder |
| C3 | VPS renewal price | $8.79 a month for 24 months, $210.96 upfront, then $14.99 | Low | Known | Founder |
| C4 | One person runs the server | Missed security updates, or an outage nobody notices | Medium | Plan covers updates, alerts and restore drills | Founder, Build |
| C5 | Server attacked or abused | Stolen files are encrypted but still exposed, and uploads could fill the disk | Medium | Per-account limits and token checks planned | Build |
| C6 | AI features cost money | Every call costs, so free and unlimited would break the budget | Medium | Off in v1; paid credits later | Founder |
| C7 | Supabase Pro at launch | $25 a month is needed once real member numbers exist | Low | Approved | Founder |

## Related documents

- `docs/decisions.md`: what was decided
- `docs/prd-v1.md`: "Still open"
- `docs/server-backup-plan.md`: gates for server backups
- `docs/login-setup.md`: the lawyer's questions and launch checklist
- `docs/security.md`: threats and how the app handles them
- `docs/clinical-safety/hazard-log.md`: the clinical view of the medical and data-loss risks, awaiting clinical review
