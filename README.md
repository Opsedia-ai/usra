# Usra (أسرة): family medical history app

Usra keeps one family's whole medical history in one place: visits, doctors, medicines, scans, labs, vaccinations, surgeries, insurance cards and spending. It sends reminders and suggests follow-ups, and it is built for elderly users and their caregivers, children and pregnancy. It is offline-first: records stay encrypted on the phone.

**Status:** design phase. No app code yet. The next step is milestone M0 (foundations) from the technical design.

## What is in this repo

```
docs/
  01-product-proposal.md      Full product proposal (features, pricing model, roadmap)
  decisions.md                Every decision made so far, in one table
  pdf/
    01-product-proposal.pdf   Proposal with charts and diagrams
    02-mena-research.pdf      Sourced MENA market research (Egypt, KSA, UAE, Jordan, Morocco)
    03-feasibility-review.pdf Solo-founder feasibility, Egypt first, validation plan
    04-technical-design.pdf   Stack, Flutter vs React Native, architecture, OCR, AI Doctor
design/
  README.md                   Colours, severity scale, character, screen list
  screens/                    Source of all 31 designed screens (.dc.html) + canvas.json
```

## Live versions (private until shared)

| Document | Link |
| --- | --- |
| Product proposal (+ MENA research and feasibility tabs) | https://claude.ai/artifact/T7XjuU1SLXYcJ1NuiZXQBt |
| Technical design | https://claude.ai/artifact/AutTaVmfR2nrUHYLwvApho |
| App screens, character and tutorials (design canvas) | https://claude.ai/artifact/44YSoLZ4WSvWkebQyb2cAi |

The live documents are the most up to date. The files here are snapshots taken on 2 Nov 2026.

## Key decisions (short)

- **First market:** Egypt. Arabic-first, then KSA and UAE.
- **Business model:** free app. Revenue later from clinic partnerships and an optional AI Doctor (credits + "Usra Plus" subscription).
- **Mobile:** Flutter, one codebase for Android and iOS.
- **Backend:** Supabase (Auth, Postgres, Edge Functions). Health data stays on the phone in v1; end-to-end encrypted sync later.
- **Design:** Nile blue brand colour, plus a 5-level severity scale (blue, green, yellow, orange, red).
- **Character:** Dr. Usra (دكتور أسرة).

See [docs/decisions.md](docs/decisions.md) for the full list.
