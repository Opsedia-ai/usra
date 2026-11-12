# Sources for usra-paediatrics

Status:
- **Verified:** the primary page or document was opened on the date shown and says what the skill says.
- **Partly verified:** the citation and the key figure were confirmed, but only through an abstract or a search excerpt of the primary source.
- **From repo doc:** checked by an earlier session on the date shown; not re-opened here.
- **Unverified:** not confirmed against a primary source. Don't rely on it until the paediatrician confirms it.

| # | Source | Version or date | URL | Checked | Status | Used for |
|---|---|---|---|---|---|---|
| P1 | NICE NG143, Fever in under 5s: assessment and initial management | Published 7 Nov 2019, last updated 26 Nov 2021 | https://www.nice.org.uk/guidance/ng143/chapter/Recommendations | 2026-11-12 | Verified (recs 1.1.1-1.1.6, 1.2.12-1.2.14, table 2) | Traffic light, thermometer sites, age thresholds |
| P2 | WHO Child Growth Standards | 2006 (head circumference 2007) | https://www.who.int/tools/child-growth-standards | 2026-11-12 | Verified (page) | Tables 0-60 months |
| P3 | WHO `anthro` R package, "Computation of the WHO Child Growth Standards", reference manual | v1.1.0, CRAN 2026-01-29, maintained by WHO | https://cran.r-project.org/web/packages/anthro/anthro.pdf | 2026-11-12 | Verified | Implausibility flags, 0.7 cm length/height adjustment, 30.4375-day month |
| P4 | WHO Growth Reference 5-19 years | 2007 | https://www.who.int/tools/growth-reference-data-for-5to19-years | 2026-11-12 | Verified (page) | Growth after 5 |
| P5 | CDC Learn the Signs. Act Early. Milestones | Last reviewed 17 Feb 2026 | https://www.cdc.gov/act-early/milestones/index.html | 2026-11-12 | Verified (act early, screening at 9, 18, 30 months) | Milestones and doctor wording |
| P6 | Zubler JM et al., Evidence-Informed Milestones for Developmental Surveillance Tools, Pediatrics 2022;149(3):e2021052138 | 2022 | https://pubmed.ncbi.nlm.nih.gov/35132439/ | 2026-11-12 | Partly verified (abstract via search) | 75% threshold |
| P7 | WHO Multicentre Growth Reference Study Group, WHO Motor Development Study: windows of achievement for six gross motor development milestones, Acta Paediatr Suppl 2006;450:86-95 | 2006 | https://pubmed.ncbi.nlm.nih.gov/16817682/ and https://www.who.int/tools/child-growth-standards/standards/motor-development-milestones | 2026-11-12 | Partly verified (abstract via search) | Motor windows |
| P8 | Egypt immunisation schedule research | 2026-11-04 | `docs/research/egypt-vaccine-schedule.md` (sources 1-21 inside) | 2026-11-04 | From repo doc | Schedule, catch-up |
| P9 | Fever warning signs research (NHS, AAP, WHO IMCI and others) | 2026-11-05 | `docs/research/fever-warning-signs.md` | 2026-11-05 | From repo doc | Current warning list |
| P10 | WHO prevalence cut-offs (z -2, -3, +2) for stunting, wasting, overweight | not opened | https://www.who.int/tools/child-growth-standards | - | **Unverified** | Range wording question |
| P11 | Rotavirus and other product labels (Rotarix, RotaTeq, Nimenrix) | not opened | - | - | **Unverified** (as the research doc says) | Vaccine age limits |

Re-check any source over 12 months old, or when the publisher shows a newer version, before changing the related code or text.
