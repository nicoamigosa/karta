# Issue #172 — First open and onboarding, verification shots

Simulator: iPhone 17 (iOS simulator runtime from Xcode 27.0 RC;
`/Applications/Xcode-27.0-RC.app`).
Xcode: 27.0 (Release Candidate).
Tested commit: `a4a08c8bfa5c5145b6d5b0d29fc776b831841856` (the shots were
taken against that build; this README line was filled in afterwards).

Every state is driven by `KARTA_SEED=<name>` (launched via
`SIMCTL_CHILD_KARTA_SEED=<name> xcrun simctl launch`), one relaunch per
shot. AX1 = `xcrun simctl ui <device> content_size accessibility-medium`
(read back: `accessibility-medium`); the simulator's content size was
restored to `large` afterwards. Reduce Motion = `defaults write
com.apple.Accessibility ReduceMotionEnabled -bool true` on the device
(restored to `false` afterwards).

## Shots

| File | Seed | Size | State |
|---|---|---|---|
| `shots/01-tour-cookbook.png` | `onboarding` | default | Tour stop 1: spotlight + brand ring on the cookbook door, "Tap anywhere to skip to the filter" |
| `shots/02-tour-world.png` | `onboarding-tour-world` | default | Tour stop 2: spotlight on the Mundo pill |
| `shots/03-tour-filters.png` | `onboarding-tour-filters` | default | Tour stop 3: spotlight on the filter button, no skip line (the ring pulse every 1.4 s is animated) |
| `shots/04-panel-empty.png` | `onboarding-panel-empty` | default | First-run panel, no answers yet: "Show my cards" in the disabled look |
| `shots/05-banner.png` | `onboarding-banner` | default | The Baraja segura banner ("Free of all five allergens until you tell us yours." / Set mine), tour over |
| `shots/06-panel.png` | `onboarding-panel` | default | First-run panel with Dairy + Hogar 4 chosen: "Show my cards" live |
| `shots/07-panel-none.png` | `onboarding-panel-none` | default | First-run panel, Hogar 2, "none" intolerance line |
| `shots/08-filters-household.png` | `filters-household` | default | Full filter panel: COOKING FOR between NEVER SHOW ME and READY IN, Hogar 4 saved |
| `shots/09-tour-reduce-motion.png` | `onboarding` | default + Reduce Motion | Stop 3 alone on first launch, no pulse, no skip line |
| `shots/10-tour-ax1.png` | `onboarding-tour-filters` | AX1 | Stop 3: full-width bubble between the 22 pt margins |
| `shots/11-panel-ax1.png` | `onboarding-panel` | AX1 | First-run panel stacked, track one option per row |
