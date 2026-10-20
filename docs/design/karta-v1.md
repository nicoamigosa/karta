# Karta visual identity v1

Signed off on 2026-09-25 by the founder and the designer (#15). Values live in
[`tokens.json`](tokens.json); this page explains how they fit together. The
interactive reference (all rounds plus the deck prototype, page *Final · deck*)
is the design canvas linked from #15. Product context: `CONTEXT.md` → **Card**,
**Course**; ADR 0012 and 0013.

## Concept

*karta* is a card of a deck **and** *à la carte*. Each recipe is a Card; the
Feed is a vertical deck you pass one card at a time. Warm, homey and tactile,
never neon or TikTok-loud. **Light mode only.**

## Colour

- **Paper** `#F3EBDD` is the screen background. **Card** `#FFFAF0` is the face
  of every card.
- **All text is oxblood** `ink #4E1A12`: time, suit label, title, buttons.
  `inkMuted #7A4A3C` only for secondary hints.
- **The wordmark is the only brand-coloured text** (`brand #A5432D`).
- Colour otherwise comes from the **suit** (the recipe's primary Course): the
  back of the card and the chips. Each suit has four tones: `back`, `edge`,
  `chip`, `chipInk`.

## Type

Two families, both OFL, bundled in the app: **Fraunces** (display, `SOFT` axis
at 100) and **Figtree** (UI). Card roles: `rank` (the minutes), `rankUnit`
("MIN"), `suitLabel` (the Course, lowercase italic), `cardTitle`, `chip`.

## The Card

```
┌───────────────────────────────┐  radius 26, face #FFFAF0
│ 35 MIN                 dinner │  rank + rankUnit · suitLabel (no icon)
│ ┌───────────────────────────┐ │
│ │                           │ │  photo, radius 18, inset 12,
│ │          photo            │ │  grows to fill the free height
│ │                           │ │
│ └───────────────────────────┘ │
│  Spanish Tortilla             │  cardTitle
│  [Serves 4] [Easy]            │  chips tinted by the suit
└───────────────────────────────┘
```

- Always exactly: time, servings, difficulty, primary Course. No tags, no diet,
  no Save button (ADR 0012/0013).
- **Relief:** the card has a visible 4 px edge (four 1 px layers, `cardEdge`)
  plus a soft drop shadow. The cards behind get the same edge in their suit's
  `edge` tone.
- The photo sits **inset** in the card (rounded, 12 pt margin), not edge to
  edge. The photo stretches; the text block stays tight below it.

## The deck

- Two cards peek behind the front one, fanned (`deck.back1`, `deck.back2`).
  Each shows its **back**: a flat card in its own suit colour with a thin
  cream inner frame, so the upcoming suits are visible at a glance.
- **Next:** the front card lifts up and away (`deck.leaving`), `back1`
  straightens into the front slot and turns face up (face fades in after
  120 ms), `back2` moves to `back1`, and the following card slides in as the
  new `back2`. **Previous** plays it in reverse. 460 ms, curve
  `(0.22, 1, 0.36, 1)`; a vertical swipe past 40 pt commits.
- **Entry nudge (teaches the gesture, no overlay):** when the deck first
  appears, the front card lifts slightly (`deck.entryNudge`), shows the card
  beneath and settles back, twice, then stops; it stops at once on the first
  touch. Under the deck a hint ("Swipe up or down") fades out after 3 s. There
  is no tutorial pop-up.
- **Reduce Motion:** replace the movement with a cross-fade and skip the nudge.
- **Vertical axis.** Horizontal swipes are reserved for moving between steps in
  the cooking session. A usability test (#86) may revisit this later.
- A card counts as a **Vista** only once it has settled in the front slot.

## The reverse (recipe detail)

Tapping a Card flips it over and grows it into the reverse (the Apertura).

```
 suit colour (dinner = #C8553D), 30 pt above and below, 10 pt at the sides
┌───────────────────────────────┐  card face, radius 26, same edge + shadow
│ (✕)          dinner    [Save] │  3-column grid: the suit label is centred
│ [photo 76] Spanish Tortilla   │  on the card, whatever the button widths
│            Serves 4 · Easy    │  time is not repeated here
│ YOU'LL NEED                   │
│ Yukon Gold potatoes ···· 4 med│  ingredient bold, quantity regular, dotted
│ Green bell pepper optional ·· │  optional: muted, italic "optional", dashed
│ HOW TO                        │  no step count
│ (1) one-line step summary     │  22 pt number disc centred on the first line
│ (2) … [12 min]                │  timer / clip labels inline
│                               │
│ [      Start cooking  →     ] │  pinned to the bottom
└───────────────────────────────┘
```

- **Ingredients** are named with the exact variety to buy (`Yellow onion`).
- **Steps** show the editor's one-line summary; the full step text lives in
  the cooking session. **Optional steps are not listed here**; they appear
  only in the cooking session.
- For a user with an intolerance, an optional ingredient containing that
  allergen (and its optional step) is not shown anywhere (`CONTEXT.md` →
  Ingrediente opcional).
- **Save** lives only here, never on the front of the Card.

Layout rules (reference: canvas board *Reverse A centered · course on top*):

- **One ingredient, one line.** Name (Figtree 700, `ink`) · dotted leader ·
  quantity (Figtree 500, `inkMuted`), all 15 pt and on one baseline; the row
  never wraps. The quantity keeps its full width, the leader absorbs the slack
  and, only as a last resort, the name truncates with `…`. Every quantity ends
  on the same right edge.
- **Step labels flow inline.** The timer (`12 min`) and `clip` labels follow
  the last word of the step like another word: on the same line when they
  fit, otherwise at the start of the next line; never forced onto a line of
  their own under the text. Chip text 12 pt, weight 800, suit `chip` /
  `chipInk`, radius 8.
- Step text is 15 pt on a 22 pt line, left-aligned on a common edge after the
  number disc.
- **✕ and Save are tactile buttons**, never bare text or icons: 40 pt high,
  fill `card`, 1 pt border `line`, 2 pt solid bottom edge `buttonEdge`. ✕ is
  a circle (14 pt cross, stroke 2); Save is a pill with 14 pt side padding,
  a 16 pt stroke icon, 6 pt gap and the `button` type. Saved and
  cap-blocked states keep the same shape.
- **Start cooking** is the one filled button: `brand` fill, 54 pt high,
  radius 18, label plus 18 pt arrow (gap 10) in Figtree 800 17 pt `card`,
  3 pt solid bottom edge `brandEdge` plus a soft drop shadow.

## The cooking session

Signed off on 2026-10-19 by the founder. Reference: canvas page *Cooking · round 3* (four
boards *Chosen · step 1–4*, the board *Chosen · step 3 while the step 2 timer runs*, and a
prototype to swipe), PNGs in `docs/design/screens/cooking-*.png`. Product terms:
`CONTEXT.md` → **Paso**, **Resumen**, **Detalle**, **Foto del paso**, **Cantidad**,
**Temporizador**; ADR 0014.

Each Paso is a card the same size as the reverse, on the same suit-coloured frame. The cook
passes them sideways like a deck.

```
 suit colour, 30 pt above and below, 10 pt at the sides
┌───────────────────────────────┐  card face, radius 26, same edge + shadow
│ (✕)        ▬ ▬ ▭ ▭            │  ✕ + progress bar, nothing else
│ Fry until tender              │  Resumen, ≤ 36 characters, ≤ 2 lines
│ Medium heat. They should      │  Detalle
│ soften, not brown.            │
│ ┌───────────────────────────┐ │
│ │       Foto del paso       │ │  220 pt high, inset 12, radius 18
│ │[When it looks like this…] │ │  label chip (or the clip's name)
│ └───────────────────────────┘ │
│ FOR THIS STEP                 │
│ 4 medium Yukon Gold potatoes  │  Cantidad first, then the name
│ 1 medium Yellow onion         │
│                               │  ≥ 20 pt, grows with free space
│ [ 12:00 TIMER            (▶) ]│  only on a Paso with a Temporizador
│───────────────────────────────│
│ [img] UP NEXT                 │  next Paso: Foto del paso + Resumen
│       Fold the potatoes in… ← │
└───────────────────────────────┘
```

Order, top to bottom (all left-aligned on the 20 pt inner edge unless stated):

- **Header** (16 pt from the top): the ✕ tactile button (as on the reverse) on the left and
  the **progress bar** centred: one 22 × 6 pt segment per Paso, radius 3, suit `back` for done
  and current, suit `chip` for the rest. No Course label, no "Step 2 of 4" text.
- **Resumen**: Fraunces 700, 34 / 39 pt, tracking −0.4, `ink`, 16 pt below the header. At most
  36 characters, so never more than two lines.
- **Detalle**: Figtree 500, 17 / 24 pt, `ink`, 6 pt below.
- **Media window**: 16 pt below, inset 12 pt from the card edges, 220 pt high, radius 18.
  It always shows the Foto del paso (`object-fit: cover`). A chip at the bottom-left (10 pt
  in; `card` fill, Figtree 800 12 pt, suit `chipInk`, radius 8) reads *When it looks like
  this, move on*. If the Paso has a technique clip, the chip shows the clip's name and length
  instead, and a 60 pt `card` circle with a play glyph sits in the centre: tapping it plays the
  clip **in the same window**; when it ends, the photo returns.
- **FOR THIS STEP**: 16 pt below; eyebrow as *YOU'LL NEED* on the reverse. One row per
  ingredient, 5 pt apart: the Cantidad in Figtree 800 17 / 23, then the name in Figtree 500.
  No boxes, no leaders, no wrapping tricks: a long row simply wraps.
- **Free space**: at least 20 pt, and it absorbs whatever is left, so the bottom zone is
  always pinned to the bottom of the card.
- **Bottom zone**, pinned:
  - **Temporizador** (only on a Paso that declares one): 14 pt above the line; suit `chip`
    fill, radius 18; the time in Fraunces 900 36 pt, suit `chipInk`, tabular figures, plus
    *TIMER* (Figtree 800 12, tracking 1.2); a 52 pt `brand` circle with a play glyph on the
    right. Running: the remaining time, a pause button and a thin progress line. Done:
    `brand` fill, *Time's up* and a *Stop* pill (canvas page *Cooking · round 2*, board D2).
  - **Up next** (every Paso but the last): 1 pt `line` on top, 14 / 20 / 20 pt padding; a
    64 pt thumbnail (the next Foto del paso, radius 12), the eyebrow *UP NEXT* (on the first
    Paso, *UP NEXT · SWIPE LEFT*) and the next Resumen in Fraunces 700 18 / 22; a left arrow
    on the right edge, `inkMuted`.
  - **Last Paso**: *How did it turn out?* (Fraunces 700 22, centred) and three 68 pt tactile
    buttons with an icon and a label: *Good*, *Not great*, *Add photo*. No emoji. After an
    answer: a check disc, *Cooked. Enjoy it!* and **Finish** (the primary button, 56 pt),
    which ends the session without asking.

Behaviour:

- **Moving between Pasos**: swipe left for the next Paso, right for the previous one; the
  card leaves like a card of the deck. The next one or two Pasos peek behind the front card
  (translated 4 / 8 pt, rotated 1.8° / 3.5°, `paper` and `cardEdge[0]`); the last Paso has
  nothing behind it. Tapping the right half of the card also advances and the left half goes
  back; buttons (play, timer, outcome, ✕) never move between Pasos. There is no vertical
  gesture in the session.
- **Leaving**: only the ✕, and it always asks first: a sheet *Leave cooking? You're on step
  3 of 4.* with *Keep cooking* and *Leave*. Leaving ends the session for good (#34).
- **A running Temporizador seen from another Paso**: its Paso's segment in the progress bar
  becomes an outlined pill, 26 pt high, radius 13, 1.5 pt suit `chipInk` border, `card` fill,
  Figtree 800 13 pt suit `chipInk`, tabular: *11:42*. At zero it fills with `brand` and reads
  *Time's up* in `card`, with haptics and sound. Tapping it goes to that Paso. Several
  running timers each take their own segment. Outside the app, AlarmKit shows the countdown
  on the Lock Screen and Dynamic Island and rings even in silent mode (ADR 0014).
- The screen stays awake for the whole session. Colours come from the suit of the recipe's
  primary Course even though the Course is not named.

## Suits (Course icons)

`suits/breakfast.svg` (fried egg), `suits/lunch.svg` (half sandwich),
`suits/dinner.svg` (cloche), `suits/dessert.svg` (cupcake). They are **not**
shown on the Card (the suit there is the italic label); they are used in
filters, the recipe detail and empty states. 24 × 24 viewBox, flat colour.

## App icon and wordmark

- **Icon** (`app-icon.svg`): three cards fanned on paper `#F3EBDD`, sage,
  mustard and a front card in `card` with a Fraunces 900 "k" in `brand`.
  Export at 1024 × 1024 without transparency; the "k" must be converted to
  outlines on export.
- **Wordmark:** "karta", lowercase, Fraunces 900 `SOFT` 100, tracking −0.8
  at 30 pt, in `brand`.
