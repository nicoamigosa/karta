# Mac handoff — building the SwiftUI shell over KartaCore

> **⚠️ Large parts of this document are out of date. Read `CONTEXT.md` and
> `docs/adr/` first — they win wherever they disagree with this file.**
>
> This was written assuming a macOS host that would pick up UI issues directly
> against the `KartaCore` API as it stood in September 2026. Both assumptions
> changed: the macOS work goes to **Devin**, which does not run the ralph loop,
> and ADRs 0001–0010 changed the domain underneath. The per-issue *acceptance
> criteria* below are still broadly right; the **API cheat-sheet in §3 is not a
> contract any more** — it is a snapshot of a surface that is being reshaped.

Read, in this order: `AGENTS.md` (working agreement), `CONTEXT.md` (glossary),
`docs/adr/` (decisions), `docs/PRD-karta-mvp.md` (product scope). This file is
the bridge between them and the simulator.

---

## −1. What changed since this was written

| ADR | Decision | What it voids here |
|---|---|---|
| 0001 | `KartaCore` + `KartaPresentation`, two targets | "thin shell over KartaCore"; the shell now consumes a store, not raw value types |
| 0002 | Closed allergen vocabulary, `dairy` not `lactose`, unreviewed recipes unrepresentable | `contains: [String]`; the §5 seed table |
| 0003 | History carries dates; the clock is injected | `seen: Set<String>` |
| 0004 | A **frontier** between new and already-seen; crossing it does not re-mark | "holds back recently-seen (never empties)" |
| 0005 | Catalog authored in English with US units; no locale conversion | the Spanish seed; "locale-inferred units" in #10 |
| 0006 | Recipes declare servings; household size labels and orders, never filters | #10's household question now has a visible effect |
| 0007 | Downgrading from premium never deletes saves; the cap becomes a ceiling | #7's "cap" behaviour |
| 0008 | Cooked is inferred from the whole session, not 20 s of dwell; only explicit cooks feed Leftovers | #4's `inferProbablyCooked(dwellSeconds:)`; #9's input |
| 0009 | Feed position is session memory: kept on open/back and world switches, reset next day and on filter change | #2 and #8's "restores scroll position" |
| 0010 | An explicit versioned snapshot; a half-finished cooking session **is** saved; unreadable data is never deleted | "persistence is the UI shell's job" |

Issues #2 and #8 were labelled "pure UI — nothing in KartaCore". That is wrong:
navigation, worlds, routes and the scroll anchor are state, they live in
`KartaPresentation`, and they are tested on Linux.

---

## 0. Setup on a freshly-cloned macOS host

From the repository root:

```bash
# 1. Verify the logic packages build and every test passes (no Xcode needed)
swift test --package-path KartaCore

# 2. The iOS app does not exist until issue #1 scaffolds it in Karta/
#    (Karta/project.yml, generated with XcodeGen; the .xcodeproj is not committed):
xcodegen generate --spec Karta/project.yml
open Karta/Karta.xcodeproj
```

The CI job that builds and tests the app, and the check (`gate`) that every PR
needs, are described in `AGENTS.md` ("Gates") and in
`docs/reviews/2026-09-astra-pipeline-runbook.md` (step 6).

- The iOS app target is a **thin shell**: it links both packages and renders
  them. Rules go in `KartaCore`, screen state and reducers in
  `KartaPresentation`, and both are covered by `swift test` on Linux before the
  shell is written. Nothing that a Linux test could catch belongs in a view.
- The **intolerance / feed-safety filtering is a critical guarantee**; never
  bypass it in the UI and never re-implement a filter in a view.

---

## 1. Workflow on the macOS host (differs from the logic phase)

Same per-issue branch/commit/PR loop as `AGENTS.md`, with one important change
— and note that the ralph loop does **not** run here: the agent on this host
never merges, never approves and never closes an issue itself.

- During the logic phase we could **not** verify UI, so PRs said `Part of #N`
  and issues stayed **open**.
- On the Mac you **can** verify acceptance in the simulator. So once an issue's
  UI is built and you've confirmed every acceptance checkbox on a running
  simulator, the commit may say **`Closes #N`** and merging actually completes
  the issue.
- If you build the UI but cannot verify a criterion (e.g. needs a device, needs
  StoreKit sandbox), keep `Part of #N` and leave it open — do not fake-close.

Per issue: branch from up-to-date `main` → build SwiftUI over the two packages
→ verify in simulator → `Closes #N` commit → push → PR. The merge happens
elsewhere.

---

## 2. What's already done (merged into `main`)

