# Chinese (Simplified) (zh, unofficial): translation refresh, 2026-11-12

Source change: smart-ips-pilgrimage#71 (fictional Onesa and Taifafeki, a generic pilgrimage). Translated by agent; no person has signed this off.

## Strings

- 124 new or changed strings translated (old wording kept as `#~`).
- 60 already-translated strings corrected for a Hajj-specific term where the English says only "pilgrim(age)": 朝觐 → 朝圣.
- Glossary entries marked `#, localised` are left empty, as the term-base rules intend.

## Gates

- `translation-pot.ts --check`, `translate-user-scenarios:check`, `check:translation-officiality`: pass.
- `po-status`: every string in zh translated, 0 fuzzy, 0 new.
- `translation:page-qa` terms preserved: 65 pass, 0 warn, 3 fail.

The 3 `terms preserved` fails are one pre-existing string this run did not touch, the label "generate SHL &#38; configure access to IPS via SHL" in three diagrams: the checker reads the `38` of the HTML entity `&#38;` (an ampersand) as a lost number, and the translation renders "&" as 并 ("and"). The same fails are on main; this repository's CI does not run the check.

## Untainted round trip

Every string this run touched (184). The back-translator saw only the Chinese (Simplified) text; the adjudicator saw only the English and the back-translation. Both declared their tools (one file read, one written).

- First pass: 179 not drift, 5 drift.
  - `zh-10`: "two tablets a day" became "two kinds of tablets daily" and "one phone" became "a mobile phone", losing the count. Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift** (a second fix, then not drift: Tanavu is a town).
  - `zh-69`: "on behalf of the health sector" became "on behalf of the health ministry", changing the entity. Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
  - `zh-87`: Three alternatives (season, per facility, or per encounter) became two (season, or per facility and per visit). Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
  - `zh-134`: "originates" became "was born", narrowing origin country to birth country. Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
  - `zh-139`: "kick-start the process of designing or adapting the exchange" became a design process "for initiating" the exchange, moving what is kick-started. Fixed; re-checked by a fresh back-translator and adjudicator: **not-drift**.
- Result: no open drift.

## Source mistakes found (reported upstream, not fixed in the translation)

- "inital" for "initial" in the counselor lane label of every process diagram.
- actor-pilgrim: "provide explicit consent to access a patient summary information to a Host Country Health Worker" is ungrammatical.
- scenarios: "the National IHE" where the actor is a HIE.
- actor-ochie uses `issue-shl-request`, actor-ochw `issue-vhl-request`.
