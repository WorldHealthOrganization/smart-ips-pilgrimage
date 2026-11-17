# Home page cards and story, five locales (unofficial): 2026-11-13

Source: `translations/<locale>/journey-cards.pot`, written by `input/scripts/journey-cards.ts` from the moments in `user-scenarios/` and the workshop's presentation (owner, 2026-11-13: "translate the top menu bar too and the cards"). Translated by agent; no person has signed this off.

## Strings

- 38 strings per locale (ar, es, fr, ru, zh), all translated, 0 fuzzy.
- Names and places stay in Latin script, and each locale's existing terms are kept (ar الزيارة الدينية, fr DME, ru «разбить стекло», zh 紧急破例访问), as on the pages already translated.

## Gates

- `journey-cards.ts --check`, `translation-pot.ts --check`: pass.

## Untainted round trip

All 190 strings. The back-translator saw only the five translations; the adjudicator saw only the English and the back-translations.

- 184 pass, 6 minor, 0 fail.
- Corrected: es 11 (Salmah brings him, not arrives with him), ru 11 ("dizzy"), ru 20 (no "merely"), zh 17 (checked *through* GDHCN, not by it).
- Kept: ar 20 (زائر for "pilgrim" is this site's Arabic), zh 38 (紧急破例访问 is this site's Chinese for "break the glass").
