# Usra design

The live, clickable canvas is at https://claude.ai/artifact/44YSoLZ4WSvWkebQyb2cAi (press Play on any screen). `screens/` holds the source of every frame (`.dc.html`) and the canvas layout (`canvas.json`). They are design references, not app code.

## Colours

| Token | Hex | Use |
| --- | --- | --- |
| Primary (Nile blue) | `#1F5FA8` | Buttons, active tab, links, brand |
| Primary dark | `#174A85` | Pressed states, alarm screen |
| Primary tint | `#E6EEF8` | Icon tiles, selected chips |
| Background | `#F3F6FA` | Screen background |
| Surface | `#FFFFFF` | Cards |
| Text | `#14263D` | Main text |
| Muted text | `#55657A` | Secondary text |
| Warm sand | `#F6EEDF` | Warm accents (spending tile, Dr. Usra's face) |
| Lines | `#DDE5EF`, `#E8EDF4` | Borders, dividers |

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

IBM Plex Sans Arabic for Arabic and English. Body 15–16 px, Simple Mode 22–30 px. Touch targets at least 44 px (56–76 px in Simple Mode).

## Character: Dr. Usra (دكتور أسرة)

A Nile blue house-shaped character with a sand face, warm cheeks and a white heart. Poses: hello, reminding (holding a pill), celebrating, caring (needs attention), explaining. Never shown on emergency screens.

## Screens (31 frames, 5 pages)

1. **Everyday use:** Welcome, Family home, Member timeline, Family members and permissions, Scan prescription, Medicine and reminder, Medicine alarm, Create any reminder, Add record, Suggested follow-ups, Spending, Backup and privacy, Home-screen widget
2. **Doctors, insurance, records:** Doctors and hospitals, Doctor card, Clinic appointment reminder, Share summary with a doctor, Insurance wallet, Surgery record, Home medicine cabinet, Lab result trends
3. **Children and pregnancy:** Child growth, Vaccination schedule, Infant daily log and fever, Pregnancy
4. **Elder view and caregivers:** Elder Simple Mode (Arabic), Caregiver missed-dose alert, Emergency card, Tutorial for older users (Arabic)
5. **Character and tutorials:** Character and logo, Tutorial for everyone

Names, fees and dates in the screens are sample data. Insurer, clinic and hospital names are placeholders.
