# Leftovers package contract (#180)

The signed boards and copy remain in `karta-v1.md` → Leftovers. The Linux packages
provide the rules and projections below; the macOS shell follow-up renders them.
Leftovers is free. Both Mundos use the applied filters and effective safety profile,
including the Baraja segura before the intolerance answer.

- Read `store.leftoversFeed(recipes:clock:)`. Its `Feed.hasFrontier` is false;
  its items contain only recipes, ordered by distinct shared purchase keys, then
  the same Gusto, freshness, household and popularity ordering as For You.
  Settled Cards still send `recordView`.
- Ask `lastCard(recipeID:world:recipes:clock:)` for end-of-deck behavior. A non-nil
  result means no cards behind, rebound on forward swipe and a 3-second hint.
  Reduce Motion uses the hint without movement. For You retains its Frontera.
- Use `cardPresentation(for:world:recipes:clock:)` for `leftoversPill`. The older
  projection supplies no pill. Capture the Mundo at Apertura and pass it to
  `reversePresentation(for:openedFrom:recipes:clock:)` for `leftoversNote`.
  Pass nil for a Cookbook or external-link reverse.
- `PurchasePolicy.reusedIngredients` is the shared explanation seam for Leftovers
  and the shopping add sheet: distinct keys in target ingredient order, with all
  distinct source recipes most recent first. Optional ingredients and pantry
  basics do not supply leftovers.

## Catalog and editorial review

Each catalog ingredient requires `shortName`, including pantry basics and optional
rows. The seed's proposed short names need the editor's review. Decoding rejects
missing, null or blank values with `missingIngredientShortName`.

`RecipeCatalog.decode` checks the maximum possible pill for every potential first
leftover ingredient, against that recipe's own chips. Unknown glyphs fail closed.
The unhinted Figtree advance tables and reproducible derivation are documented in
`LeftoversPillFit.swift` and `scripts/figtree-advances.py`. No font library is needed
at runtime. This default-size check does not replace the signed AX1 own-line layout.

The signed 318 pt row / 163 pt gap implies 8 pt horizontal insets per chip with
Figtree 700 14 pt and two 8 pt gaps. The existing shell uses 12 pt chip insets;
the shell follow-up must reconcile its geometry with the signed fit contract.

## Empty states and See toast

`store.leftoversEmptyState(recipes:clock:)` returns `LeftoversEmptyState` with the
signed title, line, primary button and (for Go to For You) action. Profile emptiness
wins before cook history, then nothing cooked, then nothing to reuse, then filters.
The shell opens its own filter sheet for Change filters and sends `filter(.reset)`
for Clear all filters; `noMatchForFilters` also carries the retained-intolerance line.
A removed source recipe keeps its history: the out-of-window line omits its missing
name; an unmatched cook with no surviving source name uses “what you cooked this week”.

Initialize `KartaStore(state:recipes:clock:)` with the catalog and clock, as for the
shopping contract. `exitCooking` then supplies that context to the reducer's
`exitCookingContext(recipes:now:)`. Pure reducer consumers can send the latter directly.
An eligible explicit session offers `state.leftoversToast` on For You, after returning
to the deck. Its count includes only ideas reusing that specific cook. Good and Not
great both qualify; inferred cooks do not. The source line names all distinct required,
non-pantry leftover short names in source recipe order.

Render the title, line and See button in the signed slot. On See send
`closeLeftoversToast(.see)`; on the 5-second timeout, swipe or accessibility dismissal
send `.dismissed`. See resets the Leftovers anchor to the top and the dismissal streak.
Three consecutive dismissals retire the toast. Recipe-gone wins the slot and discards
a pending See toast. Repeated exit or close actions cannot consume it twice.

`leftoversToastHistory` persists shown recipe IDs at offer time and the dismissal
streak through `UserSnapshot`; pending toast/navigation do not persist. Older snapshots
without the optional DTO field start with no offers or dismissals. Malformed history
preserves the unreadable snapshot through the existing restoration policy.
