# Development milestones

> Draft. Not reviewed by a doctor. A paediatrician must sign off before this is relied on.

Code: `app/lib/features/children/milestones.dart`, `development_screen.dart`, ARB keys `dev*` and `m{age}_{area}`.

## Sources

| Source | What it gives | Status |
|---|---|---|
| CDC "Learn the Signs. Act Early." milestone checklists, 2022 revision | Milestones by well-child age, 2 months to 5 years, four areas | Page checked 2026-11-12 (last reviewed 17 Feb 2026) |
| Zubler JM et al., Pediatrics 2022;149(3):e2021052138 | Why the 2022 checklists use milestones 75% or more of children reach by that age (earlier lists used 50%) | Abstract checked 2026-11-12 via search; full text not opened |
| WHO Motor Development Study, Acta Paediatrica 2006 Suppl 450:86-95 | Windows of achievement (1st to 99th percentile) for six gross-motor milestones, e.g. walking alone about 8.2-17.6 months | Abstract checked 2026-11-12 via search; full text not opened |

The app uses the CDC 2022 list. Because CDC chose milestones that 75% or more of children reach, a child who hasn't reached one is in the slowest quarter or less. That is a reason to talk to the doctor, not a diagnosis.

## How to word "check with the doctor"

CDC's own advice (checked 2026-11-12): if a child misses a milestone, loses a skill, or the parent is worried, talk to the child's doctor, share the concern and ask about developmental screening, and don't wait.

The app's current text follows this and should stay close to it:

- Banner: "Some milestones for {age} aren't ticked yet. Talk to your pediatrician about them; there's no need to wait."
- Per item: "Talk to your pediatrician" (not "late", "delayed" or "behind").
- Not yet due: "Later". Due now: "Watch for it".

Rules:

1. **Never** say "delayed", "behind", "abnormal", "autism", or name any condition. Never say "your child is on track" either: say "{done} of {total} ticked".
2. **Always add the loss-of-skill line** wherever milestones appear: "If your child stops doing something they used to do, talk to the doctor soon." **Not in the app yet.** CDC lists it; the text needs the paediatrician.
3. **A parent's worry is enough.** Offer "I'm worried about something" as a reason to talk to the doctor, even with everything ticked.
4. **Preterm babies:** until corrected age is built (hazard H-N1), say the checklist uses the birth date and ask the doctor about a baby born early.
5. Ticking is the parent's record of what they saw. Don't score it, don't add a percentage, don't compare areas.

## WHO motor windows

Not used in the app. If added, show the window ("most children walk alone between about 8 and 18 months"), never a single "should by" age, and only with the paediatrician's approval of the text.
