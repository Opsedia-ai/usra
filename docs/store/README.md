# Store listings

Launch texts for Usra v1 (M5). The beta and first public launch are in Egypt only, so Arabic (Egyptian colloquial) is the
primary listing; English is the second listing for both stores.

| File | What |
| --- | --- |
| [google-play.md](google-play.md) | Play Store listing, Arabic and English |
| [app-store.md](app-store.md) | App Store listing, Arabic and English |
| [screenshots.md](screenshots.md) | Screenshot order and captions (both stores) |
| [data-safety.md](data-safety.md) | Play Data safety, Apple privacy labels, health declarations |
| [../legal/](../legal/) | Privacy policy and terms (drafts, need legal review) |

## Character limits

Counted in characters as the consoles count them. Each text in the listing files
shows its count; `python3 tools/store/check_lengths.py` re-checks them all.

| Field | Google Play | App Store |
| --- | --- | --- |
| App name / title | 30 | 30 |
| Short description / subtitle | 80 (short description) | 30 (subtitle) |
| Promotional text | – | 170 (can change without a new build) |
| Full description | 4,000 | 4,000 |
| Keywords | – (Play has no field; it reads the description) | 100 bytes, comma separated, no spaces after commas |
| What's new | 500 (release notes, per language) | 4,000 |
| Screenshot captions | No field: captions are drawn into the image | No field: captions are drawn into the image |

Notes:

- Apple counts keywords in **bytes** in practice: an Arabic letter is 2 bytes in UTF-8,
  so the Arabic keyword line is kept under 100 bytes, not 100 letters.
- Neither store allows the app name to repeat in keywords; Apple already indexes the
  name, subtitle and company name, so those words are not in the keyword field.
- Play metadata policy: no "best / #1 / free" claims in the title, no emoji in the
  title, no keyword lists in the description, no testimonials. Apple 2.3.7: the name
  and subtitle must not be stuffed with keywords or prices.
- Health wording follows Apple 1.4.1 and Play's health misinformation policy: the
  texts describe record keeping and reminders, never diagnosis or treatment, and the
  descriptions end with the "not a medical device" line also shown in the app.

## Before submitting

- [ ] Final name after the trademark and store-name checks (`docs/decisions.md`, open questions).
- [ ] Support e-mail, website and the hosted privacy policy URL. Store builds must pass
      `--dart-define=USRA_RELEASE=true --dart-define=USRA_WEBSITE=https://<domain>`;
      with `USRA_RELEASE` and no `USRA_WEBSITE` the compile fails on purpose
      (`releaseWebsiteCheck` in `app/lib/features/settings/about_privacy_screen.dart`),
      so the placeholder `https://usra.example` can't ship. The app opens
      `<domain>/ar/privacy`, `/en/privacy`, `/ar/terms`, `/en/terms`.
- [ ] Saudi Arabia and Jordan listings, after a local doctor has reviewed their
      schedules: settle the dialect (still open in `docs/prd-v1.md`), then swap "العيلة"
      and the Egyptian phrasing to match, and replace "Egypt's vaccine schedule" and
      the 123 emergency number with that country's. UAE comes later.
