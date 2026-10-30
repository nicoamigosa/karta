# Issue #146 — Temporizador T1 zone at large Dynamic Type sizes

Verification of the T1 bottom zone and the technique-clip media window at
accessibility text sizes, as a follow-up to #5 / PR #143 and PR #147.

## Environment

- Simulators: iPhone 17 — iOS 27.0 (E0224A22-F874-4B8C-83FB-EB084492C493) and
  iPhone 17 — iOS 26.5 (EDD9B083-63F1-44E6-9A7B-0A6964CC2561).
- Build: Xcode 27.0 RC (`/Applications/Xcode-27.0-RC.app`), Debug, bundle id
  `app.karta.Karta`, seeds via `SIMCTL_CHILD_KARTA_SEED`
  (`cooking-t1-running`, `cooking-t1-paused`, `cooking-t1-done`,
  `cooking-clip`).
- Tested commit: `6700cab` (tip of `ralph/issue-146` at capture time).

## Content size was really applied — and why there is no AX5

`xcrun simctl ui <device> content_size` was read back after every change and
the rendered text was compared pixel-wise between sizes.

- AX1 = `accessibility-extra-large`, AX3 =
  `accessibility-extra-extra-extra-large` — both verified applied (compare
  the AX1 and AX3 captures: the same Paso renders visibly larger).
- **AX5 does not exist on iOS 26.5 / iOS 27.0.** The `simctl` enum tops out
  at `accessibility-extra-extra-extra-large`, and `UIKitCore` in both
  runtimes only contains `UICTContentSizeCategoryAccessibility{M,L,XL,XXL,XXXL}`
  — there are no `XXXXL`/`XXXXXL` categories at all (AX4/AX5 were removed
  from UIKit in iOS 26; the largest Dynamic Type size on these runtimes is
  AX3). Writing `UICTContentSizeCategoryAccessibilityXXXXXL` into the
  device's `com.apple.UIKit` preferences makes `simctl` report `unknown` and
  the app falls back to default size:
  `iphone17-ios265-ax5-attempt-renders-default.png` (AX5 attempt) is
  pixel-identical to `iphone17-ios265-default-t1-paused.png`.
- So every "AX5" criterion is verified at **AX3 — the real OS maximum** on
  the available simulators. A real AX5 would need a device/simulator on
  iOS ≤ 18, which is not available here.

## Captures

### AX1 (iPhone 17, iOS 27.0) — reference

- `iphone17-ios27-ax1-t1-running.png` — running: digits + `LEFT` + pause in
  one row.
- `iphone17-ios27-ax1-t1-paused.png` — paused: `8:15` fits, `PAUSED` wraps
  to `PAUSE\nD`.
- `iphone17-ios27-ax1-t1-done.png` — Time's up: label wraps, `Stop` inside
  its pill.
- `iphone17-ios27-ax1-clip.png` — clip Paso with the media window fully
  on-screen (`Flip the tortilla · 6 s`).

### AX3 = maximum size (iPhone 17, iOS 27.0)

- `iphone17-ios27-ax3-t1-running.png` — running: `11:35` + `LEFT` + pause in
  one row; digits do not cover the rule.
- `iphone17-ios27-ax3-t1-paused.png` — paused: `8:1\n5` and `PAUS\nED` both
  wrap; the row does not fit on one line. Digits still do not cover the
  rule.
- `iphone17-ios27-ax3-t1-done.png` — Time's up: `Time's\nup` wraps; `Stop`
  stays inside its pill.
- `iphone17-ios27-ax3-clip.png` — clip Paso mid-scroll.

### AX3 = maximum size (iPhone 17, iOS 26.5)

- `iphone17-ios265-ax3-clip-top.png` — clip Paso at top of scroll.
- `iphone17-ios265-ax3-clip-media.png` — the clip media window shrinks to a
  sliver at AX3 and its chip is truncated (`Flip the tortilla ·…` — the
  `6 s` duration is cut).
- `iphone17-ios265-ax3-clip-bottom.png` — bottom of the same Paso.

### Default size

- `iphone17-ios27-default-t1-running.png` — the zone still measures ~71 pt
  (210 px @3x), matching `docs/design/screens/cooking-timer-*.png`.
- `iphone17-ios265-default-t1-paused.png` — default-size reference used for
  the AX5-fallback comparison.

## Findings

- At the real maximum size (AX3): the digits never cover the rule and the
  `Stop` label stays inside its pill — the spec-covered constraints hold.
- At AX3 paused, digits + `PAUSED` + the two buttons do not fit in one row
  (digits and label wrap). Per the issue, not redesigned — needs a design
  round.
- The clip media window at AX3 shrinks to a sliver and the chip truncates
  the clip's duration (`Flip the tortilla ·…`). Per the issue, described
  under Open decisions, not redesigned.
