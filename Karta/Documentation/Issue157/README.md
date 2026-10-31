# Issue #157 — Sharing a recipe (iOS shell)

The iOS side of *Share* (`docs/design/karta-v1.md` → *Share*) on top of the
merged contract (#156, PR #164): the share card on the finish card after
**Good**, **Share** above *Remove from cookbook* in the cookbook context
menu, the native share sheet (`UIActivityViewController` +
`LPLinkMetadata`), and opening links through
`KartaStore.openRecipeLink(_:recipes:at:)`.

## Environment

- Simulator: iPhone 17 — iOS 27.0 (E0224A22-F874-4B8C-83FB-EB084492C493).
- Build: Xcode 27.0 RC (`/Applications/Xcode-27.0-RC.app`), Debug, bundle id
  `app.karta.Karta`, seeds via `SIMCTL_CHILD_KARTA_SEED`; the test base URL
  `https://karta.app` via `SIMCTL_CHILD_KARTA_SHARE_BASE_URL`
  (`KARTA_SHARE_BASE_URL` is read by `ShareLinks.baseURL` in DEBUG only —
  Release gets the real domain from #155's `KartaShareBaseURL`
  Info.plist key).
- Tested commit: see the branch head of `ralph/issue-157`.

## Captures

Board (left) and simulator capture (right) in each `compare-*.png`.

- `sim-no-base-url.png` — `cooking-answered` seed **without**
  `KARTA_SHARE_BASE_URL`: the finish card after **Good** looks exactly as
  today; no share card, no Share item. Nothing is drawn for this state, so
  there is no board.
- `compare-share-card.png` — vs `share-finish-card.png`: the card floats
  over the bottom of the Foto, 20 pt sides, 12 pt above the bottom-zone
  rule; grabber, the two miniature backs (suit `edge` −8°, `back` +8°),
  *Pass this card on*, **Share** pill with `square.and.arrow.up`.
- `compare-share-card-ax1.png` — vs `share-finish-card-ax1.png` at
  `accessibility-medium` (applied with `xcrun simctl ui <device>
  content_size accessibility-medium` and read back): the card is plain
  scroll content 14 pt under the Foto, message wraps, pill under the
  message; no grabber, no swipe, no timeout.
- `compare-cookbook-menu.png` — vs `share-cookbook-menu.png` (`repertoire`
  seed, long-press on the Pesto Pasta card): **Share** with the share glyph
  above destructive *Remove from cookbook*.
- `compare-share-sheet.png` — vs `share-sheet.png`: the sheet opens at the
  medium detent (`.presentationDetents([.medium, .large])`) and its header
  shows the Foto thumbnail and the name over the `karta.app` domain line. The
  second title line (*Serves 4 · 35 min · Easy*) is set in
  `LPLinkMetadata.title` (U+2028, asserted by
  `ShareSheetTests.linkMetadata`) but the iOS 27.0 simulator collapses it
  to one line — both title lines can only be confirmed on a device
  (Open decisions in the PR).
- `compare-recipe-gone.png` — vs `share-recipe-gone.png` (`share-gone`
  seed, which drives `openRecipeLink` with an id absent from the
  catalogue; links arriving before the seed loads are held in
  `pendingLink` until `isLoaded`): the Feed with the toast 12 pt below the header row and
  22 pt from the sides — cookbook box glyph in `card`, *This recipe is no
  longer on Karta* over *Here's your deck instead.*, no button, 5 s.

## Not photographed

- Swipe-down / Finish / 8 s dismissal and the VoiceOver *Dismiss* action
  are interactive states: covered by `ShareCardView`'s gestures/actions
  and by the contract's `closeShareCard` tests on Linux; no still board
  requires them.
- The `.reverse` link opening pushes the standard recipe reverse over the
  current Mundo and records the Apertura — same presentation as an in-app
  card open; no separate board.