| # | Issue | Logic status | PR |
|---|-------|--------------|----|
| 1 | Scaffold + vertical feed | `Recipe` model + `RecipeCatalog.seed()` ready; **app target + feed UI pending** | #1 |
| 2 | Recipe detail | ~~pure UI~~ — navigation + scroll anchor are state (ADR 0009) | — |
| 4 | Cooking mode state machine | `CookingSession` + `cooked` event done | #16, #23 |
| 5 | In-step timers | timer logic done | #17, #23 |
| 6 | Filters UI | engine (`FeedFilters`/`FeedQuery`) done | #3 |
| 7 | Save + cookbook + cap | `Cookbook` + free cap done | #18 |
| 9 | Leftovers loop | `LeftoversQuery` done | #19 |
| 10 | Onboarding + calibration | `OnboardingProfile`/`TasteCalibration` done | #20 |
| 12 | Technique clips | clip model + library done | #21, #23 |
| 13 | Share recipe | `RecipeShare.payload` done | #22 |

Still **fully** open (need product/Mac decisions, not just UI):
- **#8** Top-nav dropdown (For You / Saved / Leftovers) — ~~pure UI~~: worlds,
  routes and per-world position are state (ADR 0009).
- **#11** Auto shopping list — **blocked by #14**.
- **#14** Freemium gating + StoreKit — `hitl`, needs Nico's product + StoreKit
  decisions. No logic stub exists yet.
- **#15** Visual direction sign-off — `hitl`, design.

---

## 3. KartaCore API cheat-sheet *(September 2026 snapshot — no longer the contract)*

```swift
import KartaCore

// ---- Domain model -------------------------------------------------------
struct Recipe: Codable, Identifiable {
    let id: String; let name: String; let heroPhotoURL: String
    let totalMinutes: Int; let difficulty: Difficulty
    let tags: [String]; let ingredients: [Ingredient]
    let steps: [CookingStep]          // structured: text + optional ingredient/timer/clip
    let contains: [String]            // intolerance tags, e.g. ["gluten","lactose"]
    let popularity: Int
    func cookingSession() -> CookingSession   // open cooking mode for this recipe
}
struct Ingredient { let name: String; let quantity: String }
enum Difficulty: String { case easy, medium, hard }   // Comparable

// ---- Catalog (bundled seed) --------------------------------------------
RecipeCatalog.seed() throws -> [Recipe]                // ~8 recipes
TechniqueClipLibrary.seed() throws -> TechniqueClipLibrary

// ---- Feed (For You) -----------------------------------------------------
struct FeedFilters {                                   // all optional
    var intolerances: Set<String>; var maxMinutes: Int?
    var maxDifficulty: Difficulty?; var requireOnePan: Bool
    static let onePanTag = "one-pan"
}
FeedQuery.feed(recipes:[Recipe], seen:Set<String>, filters:FeedFilters) -> [Recipe]
// Applies safety + hard filters, holds back recently-seen (never empties),
// orders by popularity. Pure function — call it from the view model.

// ---- Cooking mode (#4) --------------------------------------------------
struct CookingStep { let text:String; let ingredient:Ingredient?
                     let timerSeconds:Int?; let clipID:String? }   // string literal => text-only
struct CookingSession {                                 // value type; mutate a copy in your VM
    var currentIndex:Int; var currentStep:CookingStep?
    var isExited:Bool; var isOnLastStep:Bool; var showsOutcomePrompt:Bool
    mutating func next(); mutating func previous(); mutating func exit()
    mutating func respond(_:CookOutcome) -> CookedEvent?           // 👍/👎/📷 on last step
    mutating func inferProbablyCooked(dwellSeconds:TimeInterval) -> CookedEvent?
    var cookedEvent: CookedEvent?
    // timers (#5) — inject your own clock (e.g. Date().timeIntervalSince1970):
    mutating func startTimer(now:TimeInterval)
    func currentStepTimerRemaining(at:TimeInterval) -> TimeInterval?
    func currentStepTimerHasFired(at:TimeInterval) -> Bool
}
enum CookOutcome { case thumbsUp, thumbsDown, photo }
struct CookedEvent { let recipeID:String; let outcome:CookOutcome?; let wasInferred:Bool }

// ---- Technique clips (#12) ---------------------------------------------
struct TechniqueClip: Identifiable { let id:String; let title:String; let seconds:Int }
library.clip(for: step) -> TechniqueClip?              // nil => render step text-only

// ---- Cookbook + save cap (#7) ------------------------------------------
struct Cookbook {
    static let freeSaveCap = 7
    var savedIDs:[String]; var isAtCap:Bool
    func isSaved(_:String) -> Bool
    mutating func save(_:String) -> SaveResult         // .saved / .alreadySaved / .blockedByCap
    mutating func unsave(_:String)
}
enum SaveResult { case saved, alreadySaved, blockedByCap }   // blockedByCap => show upgrade

// ---- Leftovers (#9) -----------------------------------------------------
LeftoversQuery.suggestions(recipes:[Recipe], cookedRecipeIDs:Set<String>,
                           filters:FeedFilters) -> [Recipe]

// ---- Onboarding (#10) ---------------------------------------------------
struct OnboardingProfile { let intolerances:Set<String>; let householdSize:Int
                           var feedFilters:FeedFilters }
struct TasteCalibration { var likedIDs:[String]; mutating func tap(_:String) }
// calibration is a SEPARATE channel from Cookbook — taps must NOT call cookbook.save

// ---- Share (#13) --------------------------------------------------------
RecipeShare.payload(for: Recipe) -> SharePayload       // { text:String, url:URL? }
```

