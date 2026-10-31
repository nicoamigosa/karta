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
On 2026-10-29 (#5, #12) the founder signed off the Temporizador bottom zone **T1 · Line** in all
its states (ready, running, paused, *Time's up*), pause and Stop, the *Leave cooking?* sheet,
the one-time alarm permission sheet and the technique clip states (loading, paused, full screen,
unavailable). That round replaces the filled bottom zone of *Cooking · round 2*, board D2.
Its reference is the artifact *Karta · Cooking timer and clip*
(<https://claude.ai/artifact/KZiYnZdk5sqrNrAn2LDDbQ>, tab *Para firmar · T1*, marked *Signed off
2026-10-29*; rounds 1 and 2 are kept in their own tabs).
On 2026-10-30 (#149) the founder signed off the session at the largest text sizes, AX3 to AX5
(*Text size*). Its round is the artifact *Karta · Cocina a AX3–AX5*
(<https://claude.ai/artifact/61V6pGqppgcBmiitBEuhsG>; the simulator captures of #146 next to
each variant); the signed boards are copied to the *Signed off* page of the canvas linked from #15.
Earlier reference: the design canvas *Karta · Cooking fit (#101)*
(<https://claude.ai/artifact/UHnP8RdK9jP9a1fkDeLUm5>; rounds D and E side by side, the signed
boards are the `Signed*` artboards), plus *Cooking · round 3* in the canvas linked from #15 for
everything this section does not change. PNGs in `docs/design/screens/`, all drawn on an iPhone
17 (402 × 874 pt) with the safe areas hatched:

| PNG | Board |
|---|---|
| `cooking-step-first.png` | Paso 1 with the swipe hint |
| `cooking-step-timer.png` | Paso 2, Temporizador ready (T1) |
| `cooking-timer-running.png`, `cooking-timer-paused.png`, `cooking-timer-done.png` | Paso 2, Temporizador running, paused and *Time's up* (T1) |
| `cooking-step.png` | Paso 3 |
| `cooking-last-step.png` | last Paso with the technique clip; the finish card peeks behind |
| `cooking-finish.png`, `cooking-finish-answered.png` | the finish card, before and after the outcome |
| `cooking-timer-elsewhere-{running,paused,done}.png` | a Temporizador seen from another Paso: running, paused, *Time's up* |
| `cooking-leave.png` | the *Leave cooking?* sheet, here over Paso 2 with its Temporizador running |
| `cooking-alarm-permission.png` | the one-time sheet after the alarm permission is denied |
| `cooking-clip-loading.png`, `cooking-clip-paused.png`, `cooking-clip-unavailable.png` | the technique clip loading, paused (with the full-screen button) and unavailable |
| `cooking-clip-fullscreen.png` | the technique clip full screen, paused |
| `cooking-step-shrunk.png` | a long Paso: the media window gives way (see *When a Paso does not fit*) |
| `cooking-step-ax.png` | Paso 2 at Dynamic Type AX1: the card scrolls with the signal |
| `cooking-ax-timer-paused-ax3.png`, `cooking-ax-timer-paused-ax5.png` | Paso 2 at AX3 and AX5, end of the scroll, Temporizador paused: the label under the time |
| `cooking-ax-timer-running.png`, `cooking-ax-timer-done.png` | Paso 2 at AX5, end of the scroll, Temporizador running and *Time's up* |
| `cooking-ax-photo.png` | Paso 2 at AX3: the window's chip under the window, the short signal chip |
| `cooking-ax-clip.png` | last Paso at AX5: the clip's name and length under the window, the short signal chip |

On the boards of Pasos 1–3 the Foto del paso is a placeholder because no step photos exist yet
(#104); build the window as on the last Paso. The clip boards show the name *Flip the tortilla*
as a stand-in: the seed's clip titles are still in Spanish and the editor replaces them (#12).
Product terms: `CONTEXT.md` → **Paso**, **Resumen**,
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
│ ───────────────────────────── │  1 pt line; the progress line runs along it
│ 12:00 TIMER               (▶) │  only on a Paso with a Temporizador  (pinned)
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
  it ends, the photo returns. Its other states are in *The technique clip*.
- **FOR THIS STEP**: 16 pt below; eyebrow as *YOU'LL NEED* on the reverse. One row per
  ingredient, 5 pt apart: the Cantidad in Figtree 800 17 / 23, then the name in Figtree 500.
  No boxes, no leaders, no wrapping tricks: a long row simply wraps.
- **Free space**: at least 20 pt, and it absorbs whatever is left, so the bottom zone is
  always pinned to the bottom of the card.
- **Bottom zone**, pinned, only on a Paso that declares a **Temporizador** (T1 · Line, signed
  off 2026-10-29). It has no fill and no box: it is one row under a 1 pt `line` rule, 20 pt from
  the sides of the card and 14 pt from its bottom edge, with 12 pt between the rule and the row.
  It is 71 pt tall with its margin whatever the state, so the card never jumps when the state
  changes. The row holds, left to right: the time in Fraunces 900 28 pt, suit `chipInk`, tabular
  figures; a label 8 pt after it (Figtree 800 11 pt, tracking 1.2, suit `chipInk`); and the
  buttons on the right, 44 pt circles 8 pt apart. A Paso without a Temporizador has no bottom
  zone. From AX3 the label goes under the time (*Text size*).
  - **Ready** (`cooking-step-timer.png`): the declared time (*12:00*) and *TIMER*; a `brand`
    circle with a play glyph in `card`, edge `brandEdge`. Tapping it starts the Temporizador,
    never on arrival at the Paso.
  - **Running** (`cooking-timer-running.png`): the remaining time and *LEFT*; a `card` circle
    with a pause glyph in suit `chipInk` (1 pt `line` border, `buttonEdge` edge). The rule
    becomes the progress line: a 2 pt `brand` bar over it, from the left edge, as long as the
    fraction elapsed.
  - **Paused** (`cooking-timer-paused.png`): the time stays still and the label reads *PAUSED*;
    the progress bar stays where it was, in suit `chipInk` at 45 % opacity. Two buttons: a
    `card` circle with a reset glyph (↺), which takes the Temporizador back to ready, and the
    `brand` play circle, which resumes it.
  - **Time's up** (`cooking-timer-done.png`): the rule becomes a 2 pt `brand` line along the
    whole width; the row reads *Time's up* in Fraunces 900 26 pt `brand`, with a *Stop* pill
    on the right (44 pt high, 20 pt padding, `brand` fill, `brandEdge` edge, Figtree 800 15 pt
    `card`). In the app it plays a sound and haptics once at zero.
  - **Stop** takes the Temporizador back to ready: the zone shows the declared time and the
    play circle again, and the cook can start it again. Its pill leaves the progress bar.
    Stopping the alarm from the Lock Screen does the same as Stop in the app.
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
- After **Good**, the share card may rise over the bottom of the Foto (*Share*, below), never
  over **Finish**.
- The answer is the only explicit Cocinado (ADR 0008); a session that ends without it is left
  to the inferred one.

### The technique clip

The clip always plays **without sound**: there is no sound control, in the window or full
screen, and it never interrupts the cook's music. It plays once; when it ends, the photo, the
chip and the play circle come back. From AX3 the chip's text sits under the window instead of
in it (*Text size*).

- **Loading** (`cooking-clip-loading.png`): the play glyph in the 60 pt circle gives way to an
  activity indicator (suit `chip` track, suit `chipInk` arc). It shows only if loading takes
  longer than 0.3 s.
- **Playing**: the clip fills the window (`cover`, same radius). The play circle goes; the chip
  with the clip's name stays; a 5 pt progress line runs along the bottom edge of the window,
  `card` over a `videoTrack` track.
- **Paused** (`cooking-clip-paused.png`): a tap anywhere on the playing window pauses it. The
  play circle comes back in the centre, and a 36 pt `card` circle with an expand glyph (suit
  `chipInk`) sits 10 pt from the top right corner. The progress line stays where it stopped.
  Another tap on the window, or the play circle, resumes; the expand button opens the clip
  full screen.
- **While the clip plays or is paused the window keeps its taps**: a tap on it never changes
  Paso. Outside the window the halves of the card work as always. Changing Paso, or leaving the
  session, stops the clip and the photo returns.
- **Full screen** (`cooking-clip-fullscreen.png`): a near-black screen (`videoGround`) with the clip
  fitted to the width and centred. At the top, 8 pt below the top safe area: a 44 pt collapse
  button (`card` at 16 % on the dark ground) and the clip's name (Figtree 800 15 pt `card`) over
  the Resumen of its Paso and the step number (Figtree 600 13 pt, `card` at 65 %). At the bottom,
  24 pt above the bottom safe area: a scrubber with the elapsed and total time (Figtree 700
  13 pt, tabular) and a 64 pt `card` play/pause circle. No sound or volume control. While it
  plays, the controls hide after 2 s and a tap shows them. The collapse button or a swipe down
  closes it and returns to the Paso with the clip paused at the same point. Turning the phone
  shows the clip landscape, full screen; the cooking session itself stays portrait.
- **Unavailable** (`cooking-clip-unavailable.png`): if the clip cannot load, the photo stays,
  the chip reads *Clip unavailable* after a small warning glyph, and the play circle goes.
  There is no retry: clips are bundled with the app, so retrying would not help. The Paso works
  as usual.

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
220 pt (Paso 2: about 105 pt free with the T1 bottom zone; last Paso: about 85 pt free). A Paso with a two-line
Resumen, a three-line Detalle, six ingredients and a Temporizador fits with the window at
182 pt (`cooking-step-shrunk.png`; it was 166 pt with the filled bottom zone). The canvas measures every case live under each board.

### Text size

Text follows Dynamic Type, scaled relative to: Resumen and the finish-card title →
`.largeTitle`; the timer digits and *Time's up* → `.title1`; Detalle, ingredient rows and
**Finish** → `.body`; *FOR THIS STEP* and the media chip → `.caption1`; the timer label
(*TIMER*, *LEFT*, *PAUSED*) → `.caption2`; the outcome labels, the swipe hint and the signal chip
→ `.footnote`. Buttons and circles keep their size and grow only if their label needs it. The
share card has its own roles (*Share* → *Text size*).

- **Up to xxxL** the rules above apply as they are.
- **From AX1 to AX5** nothing stays pinned at the bottom: the Temporizador, and on the finish
  card the outcome buttons (or **Finish**), move to the end of the scroll. The outcome buttons
  stack one per row, 56 pt high, the icon left of the label. The header stays pinned. Steps 1–3
  of *When a Paso does not fit* still apply, with the same signal (`cooking-step-ax.png`).
- **From AX3 to AX5** (signed off 2026-10-30, #149) four more things change. AX2 stays as AX1.
  No word and no time is ever broken in the middle, and nothing is truncated.
  - **Temporizador** (`cooking-ax-timer-paused-ax3.png`, `cooking-ax-timer-paused-ax5.png`,
    `cooking-ax-timer-running.png`): in every state with a time (ready, running, paused) the
    label goes **under the time**, left-aligned, 2 pt below it: *12:00* over *TIMER*, *11:35*
    over *LEFT*, *8:15* over *PAUSED*. The buttons stay on the right, 44 pt circles 8 pt apart,
    centred on that two-line block. The rule, the progress line, the fonts and the colours do not
    change. The layout is the same in all three states, so pausing or resuming never moves the
    time. A time with hours (*1:05:00*) still fits next to two circles at AX5.
  - ***Time's up*** (`cooking-ax-timer-done.png`) keeps its one row: *Time's up* wraps between
    its two words when it must, and the *Stop* pill stays on the right, centred, with its label
    inside; the pill grows with its label.
  - **Media window chip** (`cooking-ax-photo.png`, `cooking-ax-clip.png`): the chip leaves the
    window. Its text goes **under the window**, 8 pt below it, on the 20 pt inner edge, with no
    fill and no box: Figtree 800, `.caption1`, suit `chipInk`, wrapping on as many lines as it
    needs. This applies to *When it looks like this, move on*, to the clip's name and length and
    to *Clip unavailable* (with its warning glyph). The clip's length never goes to a line on
    its own without its dot (*· 6 s* stays together). The window keeps everything else: the
    photo, the 60 pt play circle centred and uncovered, the expand button, the progress line,
    and its 220 → 160 pt give-way.
  - **Signal chip** (`cooking-ax-photo.png`, `cooking-ax-clip.png`): it reads *N more*
    (*1 more*) instead of *N more ingredients*, and *More* instead of *More below*. The arrow,
    the fade, the place, the tap and the rule for when it shows do not change.

### Behaviour

- **Moving between Pasos**: swipe left for the next Paso, right for the previous one; the
  card leaves like a card of the deck. The next one or two cards peek behind the front card
  (translated 4 / 8 pt, rotated 1.8° / 3.5°, `paper` and `cardEdge[0]`); behind the last Paso
  peeks the finish card, and the finish card has nothing behind it. Tapping the right half of
  the card also advances and the left half goes back; buttons (play, timer, outcome, signal
  chip, ✕) never move between Pasos. The only vertical gesture is scrolling a card whose
  content does not fit.
- **Leaving**: only the ✕, and it always asks first (`cooking-leave.png`): a sheet titled
  *Leave cooking?* (Resumen style, 28 pt) with the step position (*You're on step 2 of 4.*, Detalle style) below
  it, the primary *Keep cooking* button (56 pt, `brand`) and the secondary *Leave* button
  (56 pt, `card` with the tactile edge) under it. The sheet rises from the bottom over a
  `scrim`, radius 26 at the top, 20 pt side padding and a grabber; its buttons end 16 pt above
  the bottom safe area. The text does not change when a Temporizador is running. Leaving ends
  the session for good (#34) and **stops every Temporizador**: running or paused ones are
  cancelled with their AlarmKit alarms, so nothing rings after the session is over.
- **A running Temporizador seen from another Paso**: its Paso's segment in the progress bar
  becomes an outlined pill, 26 pt high, radius 13, 1.5 pt suit `chipInk` border, `card` fill,
  Figtree 800 13 pt suit `chipInk`, tabular: *11:42*. At zero it fills with `brand` and reads
  *Time's up* in `card`, with haptics and sound. A paused one keeps the pill, with a
  pause glyph before the still time and a dashed border (`cooking-timer-elsewhere-paused.png`).
  *Time's up* stays until Stop. Tapping the pill goes to that Paso. Several running timers each
  take their own segment. Outside the app, AlarmKit shows the countdown
  on the Lock Screen and Dynamic Island and rings even in silent mode (ADR 0014). Pausing or
  resuming in the app pauses or resumes the AlarmKit countdown, and AlarmKit's own pause and
  resume buttons do the same as the app's.
- **Alarm permission**: Karta asks for it the first time the cook starts a Temporizador, never
  before (ADR 0014). If the cook denies it, the Temporizador starts anyway and a sheet explains
  it, once (`cooking-alarm-permission.png`): *Alarms are off* (Resumen style, 28 pt), *The timer
  runs, but it can only ring while Karta is open. To hear it with the phone locked, allow alarms
  in Settings.*, then *OK* (primary) and *Open Settings* (secondary), laid out as *Leave
  cooking?*. After that the bottom zone is the usual one and the sheet never comes back. With the
  permission denied, the Temporizador rings only while Karta is open.
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
  **After a downgrade** (ADR 0007) the sheet keeps its shape but states the
  ceiling instead of seven: the count reads `23 OF 23 SAVED` and the line
  "Your cookbook keeps all 23 recipes on the free plan. Go unlimited to add
  more." (`screens/premium-cookbook-full-downgraded.png`, #14).
- **Cupo count** (canvas page *Cookbook · round 1*, board *N2*): one centred
  line under the switch, 13 pt Figtree 700 `inkMuted`: "5 of 7 saved on the
  free plan". It shows only when 2 or fewer slots are left: from 5 of 7 on
  the free plan, and always after a downgrade (ADR 0007), when the user sits
  at the ceiling ("23 of 23 saved on the free plan"). On the free plan the
  line ends with an underlined **Go unlimited** (Figtree 800 `ink`) that
  opens the paywall. On premium the same line names the plan instead of the
  count (*Premium and the paywall* below).
- **Unsaving**, two ways: tap **Saved** on the reverse (the pill goes back to
  **Save** at once, no animation), or long-press a card in the cookbook grid
  for the native iOS context menu: **Share** (*Share* below), then the
  destructive **Remove from cookbook**. Unsaving never deletes the recipe's cooked history: saving it
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
- Two Mundo rows, 62 pt high, radius 13, 12 pt padding: a 26 pt line icon, the name (Figtree 800
  16 pt) over one line in Figtree 600 13 pt `inkMuted`, and an 18 pt check on the current row,
  which also has a `paper` fill.
  - **For You** · *Your deck for today* (icon: two cards fanned).
  - **Leftovers** · *Reuse what you cooked* (icon: a bowl with steam).
  - On the free plan only, a third row under a 1 pt `line` divider: **Go Premium** (#14,
    `screens/premium-world-menu.png`). It is not a Mundo: a chevron instead of the check, and
    tapping it opens the paywall (*Premium and the paywall* below).
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

## Premium and the paywall

Signed off on 2026-10-30 by the founder (#14). The rounds behind each choice are in two
artifacts: *Karta Premium ronda 1* (<https://claude.ai/artifact/4oxC46WwATG15RJoV4fVeM>), rows
Aviso C, Forma C, Planes A, Prueba A, Legal A, Estados, Premium A and Fin de prueba A; and *Karta
Premium ronda 2* (<https://claude.ai/artifact/4jdsvKGY5knBHLu7H2UoKS>), rows Celebración A and
Entrada B. Copies sit on the canvas page *Signed off*. Product context: `CONTEXT.md` → **Cupo**;
ADR 0007; PRD stories 35–40. Decisions that are not design (plan name, product IDs, prices,
whether the paywall names the shopping list before #11 ships, Leftovers, Terms and privacy) are
open in #153. The copy below uses the drawn placeholders until #153 answers them.

All boards are drawn on an iPhone 17 (402 × 874 pt) with the safe areas hatched:

| PNG | Board |
|---|---|
| `premium-cookbook-go-unlimited.png` | cupo line on the free plan, with **Go unlimited** |
| `premium-save-toast.png` | the one-time toast after the sixth save |
| `premium-world-menu.png` | the Mundo menu on the free plan, with **Go Premium** |
| `premium-paywall.png` | the paywall, grown from K3 |
| `premium-paywall-entry.png` | the paywall opened from an entry point below the cap |
| `premium-paywall-buying.png` | waiting for the App Store |
| `premium-paywall-error.png` | the purchase failed |
| `premium-paywall-pending.png` | the purchase waits for approval (Ask to Buy) |
| `premium-paywall-no-trial.png` | this Apple ID already used the trial |
| `premium-paywall-restore-empty.png` | Restore found nothing |
| `premium-welcome.png` | purchase done: the celebration |
| `premium-cookbook-trial.png` | the cookbook during the trial |
| `premium-cookbook-premium.png` | the cookbook on premium |
| `premium-cookbook-full-downgraded.png` | K3 after a downgrade (ADR 0007) |

**Free forever:** the feed, deciding, the cooking session, the Intolerancias and the time,
difficulty, Practical and Diet filters, and a cookbook of seven. **Premium:** the unlimited
cookbook and the shopping list (#11). No premium check ever stands in front of an Intolerancia.

### Ways in

Nothing about premium appears when the app opens or before the user has saved anything. Every
way in is something the user taps; each opens the same paywall.

1. **K3** (*Save and the cookbook*): **Unlock unlimited cookbook**.
2. **The cupo line** in the cookbook, from 5 of 7: "5 of 7 saved on the free plan ·
   **Go unlimited**" (`premium-cookbook-go-unlimited.png`). Only the underlined words are the
   link.
3. **The sixth save**, once per user (`premium-save-toast.png`): when the save animation ends,
   the signed toast appears on the reverse with **Saved to your cookbook** over "1 spot left on
   the free plan" and a cream **See plans** pill in place of **Undo**. It stays about 5 seconds.
   It never shows again, not even after unsaving and saving again.
4. **The Mundo menu** (`premium-world-menu.png`): the **Go Premium** row described in
   *The Mundo menu*. Icon: a 30 pt `brand` circle with a 20 pt sparkle in `card`; the line
   under the name reads *Unlimited cookbook, lists* (pending #153, question 6).

Ways 2–4 are hidden during the trial and on premium. After a downgrade they come back.

### The paywall

`premium-paywall.png`. **K3 grows into it:** tapping **Unlock unlimited cookbook** keeps the
same sheet, which grows to fit the paywall; the fan and the count stay at the top and the rest
cross-fades. From the other ways in, the same sheet rises over the current screen with the
`scrim` (`premium-paywall-entry.png`). The sheet hugs its content: `card` fill, radius 28 at
the top, 10 pt top and 22 pt side padding, 12 pt above the bottom safe area, the grabber
(38 × 5 pt, `line`) 14 pt above the content, and 14 pt between blocks. Top to bottom:

1. **The fan** of seven card backs from K3 (90 %) and, under it, the count in Figtree 800
   12 pt, tracking 2, `inkMuted`: the real count, `7 OF 7 SAVED` from K3, `3 OF 7 SAVED` from
   an entry below the cap, the ceiling after a downgrade (`23 OF 23 SAVED`).
2. **Keep every recipe you like**, Fraunces 700 27 pt, centred.
3. **Three lines**, 10 pt apart: a 36 pt `paper` circle with an 18 pt icon, the name in
   Figtree 800 15 pt and one line in Figtree 500 13 / 17 pt `inkMuted`:
   - box · **Unlimited cookbook** · *No cap. Keep every recipe worth making again.*
   - list · **Shopping list** · *Any recipe becomes a list you tick off at the store.*
     (pending #153, question 6)
   - shield · **Free for good** · *The feed, cooking and your intolerance filters.* Its
     circle has no fill and a 1 pt dashed `line` border: it is what stays free.
4. **The plans**, two rows 64 pt high, 10 pt apart, radius 16, `card` fill, 1 pt `line`, 2 pt
   `buttonEdge`, 16 pt side padding. On the left a 22 pt radio, then the plan (Figtree 800
   16 pt) over one line in Figtree 600 12.5 pt `inkMuted`; on the right the billed price
   (Fraunces 700 22 pt) over its period (Figtree 600 12 pt `inkMuted`).
   - **Yearly** first and chosen when the paywall opens: 2 pt `ink` border and `inkEdge`
     edge, the radio filled `ink` with a `card` check. Line: *$4.17 a month, billed yearly*;
     price **$49.99** *per year*. A **SAVE 40%** badge sits on its top edge, 14 pt from the
     right: `brand` fill, Figtree 800 10.5 pt `card`, tracking 1, radius 7.
   - **Monthly**: *Billed every month*; **$6.99** *per month*.
   - The billed price is always the largest price on the screen; the monthly equivalent of
     the yearly plan stays small (App Review rule). Prices and the percentage come from the
     App Store for the user's storefront, never from the app.
5. **Start 7-day free trial**, the primary button.
6. **The renewal line**, Figtree 500 12 / 16 pt `inkMuted`, centred, always visible: *7 days
   free, then $49.99 a year. Renews automatically until you cancel; cancel in Settings at least
   24 hours before it renews.* It follows the chosen plan.
7. **The footer**, Figtree 700 12.5 pt `ink`, underlined in `line`: **Restore purchases ·
   Terms of Use · Privacy Policy**. The two links open in Safari (targets pending #153,
   question 7).

Swiping the sheet down or tapping the scrim closes it, like **Not now**.

### Purchase states

Cancelling on Apple's purchase sheet returns to the paywall as it was, with no message.

- **Waiting for the App Store** (`premium-paywall-buying.png`): the button shows an 18 pt
  spinner and *Waiting for the App Store…*; everything else drops to 45 % and nothing can be
  tapped. Apple's own sheet appears on top (not drawn).
- **Failed** (`premium-paywall-error.png`): a note above the button, `paper` fill, radius 14,
  10 × 12 pt padding, Figtree 700 13.5 / 19 pt `ink`, centred: *The App Store didn't answer.
  Check your connection and try again. You haven't been charged.* The button reads **Try
  again**. Never `alert`: crimson belongs to the Intolerancias.
- **Waiting for approval** (`premium-paywall-pending.png`, Ask to Buy): the same note with
  *Waiting for approval. Premium turns on by itself as soon as it's approved.* and a tactile
  **Close** in place of the button.
- **No trial left** (`premium-paywall-no-trial.png`): when the App Store says this Apple ID
  already used the trial, the button reads **Subscribe for $49.99 a year** and the renewal line
  starts *Your free trial was already used on this Apple ID.*
- **Restore found nothing** (`premium-paywall-restore-empty.png`): the signed toast, without a
  pill, at the top of the screen: **Nothing to restore** over *No Karta subscription on this
  Apple ID*. When Restore finds a subscription it behaves as a finished purchase.

### Purchase done

`premium-welcome.png`. The same sheet shows the celebration, and the recipe whose save hit the
cap is saved behind it (the pill reads **Saved**):

- A 200 pt band with a 92 pt `brand` circle in the middle holding the box-with-check icon
  (44 pt, `card`, stroke 1.7), its 4 pt `brandEdge` edge and a soft shadow; around it, about
  twenty small card backs (16 × 22 pt, radius 3, a 1 pt cream frame) in the four suits' `back`
  colours, each with its suit's `edge`.
- **Welcome to Premium**, Fraunces 700 30 pt; *Spanish Tortilla is saved. Keep every recipe you
  like from now on.*; the primary **Done**, which closes the sheet.
- **Motion**, about 1.2 s: the cards fall and spin into place while the circle bumps to 1.07
  and settles; a success haptic as it lands. **Reduce Motion:** the final frame fades in.
- Opened from a way in without a recipe (the Mundo menu, the cupo line), the line drops the
  first sentence. Not drawn.

### Premium in the cookbook

The cupo line under the switch names the plan, with **Manage** underlined; **Manage** opens
Apple's manage-subscriptions sheet. There is no settings screen.

- **Trial** (`premium-cookbook-trial.png`): *Free trial until Nov 6 · **Manage***.
- **Premium** (`premium-cookbook-premium.png`): *Premium · **Manage***.
- Both always show, whatever the count.

### When the trial or the subscription ends

Nothing new appears (ADR 0007). Everything saved stays. The cupo line shows the ceiling with
**Go unlimited** ("23 of 23 saved on the free plan · Go unlimited"), the Undo toast states the
new ceiling, and the next save opens K3 with the downgrade copy
(`premium-cookbook-full-downgraded.png`).

### Open decisions

- #153 (product and App Store Connect): plan name, IDs, prices per storefront, the trial on
  each plan, the shopping-list line on the paywall and in the Go Premium row before #11,
  Leftovers, Terms and privacy, Family Sharing.
- Not drawn: the paywall at larger text sizes. The renewal line and the footer must stay
  visible next to the button, so ask before letting them scroll away.
- Decided: the sixth-save "toast already shown" flag lives in the user snapshot (ADR 0010).
- The shopping list itself, its button and how a free user meets it belong to #11.

## Share

Signed off on 2026-10-30 by the founder (#13). The six rounds behind it are each in their own
artifact: *Karta · Share round 1* (<https://claude.ai/artifact/Ap7SyFAfJcSL2zMYRLDbFh>, row
Otros sitios B), *round 2* (<https://claude.ai/artifact/E7JgVRUNvM77mLNA8PJ3Ak>, rows Enlace B and
Cabecera B), *round 3* (<https://claude.ai/artifact/6J16SJPWMctYJ3YVWo5Yob>), *round 4*
(<https://claude.ai/artifact/Kkt6HaCzTYQb9DcBJxR7Gq>, row Retirada A), *round 5*
(<https://claude.ai/artifact/USNAKZxrg1ZDUxZxnGMjgb>) and *round 6*
(<https://claude.ai/artifact/WpvZh8qN3EQcpQkeQnxJFE>, Tarjeta A and Mensaje 1, with its AX1
board). Copies sit on the canvas page *Signed off*. Product context: PRD story 46;
`CONTEXT.md` → **Apertura**, **Intolerancia**; ADR 0010, 0011. Built in #156 (the KartaCore contract) and #157
(iOS).

**Hidden until the domain exists.** Everything below needs a domain that serves the link
(#155). The provisional domain is `karta.app`, still to be confirmed. Until the domain is
live, the app shows no share card and the cookbook menu keeps its one item: Share is switched
off, never half-working (a text without a link would give the receiver nothing to open).

All boards are drawn on an iPhone 17 (402 × 874 pt) with the safe areas hatched:

| PNG | Board |
|---|---|
| `share-finish-card.png` | the share card on the finish card, after **Good** |
| `share-finish-card-ax1.png` | the same at Dynamic Type AX1, scrolled to the end |
| `share-cookbook-menu.png` | the cookbook context menu with **Share** |
| `share-sheet.png` | the iOS share sheet and its header |
| `share-link-messages.png`, `share-link-whatsapp.png` | the link as it arrives in Messages and WhatsApp |
| `share-link-image.png` | the link image itself, 1200 × 630 |
| `share-recipe-gone.png` | opening the link of a recipe that is no longer in the catalogue |

There is no share button on the Card or on the reverse.

### The share card

- **When:** on the finish card, right after the cook taps **Good**, as the title turns into
  *Cooked. Enjoy it!* and **Finish** appears. Never after *Not great*, never in the middle of a
  session, never anywhere else.
- **Where:** it floats over the bottom of the Foto, 20 pt from the sides of the card and 12 pt
  above the rule of the bottom zone. It never covers **Finish** and dims nothing.
- **Look:** `card` fill, 1 pt `line` border, radius 18, the button edge (`buttonEdge`, 2 pt) plus
  the toast's drop shadow; padding 16 pt on top, 12 pt on the right and bottom, 14 pt on the
  left. A grabber, 32 × 4 pt in `line`, sits centred 5 pt from the top. In one row:
  - two **card backs in miniature**, 24 × 34 pt, radius 5, fanned as in the deck: the back one
    in the suit's `edge`, turned −8°, the front one in the suit's `back`, turned 8° and 8 pt to
    the right; each with a 1 pt `card` inner frame 2.5 pt in (the deck's back, small);
  - 12 pt after them, **Pass this card on** in Fraunces 700, 18 / 22 pt, `ink`, one line;
  - on the right, a tactile **Share** pill like Save (38 pt high, 12 pt padding, the share
    glyph `square.and.arrow.up` at 16 pt, Figtree 700 14 pt `ink`).
- **Share** opens the share sheet (below) and the card goes away. When the sheet closes, the
  cook is back on the finish card with nothing new on it: no toast and no confirmation, whatever
  she chose in the sheet.
- **Closing it without sharing** (there is no ✕): swipe it down; or tap **Finish**, which ends
  the session as before; or wait: it leaves on its own after 8 s. With VoiceOver it offers a
  *Dismiss* action (and the escape gesture) and never leaves on its own while it has focus.
- **Motion:** it rises 12 pt and fades in over 300 ms, about 400 ms after the answer; it leaves
  the same way, downwards. **Reduce Motion:** fade only.
- **How often** (a default rule: the founder has not confirmed it yet, so it may change): it
  shows only after **Good**, at most once per recipe, and after three dismissals in a row it
  never shows again. A dismissal is any close without tapping **Share** (swipe, **Finish**,
  timeout); tapping **Share** resets the count. Sharing from the cookbook is not affected. The
  recipes it has shown for and the count live in the user snapshot (ADR 0010), like the alarm
  permission flag.

### In the cookbook

Long-pressing a card in the cookbook grid opens the native context menu with **Share** (share
glyph) above the destructive **Remove from cookbook** (`share-cookbook-menu.png`). It opens
the same share sheet. This is the only way to share a recipe outside the cooking session.

### What is shared

- **The payload:** the line *Spanish Tortilla on Karta* (`<name> on Karta`) and the link
  `https://karta.app/r/spanish-tortilla` (`/r/<recipe id>`; the id never changes after launch,
  ADR 0011). Nothing else: no ingredients, no steps.
- **The sheet header** (`share-sheet.png`): the recipe's Foto as the thumbnail and a two-line
  title, the name over *Serves 4 · 35 min · Easy* (servings · minutes · difficulty). iOS adds
  the domain under it; that line is not ours.
- **The link image** (`share-link-image.png`), 1200 × 630, made for each recipe from the
  catalogue: the suit's `back` fills it; inset 7 % sits a `card` face (radius 52 at this size,
  the card edge) holding the Foto on the left (44 % of its width, radius 34) and, on the right, the rank
  (*35 MIN*) with the suit label, the name in `cardTitle`, the chips *Serves 4* and *Easy* in
  the suit's chip colours, and the wordmark at the bottom right. Its title is the recipe name
  and its description *A recipe card from Karta*.
- **How it arrives:** Messages shows the image, the name and the domain
  (`share-link-messages.png`); WhatsApp adds the description (`share-link-whatsapp.png`). The
  line *Spanish Tortilla on Karta* travels with it.

### Opening a link

- **With Karta installed**, the link opens the app on the reverse of that recipe, over the
  current Mundo. It counts as an **Apertura**, like a tap on a Card.
- **Without Karta**, the link goes straight to Karta's App Store page. After installing, the
  app starts as usual; it does not remember the link.
- **A recipe that is no longer in the catalogue** (`share-recipe-gone.png`): the app opens the
  Feed and shows a toast 12 pt below the header row, 22 pt from the sides: the toast of *Save and
  the cookbook* without a button, the box icon in `card`, **This recipe is no longer on Karta**
  over *Here's your deck instead.* It leaves on its own after 5 s. Without Karta the link goes
  to the App Store as above, with no notice.

### Text size

The share card follows Dynamic Type: the message → `.title3`, the Share pill → `.subheadline`.
The card backs keep their size. **From AX1** (`share-finish-card-ax1.png`) the card stops
floating: it takes its place at the end of the scroll, between the Foto and **Finish**, 14 pt
under the Foto and 20 pt from the sides. The message wraps on as many lines as it needs and the
pill moves under it, aligned with the message. It does not time out or swipe away there; it goes
when the session ends. It is content like any other, so the signal of *When a Paso does not fit*
counts it (*More below*).

### Open decisions

- #155: confirm `karta.app`, the minimal page per recipe with the link image that redirects
  to the App Store, the universal-links file and Associated Domains. Until then Share stays off.
- The frequency rule above is a default the founder has not confirmed.
- Not drawn: opening the link of a recipe that contains one of the receiver's Intolerancias.
  Karta never offers it (`CONTEXT.md` → Intolerancia); ask before choosing what the receiver
  sees.
- To check on a device: that iOS shows the two-line title in the sheet header. If it cuts it to
  one line, ask before dropping the servings line.

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
