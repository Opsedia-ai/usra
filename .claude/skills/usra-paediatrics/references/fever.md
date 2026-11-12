# Fever and warning signs

> Draft. Not reviewed by a doctor. A paediatrician must sign off before this is relied on.

The app's current list, thresholds, sources (NHS, AAP, WHO IMCI) and open questions are in `docs/research/fever-warning-signs.md` (2026-11-05). Code: `app/lib/features/sick_days/fever.dart`, `warning_signs_card.dart`, ARB key `warnSign`. This file adds the NICE view and the gaps it shows.

## NICE NG143, the traffic-light system

NICE NG143, "Fever in under 5s: assessment and initial management" (published 7 Nov 2019, last updated 26 Nov 2021, checked 2026-11-12). It is written for clinicians, not parents. Usra uses it to check that nothing high-risk is missing from the parent list, not to grade a child.

| NICE | What it means for Usra | In the app? |
|---|---|---|
| Under 3 months with 38 °C or more: high risk (1.2.12, red) | "Contact a doctor now" at least. Doctor question: should it be "call 123"? | Yes (`under3Months`) |
| 3 to 6 months with 39 °C or more: at least intermediate risk (1.2.13, amber) | "Contact a doctor now" | Yes (`months3to6`) |
| Fever for 5 days or more: assess for Kawasaki disease (1.2.14, amber) | "Contact a doctor now" | Yes (`fiveDays`) |
| Red: pale, mottled, ashen or blue skin, lips or tongue | Ambulance | Yes (`skinColour`) |
| Red: no response to social cues, doesn't wake or doesn't stay awake | Ambulance | Yes (`drowsy`) |
| Red: weak, high-pitched or continuous cry | Ambulance | **No.** `confused` covers "won't stop crying" only |
| Red: grunting, breathing more than 60 a minute, chest indrawing | Ambulance | Partly (`breathing`) |
| Red: non-blanching rash, neck stiffness, bulging fontanelle, fits, focal neurological signs | Ambulance | Rash, neck, fits yes. **Bulging fontanelle no** |
| Red: reduced skin turgor | Ambulance | Partly, under `dehydration` (a "doctor now" sign) |
| Amber: poor feeding in infants, reduced urine output, dry mouth | Doctor now | Yes (`notDrinking` is ambulance, `dehydration` doctor) |
| Amber: rigors | Doctor now | **No** |
| Amber: swelling of a limb or joint, not bearing weight or not using a limb | Doctor now | **No** |
| 1.1.6: a parent's sense that the child has a fever is valid and taken seriously | Never tell a parent the reading proves there's no fever | Yes, under-3-months note |

The missing items are hazard H-N2. Adding them changes medical text, so it waits for the paediatrician.

## Thermometer site

- NICE 1.1.1-1.1.3: don't routinely use oral or rectal readings in under-5s; electronic axillary under 4 weeks; axillary or infra-red tympanic from 4 weeks to 5 years. 1.1.5: forehead chemical thermometers are unreliable (for professionals).
- AAP (via `docs/research/fever-warning-signs.md`) recommends rectal readings for babies.
- The app accepts every site and uses 38 °C for all of them. **The two sources disagree. Ask the paediatrician** which site to suggest for each age in Egypt, and whether the fever label should depend on the site.

## Plausibility

Already built: readings outside 30-43 °C are refused; below 34 °C or above 42 °C ask "Is this right?". Fahrenheit is converted. Keep boundary tests at 29.9, 30, 33.9, 34, 37.9, 38, 41.9, 42, 43, 43.1 °C and the Fahrenheit equivalents.

## Rules for this feature

- Every sign is shown for the right age, with its source key, and the ones matched by what the family logged go to the top.
- The card always ends: "For information only, not a diagnosis. If you're worried, contact a doctor or call 123, even if nothing here matches."
- **No sign may ever say or imply "not serious".** A child without a matched sign gets the same closing line, nothing more.
- **Sign text follows the child's sex** (hazard H-B3: today every sign is masculine, so a girl or a woman sees "نعسان", "سنه", "حرارته"). See `wording.md`.
- Never mention medicine names, amounts or "give a fever reducer". The "hours after this dose" line uses only the family's own field (risk M2).
