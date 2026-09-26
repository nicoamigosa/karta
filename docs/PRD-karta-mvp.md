# Karta — MVP PRD

> Status: Draft for v0 build. Synthesized from the product grilling session (2026-06-12).
> Target beachhead: Spanish/Latina women cooking daily for a household in the USA (seed: Charlotte, NC). English-first.

---

## Problem Statement

Home cooks who are responsible for feeding a household face the same painful decision **twice a day, every day**: *"What do I cook?"* Our concrete persona is **Paola** — an American woman of Hispanic heritage, ~28–42, who cooks daily for her household, has disposable income, and is an intermediate-to-beginner cook.

Today she solves this by scrolling TikTok and Instagram looking for ideas. This fails her in specific ways:

- **The format works against deciding.** Infinite social feeds are built to keep her scrolling, not to help her *decide*. She loses an hour and still hasn't chosen dinner. The tool meant to help is the source of the stress.
- **The recipes are unreliable.** Social recipes are often badly explained, missing ingredients, or missing steps. She follows one and it doesn't come out right.
- **The experience is fragmented.** She hops between apps and platforms, adding friction and overhead to something she must do every single day.
- **Leftover anxiety.** She buys ingredients for one recipe, has some left over, and doesn't know how to reuse them — so they go to waste.
- **No trusted personal repertoire.** Her "saved" folders on Instagram are full of recipes she will never actually cook — a folder of guilt, not a usable cookbook.

The core emotional state to relieve is **decision anxiety**, not boredom. The enemy is not TikTok; it is the daily suffering of "what do I cook today?"

## Solution

**Karta** is an iOS app that helps Paola **decide what to cook — fast** — and then cook it successfully, using a familiar card/feed format but optimized for *deciding*, not for endless scrolling.

- A vertical **deck** of full-screen recipe **cards** (appetizing hero photo + name + key info), one card per screen, passed like a deck of cards (ADR 0012). She browses, and when one grabs her, she opens it and can **cook it step by step**.
- Every recipe is **curated and verified** so it is complete and actually works — the opposite of the unreliable social recipes. This trust is the core differentiator versus TikTok/Instagram, where Karta can never win on quantity.
- Recommendations come from **hard filters + popularity/freshness + don't-repeat** logic (no ML at launch).
- A **step-by-step cooking mode** built for real kitchen conditions (messy hands, multitasking).
- A growing **personal cookbook of "what I actually cooked and liked"**, plus a **light leftovers loop** ("you cooked X, here are recipes that reuse similar ingredients") and an auto-generated **shopping list**.

Success is measured as **"the session ended in a decision"** (she entered cooking mode / reached the end of a recipe), with *time-to-decide* as a secondary quality metric. A short session is only good if it ended in a decision; a short session with no decision is the red alarm.

## User Stories

### Browsing & deciding (the core loop)
1. As Paola, I want a vertical deck of full-screen recipe cards I pass one at a time (like Reels/Shorts, but photos), so that browsing feels familiar and low-effort.
2. As Paola, I want each card to show an appetizing photo, the name, and key info (time, servings, difficulty), so that I can judge quickly whether to open it. The card gives cues, not a description; tags and details live behind the open.
3. As Paola, I want to tap a card (or swipe right) to open the full recipe, so that I can see ingredients and the complete method.
4. As Paola, I want the feed to *not* repeat recipes I've already seen recently, so that browsing feels fresh day after day.
5. As Paola, I want to reach a dinner decision in a couple of minutes, so that I stop suffering over the choice.
6. As Paola, I want the feed prioritized by popularity and freshness within my filters, so that what I see is relevant without me configuring much.

### Top navigation (the three worlds)
7. As Paola, I want a central dropdown at the top (Instagram-style) to switch between **For You**, **Saved**, and **Leftovers**, so that I can move between my personal worlds quickly.
8. As Paola, I want **For You** to be my personalized feed, so that I see relevant options first.
9. As Paola, I want **Saved** to be my personal cookbook, so that I can return to recipes I chose to keep.
10. As Paola, I want **Leftovers** to surface recipes that reuse ingredients from things I recently cooked, so that I waste less food.

