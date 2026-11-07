# Usra (أسرة): family medical history app

Usra keeps one family's whole medical history in one place: visits, doctors, medicines, scans, labs, vaccinations, surgeries, insurance cards and spending. It sends reminders and suggests follow-ups, and it is built for elderly users and their caregivers, children and pregnancy. It is offline-first: records stay encrypted on the phone.

**Status:** building v1. Closed beta with 50 families on 31 December 2026. Product plan: [docs/prd-v1.md](docs/prd-v1.md) and [docs/product-definition.md](docs/product-definition.md).

## What is in this repo

```
docs/
  prd-v1.md                   What v1 is: scope, requirements, release plan, decisions
  product-definition.md       Vision, users, brand, colours, business model
  01-product-proposal.md      Original product proposal, kept as history (the PRD overrides it)
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

- **First market:** Egypt only for the beta and first public launch. Arabic-first. Saudi Arabia and Jordan follow once a local doctor has reviewed their schedules; UAE later.
- **Business model:** the first 5,000 signed-in users to save a record are founding members, free for life; after that a 1-year pass or Lifetime, through the stores. Clinic partnerships later.
- **Mobile:** Flutter, one codebase for Android and iOS.
- **Backend:** Supabase (Auth, Postgres, Edge Functions), on Pro from the moment real member numbers exist; until then nothing runs. Health data stays on the phone in v1; end-to-end encrypted sync later.
- **Design:** Twilight palette (navy and orchid), plus a 5-level severity scale (blue, green, yellow, orange, red).
- **Character:** Dr. Usra (دكتور أسرة).

See [docs/prd-v1.md](docs/prd-v1.md) for the current decisions and [docs/decisions.md](docs/decisions.md) for the full history.
