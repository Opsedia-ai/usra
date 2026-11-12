# Reading medicine names from prescription photos (روشتة)

> **Status: experiment, small sample, needs a pharmacist.** Run on
> 2026-11-13, approved by the founder the same day. No app code changed.
> The expected medicine names were read by the development team, not by a
> pharmacist, so every number below is provisional.

## The question

Today the app reads printed Latin text on medicine boxes with Google ML Kit
on the phone and matches it against the bundled list of medicines sold in
Egypt (`app/lib/core/ocr/`, `app/assets/medicines/egypt_medicine_names.txt`).
Prescription photos are saved but never read.

The idea tested: OCR reads whatever it can from a prescription photo, even
partial words. The app then shows the 2 or 3 closest real names from a
medicine list, and the parent taps one. The app never invents a name, never
reads doses or instructions from handwriting, and the parent always
confirms.

Two things decide whether that's worth building:

1. How often is the right medicine among the 2 or 3 names shown?
2. How often is a *different* real medicine shown, especially one that
   looks certain? That's the safety risk.

## Short answer

- **Printed or typed prescriptions:** the right name was among the
  suggestions for about 4 in 5 medicines (Apple Vision, 48 of 61).
- **Handwritten medicine names:** about 1 in 2 (34 of 67), falling to
  2 of 7 for handwriting a person could barely read. Tesseract found
  almost none (4 of 67).
- **Different medicines shown:** with a large medicine list, about half
  the photos (15 of 32) showed at least one suggestion that was a
  different medicine from the ones prescribed. Most came from text that
  isn't a prescription line at all: headers, addresses, website names,
  lab-test checklists.
- **The current bundled list is too small for this.** Only 15 of the 128
  prescribed names in the sample are in it. With that list, wrong
  suggestions are rare (3 of 32 photos), but so are right ones.

**Recommendation:** don't build a prescription reader yet. A "pick from
the closest names" helper is worth a second test, limited to the line the
parent points at, once the app has the full Egyptian register and the test
uses real Egyptian prescriptions and ML Kit on a phone. Details below.

## Method

### Test images (32)

| Source | Photos | Kind | Licence |
| --- | --- | --- | --- |
| Mendeley Data, "Image-to-Text Bilingual Dataset from Medical Prescriptions" v2, Bangladesh (doi:10.17632/tg2hm7n2bs.2) | 21, picked at random with a fixed seed | 12 handwritten, 7 mixed (printed form with handwritten names), 2 printed | CC BY 4.0 |
| Wikimedia Commons, "Medical prescriptions" category and search | 11 | 7 handwritten (Nigeria, Cuba, Spain), 4 printed (pharmacy labels, a German prescription, a Spanish one) | CC0, public domain, CC BY-SA |

Each photo's URL, licence and type is in `sources.csv` next to the images.
The images were kept outside the repo (the scratchpad of the session),
because some show doctors' names, and the dataset photos were only
partly blurred by their authors. Nothing from them is in this document
apart from medicine names.

**No Egyptian prescriptions were found** under an open licence. The
closest are Bangladeshi: Latin-script brand names, handwriting mixed with
another script (Bangla), and similar paper forms. This is the biggest gap
in the test.

For each photo the team wrote down the medicine names it could read
(`truth.csv`), each marked as printed or handwritten, and the photo as
clear, hard or unreadable. The dataset's own English captions helped with
the hardest ones. 128 prescribed names in all: 61 printed, 67 handwritten.
Some names nobody could read were left out, so a few "wrong" suggestions
below are probably right.

### OCR engines (run on a Mac, Apple M3 Pro)

| Engine | Version | Size | Arabic |
| --- | --- | --- | --- |
| Apple Vision `VNRecognizeTextRequest`, accurate level | macOS 27.2, revision 3 | Built into iOS and macOS, nothing to ship | Yes: `ar-SA` and `ars-SA` in accurate mode only (33 languages in all; fast mode has 6, no Arabic) |
| Tesseract | 5.5.4 (Homebrew) | 25 MB, `eng` model 4.1 MB, `ara` model 1.4 MB | Yes |
| PaddleOCR PP-OCRv5 mobile | paddleocr 3.7.0, paddlepaddle 3.3.1 | Models 4.8 MB (detection) + 7.7 MB (English recognition); Python install about 1 GB | Separate Arabic model, not tested |
| Google ML Kit text recognition | - | - | Not tested: runs only on a phone or emulator |

