# Journeys visualiser — as-is intent

**Covers:** the `journeys` visualiser that `smart-ips-pilgrimage.json` declares
in `visualisers` (renderedBy `journeys-viewer`, covering the `user-scenario`
directory `user-scenarios/` and the `workshop` directory `workshops/`), served
at `<base>/en/smart-ips-pilgrimage/journeys/`. The harness's
`cat-harness-tools/scripts/gen-journeys-viz.ts` writes every page of it; this
instance supplies only the journeys, the workshop, the actors in `scenarios/`
and the BPMN in `input/business-processes/`.

**Who it is for:** a policy maker or programme lead from an origin or host
country of the pilgrimage, and the facilitator of a workshop with them. They
are not FHIR readers: the IG's pages answer "what is exchanged", these pages
answer "what happens to the pilgrim, who is involved, and where it can go
wrong".

**What they need to do:**
- see the whole journey at once: the parent journey (P0 to P7) and its eight
  moments, in the order the story follows, with who takes part in each
- find a moment by its code, title or a word
- open one moment and read it as a journey map: a lane per person or system,
  what each does and feels, the pain point, what makes it work, the state of
  the record, and the hand-off to the next moment
- step from a moment to the one before and after it, and up to the journey it
  is part of
- reach the workshop that asks the policy questions of each moment

**What it shows:** two pages, drawn as two candidates.

- `as-is-index.html`, the index: the eyebrow "Journeys", the `h1` "Every
  journey in SMART Verifiable IPS for Pilgrimage", a count lede, a filter, one
  group per instance (here one) with its journey cards (the parent card with
  its personas' initials and a feeling sparkline, then its eight sub-journey
  cards indented under it), then the workshops.
- `as-is-journey.html`, one moment (P5): breadcrumb, eyebrow, `h1`, the
  description, the when / where / country / steps facts, a card per person or
  system, the follows / part of / followed by links, then the journey map
  (a column per step, a lane per person, the feeling scale, the pain point,
  what makes it work, the record, the hand-off) and the step-by-step section.

## Findings

Both candidates draw the pages as built from this branch at cat-harness
`38c6c59` and cat-harness-tools `4a21e1e`, at 1280×800 and 390×844;
`checks/` holds the screenshots and the check report. These are observations
for the harness's viewer, not defects of this instance's content.

1. **Initials only on the index cards.** A card's people are coloured initials
   (`KN`, `MH`, `DF`); a reader has to open a moment to learn who `TM` is.
   A name on hover or focus would answer it in place.
2. **One step per moment.** Each moment P0 to P7 is a journey of one step, so
   the moment page's "Steps 1" and its one-column journey map say little; the
   parent journey is where the sequence is read.
3. **At phone width the moment's facts stack** (when, where, country, steps)
   and push the people below the first screen. Nothing scrolls sideways.
