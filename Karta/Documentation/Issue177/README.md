# Issue 177 — shopping list screenshots

iPhone 17 simulator screenshots of every `docs/design/screens/shopping-*.png`
board, each next to the board it matches, plus the list at AX1
(`accessibility-medium`, applied with `xcrun simctl ui <device> content_size
accessibility-medium` and read back before shooting).

Environment: iPhone 17 simulator, Xcode 27.0 (27A266a).
Tested commit: `308858c` — the code the screenshots were generated on;
the PR head differs only by this documentation directory.

Each state is seeded through the `KARTA_SEED` debug environment variable
(`DebugSeeds`); the shots are named after the seed, which matches the board
name:

| Board (`docs/design/screens/`) | Screenshot | Seed |
|---|---|---|
| shopping-cookbook-door.png | shopping-cookbook-door.png | `shopping-cookbook-door` |
| shopping-cookbook-select.png | shopping-cookbook-select.png | `shopping-cookbook-select` |
| shopping-cookbook-removed.png | shopping-cookbook-removed.png | `shopping-cookbook-removed` |
| shopping-list.png | shopping-list.png | `shopping-list` |
| shopping-list-got-it.png | shopping-list-got-it.png | `shopping-list-got-it` |
| shopping-list-done-undo.png | shopping-list-done-undo.png | `shopping-list-done-undo` |
| shopping-reverse-add.png | shopping-reverse-add.png | `shopping-reverse-add` |
| shopping-reverse-on-list.png | shopping-reverse-on-list.png | `shopping-reverse-on-list` |
| shopping-add-sheet.png | shopping-add-sheet.png | `shopping-add-sheet` |
| shopping-ask-auto.png | shopping-ask-auto.png | `shopping-ask-auto` |
| shopping-free.png | shopping-free.png | `shopping-free` |
| shopping-save-auto.png | shopping-save-auto.png | `shopping-save-auto` |
| shopping-empty.png | shopping-empty.png | `shopping-empty` |
| shopping-ax1.png (list at AX1) | shopping-ax1.png | `shopping-ax1` |

Notes on board-to-shot differences:

- `shopping-list-got-it` / `shopping-list-done-undo`: the seed lists a single
  recipe (Spanish Tortilla) so the `Got it · 2` divider and the ticked rows
  stay on screen; the board draws a longer list with the same chrome.
- `shopping-cookbook-removed`: the board shows the removal toast; the shot
  shows it after removing Banana Pancakes via the list chip / unsave path.
