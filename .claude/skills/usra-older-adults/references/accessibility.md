# Accessibility and cognitive load

> Draft. A geriatrician or GP should confirm the cognitive-load rules; the figures come from WCAG and the PRD.

## Numbers to build to

| What | Usra target | Source |
|---|---|---|
| Body text | 16 px, Simple Mode 20 px, both scaling with the phone's font size | PRD design requirements |
| Simple Mode now | 1.3x the phone's text size, 64 dp buttons and rows | `app/lib/core/design/theme.dart` |
| Text resize | Works up to 200% with nothing cut off | WCAG 2.2 SC 1.4.4 (AA) |
| Text contrast | At least 4.5:1, 3:1 for large text; aim for 7:1 in Simple Mode (WCAG 1.4.6, AAA) | WCAG 2.2 SC 1.4.3 (AA) |
| Tap targets | 48 dp, 56 dp in Simple Mode (PRD); WCAG's minimum is 24x24 CSS px (2.5.8, AA) and enhanced 44x44 (2.5.5, AAA) | PRD, WCAG 2.2 |
| Gestures | No swipe-only, drag-only or long-press-only actions | PRD; WCAG 2.2 SC 2.5.7 Dragging Movements |
| Colour | Never the only signal: severity always has an icon and words | PRD; WCAG 1.4.1 |
| Sign-in and PIN | No step that needs remembering or transcribing a code without an alternative (biometrics, paste) | WCAG 2.2 SC 3.3.8 Accessible Authentication |
| Repeat entry | Don't make people retype what they already gave | WCAG 2.2 SC 3.3.7 Redundant Entry |

WCAG 2.2 is a W3C Recommendation (12 Dec 2024), checked 2026-11-12. It is written for web content; we apply it to the app as good practice.

## Fewer steps, nothing from memory

1. **One main action per screen** (PRD). In Simple Mode, the next dose and its Taken button are on the first screen.
2. **Show, don't ask to recall:** the medicine's name, strength, photo of the box if taken, and for whom, on the reminder and the Taken screen.
3. **No time limits** on any screen or confirmation.
4. **Undo over "Are you sure?"** for reversible actions (Taken, Snooze). Keep a confirmation, naming what happens, for irreversible ones (delete, start fresh, move a record to another person, risk M6).
5. **Same place, same words:** buttons don't move between screens; one term per thing ("medicine", not also "drug" and "tablet").
6. **Plain words:** no abbreviations (BP, mg/dL) without the word next to them in Simple Mode ("Blood pressure", "sugar").
7. **Errors say what to do:** "This number looks too high. Check it and type it again", not "Invalid input".
8. **Screen reader:** every control has an Arabic and English label; test VoiceOver and TalkBack on a real phone (risk T5, not done yet).
9. **Leaving Simple Mode** takes a deliberate step (and the PIN, if one is set), so it isn't left by accident.

## Questions about cognition for the geriatrician

See `checklist-and-questions.md`. In short: should Simple Mode hide anything with a medical judgement (readings, labels), and should it keep an emergency button (open PRD question)?