> **Stale — see §−1.** Two corrections worth stating explicitly, because both
> were verified rather than assumed:
>
> - Reassigning after each mutating call is **not** necessary for a stored
>   property of an `@Observable` class; `withObservationTracking` confirms the
>   mutation is observed. Do not write code around a constraint that is not there.
> - Persistence is **not** freeform shell work. ADR 0010 defines what is saved,
>   what is deliberately not, and what happens to data the app cannot read.
>   The shell reads and writes the snapshot; it does not design it.

---

## 4. Per-issue build guide (suggested order)

Order respects dependencies; start at the top.

### #1 — Scaffold + vertical feed *(do first; unblocks everything visual)*
- **Build:** the iOS app target/project; a vertically scrolling feed of recipe
  cards from the seed catalog.
- **KartaCore:** `RecipeCatalog.seed()` → `FeedQuery.feed(recipes:seen:filters:)`
  with empty `FeedFilters()` for the first cut.
- **Card shows:** `heroPhotoURL`, `name`, `totalMinutes`, `difficulty`.
- **Accept:** app runs on simulator; cards render hero+name+time+difficulty;
  vertical scroll moves between recipes; seed decodes (already unit-tested).

### #2 — Recipe detail (ingredients + method)
- **Build:** tap a card → full detail (all `ingredients` with quantities, the
  ordered `steps`). Swipe-right on a card also opens it. Back restores feed
  scroll position.
- **KartaCore:** `Recipe.ingredients`, `Recipe.steps` (each `CookingStep.text`;
  show `ingredient`/`timerSeconds`/`clipID` hints if you like).
- **Accept:** tap + swipe-right open detail; full ingredients + full method;
  back keeps scroll position.

### #6 — Filters (intolerances / time / difficulty / one-pan) *(needs #1)*
- **Build:** filter controls that feed a `FeedFilters` into `FeedQuery.feed`.
- **KartaCore:** mutate a `FeedFilters` (intolerances, `maxMinutes`,
  `maxDifficulty`, `requireOnePan`) and re-run the feed. One-pan tag =
  `FeedFilters.onePanTag`; show it as a card badge.
- **Critical:** intolerance filters are **always free / no paywall** and must
  never show a violating recipe. (Engine already guarantees this — just don't
  filter in the view yourself.)

### #7 — Save button + cookbook + cap *(needs #2)*
- **Build:** a Save button (recipe-box icon, **not a heart**) + animation;
  saved recipes listed in a cookbook screen.
- **KartaCore:** `Cookbook.save(id)` → on `.blockedByCap` surface the upgrade
  invitation; `unsave`; `isSaved`; `savedIDs`. Persist `savedIDs` yourself.
- **Accept:** save persists + lists; 8th save blocked at cap; cap shows upgrade
  hook; unsave frees a slot.

### #8 — Top-nav dropdown (For You / Saved / Leftovers) *(needs #1, #7)*
- **Build:** Instagram-style central selector switching the three worlds.
  Difficulty is NOT a world. Leftovers may be a placeholder until #9.
- **Accept:** dropdown switches worlds; For You = feed, Saved = cookbook;
  switching preserves feed position.

### #4 — Cooking mode *(needs #2)*
- **Build:** full-screen step-by-step mode. Gestures: swipe-right `next()`,
  swipe-left `previous()`, swipe-down `exit()`. Tap half the screen = advance.
  Large text (readable ~0.5 m), large tap targets, **keep screen awake**
  (`UIApplication.shared.isIdleTimerDisabled` / SwiftUI equivalent).
