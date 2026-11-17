# Arabic (ar, unofficial): translation refresh, 2026-11-12

Source change: smart-ips-pilgrimage#71 (fictional Onesa and Taifafeki, a generic pilgrimage). Translated by agent; no person has signed this off.

## Strings

- 59 new or changed strings translated (old wording kept as `#~`).
- 53 already-translated strings corrected for a Hajj-specific term where the English says only "pilgrim(age)": الحاج / الحجاج → الزائر / الزوار, الحج → الزيارة الدينية.

## Gates

- `translation-pot.ts --check`, `translate-user-scenarios:check`, `check:translation-officiality`: pass.
- `po-status`: every string in ar translated, 0 fuzzy, 0 new.
- `translation:page-qa` terms preserved: 58 pass, 6 warn, 0 fail.

## Untainted round trip

Every string this run touched (112). The back-translator saw only the Arabic text; the adjudicator saw only the English and the back-translation. Both declared their tools (one file read, one written).

- First pass: 108 not drift, 4 drift.
  - `ar-1`: "MHD style manifests" became "MHD-style data", losing the MHD term of art "manifests". Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
  - `ar-65`: "encrypted data" in the QR code became "encoded data", a different security claim. Ruling: not drift on reading the translation: مشفّرة is "encrypted"; the back-translation misread it as "encoded".
  - `ar-69`: "originates" became "descends", shifting origin country to ancestry. Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
  - `ar-73`: "pilgrim forms" became "models", swapping the questionnaire forms for a different thing. Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
- Result: no open drift.

## Source mistakes found (reported upstream, not fixed in the translation)

- "inital" for "initial" in the counselor lane label of every process diagram.
- actor-pilgrim: "provide explicit consent to access a patient summary information to a Host Country Health Worker" is ungrammatical.
- scenarios: "the National IHE" where the actor is a HIE.
- actor-ochie uses `issue-shl-request`, actor-ochw `issue-vhl-request`.
