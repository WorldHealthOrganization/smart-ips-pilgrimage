# French (fr, unofficial): translation refresh, 2026-11-12

Source change: smart-ips-pilgrimage#71 (fictional Onesa and Taifafeki, a generic pilgrimage). Translated by agent; no person has signed this off.

## Strings

- 59 new or changed strings translated (old wording kept as `#~`).

## Gates

- `translation-pot.ts --check`, `translate-user-scenarios:check`, `check:translation-officiality`: pass.
- `po-status`: every string in fr translated, 0 fuzzy, 0 new.
- `translation:page-qa` terms preserved: 42 pass, 22 warn, 0 fail.

## Untainted round trip

Every string this run touched (59). The back-translator saw only the French text; the adjudicator saw only the English and the back-translation. Both declared their tools (one file read, one written).

- First pass: 58 not drift, 1 drift.
  - `fr-1`: "Pilgrim Folder" (the MHD Folder) became "the pilgrim's record". Ruling: not drift on reading the translation: "dossier" is the standard French for an MHD Folder; the back-translation read it as "record".
- Result: no open drift.

## Source mistakes found (reported upstream, not fixed in the translation)

- "inital" for "initial" in the counselor lane label of every process diagram.
- actor-pilgrim: "provide explicit consent to access a patient summary information to a Host Country Health Worker" is ungrammatical.
- scenarios: "the National IHE" where the actor is a HIE.
- actor-ochie uses `issue-shl-request`, actor-ochw `issue-vhl-request`.
