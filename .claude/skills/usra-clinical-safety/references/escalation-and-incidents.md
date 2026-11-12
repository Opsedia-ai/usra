# Red-flag escalation and incident handling

> Draft. A clinical safety reviewer must agree this before it is relied on.

## Escalation pattern

Two levels only, the same everywhere (fever, pregnancy, readings, falls):

| Level | Words | Button | Colour |
|---|---|---|---|
| Emergency | "Call an ambulance (123) now" | Calls the country's number from `docs/prd-v1.md` F16 (123 Egypt) | Urgent (red) with icon and words |
| Urgent | "Contact a doctor now" | Calls or WhatsApps the person's doctor if one is saved; otherwise shows how to add one, plus the 123 button | Act soon (orange) with icon and words |

Rules:

1. **The red flag comes first** on the screen, above any chart or history.
2. **Matched signs go to the top,** but unmatched signs stay visible. The family may see something the app couldn't log.
3. **Never reassure by absence.** When nothing matches, show the same closing line, never "nothing to worry about": "For information only, not a diagnosis. If you're worried, contact a doctor or call 123, even if nothing here matches."
4. **Never delay.** No "wait and measure again" before an emergency sign. Re-measuring is only for a single surprising number without symptoms, with the doctor's approved wording.
5. **Never lower a level** because of another reading. Two readings, one emergency: emergency.
6. **Never suggest a medicine** as the response to a red flag.
7. **Numbers work offline** and from the lock screen's emergency card. Test calls on a real phone (risk T5).
8. **Outside Egypt** the number and the schedules stay off until wired and reviewed (risk M9).
9. **The doctor sets the level** for every sign. Builders propose; the list in `docs/research/fever-warning-signs.md` shows the format.

## Incidents: a family reports a medical error

Examples: a wrong due date, a missing warning, a growth value labelled in range that isn't, a reminder that didn't ring, a dose recorded under the wrong person, wrong-sex wording on a warning.

1. **Reply the same day** from the support address (aya@opsedia.ai for now, `docs/decisions.md`). Thank them. If anyone may be unwell now, the first line is: "If you're worried about {name} now, please call 123 or your doctor." Don't give medical advice by email.
2. **Record it** in a private incident log (not the public repo; it holds personal data): date, reporter contact, what they saw, app version, phone, steps, whether harm happened or nearly happened. Ask for a screenshot only if they're happy to send one, and tell them not to send records they don't need to.
3. **Triage within one working day** with the clinical safety reviewer: which hazard (or a new one), severity, likelihood, how many users could be affected.
4. **Contain:** if the risk score is 4 or 5, stop the feature remotely if possible (remote config), or ship a fix forward as fast as the stores allow (fix forward, never roll back, per the PRD). Tell affected beta families what to check.
5. **Fix with a test** that reproduces the report first (as PR #66 did for bug A).
6. **Update the hazard log** (new hazard or new cause, controls, residual risk) and the safety case for the next release.
7. **Tell the reporter** what changed and thank them.
8. **Regulatory reporting:** Usra isn't registered as a device, so there's no vigilance duty today. If that changes, follow the regime's rules. If personal data leaked, the Egypt PDPL breach rules apply: ask the lawyer for the deadline (**unverified** here).
9. **Review monthly** with the clinical safety reviewer: open incidents, trends, hazards to re-score.

Public GitHub issues must never contain a family's health details. Write the issue in general terms and keep details in the private log.
