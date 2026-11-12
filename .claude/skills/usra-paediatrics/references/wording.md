# Wording for children's features

> Draft. Not reviewed by a doctor. A paediatrician, and the Arabic reader for the Arabic, must sign off before this is relied on.

## Neutral, sourced, never reassuring

| Don't write | Write | Why |
|---|---|---|
| "Normal", "fine", "healthy", "طبيعي", "سليم", "كويس" | "Within the WHO reference range for this age (percentile 40)" / "جوه المعدل المرجعي للسن ده" | A reference range describes a population, not this child (risk M3) |
| "Your child is fully vaccinated" | "18 of 18 required doses recorded" | The app only knows what was typed |
| "Delayed", "behind", "late" (development) | "Talk to your pediatrician" | CDC: act early, don't label |
| "No need to see a doctor" | Nothing. End with the standard closing line | No false reassurance |
| "Give paracetamol" or any medicine | Nothing | Apple 1.4.2, PRD |
| "Underweight", "obese", "stunted" | "Outside the usual range. Talk to your pediatrician." | These are diagnoses |
| "Overdue" for a catch-up dose | "Catch-up · due {date}" | Only the first missing dose is overdue |

Every medical card ends with the source name and date, and, where it applies: "For information only, not a diagnosis. If you're worried, contact a doctor or call 123."

## Arabic that follows the child's sex

The founder decided (7 Nov 2026) that text addressed to the user follows the sex in "About you", and text about a family member follows that member's sex (PRD F22).

1. **Every string that refers to the child takes a `sex` select in the ARB:** `{sex, select, female{…} other{…}}`. Pass the profile's sex, never the user's, when the text is about the child.
2. **Check every word that changes:** adjectives (نعسان / نعسانة, تعبان / تعبانة), pronoun endings (سنه / سنها, حرارته / حرارتها, عينه / عينها, بيتنفس / بتتنفس), verbs (بيرضع / بترضع, بيرجّع / بترجّع), and possessives (ابنك / بنتك).
3. **Text addressed to the parent** uses the parent's sex from "About you" (اتأكد / اتأكدي, راجع / راجعي).
4. **A sentence with both** (about the child, to the parent) takes both selects. Test all four combinations.
5. **When sex is unknown,** use a neutral construction (الطفل, السن) rather than defaulting to masculine. Sex is required in Usra, so this should only happen in old records.
6. **Feminine nouns agree too:** جرعة (dose) takes اتاخدت / متأخرة / ميعادها; روشتة takes متوقفة (PR #69).
7. **Digits:** Arabic-Indic in Arabic text, units left-to-right inside Arabic lines.

**Known bug (hazard H-B3):** `warnSign` in `app/lib/l10n/app_ar.arb` is masculine only, so a girl or a woman sees "نعسان جدًا", "سنه أقل من ٣ شهور", "حرارته". The fix needs a `sex` select on every sign, a widget test for a girl and a boy, and the paediatrician's and the Arabic reader's approval, because it changes medical text.

## Tests every child-facing string needs

- A widget test with a girl and with a boy, asserting the Arabic text for each.
- A test that no string in the feature contains the banned words above (Arabic and English).
- A test that the source line is on screen.
