# Clinical risk management process

> Draft. A clinical safety reviewer must agree this process before it is relied on.

Usra isn't an NHS system, and DCB0129 doesn't apply to it legally. We copy its shape because it is a well-tried, published way for a health-software maker to manage clinical risk. Source: NHS Digital DCB0129, Clinical Risk Management: its Application in the Manufacture of Health IT Systems, specification v4.2 (Amd 24/2018) and implementation guidance v3.2 (2 May 2018); page last edited 21 Jul 2025; under review by NHS England. Checked 2026-11-12.

## Roles

| DCB0129 role | Usra | Status |
|---|---|---|
| Top Management | The founder: accepts residual risk, approves releases | In place |
| Clinical Safety Officer (CSO): a suitably qualified, experienced clinician with current professional registration, knowledgeable in risk management (DCB0129 spec v4.2) | **The clinical safety reviewer.** A registered doctor (or other registered clinician) named in `docs/clinical-safety/hazard-log.md` | **Not named.** The doctor who reviewed the wording on 7 Nov 2026 isn't recorded (risk M1) |
| Specialist reviewers | Paediatrician (children), obstetrician (pregnancy), geriatrician or GP (older adults) | Paediatrician and obstetrician planned in the PRD; geriatrician or GP not planned |
| Builders | Anyone writing code or text, including agents | Follow these skills |

## Documents

| DCB0129 document | Usra file | Rule (DCB0129 spec) |
|---|---|---|
| Clinical Risk Management Plan | This file plus `SKILL.md` | The CSO approves it |
| Hazard Log | `docs/clinical-safety/hazard-log.md` | The CSO approves each version; an issued hazard log goes with each safety case report |
| Clinical Safety Case Report | `docs/clinical-safety/safety-case-<version>.md`, written before each beta or store release | The CSO approves each one |
| Audit trail | Git history of these files and of `docs/medical-review-changes.md` | Keep every version |

## Scoring a hazard

DCB0129's implementation guidance gives example scales. Usra uses them as they are.

**Severity:** Minor (minor injury, upset or inconvenience, one person) · Significant (minor injury not quickly recovered, or significant psychological trauma, one person) · Considerable (severe injury with expected recovery, one person; or significant harm to several) · Major (death or permanent incapacity, one person; or severe injury to several) · Catastrophic (death or permanent incapacity, several people).

**Likelihood:** Very low (negligible) · Low (could occur, but in the great majority of occasions won't) · Medium (possible) · High (very possible, expected in most cases) · Very high (certain or almost certain).

Software faults can't be counted like hardware failures; use a "reasonably pessimistic" judgement.

**Risk** (1 acceptable, 5 unacceptable):

| Likelihood \ Severity | Minor | Significant | Considerable | Major | Catastrophic |
|---|---|---|---|---|---|
| Very high | 3 | 4 | 4 | 5 | 5 |
| High | 2 | 3 | 3 | 4 | 5 |
| Medium | 2 | 2 | 3 | 3 | 4 |
| Low | 1 | 2 | 2 | 3 | 4 |
| Very low | 1 | 1 | 2 | 2 | 3 |

- **5:** unacceptable. Don't release.
- **4:** the hazard must be removed or a control added.
- **3:** undesirable. Reduce it unless that's impractical; the CSO must accept it in writing.
- **2:** acceptable where further reduction costs more than it gains.
- **1:** acceptable.

Score before and after controls. The "after" score is the residual risk.

## Controls, best first

1. **Design it out:** don't build the risky thing (no dose calculator, no interaction checker, no "you're fine").
2. **Prevent in the app:** plausibility checks, confirmations naming the person, refusing impossible values.
3. **Tell the user:** warnings, sources, "ask your doctor". Weakest; never the only control for a score of 4 or 5.

Each control has a test or a document that proves it exists. Write its path in the hazard log.

## When to update the hazard log

- A new feature, screen or calculation with medical meaning.
- A bug found in medical behaviour (from a test, review, the founder's phone test or a family).
- A change to medical text, a threshold or a schedule.
- Before each release: re-score every open hazard, then the CSO signs.

New entries are "awaiting clinical review" until the CSO has scored them. Builders propose scores; the CSO decides.

## Sign-off before release

No beta or store build goes to families until:

1. The hazard log has no hazard at risk 4 or 5 without an accepted control.
2. Every risk-3 hazard is accepted in writing by the CSO.
3. A safety case report for that version lists the hazards, controls, residual risks and open items, and the CSO has signed it (name, registration, date).
4. The founder has accepted the residual risk.

The Dec 2026 closed beta needs this too: 50 families are real users.
