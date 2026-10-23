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

Signed off on 2026-10-19 by the founder. On 2026-10-22 (#101) the founder also signed off how a
Paso fits on a real phone, the finish card and what gives way when a Paso does not fit. That
round replaces the Up next row and the outcome on the last Paso of *Cooking · round 3*.
Reference: the design canvas *Karta · Cooking fit (#101)*
(<https://claude.ai/artifact/UHnP8RdK9jP9a1fkDeLUm5>; rounds D and E side by side, the signed
boards are the `Signed*` artboards), plus *Cooking · round 3* in the canvas linked from #15 for
everything this section does not change. PNGs in `docs/design/screens/`, all drawn on an iPhone
17 (402 × 874 pt) with the safe areas hatched:

| PNG | Board |
|---|---|
| `cooking-step-first.png` | Paso 1 with the swipe hint |
| `cooking-step-timer.png` | Paso 2, Temporizador ready |
| `cooking-step.png` | Paso 3 |
| `cooking-last-step.png` | last Paso with the technique clip; the finish card peeks behind |
| `cooking-finish.png`, `cooking-finish-answered.png` | the finish card, before and after the outcome |
| `cooking-timer-elsewhere-{running,done}.png` | a running Temporizador seen from another Paso (#5) |
| `cooking-step-shrunk.png` | a long Paso: the media window gives way (see *When a Paso does not fit*) |
| `cooking-step-ax.png` | Paso 2 at Dynamic Type AX1: the card scrolls with the signal |

On the boards of Pasos 1–3 the Foto del paso is a placeholder because no step photos exist yet
(#104); build the window as on the last Paso. The *Leave cooking?* sheet has no board yet; only
its text below is signed off. Product terms: `CONTEXT.md` → **Paso**, **Resumen**,
**Detalle**, **Foto del paso**, **Cantidad**, **Temporizador**, **Cocinado**; ADR 0008 and 0014.

Each Paso is a card the same size as the reverse, on the same suit-coloured frame. The cook
passes them sideways like a deck. After the last Paso comes one more card, the **finish card**.

```
 suit colour fills the screen, safe areas included
 card: 30 pt inside each safe area (top, bottom), 10 pt at the sides
┌───────────────────────────────┐  card face, radius 26, same edge + shadow
│ (✕)        ▬ ▬ ▭ ▭            │  ✕ + progress bar, nothing else  (pinned)
│ Fry until tender              │  Resumen, ≤ 36 characters, ≤ 2 lines
│ Medium heat. They should      │  Detalle
│ soften, not brown.            │
│ ┌───────────────────────────┐ │
│ │       Foto del paso       │ │  220 pt high (160 at the least), inset 12, radius 18
│ │[When it looks like this…] │ │  label chip (or the clip's name)
│ └───────────────────────────┘ │
│ FOR THIS STEP                 │
│ 4 medium Yukon Gold potatoes  │  Cantidad first, then the name
│ 1 medium Yellow onion         │
│                               │  ≥ 20 pt, grows with free space
│ [ 12:00 TIMER            (▶) ]│  only on a Paso with a Temporizador  (pinned)
└───────────────────────────────┘
```

### On the screen

- **Boards are measured on the device, safe areas included.** The suit colour fills the whole
  screen, Dynamic Island and home indicator areas too. The card sits 30 pt inside the top safe
  area, 30 pt inside the bottom safe area and 10 pt from the sides. On an iPhone 17 that is
  62 + 30 pt at the top and 34 + 30 pt at the bottom, so the card is 382 × 718 pt. Never check a
  layout against a frame without safe areas (the old 390 × 844 boards): that hid the overflow of
  #101.

### The Paso card

Order, top to bottom (all left-aligned on the 20 pt inner edge unless stated):

- **Header** (16 pt from the top, pinned): the ✕ tactile button (as on the reverse) on the left
  and the **progress bar** centred: one 22 × 6 pt segment per Paso, radius 3, suit `back` for
  done and current, suit `chip` for the rest. No Course label, no "Step 2 of 4" text. The
  finish card has no segment of its own.
- **Resumen**: Fraunces 700, 34 / 39 pt, tracking −0.4, `ink`, 16 pt below the header. At most
  36 characters, so never more than two lines.
- **Detalle**: Figtree 500, 17 / 24 pt, `ink`, 6 pt below.
- **Media window**: 16 pt below, inset 12 pt from the card edges, 220 pt high, radius 18; it
  gives way down to 160 pt (*When a Paso does not fit*). It always shows the Foto del paso
  (`object-fit: cover`). A chip at the bottom-left (10 pt in; `card` fill, Figtree 800 12 pt,
  suit `chipInk`, radius 8) reads *When it looks like this, move on*. If the Paso has a
  technique clip, the chip shows the clip's name and length instead, and a 60 pt `card` circle
  with a play glyph sits in the centre: tapping it plays the clip **in the same window**; when
  it ends, the photo returns.
- **FOR THIS STEP**: 16 pt below; eyebrow as *YOU'LL NEED* on the reverse. One row per
  ingredient, 5 pt apart: the Cantidad in Figtree 800 17 / 23, then the name in Figtree 500.
  No boxes, no leaders, no wrapping tricks: a long row simply wraps.
- **Free space**: at least 20 pt, and it absorbs whatever is left, so the bottom zone is
  always pinned to the bottom of the card.
- **Bottom zone**, pinned, only on a Paso that declares a **Temporizador**: 20 pt from the
  sides, 14 pt from the bottom edge; suit `chip` fill, radius 18; the time in Fraunces 900
  36 pt, suit `chipInk`, tabular figures, plus *TIMER* (Figtree 800 12, tracking 1.2); a 52 pt
  `brand` circle with a play glyph on the right. Running: the remaining time, a pause button
  and a thin progress line. Done: `brand` fill, *Time's up* and a *Stop* pill (canvas page
  *Cooking · round 2*, board D2). A Paso without a Temporizador has no bottom zone.
- **No Up next.** The next Paso is one swipe away and already peeks behind the card. On the
  first Paso only, a hint floats 20 pt above the bottom edge, centred, and takes no space: a
  left arrow and *Swipe left for step 2* (Figtree 700 13, `inkMuted`). It fades out after 3 s
  (600 ms) or on the first touch, like the deck hint (`deck.hint`).

### The finish card

- The card after the last Paso, same size and frame. Swiping left on the last Paso (or tapping
  its right half) reaches it; it peeks behind the last Paso as the next Paso does. Swiping
  right goes back to the last Paso. The ✕ works as on any Paso.
- Header as on a Paso, with every segment of the progress bar done.
- *How did it turn out?* in the Resumen style; below it, the recipe name in the Detalle style.
- The recipe's Foto (not a Foto del paso), inset 12 pt, radius 18, `cover`, filling the free
  height (160 pt at the least). No chip, no play button.
- Bottom zone, pinned: 1 pt `line` on top, 14 / 20 / 20 pt padding, three 68 pt tactile buttons
  with an icon and a label: *Good*, *Not great*, *Add photo*. No emoji.
- After an answer the title becomes *Cooked. Enjoy it!* and the three buttons give way to
  **Finish** (the primary button, 56 pt), which ends the session without asking.
- The answer is the only explicit Cocinado (ADR 0008); a session that ends without it is left
  to the inferred one.

### When a Paso does not fit

The card height comes from the screen; the content does not. When the content is taller than
the card, things give way in this order, and only in this order:

1. The free space shrinks to its 20 pt minimum.
2. The media window shrinks from 220 pt to 160 pt. The photo stays `cover`, the chip stays at
   the bottom-left and the play button stays centred.
3. The body scrolls. The header and the bottom zone stay pinned and everything between them
   scrolls under the bottom zone. Hidden content is **always** signalled:
   - a 32 pt fade from transparent to `card` along the bottom of the scrolling area, right
     above the bottom zone (or the card edge when there is none);
   - a chip on the right, 16 pt in and 8 pt above that edge: suit `chip` fill, Figtree 800
     13 pt suit `chipInk`, 32 pt high, radius 16, the chip relief of `elevation.chip` and a
     down arrow. It reads *N more ingredients* (*1 more ingredient*) while rows of FOR THIS
     STEP are below the edge or under the fade, and *More below* for anything else. It is a
     button: tapping it scrolls to the next hidden row, and it never changes Paso;
   - the scroll indicator, visible and flashed when the card appears.

   The fade and the chip go away once the end of the body is reached.

Never give way: the Resumen, the Detalle, any row of FOR THIS STEP (never truncated, never
set smaller, never in columns), the 20 pt of free space when scrolled to the end, and the
type sizes. Nothing is ever clipped without the signal.

With the seed at the default text size on an iPhone 17 every Paso fits with the window at
220 pt (Paso 2: about 90 pt free; last Paso: about 85 pt free). A Paso with a two-line
Resumen, a three-line Detalle, six ingredients and a Temporizador fits with the window at
166 pt (`cooking-step-shrunk.png`). The canvas measures every case live under each board.

### Text size

Text follows Dynamic Type, scaled relative to: Resumen, the finish-card title and the timer
digits → `.largeTitle`; Detalle, ingredient rows and **Finish** → `.body`; *FOR THIS STEP*,
*TIMER* and the media chip → `.caption1`; the outcome labels, the swipe hint and the signal chip
→ `.footnote`. Buttons and circles keep their size and grow only if their label needs it.

- **Up to xxxL** the rules above apply as they are.
- **From AX1 to AX5** nothing stays pinned at the bottom: the Temporizador, and on the finish
  card the outcome buttons (or **Finish**), move to the end of the scroll. The outcome buttons
  stack one per row, 56 pt high, the icon left of the label. The header stays pinned. Steps 1–3
  of *When a Paso does not fit* still apply, with the same signal (`cooking-step-ax.png`).

### Behaviour

- **Moving between Pasos**: swipe left for the next Paso, right for the previous one; the
  card leaves like a card of the deck. The next one or two cards peek behind the front card
  (translated 4 / 8 pt, rotated 1.8° / 3.5°, `paper` and `cardEdge[0]`); behind the last Paso
  peeks the finish card, and the finish card has nothing behind it. Tapping the right half of
  the card also advances and the left half goes back; buttons (play, timer, outcome, signal
  chip, ✕) never move between Pasos. The only vertical gesture is scrolling a card whose
  content does not fit.
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

## Save and the cookbook

Signed off on 2026-10-20 by the founder (#7). Reference: canvas page *Signed
off*, rows *Save + cookbook (#7)*; the rounds behind each choice are on the
pages *Cookbook · round 1*, *Save · round 1*, *Intolerance tag · round 1* and
*Cookbook door · round 1*. PNGs: `screens/feed-cookbook-door.png`,
`screens/cookbook-*.png` and `screens/reverse-{saved,cookbook-full,unsaved-undo,unsaved-undo-ceiling,intolerance}.png`.
Product context: `CONTEXT.md` → **Cookbook**, **Repertorio**, **Por
probar**, **Cupo**, **Intolerancia**; ADR 0007, 0008.

- **Shape:** paper background, 58 pt top and 22 pt side padding, 18 pt
  between blocks. Under the header, a switch shows one half at a time:
  **Your repertoire · N** (saved recipes cooked at least once, explicit or
  inferred) and **Want to try · N** (saved, not cooked yet). The switch is a
  `line`-tinted track (`#EADDC7`, radius 14, 4 pt inset) holding two equal
  segments; the active one is a tactile `card` segment (radius 11, 1 pt
  `line` border, 2 pt `buttonEdge`), Figtree 800 14 pt `ink`; the other is
  Figtree 700 14 pt `inkMuted` with no fill.
- **Grid:** two columns, 12 pt gap. Each card: `card` face, radius 18, 8 pt
  padding (12 pt at the bottom), the soft card shadow; photo 118 pt high,
  radius 12; then the title (Fraunces 700, 17/20 pt) and the time
  (`35 MIN`, Figtree 800 12 pt, tracking 1). No suit colour, no servings, no
  difficulty. Tapping a card flips it into its reverse, as in the Feed.
- **The door** (canvas page *Cookbook door · round 1*, board *P1*): the
  cookbook is not a Mundo. On For You, a 40 pt tactile circle with the same
  box icon as Save (18 pt) sits right of the **For You** pill, 10 pt gap The
  filter button sits left of the pill (*The feed header* below).
- **Header inside the cookbook** (board *H3*): the wordmark stays on the
  left and the door button stays on the right, pressed: `ink` fill and
  border, a darker 2 pt edge, the box icon in `card`. Tapping it again goes
  back to For You. There is no title and no ✕; the switch sits right under
  the header.
- **Empty states** (boards *Cookbook · nothing saved yet*, *nothing cooked
  yet*, *everything saved is cooked*): centred in the free space, the box
  icon at 64 pt in a thin `#C9B79C` stroke, a Fraunces 700 22 pt line and a
  Figtree 600 15/22 pt `inkMuted` line; no button.
  - Nothing saved: no switch. **Nothing saved yet** / "Tap Save on a recipe
    you like and it lands here."
  - Your repertoire empty: **Nothing cooked yet** / "Cook a recipe from Want
    to try and it moves here."
  - Want to try empty: **You've cooked them all** / "Save something new from
    For You to try next."
- **Toast** (used by Undo): 22 pt from the sides, `ink` fill, radius 18,
  12 pt padding (16 pt left), a two-line text block (Figtree 800 15 pt
  `card`, then Figtree 600 13 pt `#EADDC7`) and a 40 pt **Undo** pill
  (`card` fill, Figtree 800 14 pt `ink`, 2 pt `#C9B79C` edge). It sits 40 pt
  above the bottom in the cookbook and just above **Start cooking** on a
  reverse. It stays about 5 seconds.
- **Which half opens:** the one the user left last time. The first time it
  is **Want to try**, because nothing has been cooked yet. This is a shell
  preference, not part of the user snapshot (ADR 0010).
- **Save pill, saved state** (canvas page *Save · round 1*, board *S2*):
  same shape as the default pill; fill and border take the suit's `chip`,
  label and icon its `chipInk`, and the 2 pt edge the suit's new `chipEdge`. The
  label reads **Saved** and the box icon shows a check instead of the slot.
- **Save animation** (board *M1 · into the box*), about 800 ms: the box
  icon's lid opens, a small card in the suit's `back` colour drops into the
  box, the lid closes, the pill tints to the saved state with a 1.07 bump
  and the check draws in. A success haptic when the card lands. Unsaving is
  instant, with no animation. **Reduce Motion:** the pill cross-fades to the
  saved state; no lid, no drop.
- **Save with the cookbook full** (board *K3*): the pill keeps its default
  look; tapping it saves nothing and opens a bottom sheet over a scrim: a fan
  of seven card backs in their suit colours, **Your cookbook is full**, the
  count (`7 OF 7 SAVED`), one line ("Free cookbooks hold 7 recipes. Go
  unlimited to keep every recipe you like."), the filled **Unlock unlimited
  cookbook** button (opens the paywall, #14) and a tactile **Not now**. This
  is the upgrade invitation of PRD story 22, not the paywall itself.
- **Cupo count** (canvas page *Cookbook · round 1*, board *N2*): one centred
  line under the switch, 13 pt Figtree 700 `inkMuted`: "5 of 7 saved on the
  free plan". It shows only when 2 or fewer slots are left: from 5 of 7 on
  the free plan, and always after a downgrade (ADR 0007), when the user sits
  at the ceiling ("23 of 23 saved on the free plan"). Never on premium.
- **Unsaving**, two ways: tap **Saved** on the reverse (the pill goes back to
  **Save** at once, no animation), or long-press a card in the cookbook grid
  for the native iOS context menu with one destructive item, **Remove from
  cookbook**. Unsaving never deletes the recipe's cooked history: saving it
  again puts it straight back in Your repertoire.
- **Undo, never a confirmation** (canvas page *Save · round 1*, boards
  *U1–U3*): every unsave shows a toast near the bottom for a few seconds,
  `ink` fill, **Removed from cookbook** over the recipe's name, and a cream
  **Undo** pill. After a downgrade the second line states the new ceiling
  ("Your cookbook now holds 22 recipes"). Undo puts everything back,
  ceiling included.
  - From a reverse opened **in the cookbook**: the reverse closes (the card
    flips back into its slot), the card leaves the grid, then the toast
    appears. **Undo** returns the card to its slot and opens the reverse
    again; that reopening is not an Apertura.
  - From a reverse opened **in the Feed**: the user stays on the reverse;
    the pill goes back to **Save** and the toast appears there.
- **A saved recipe with a new Intolerancia** (canvas page *Intolerance tag ·
  round 1*, boards *T1 · crimson fill, no icon* and *R2 · crimson fill, no
  icon*): it stays in the cookbook, openable and cookable (`CONTEXT.md` →
  Intolerancia). New tokens: `alert` `#B3122E` (fill) and `alertInk`
  `#FFFAF0` (text). Crimson is colder and darker than the dinner suit and
  no suit uses it. **No warning icon**: red plus a triangle reads as a
  danger to life, and Karta cannot tell a mild intolerance from an allergy.
  - **Grid card:** a chip right after the time, on the same line and never
    wrapping: the allergen's short name (**Dairy**), 12 pt Figtree 800,
    radius 8, 2 × 7 pt padding. With two or more: **Dairy +1**.
  - **Reverse:** a one-line note under the title block, radius 14, 10 × 12 pt
    padding, 14 pt Figtree 800: **Contains dairy, one of your
    intolerances**. Nothing else on the reverse or in the cooking session
    changes; allergens are tagged per recipe, so no ingredient is marked.

## The feed header: Mundos and filters

Signed off on 2026-10-23 by the founder (#8, #6). Reference: the design canvas *Karta · Cabecera
del feed (#8 #6)* (<https://claude.ai/artifact/Cugzu4JgxTBR4D3AXAxQYk>). Page *Ronda 2*: column E
is the signed panel, and the two empty boards are signed as drawn. Page *Ronda 1*: variants A–C,
whose A gave the header and the Mundo menu. PNGs in `docs/design/screens/`, all drawn on an
iPhone 17 (402 × 874 pt) with the safe areas hatched:

| PNG | Board |
|---|---|
| `feed-header.png` | the feed with the header, no filters applied |
| `feed-world-menu.png` | the Mundo menu open |
| `feed-filters.png` | the filter panel open, editing 30 min + One pan |
| `feed-filters-intolerance.png` | the panel right after adding gluten as an Intolerancia |
| `feed-filters-applied.png` | the feed with two filters applied (badge) |
| `feed-empty-filters.png` | nothing matches the applied filters |
| `feed-empty-profile.png` | nothing matches the Intolerancias, with no filter applied (ADR 0004) |

`feed-header.png` replaces the header of `feed-cookbook-door.png`; the door itself does not
change. Product terms: `CONTEXT.md` → **Mundo**, **Filtros**, **Intolerancia**, **Dieta**,
**Etiqueta**, **Frontera**; ADR 0002, 0004, 0009, 0013.

```
 paper, safe areas included
 karta            (≡) [For You ▾] (□)    header: 44 pt row, 6 pt below the top safe area
┌─────────────────────────────────────┐  panel: 10 pt below the header row, 10 pt at the sides
│ Filters                     [Reset] │    pointer centred under (≡)
│ ┌─ NEVER SHOW ME ───── Always free ┐│
│ │ [Dairy][ Egg ][Fish][Gluten][Nuts]││  multi-choice track, saved as you tap
│ │ Saved as you tap. Reset and …    ││
│ └──────────────────────────────────┘│
│ READY IN                    MINUTES │
│ [ Any | 20 | 30 | 45 | 60 ]         │  single-choice track
│ DIFFICULTY                          │
│ [ Any | Easy | Up to medium ]       │
│ PRACTICAL                ANY NUMBER │
│ [One pan| Oven |Make ahead|Shareable]  multi-choice track
│ DIET                                │
│ [ Any | Vegetarian | Vegan ]        │
│ [         Show 2 recipes          ] │  pinned to the bottom of the panel
└─────────────────────────────────────┘
```

### The header

- On the feed of either Mundo, one row: the wordmark on the left; on the right, 10 pt apart,
  the **filter button**, the **Mundo pill** and the **cookbook door** (#7). The row is 44 pt
  high and sits 6 pt below the top safe area, 22 pt from the sides. The deck starts 20 pt
  below the row.
- **Filter button**: a 40 pt tactile circle like the door (`card` fill, 1 pt `line`, 2 pt
  `buttonEdge`), with an 18 pt sliders icon (two lines with knobs, stroke 1.7, `ink`).
  - **Badge**: when one or more filters are applied, a 20 pt `brand` circle sits on its
    top-right corner (offset −5 / −5), with a 2 pt `paper` ring and the count in Figtree 800
    11 pt `card`. The count is the number of applied controls: a time, a difficulty and a Diet
    count one each, and each Practical tag counts one. Intolerancias never count and never
    show a badge.
  - **Pressed** while the panel is open: `ink` fill and border, a 2 pt `inkEdge` edge, the icon
    in `card` (as the door inside the cookbook).
- **Mundo pill**: as signed in #7 (Figtree 700 14 pt, 40 pt high, chevron). It reads the
  current Mundo: **For You** or **Leftovers**. Pressed while its menu is open: `ink` fill, the
  chevron turned up.
- Inside the cookbook the header stays as signed in #7 (wordmark and pressed door only): no
  filter button and no pill.

### The Mundo menu

- Tapping the pill opens a small menu 10 pt below the header row, its right edge on the pill's
  right edge, 252 pt wide: `card` fill, 1 pt `line`, radius 18, 6 pt padding, the button relief
  plus a drop shadow (0, 18, 34, −10, `shadow`).
- Two rows, 62 pt high, radius 13, 12 pt padding: a 26 pt line icon, the name (Figtree 800
  16 pt) over one line in Figtree 600 13 pt `inkMuted`, and an 18 pt check on the current row,
  which also has a `paper` fill.
  - **For You** · *Your deck for today* (icon: two cards fanned).
  - **Leftovers** · *Reuse what you cooked* (icon: a bowl with steam).
- Everything below the header row is dimmed with `scrim`. Tapping a row selects that Mundo and
  closes the menu; tapping the current one, the pill or the scrim only closes it.
- Switching Mundo keeps each Mundo's position (ADR 0009) and **never changes the filters**:
  there is one set of filters and one set of Intolerancias for both Mundos.

### The filter panel

- Tapping the filter button opens a panel that drops from the button, 10 pt below the header
  row and 10 pt from the sides: `card` fill, 1 pt `line`, radius 24, the button relief plus
  the drop shadow of the Mundo menu. A pointer (a 12 pt square turned 45°, same fill and
  border) sits on its top edge, centred under the filter button. Everything below the header
  row is dimmed with `scrim`.
- **Every option of every filter is visible at once.** No row folds, no popover.
- Layout: a scrolling body (padding 14 pt top, 16 pt sides, 14 pt between blocks) and a
  footer that never scrolls (padding 14 / 16 / 16 pt) with the **Show N recipes** button.
- Order, top to bottom:
  1. **Title row**: *Filters* (Fraunces 700, 24 pt) and, on the right, a **Reset** tactile
     pill (34 pt high, 14 pt side padding, Figtree 700 14 pt).
  2. **NEVER SHOW ME**, in its own block: `paper` fill, radius 16, 12 pt padding, 9 pt gap.
     Heading: a 14 pt shield and *NEVER SHOW ME* in `ink`; *Always free* on the right
     (Figtree 700 12 pt `inkMuted`). A multi-choice track with the five allergens in this
     order: **Dairy**, **Egg**, **Fish**, **Gluten**, **Nuts** (`Allergen.allCases`). Under it,
     one line in Figtree 600 13 / 18 pt `inkMuted`: *Saved as you tap. Reset and Clear never
     touch it.*
  3. **READY IN**, with *MINUTES* on the right: a single-choice track **Any · 20 · 30 · 45 ·
     60** (`maxMinutes` nil, 20, 30, 45, 60).
  4. **DIFFICULTY**: a single-choice track **Any · Easy · Up to medium** (`maxDifficulty` nil,
     `easy`, `medium`).
  5. **PRACTICAL**, with *ANY NUMBER* on the right: a multi-choice track **One pan · Oven ·
     Make ahead · Shareable** (`one-pan`, `oven`, `make-ahead`, `shareable`). A recipe must
     have every tag that is on.
  6. **DIET**: a single-choice track **Any · Vegetarian · Vegan** (vegan recipes also match
     Vegetarian).
  7. Footer: **Show N recipes** (*Show 1 recipe* for one), the primary button: `brand` fill,
     54 pt high, radius 18, Figtree 800 17 pt `card`, 3 pt `brandEdge` plus the soft shadow.
- Course is **not** a filter on this screen.
- **Section headings**: Figtree 800 12 pt, tracking 1.2, `inkMuted`, 8 pt above their track.
- **Tracks** (the cookbook switch, extended): `track` fill, radius 14, 4 pt inset, 4 pt between
  equal-width segments, each segment 40 pt high, radius 11, one line, never wrapping.
  - Single choice: the chosen segment is a tactile `card` segment (1 pt `line`, 2 pt
    `buttonEdge`, Figtree 800 14 pt `ink`); the others have no fill (Figtree 700 14 pt
    `inkMuted`). Exactly one is always chosen; **Any** is the default.
  - Multi-choice (NEVER SHOW ME and PRACTICAL): each segment toggles on its own. On: `ink`
    fill and border, 2 pt `inkEdge`, Figtree 800 13 pt `card`. Off: no fill, Figtree 700 13 pt
    `inkMuted`.

### Behaviour

- **Filters are a draft.** Changing time, difficulty, Practical or Diet changes only the
  panel. **Show N recipes** applies them all at once and closes the panel; applying a change
  discards the scroll anchors and the feed starts at the top (ADR 0009). Closing the panel any
  other way (the filter button again or the scrim) throws the draft away.
- **N** is the number of recipes the current Mundo would offer with the draft and the current
  Intolerancias, updated live. With nothing matching, the button reads *Show 0 recipes* and
  applying it leads to the empty state below.
- **Reset** sets every filter in the panel back to **Any** / off. Like any other change, it is
  applied with **Show N recipes**.
- **Intolerancias are not part of the draft.** Tapping an allergen saves it at once, on every
  surface that proposes recipes (`CONTEXT.md` → Intolerancia), even if the panel is then closed
  without applying. N updates with it. Reset, Clear and the empty states never change it, and
  no premium check stands in front of it. After a change, the line under the track becomes, in
  Figtree 800 13 pt `ink`:
  - added: *Saved. Gluten is now hidden everywhere. Reset and Clear never touch it.*
  - removed: *Saved. Gluten recipes can show up again.*
- The panel is the same in both Mundos and edits the same filters.

### Empty states

Both take the place of the deck, on `paper` and with no card, centred between the header row
and the bottom safe area, 36 pt from the sides. The header stays as it is, badge included. Icon
64 pt in a thin `emptyIcon` stroke; title Fraunces 700 22 pt; one line in Figtree 600
15 / 22 pt `inkMuted`; then full-width 54 pt buttons, 10 pt apart.

- **Nothing fits these filters** (`feed-empty-filters.png`): the applied filters leave no
  recipe, but the Intolerancias alone would leave some. Icon: the sliders. The line says what
  is applied, built by `KartaPresentation` (example: *No one-pan recipe is ready in 20 min.*).
  Buttons:
  - **Change filters** (primary) opens the panel with the applied filters.
  - **Clear all filters** (tactile, `card` fill, Figtree 800 17 pt `ink`) clears time,
    difficulty, Practical and Diet at once and shows the feed. It never touches the
    Intolerancias.
  - Under them, a 14 pt shield and Figtree 700 13 / 18 pt `inkMuted`: *Clearing keeps your
    intolerances: dairy stays hidden.* (the declared Intolerancias, lowercase, joined with
    commas and *and*; *stay hidden* for more than one).
- **No recipes fit your intolerances yet** (`feed-empty-profile.png`, ADR 0004): no recipe in
  the catalog is compatible with the Intolerancias, with or without filters. This is a content
  failure, not a dead end the user made, and it never offers to loosen an Intolerancia. Icon:
  the shield. The line: *None of our recipes is free of dairy, egg, fish, gluten and nuts. That
  gap is ours to fill, not yours.* One tactile button, **Check my intolerances**, opens the
  panel.
- When both are true, the profile state wins: clearing filters would not help.
- The Frontera (*you're all caught up*) and the empty Leftovers Mundo (nothing cooked yet) are
  not part of this section.

### Fit, text size and scroll

- Measured on an iPhone 17 at the default text size: the panel ends at 727 pt (745 pt with the
  confirmation line), at least 95 pt above the bottom safe area. Its height is never fixed: it hugs its
  content, up to the top of the bottom safe area.
- **When it does not fit** (a smaller phone, a larger text size), the panel stops at the top of
  the bottom safe area and the body scrolls under the pinned footer. Hidden content is always
  signalled: a 32 pt fade from transparent to `card` right above the footer, and the scroll
  indicator, flashed when the panel opens. The title row scrolls with the body.
- Text follows Dynamic Type, scaled relative to: *Filters* and the empty-state titles →
  `.title2`; segment labels, the menu rows and **Show N recipes** → `.body`; section headings,
  *Always free*, the menu row lines and the notes → `.footnote`; the badge → `.caption2`.
  Buttons and circles keep their size and grow only if their label needs it.
- **Up to xxxL** the tracks stay as drawn. A segment label never wraps and never truncates:
  if one does not fit, **that track** switches to its stacked form.
- **Stacked form** (every track from AX1 on): one full-width row per option, 48 pt high, in a
  `track` container with the same 4 pt inset; the chosen or on rows keep their colours, and an
  on multi-choice row adds a check at the right. Not drawn: an implementation that needs more
  than this asks under *Open decisions*.

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