### Cooking mode (step by step)
11. As Paola, I want to enter step-by-step mode by swiping right on a recipe (like stories of one profile), so that cooking feels natural and guided.
12. As Paola, I want to advance to the next step by swiping right and go back with swipe left, so that I can move at my own pace.
13. As Paola, I want to exit cooking mode by swiping down, so that closing is intuitive and doesn't clash with step navigation.
14. As Paola, I want each step to show the exact ingredient and quantity needed *for that step*, so that I never have to scroll back to the full list with messy hands.
15. As Paola, I want the screen to stay awake during cooking mode, so that I don't have to unlock with dirty fingers.
16. As Paola, I want large text readable from a half-meter away on the counter, so that I can read while cooking.
17. As Paola, I want large tap targets (e.g. tap half the screen to advance), so that I can progress with messy hands.
18. As Paola, I want embedded timers in steps ("simmer 10 min"), so that I can time things without leaving the app and getting lost.
19. As Paola, I want to reach the final step and be prompted *"How did it turn out?"* (👍 / 👎), so that I can capture the result.

### Saving & the personal cookbook
20. As Paola, I want to save a recipe with a visible button (a kitchen/recipe-box icon) plus a satisfying animation, so that saving is obvious and clearly means "keep," not "like."
21. As Paola, I want saved recipes collected in my cookbook, so that I have a personal repertoire to fall back on.
22. As Paola on the free tier, I want to save up to a small number of recipes (7), so that I can try the feature, and be invited to upgrade when I hit the limit.
23. As Paola, I want my "cooked and saved" recipes to build my real repertoire automatically, so that I have a trusted go-to list distinct from my aspirational saves.

### Cooked tracking & leftovers
24. As Paola, I want marking a recipe as cooked (via the "how did it turn out?" prompt) to feed my repertoire and leftovers, so that the app learns what I actually make.
25. As Paola, I want the app to also infer "probably cooked" if I reach the last step and spend enough time, so that my history is captured even if I don't tap.
26. As Paola, I want leftover-driven suggestions based on what I recently cooked, so that I can reuse surplus ingredients without keeping an inventory.

### Onboarding
27. As a new user, I want a minimal onboarding that asks only my **intolerances/allergies** (required) and **household size**, so that I can start fast without a long form.
28. As a new user, I want a quick taste calibration that works like the real app (real vertical scroll, tap what appeals), so that my first feed isn't generic and I learn the gestures.
29. As a new user, I want units and language inferred silently from my device locale, so that I'm not asked for GPS permission before I see value.
30. As a celiac/allergic user, I want intolerance filtering to be reliable on every recipe, so that I can trust the app with my safety.

### Filters
31. As Paola, I want to filter by my intolerances (gluten / dairy / nuts to start), so that I only ever see safe recipes.
32. As Paola, I want to filter by cooking time ("I have 20 minutes"), so that recipes match the time I actually have today.
33. As Paola, I want to filter by difficulty (beginner / intermediate / advanced), so that I can match my confidence.
34. As Paola, I want one-pan / few-dishes recipes flagged as a tag, so that I can find low-cleanup meals.
35. As Paola, I want intolerance/safety filtering to always be free, so that my safety is never behind a paywall.

### Monetization (subscription / freemium)
36. As Paola, I want the daily decision loop and cooking mode free and unlimited, so that I can build the habit without friction.
37. As Paola, I want to subscribe to unlock an **unlimited cookbook** and an **auto shopping list**, so that the app saves me even more time and effort.
38. As Paola, I want a 7-day premium trial, so that I can experience the paid features before paying.
39. As Paola, I want to hit the upgrade prompt naturally *after* I've felt the value (e.g. when saving my 6th recipe), so that paying feels worth it rather than gated up front.
40. As Paola on premium, I want an ad-free / sponsor-free experience, so that what I paid for stays clean and trustworthy.

