# Shopping-list shell contract (#176)

The signed visual specification remains `docs/design/karta-v1.md` → The shopping list.
This document names the Linux-tested API that the shell renders.

Construct `KartaStore(state:recipes:clock:)` with the current catalogue and an injected
`KartaClock`. Existing callers without these arguments retain their save-only behavior;
the shopping shell must supply both. `send(.saveRecipe(id))` then saves and, when enabled,
adds default choices atomically. Pure reducer callers supply `.saveRecipeContext` or
`.shoppingContext` explicitly. There is no package-owned clock or catalogue I/O.

- Render `reversePresentation(for:)`'s `pillTitle` and send its `pillAction`. The old
  `saveAction` remains save-only for existing shell consumers. Removing from the list
  never removes from the Cookbook; removing from the Cookbook never touches the list.
- Send `.shopping(.openAdd(id))`, render `state.shoppingSheet`, toggle by purchase key,
  then confirm or dismiss. Review uses `.review(id)` and starts from the current shares.
  `canConfirm` controls the primary button. Quantities on sheet rows are reverse quantities.
- Render `state.shoppingPresentation`: ordered nonempty aisle groups, separate `gotIt`
  rows, recipe chips, count copy, optional badge, empty flag and switch visibility.
  The shell can look up a chip's Course in the current catalogue; no match means no dot.
- Send `.toggleRow(key)`, `.doneShopping`, `.removeRecipe(id)` and `.undo` inside
  `.shopping`. Dismissing a toast expires its Undo receipt. Later list mutations invalidate
  older receipts, so Undo cannot erase newer shopping changes.
- Render `shoppingToast` and its optional action. See list sends `.openList`, Review sends
  `.review(id)`, Undo sends `.undo`. After the add toast disappears, send `.dismissToast`;
  this reveals `showsAutoAddQuestion` once. Every question dismissal sends
  `.answerAutoAdd(false)` except Yes, which sends true. The asked flag is persisted when
  the first addition schedules the question, preventing repeats after relaunch.
- `.setAutoAdd` controls the persisted switch. Render `ShoppingAutoAddQuestion` and
  `ShoppingInvitation` copy. `.openList` sets `showsShoppingList`, or opens the invitation
  on free with no retained list. A retained list stays usable after downgrade.
- Keep a single sheet mounted while `shoppingEntryIsPresented` is true. `.seePlans(products)`
  grows the shopping invitation into `paywall` with entry `.shoppingList`, as the cap entry
  does. Not now sends `.dismissInvitation`. Existing paywall actions finish the purchase.
- Persist `state.userSnapshot` through the existing storage adapter. Shares carry their
  ingredient metadata, so buying/removing an unavailable recipe requires no catalogue.
  Sheet drafts, toasts, navigation and Undo receipts are transient. Review updates
  use an Undo receipt too: a partial update says *Updated your list*; removing every
  share uses the signed *Removed from your list* toast.

`PurchasePolicy` is the one place for the seven-day leftovers window and the closed set
of pantry-basic purchase keys. Both Leftovers and shopping use it. Adding a new catalogue
product that is a pantry basic requires adding its key there; ingredient names are never
parsed to guess this. Optional ingredients never enter either purchase pool.