- **KartaCore:** `recipe.cookingSession()`; render `currentStep.text` and its
  self-contained `currentStep.ingredient`. When `showsOutcomePrompt`, show
  "How did it turn out?" (👍/👎/📷) → `respond(_:)`. Drive
  `inferProbablyCooked(dwellSeconds:)` from a dwell timer on the last step.
  Persist the returned `CookedEvent` (feeds #9 leftovers).
- **Accept:** all gesture transitions; per-step ingredient; screen awake; large
  text/targets; prompt + `cooked` emission; probably-cooked inference.

### #5 — In-step timers *(needs #4)*
- **Build:** timed steps show a start control; countdown in-app; fire a clear
  alert (visual + haptic/sound) on completion; survives step navigation.
- **KartaCore:** for steps where `currentStep.timerSeconds != nil`, call
  `startTimer(now:)` and poll `currentStepTimerRemaining(at:)` /
  `currentStepTimerHasFired(at:)` with `Date().timeIntervalSince1970`. Timer
  state already survives back/forth (kept by step index in the session).
- **Accept:** start + countdown without leaving cooking mode; fires with
  haptic/sound; survives navigation.

### #12 — Technique clips *(needs #4)*
- **Build:** at steps with a clip, show/play it inline (~6s); steps without
  stay text-only. Don't break navigation or screen-awake.
- **KartaCore:** `TechniqueClipLibrary.seed()`; `library.clip(for: step)` → if
  non-nil, render the clip (`title`, `seconds`). Seed clip ids:
  `cuajar-tortilla`, `sellar-pollo`, `punto-salmon`.
- **Accept:** clip step surfaces/plays; text-only step stays text; same clip
  shared by multiple recipes.

### #9 — Leftovers loop *(needs #4, #8)*
- **Build:** the Leftovers world: recipes reusing ingredients from recently
  cooked recipes; no manual inventory.
- **KartaCore:** `LeftoversQuery.suggestions(recipes:cookedRecipeIDs:filters:)`
  where `cookedRecipeIDs` comes from persisted `CookedEvent`s. **Pass your real
  `FeedFilters`** so safety still applies.
- **Accept:** suggestions overlap on ingredients; derived from cooked history
  only; recently-cooked not re-suggested; no intolerance violations.

### #10 — Onboarding + taste calibration *(needs #6)*
- **Build:** ask intolerances (required) + household size (1 question); infer
  units/language from `Locale` (no GPS prompt). Taste calibration = a real
  vertical-scroll/tap mini-flow.
- **KartaCore:** build `OnboardingProfile(intolerances:householdSize:)` →
  `profile.feedFilters` seeds the first feed. Use `TasteCalibration.tap(_:)`
  for calibration taps — **these must NOT call `Cookbook.save`** (never consume
  the save cap).
- **Accept:** collects intolerances+household; locale-inferred units; real
  mini-flow; non-generic first feed; calibration leaves save cap untouched.

### #13 — Share recipe *(needs #2)*
- **Build:** a share action on recipe detail presenting the native share sheet.
- **KartaCore:** `RecipeShare.payload(for: recipe)` → feed `payload.text` and
  `payload.url` into a `UIActivityViewController` / `ShareLink`.
- **Accept:** share action present; native sheet; payload names the recipe +
  carries its reference URL.

### #14 / #11 — Freemium + shopping list *(`hitl` — discuss with Nico first)*
- #14 needs StoreKit product/pricing decisions and a paywall — product-level,
  not auto-buildable. There is currently **no** freemium/premium type in
  KartaCore; design it test-first there once Nico decides the model.
- #11 (shopping list) is blocked by #14. The list itself (collect a recipe's
  `ingredients`, toggle checked state) is pure logic to add to KartaCore when
  unblocked.

---

## 5. Seed data reference *(void — the seed is being rewritten)*

The table below describes the Spanish, metric, `lactose`-tagged seed. ADRs 0002,
0005 and 0006 replace it with an English, US-unit catalog on a closed allergen
vocabulary with declared servings and an explicit review state. Kept only so the
migration can be checked against what was there.

| id | difficulty | contains | popularity | timer step? | clip? |
|----|-----------|----------|-----------|-------------|-------|
| tortilla-de-papa | easy | egg | 95 | ✓ | cuajar-tortilla |
| pasta-al-pesto | easy | gluten, lactose, nuts | 90 | ✓ | — |
| pollo-al-curry-rapido | easy | — | 88 | ✓ | sellar-pollo |
| panqueques-de-banana | easy | gluten, lactose, egg | 85 | — | — |
| wok-de-vegetales | easy | gluten | 80 | — | — |
| salmon-al-horno | medium | fish | 75 | ✓ | punto-salmon |
| ensalada-cesar | easy | gluten, lactose, egg, fish | 72 | — | — |
| guiso-de-lentejas | medium | — | 70 | ✓ | — |

Manual safety check: filtering `gluten` should drop pasta-al-pesto,
panqueques, wok, ensalada-cesar from the feed and leave the rest.