### Shopping list (premium)
41. As Paola (premium), I want an auto-generated shopping list from a recipe, so that I don't have to write ingredients down.
42. As Paola (premium), I want to check items off the list, so that I can shop efficiently.

### Content & trust
43. As Paola, I want every recipe to be complete (all ingredients, all steps, quantities, times), so that it actually comes out right.
44. As Paola, I want short reusable **technique clips** embedded only at non-obvious steps (e.g. how to dice an onion, how to tell the chicken is done), so that I can see how it's done.
45. As Paola, I want appetizing, high-quality hero photos, so that the feed makes me want to cook.

### Others
46. As Paola, I want to share a recipe with somebody through social media or messaging, so they can also cook it or shop for ingredients.

### Future-facing (captured but out of MVP scope — see Out of Scope)
47. As a user, I want to submit my own recipes, so that I can contribute (post-MVP, via review/quarantine).
48. As a brand/supermarket, I want to sponsor labeled recipes featuring my products, so that I can reach engaged cooks (post-MVP, free tier only).
49. As a user, I want a weekly meal planner, so that I can plan ahead (post-MVP premium).

## Implementation Decisions

### Product positioning
- Karta is a **decision/utility** product wearing a **feed aesthetic** — not a discovery/entertainment product. Every screen is judged by whether it moves Paola toward a cooking decision.
- **North-star metric:** % of sessions that end in a decision (entered cooking mode / reached recipe end), with time-to-decide as a secondary quality metric. The feed is intentionally low-cardinality (decide in ~10–15 cards), so it is **never capped** — capping the feed would fight the "decide fast" goal.

### The card
- On the feed, a **Card** is one full-screen block (photo + name + time · servings · difficulty) that moves as a unit; the feed advances card by card vertically, with a deck-of-cards transition. Swiping is never a verdict (no Tinder yes/no). See ADR 0012.
- Card = **high-quality hero photo + complete text steps + reusable technique clips** at non-obvious steps. No bespoke per-recipe video in MVP.
- Two distinct visual quality bars: **hero photo = high production / appetizing** (pro / stock / AI); **technique clips = clarity over production** (DIY phone, overhead, natural light, ~6s, reusable across many recipes). Steps with no useful clip stay text-only.

