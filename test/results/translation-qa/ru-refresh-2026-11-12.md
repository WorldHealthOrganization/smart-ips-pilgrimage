# Russian (ru, unofficial): translation refresh, 2026-11-12

Source change: smart-ips-pilgrimage#71 (fictional Onesa and Taifafeki, a generic pilgrimage). Translated by agent; no person has signed this off.

## Strings

- 59 new or changed strings translated (old wording kept as `#~`).

## Gates

- `translation-pot.ts --check`, `translate-user-scenarios:check`, `check:translation-officiality`: pass.
- `po-status`: every string in ru translated, 0 fuzzy, 0 new.
- `translation:page-qa` terms preserved: 54 pass, 10 warn, 0 fail.

## Untainted round trip

Every string this run touched (59). The back-translator saw only the Russian text; the adjudicator saw only the English and the back-translation. Both declared their tools (one file read, one written).

- First pass: 58 not drift, 1 drift.
  - `ru-31`: The counsellor "records it" (the consent) became "registers them" (the pilgrim), changing what is recorded. Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
- Result: no open drift.

## Source mistakes found (reported upstream, not fixed in the translation)

- "inital" for "initial" in the counselor lane label of every process diagram.
- actor-pilgrim: "provide explicit consent to access a patient summary information to a Host Country Health Worker" is ungrammatical.
- scenarios: "the National IHE" where the actor is a HIE.
- actor-ochie uses `issue-shl-request`, actor-ochw `issue-vhl-request`.