Apple Vision ran three ways: language correction off, on, and off with
English plus Arabic. Tesseract ran with `eng` and with `eng+ara`.

### Matching

A Python version of the idea in `medicine_name_extractor.dart`: every word
and pair of words on each OCR line, with the usual OCR slips fixed (0 for
o, 1 for l, rn for m), compared with every name on the list by edit
distance. Ordinary English words are never corrected into a medicine. Each
line shows at most its 3 closest names.

Two rules:

- **Strict**, the box scanner's rule: names under 5 letters must match
  exactly, 5 to 7 letters may differ by 1, longer names by 2.
- **Loose**, to test "partial words": up to 1, 2 or 3 differences by
  length, and 4-letter names may differ by 1.

Two lists:

- **Egypt list:** the 430 names bundled in the app today.
- **Large list (1,874 names):** the Egypt list, plus 1,434 brand names
  taken from the captions of all 1,000 Bangladeshi prescriptions, plus the
  expected names. It stands in for a full register: every right answer is
  on it, and so are many similar-looking names. The real Egyptian register
  is bigger, so it would have more look-alikes.

A suggestion counts as **right** if it's a prescribed name on that photo.
Suggestions that are a spelling variant of a prescribed name ("Renom" for
Renova) are wrong but harmless, so they're counted apart from suggestions
of a **different medicine**. A different medicine spelled exactly as
printed is the high-confidence case.

## Results

### By engine (large list, strict rule)

| Engine | Right name shown: all | Handwritten | Printed | Photos with a different medicine shown | Different medicine, exact spelling | Median time per photo |
| --- | --- | --- | --- | --- | --- | --- |
| Apple Vision, correction off | 82 of 128 (64%) | 34 of 67 (51%) | 48 of 61 (79%) | 15 of 32 | 6 | 0.11 s |
| Apple Vision, correction on | 83 of 128 (65%) | 35 of 67 (52%) | 48 of 61 (79%) | 16 of 32 | 6 | 0.15 s |
| Apple Vision, English + Arabic | 82 of 128 (64%) | 34 of 67 (51%) | 48 of 61 (79%) | 15 of 32 | 6 | 0.11 s |
| PaddleOCR PP-OCRv5 mobile | 79 of 128 (62%) | 30 of 67 (45%) | 49 of 61 (80%) | 15 of 32 | 5 | 5.1 s |
| Tesseract `eng` | 43 of 128 (34%) | 4 of 67 (6%) | 39 of 61 (64%) | 7 of 32 | 2 | 0.26 s |
| Tesseract `eng+ara` | 43 of 128 (34%) | 4 of 67 (6%) | 39 of 61 (64%) | 6 of 32 | 2 | 0.44 s |

Times are on the Mac, not a phone. Apple Vision's very first photo took
37 seconds while the system loaded its model, and one run with language
correction hung until restarted. PaddleOCR ran in Python on the CPU; a
phone build would use different code.

### Handwriting by how readable it is (Apple Vision, correction off, large list, strict)

| Handwriting | Right name shown |
| --- | --- |
| Clear | 17 of 30 |
| Hard | 15 of 30 |
| Unreadable | 2 of 7 |

Fewer than half of the right handwritten names (15 of 34) were read letter
for letter. The rest were near matches the parent would have to recognise.

### Strict against loose (Apple Vision, correction off, large list)

| Rule | Handwritten right | Photos with a different medicine shown | Different medicines per photo |
| --- | --- | --- | --- |
| Strict | 34 of 67 | 15 of 32 | 0.9 |
| Loose | 39 of 67 | 29 of 32 | 5.8 |

Reading partial words finds 5 more handwritten names but shows about six
times as many wrong ones. Not worth it.

### With the list the app has today (Apple Vision, correction off, strict)

Only 15 of the 128 prescribed names are in the bundled list, mostly
generic names (Omeprazole, Ceftriaxone, Metformin). The right name was
shown for 8 of those 15 (5 of 11 handwritten). Different medicines were
shown on 3 of 32 photos, never spelled exactly: Caltrate from a smudged
line, Nexium from the Bangladeshi brand "Exium", Lasix from "LASIK" in a
surgeon's title, Actos from the Spanish word "ACTO" on the form. With the
loose rule that rose to 14 of 32 photos.

