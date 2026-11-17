# The overview figure, five locales (unofficial): 2026-11-13

Source: `translations/<locale>/workflow-figure.pot`, written by `input/scripts/workflow-figure.ts` from `input/includes/workflow-figure.html` and the drawing it includes, `workflow-pretty.svg` (owner, 2026-11-13: "fix all 3"). Translated by agent; no person has signed this off.

## Strings

- 43 strings per locale (ar, es, fr, ru, zh), all translated, 0 fuzzy: each drawn label (its lines joined), each tooltip, the toggle labels, the image's alt and title, and the caption with its two links kept as written.
- The actors' and countries' names follow the pages already translated (for example ar محفظة البلد الأم, fr DME du pays d'accueil, zh 东道国 EMR).

## Gates

- `workflow-figure.ts --check`, `translation-pot.ts --check`: pass.
- Rendered from `ar/` and `zh/` against the live site: every relative link and the ArchiMate picture resolve. In Arabic each label reads right to left and keeps its place in the drawing.

## Untainted round trip

All 215 strings. The back-translator saw only the five translations; the adjudicator saw only the English and the back-translations.

- 196 pass, 19 minor, 0 fail; the caption's two links kept in every locale.
- Corrected: es, fr, ru 14 ("the patient's" care history), zh 14 (a noun phrase again), fr 27 and ru 27 ("seeks care" explicit).
- Kept: ar 23-34 (زائر for "pilgrim" is this site's Arabic), zh 2 ("original drawing" as the toggle's label).
