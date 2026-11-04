# Opening a shared recipe link

The signed copy and boards are in [Share → Opening a link](design/karta-v1.md#opening-a-link).
`KartaStore.openRecipeLink(_:recipes:at:)` owns the safety decision, navigation and Apertura.
The shell must not perform its own allergen checks.

`RecipeLinkOpening.notOffered(reason)` returns a `RecipeLinkNotOfferedReason` from Core:

- `allergensNotChecked` for an unreviewed recipe, before any other reason.
- `intolerances(Set<Allergen>)` for only the receiver's matching declared Intolerancias.
- `intolerancesUnanswered(Set<Allergen>)` for every allergen in a reviewed recipe outside
  the Baraja segura, while the receiver has not answered.

The declared profile is distinct from the protective all-five effective profile used for
an unanswered receiver. Declared Intolerancias take precedence over not answered if both
apply. A saved recipe is never an exception. Non-safety Filtros do not block a shared link.

On `notOffered`, navigation resets to the For You Feed, no Apertura or Vista is recorded,
and `state.recipeNotOfferedNotice` is set. Read its `title`, `message`, `icon`, `duration`,
`buttonTitle` and `action`; the shell does not compose copy or allergen lists. Names use
canonical lowercase alphabetical order and a final “and” without an Oxford comma.

The notice occupies the same slot as recipe-gone and Leftovers. A new gone/not-offered
link replaces the other notice and discards a pending Leftovers toast. Leftovers cannot
be offered while either shared-link notice is present. The shell dismisses the notice
with `.dismissRecipeNotOfferedNotice` once it expires or is dismissed; repeating dismissal
has no effect. Notices are transient and are not included in UserSnapshot.

Only the unanswered notice has an action. Send `.onboarding(action)` using its `.setMine`
action: this dismisses the notice and opens the existing first-run panel. Answering returns
to the Feed without reopening the link. While this notice is visible it covers the Baraja
segura banner. Use `hasAction` for the shell's action layout and VoiceOver policy: the normal
lifetime is 8 seconds, but the shell must suppress automatic expiry while VoiceOver runs
and provide Dismiss and the escape gesture. Other variants last 5 seconds. Announcements,
layout and animation remain the shell's responsibility (#157).