### What the different-medicine suggestions came from

Looking at every one for Apple Vision on the large list:

- **Text that isn't a prescription line:** headers, form labels, the
  doctor's title, websites ("Com" from ".com", "Momelo" from "Modelo",
  "Lasix" from "LASIK"). This was most of them, and the reason to read
  only the line the parent points at.
- **A lab-test checklist:** "Calcium" was suggested, spelled exactly, from
  a ticked "S. Calcium" blood test on the side of the prescription. A
  parent could easily accept it.
- **A different brand of the same or another medicine:** "Nexium" for
  "Exium", "Caltrate" from a smudge.
- **Names the team couldn't read and left out of the expected list**
  ("Dekulin", "Megacuforte"): probably right, so the true error rate is
  a little lower than the table shows.

Arabic made no difference here because the sample has no Arabic
medicine names. Language correction made almost none.

## Recommendations

1. **Engine:** on iPhone, Apple Vision is clearly the best of those
   tested, free and already on the phone. Tesseract is not good enough for
   handwriting. PaddleOCR's mobile models come close to Vision but would
   add about 12 MB of models and a new native library, and weren't timed
   on a phone. ML Kit, which the app already uses on both platforms, is
   the one that matters for Android and wasn't tested: test it next with
   the same photos before choosing.
2. **Don't build automatic prescription reading.** Half the handwritten
   names were missed, and half the photos showed a different medicine
   somewhere. Reading the whole page and listing everything found would
   put wrong names in front of parents.
3. **A "pick from closest names" helper may be worth it, with limits,**
   but not yet:
   - Only after the bundled list is replaced by the Egyptian Drug
     Authority register. With today's 430 names it would rarely have the
     right answer.
   - The parent marks the one line to read (a crop or a tap), so headers,
     addresses and lab tests are never read.
   - Strict matching only, at most 3 names, none chosen in advance, always
     a "none of these, I'll type it" option, and every name shown as
     unsure, like the box scanner's "راجعها على العلبة".
   - Names only, never a strength or dose from handwriting.
   - Expect it to help most with printed and typed prescriptions and with
     clear handwriting. How common printed ones are in Egypt is a question
     for the doctor below.
4. **Before deciding,** repeat this test with 30 to 50 real Egyptian
   prescriptions (shared with consent, names covered), the EDA register,
   and ML Kit on a mid-range Android phone.

## Risks

- **Choosing a look-alike.** The parent may tap a name that looks right
  but is a different medicine (Nexium for Exium). The suggestion feels
  like the app's answer, which may make people check less than when they
  type the name themselves. This is the main reason for strict matching,
  a single marked line and no preselection.
- **Lab tests and other text read as medicines** ("Calcium").
- **A false sense that the app read the prescription.** The wording must
  say these are guesses to check against the box or with the pharmacist.
- **Coverage.** A name missing from the list can never be suggested, and
  a near look-alike that *is* on the list will be shown instead.

## Not tested

- **Real Egyptian prescriptions**, Egyptian brand names and Arabic
  handwriting. None were found under an open licence.
- **Google ML Kit**, and any timing on a real phone.
- PaddleOCR's Arabic model and its server (non-mobile) models.
- Photos taken by parents in the app (lighting, angle, folded paper), and
  marking a single line before reading.
- The real EDA register as the list.
- Whether parents actually pick the right name when shown 3, which only a
  test with people can answer.

## Questions for the doctor

1. In Egypt today, roughly what share of prescriptions are printed or
   typed rather than handwritten, in clinics and in hospitals?
2. Do doctors usually write the brand name or the generic name? Does that
   differ for children's medicines?
3. Is a parent picking a medicine name from 3 suggestions safer or less
   safe than typing it themselves from the prescription?
4. Which mix-ups would be dangerous enough that we should never suggest
   one name in place of the other?

## Questions for the pharmacist

1. Can you check the expected names in this test, especially the hard
   ones?
2. Which Egyptian brand names look alike in handwriting and get confused
   at the counter?
3. Where can we get the current EDA register, or another complete list of
   names sold in Egypt, under terms that let us bundle it in a free app?
4. Would you share 30 to 50 prescriptions, with patient names covered, for
   a second test?