### Interaction & gesture model
- **Navigation = gestures; actions = buttons.**
- Feed: swipe = next/previous card, one full-screen card at a time, on a single axis (vertical by default; pending the usability test #86). The card follows the finger, springs back below the threshold and is thrown with the gesture's momentum above it. **Tap = open**: the card flips over and grows into the recipe detail (ingredients + method), from which cooking mode starts. Swiping never opens. Scroll-past = soft negative signal.
- Cooking mode: swipe right = next step; swipe left = previous step; swipe down = exit.
- **Save = visible button** in the recipe detail only (never on the feed card, ADR 0012) with a kitchen/recipe-box icon (explicitly *not* a heart, to avoid like-vs-save confusion) + animation. Optional double-tap shortcut deferred to v2.
- There is **no separate "like."** Only **Save** (explicit) + implicit behavioral signals (open, cook, scroll-past).

### Cooking mode
- Each step is **self-contained**: shows the ingredient + quantity for that step (no scrolling back).
- **Keep screen awake**, large legible text, large tap targets.
- **Embedded, in-app timers** in steps.
- End-of-recipe prompt *"How did it turn out?"* (👍/👎/📷) doubles as the **"cooked" event** (the success signal); also infer "probably cooked" from reaching the last step + dwell time.

### Top navigation
- Central Instagram-style dropdown = **For You / Saved / Leftovers** (NOT difficulty). Difficulty stays a filter + a card tag.

### Recommendation engine (MVP)
- **Hard filters + popularity/freshness + don't-repeat.** No ML at launch. ML deferred until there is real cooked-behavior data.

### Filters (MVP set)
- Intolerances (start with gluten / dairy / nuts — **safety, always free, must be reliably tagged on every recipe**) + cooking time + difficulty. One-pan = tag.
- **Cut from MVP:** budget, nutrition, store/aisle. (Store/products returns later as *sponsored content*, not as a feature.)

### Content strategy & production pipeline
- MVP feed is **100% curated and verified by the team**. Quality/trust is the only defensible edge vs TikTok.
- Differentiator = **American-Latina home cooking** content.
- Pipeline: **adapt already-proven recipes** (in the US, recipe ingredient lists + functional steps are not copyrightable — only literary expression and photos are; so steps are rewritten in Karta's clear format with original/licensed photos) → **AI formats** to the standard structure → **human editor (the founder's wife) tests, edits, and tags** intolerances by hand → photo.
- **Catalog staging:** private beta with the Charlotte network at **~100 recipes** to validate the core loop; **300 recipes** for public launch, produced in parallel.
- **UGC and Instagram/TikTok import are OUT of the MVP** (quality + legal). Future UGC enters via a **quarantine + threshold of successful cooks** (adaptive N) or human review; nothing user-submitted reaches Paola's feed until it earns it.

### Persona & market
- Beachhead = **Paola**: woman ~28–42, daily household cook, intermediate-low skill, has income. Explicitly **not** optimizing for young learners or older cooks in MVP.
- Market = **USA, seeded in Charlotte, NC, English-first.** The founder's wife is the live persona *and* the distribution wedge (her network) *and* the content editor *and* the graphic designer.
- Approach: **test demand broad** (cheap landing pages / ads across markets and languages), **build content narrow** (one market/language).

### Monetization
- **Subscription only** at MVP. **No ads. No creator payouts.**
- **Freemium line:**
  - **Free (the habit):** feed + deciding + step-by-step cooking + safety/intolerance filters + time/difficulty filters + saving (capped 5–10).
  - **Paid (compounding value):** **unlimited cookbook + auto shopping list (+ light leftovers).**
- Upgrade prompt appears **after** value is felt (e.g. hitting the save cap), never as an entry wall.
- **Pricing (tunable, A/B later):** ~$6.99/mo or ~$49.99/yr (annual emphasized for LTV), **7-day premium trial**.

### Onboarding
- Minimal: **intolerances (required) + household size (1 question).** Everything else (taste, skill, cuisines) is learned from behavior.
- Taste calibration = **mini real-app flow** (real vertical scroll, tap what appeals) — teaches real gestures, does **not** consume the cookbook save cap.
- Units/language from **device locale** silently. **No GPS prompt.** No profile harvesting (iOS doesn't provide it).

### Platform & tech
- **iOS-only MVP**, **native SwiftUI** (best feel for a gesture/animation-led product). Android is a later rewrite.

### Look & feel (v1 direction, 2026-09-25 session; founder + designer decide)
- The v0 build (PR #78) read as **generic and flat**. v1 keeps the calm goal but asks for a far more **original, colourful, alive, friendly, homey, soft** identity, with **some relief** without losing modernity. Reference for *spirit* (not imitation): PostHog.
- **Brand concept:** *karta* = a card of a deck **and** *à la carte* / *la carta* (the menu). Each recipe is a card; the feed is a deck you pass. The concept drives the wordmark, the app icon, the card transition and the relief.
- **Palette:** warm light base (cream/paper) + two or three **saturated earthy accents**. Colourful ≠ stimulating: **no neon, no harsh high contrast**, no TikTok aesthetic.
- **Relief:** tactile, slightly retro UI — visible card edges, solid soft shadows, buttons that look pressable. Cards feel like physical cards in a stack.
- Humour in copy and a mascot/illustrations are **optional**: explored in at most one direction, never childish.
- **Photo leads**: the food photo is the hero of every card, but the card is a block (photo + info), not photo-only.
- **Light mode only** in the MVP (the app ignores system dark mode).
- Personality: warm, trustworthy, American-Latina homey; neither clinical-tech nor childish. Launch market is the US, so all brand language is English-first.
- Process (#15): 3–4 visual directions prototyped (moodboard, palette, type, a Card, the deck transition, wordmark + app icon), filtered by a separate visual critic, chosen and signed off by the founder and the designer, then turned into shared style tokens.

## Testing Decisions

> No code exists yet; these are the proposed seams and behaviors to test once the app is scaffolded. **Please confirm the seams match your expectations before implementation.**

- **Test external behavior, not implementation details.** A good test asserts what Paola observes (the feed advances, a safe recipe is shown, the timer fires, the save cap blocks the 6th save), not internal state shapes.
- **Highest-value seam — the recommendation/feed query.** Test the filter + popularity/freshness + don't-repeat logic as a pure function over a recipe set: given filters and seen-history, assert the returned ordering excludes seen recipes and never violates a safety filter. This is the single most important seam because **a safety-filter leak (showing gluten to a celiac) is a critical-severity bug.**
- **Safety filtering gets dedicated, exhaustive tests.** Every intolerance tag path must be covered; this is the one area where a false negative is dangerous, not cosmetic.
- **Cooking-mode state machine.** Test step navigation (next/prev/exit gestures), per-step ingredient display, and timer start/fire behavior as a state machine, independent of UI rendering.
- **Success-event detection.** Test that "entered cooking mode," "reached last step," and the "how did it turn out?" response correctly emit the cooked/decision events, and that "probably cooked" inference fires on last-step + dwell.
- **Freemium gating.** Test the save-cap boundary (free user blocked at the cap, premium unlimited) and that safety filters are reachable on the free tier.
- **Onboarding output.** Test that minimal onboarding produces a non-generic first feed seed and that taste calibration does not consume the save cap.
- **Prior art:** none yet (greenfield). Establish the pure-function feed/query seam as the reference pattern for future logic tests.

## Out of Scope

The following are explicitly **not** in the MVP (most are sequenced for v2+):

- **ML / personalized recommendation engine** — deferred until real cooked-behavior data exists.
- **Pantry / inventory tracking** — users hate manual inventory; leftovers in MVP are derived from "what you cooked," not an inventory.
- **User-generated content & Instagram/TikTok import** — quality + legal risk; future UGC enters via quarantine + successful-cook threshold or human review.
- **Creator payouts / "earn money per view"** — requires audience and revenue that don't exist at launch; a fintech operation in disguise.
- **Pure advertising / banners** — rejected outright (pays poorly, breaks the clean decision UX).
- **Sponsored recipes** (brands / supermarkets / restaurants, incl. "store + exact products" cards) — v2, **free tier only**, clearly labeled, same quality bar, never overriding safety filters.
- **Budget, nutrition, and store/aisle filters** — cut from MVP (store/aisle is effectively impossible without grocery-chain planogram data).
- **Weekly meal planner** — premium, but post-MVP.
- **Bespoke per-recipe video** — only reusable technique clips in MVP.
- **Voice control in cooking mode** — v2.
- **Double-tap-to-save shortcut** — v2 (button is the MVP mechanism).
- **Android** — later rewrite.
- **Markets beyond USA (Spain, Mexico, etc.)** — demand-test cheaply, but build content for USA/English first.

## Further Notes

- **Unfair advantages to exploit:** the founder lives with the literal target persona, who is also the content editor *and* the graphic designer *and* the seed distribution channel (her Charlotte network). Build the MVP literally for her; validate every decision in their own kitchen.
- **Tracker note:** this PRD could not be published to an issue tracker because the project is greenfield (no git repo, no tracker configured). Recommend `git init` and setting up the issue tracker, after which this can be split into independently-grabbable issues (e.g. via a tracer-bullet vertical-slice breakdown).
- **Naming:** working title "Karta" (from the project directory). Not yet validated as the product name.
