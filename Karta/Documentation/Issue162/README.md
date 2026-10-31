# Issue162 — Premium (local StoreKit)

Simulator captures for the premium boards in `docs/design/screens/`.
Each `compare-*.png` puts the signed-off board on the left and the
simulator capture on the right; `sim-*.png` are the raw captures.
`-ax1` files are the same state at accessibility-medium content size,
set with `xcrun simctl ui <device> content_size accessibility-medium`
and read back before shooting.

Environment: iPhone 17 simulator, iOS 27.0
(E0224A22-F874-4B8C-83FB-EB084492C493), Xcode 27.0 (27A266a), tested at
commit `b9bb7a5` on `ralph/issue-162`. Every capture is a real app
launch seeded with `SIMCTL_CHILD_KARTA_SEED=<name>`; premium seeds are
applied by `DebugSeeds.afterPremiumLaunch` after
`PremiumController.start()` so the launch-time entitlement report does
not overwrite them.

| Board | Seed | What it shows |
|---|---|---|
| premium-paywall | `premium-paywall` | Paywall risen from K3's "Unlock unlimited cookbook" (entry `.cap`, 7 of 7 saved) |
| premium-paywall-buying | `premium-paywall-buying` | `.buying`: content dimmed, "Waiting for the App Store…" spinner button |
| premium-paywall-error | `premium-paywall-error` | `.failed`: inline error note and "Try again" — never an alert |
| premium-paywall-pending | `premium-paywall-pending` | `.pending` (Ask to Buy): approval note and Close |
| premium-paywall-no-trial | `premium-paywall-no-trial` | Products without an intro offer: "Go Premium", no trial copy |
| premium-paywall-restore-empty | `premium-paywall-restore-empty` | "Nothing to restore" toast over the open paywall (`.restoreFoundNothing`) |
| premium-paywall-entry | `premium-paywall-entry` | Paywall over the recipe reverse from a non-cap way in (3 of 7 saved) |
| premium-welcome | `premium-welcome` | Celebration after purchase: card-backs fan, "Vegetable Noodle Stir-Fry is saved" |
| premium-save-toast | `premium-save-toast` | Sixth save: "1 spot left" toast with the underlined "See plans" way in |
| premium-world-menu | `premium-world-menu` | "Go Premium" row in the Mundo menu (free users only) |
| premium-cookbook-go-unlimited | `premium-cookbook-go-unlimited` | Cupo line "6 of 7 saved on the free plan · Go unlimited" |
| premium-cookbook-trial | `premium-cookbook-trial` | "Free trial until Nov 7 · Manage" |
| premium-cookbook-premium | `premium-cookbook-premium` | "Premium · Manage" |
| premium-cookbook-full-downgraded | `premium-cookbook-full-downgraded` | K3 after premium expired: "Your cookbook keeps all 23 recipes on the free plan" |

Notes:

- The `.cap` paywall and the downgraded K3 sheet render inside the recipe
  reverse; every other entry renders in the feed overlay, which still
  sits above an open reverse — that is why `premium-paywall-entry` shows
  the paywall over the recipe.
- The celebration honours Reduce Motion (a single fade instead of the
  falling card backs, via `accessibilityReduceMotion` in
  `PaywallView.swift`). `sim-premium-welcome-reduce-motion.png` was
  captured with `defaults write com.apple.Accessibility
  ReduceMotionEnabled -bool true`; the resting frame is identical — the
  difference is the animation, not the layout.
- Terms of Use / Privacy Policy footer links point at the
  `PremiumLinks` placeholders pending the real pages.
