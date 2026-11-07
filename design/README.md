# Usra design

The live, clickable canvas is at https://claude.ai/artifact/44YSoLZ4WSvWkebQyb2cAi (press Play on any screen). `screens/` holds the source of every frame (`.dc.html`) and the canvas layout (`canvas.json`). They are design references, not app code.

**The accepted design is `app-screens/enhanced-sample`, with `app-screens/merged-review.md` (founder, 7 Nov 2026).** The colours below are from `docs/product-definition.md`. The frames in `screens/` predate them and are kept as history. `app/lib/core/design/tokens.dart` holds the current colours in the app.

## Colours

Twilight palette (navy and orchid), light and dark.

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Primary | `#26415E` | `#83A6CE` | Buttons, links, selected state |
| On primary | `#FFFFFF` | `#0B1B32` | Text on buttons |
| Heading | `#0D1E4C` | `#EAF0F7` | Titles, app bar |
| Background | `#F7F4F8` | `#0B1B32` | Screen background |
| Card | `#FFFFFF` | `#0D1E4C` | Cards, sheets |
| Accent | `#C48CB3` | `#C48CB3` | Highlights, the large Add button, Dr. Usra's heart |
| Soft accent | `#E5C9D7` | `#26415E` | Chip and tag backgrounds |
| Second highlight | `#83A6CE` | `#83A6CE` | Charts, secondary tags |
| Text | `#0B1B32` | `#EAF0F7` | Body text |

## Severity scale

Always pair a colour with a word or icon (colour-blind and older users).

| Level | Meaning | Background | Text |
| --- | --- | --- | --- |
| Blue | Information, neutral | `#E6EEF8` | `#174A85` |
| Green | Good / done (taken, normal, on track) | `#E6F4EA` | `#1F6B3F` |
| Yellow | Heads-up (coming up, later today, low stock) | `#FFF6CC` | `#7A5B00` |
| Orange | Act soon (missed dose, overdue, out of range, expiring) | `#FFE8D6` | `#A14A00` |
| Red | Urgent (emergency, severe allergy, danger signs) | `#FDECEA` / solid `#C62828` | `#B42318` / white |

## Type

Baloo Bhaijaan 2 for titles, Dr. Usra and the tour; IBM Plex Sans Arabic for everything people read closely. Body 16 px, Simple Mode 20 px. Touch targets 48 dp, 56 dp in Simple Mode.

## Character: Dr. Usra (دكتور أسرة)

A house-shaped character with a heart; new artwork is being made to the Twilight palette. Poses: hello, reminding (holding a pill), celebrating, caring (needs attention), explaining. Never shown on emergency screens.

## Screens (31 frames, 5 pages)

1. **Everyday use:** Welcome, Family home, Member timeline, Family members and permissions, Scan prescription, Medicine and reminder, Medicine alarm, Create any reminder, Add record, Suggested follow-ups, Spending, Backup and privacy, Home-screen widget
2. **Doctors, insurance, records:** Doctors and hospitals, Doctor card, Clinic appointment reminder, Share summary with a doctor, Insurance wallet, Surgery record, Home medicine cabinet, Lab result trends
3. **Children and pregnancy:** Child growth, Vaccination schedule, Infant daily log and fever, Pregnancy
4. **Elder view and caregivers:** Elder Simple Mode (Arabic), Caregiver missed-dose alert, Emergency card, Tutorial for older users (Arabic)
5. **Character and tutorials:** Character and logo, Tutorial for everyone

Names, fees and dates in the screens are sample data. Insurer, clinic and hospital names are placeholders.
