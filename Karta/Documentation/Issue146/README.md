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
- Tested commit: `000bb0e` (branch head; the app code is unchanged by this
  docs-only PR — the captures were taken on `6700cab`, which differs only
  by this evidence).

## Content-size mapping and verification

iOS has five accessibility sizes. `simctl`/`UIKit` names map like this:

| Size | `simctl` name | UIKit constant |
|---|---|---|
| AX1 | `accessibility-medium` | `UICTContentSizeCategoryAccessibilityM` |
| AX2 | `accessibility-large` | `UICTContentSizeCategoryAccessibilityL` |
| AX3 | `accessibility-extra-large` | `UICTContentSizeCategoryAccessibilityXL` |
| AX4 | `accessibility-extra-extra-large` | `UICTContentSizeCategoryAccessibilityXXL` |
| AX5 | `accessibility-extra-extra-extra-large` | `UICTContentSizeCategoryAccessibilityXXXL` |

Each capture was taken after setting `xcrun simctl ui <device> content_size
<name>` and reading the value back; growth is confirmed by comparing the
same Paso across the AX1, AX3 and AX5 captures. (`simctl` reports `unknown`
for writes outside its enum — the earlier draft of this README confused
that with "size not supported".)

## Captures

### AX1 — `accessibility-medium` (iPhone 17, iOS 27.0) — reference

- `iphone17-ios27-ax1-t1-running.png` — running: `11:57 LEFT` in one row.
- `iphone17-ios27-ax1-t1-paused.png` — paused: `8:15 PAUSED` in one row.
- `iphone17-ios27-ax1-t1-done.png` — `Time's up` in one row.
- `iphone17-ios27-ax1-clip.png` — clip Paso, media window fully on-screen.

### AX3 — `accessibility-extra-large` (iPhone 17, iOS 27.0)

- `iphone17-ios27-ax3-t1-running.png` — running row; digits do not cover
  the rule.
- `iphone17-ios27-ax3-t1-paused.png` — `8:15` fits; `PAUSED` wraps to
  `PAUSE\nD`.
- `iphone17-ios27-ax3-t1-done.png` — `Time's\nup` wraps; `Stop` inside pill.
- `iphone17-ios27-ax3-clip.png` — clip Paso with media window on-screen.

### AX5 — `accessibility-extra-extra-extra-large` (iPhone 17, iOS 27.0)

- `iphone17-ios27-ax5-t1-running.png` — `11:35 LEFT` + pause in one row;
  digits do not cover the rule.
- `iphone17-ios27-ax5-t1-paused.png` — `8:1\n5` and `PAUS\nED` both wrap;
  the row does not fit on one line. Digits still do not cover the rule.
- `iphone17-ios27-ax5-t1-done.png` — `Time's\nup` wraps; `Stop` stays
  inside its pill.
- `iphone17-ios27-ax5-clip.png` — clip Paso mid-scroll.

### AX5 — `accessibility-extra-extra-extra-large` (iPhone 17, iOS 26.5)

- `iphone17-ios265-ax5-clip-top.png` — clip Paso at top of scroll.
- `iphone17-ios265-ax5-clip-media.png` — the clip media window shrinks to a
  sliver at AX5 and its chip is truncated (`Flip the tortilla ·…` — the
  `6 s` duration is cut).
- `iphone17-ios265-ax5-clip-bottom.png` — bottom of the same Paso.

### Default size

- `iphone17-ios27-default-t1-running.png` — the zone still measures ~71 pt
  (210 px @3x), matching `docs/design/screens/cooking-timer-*.png`.
- `iphone17-ios265-default-t1-paused.png` — default-size reference.

## Findings

- At AX5: the digits never cover the rule and the `Stop` label stays
  inside its pill — the spec-covered constraints hold.
- At AX5 paused, the digits, the `PAUSED` label and the two buttons do not
  fit in one row (`8:1\n5`, `PAUS\nED`). At AX3 the row still fits but
  `PAUSED` wraps to `PAUSE\nD`. Per the issue, not redesigned — needs a
  design round.
- The clip media window at AX5 shrinks to a sliver and the chip truncates
  the clip's duration (`Flip the tortilla ·…`). Per the issue, described
  under Open decisions, not redesigned.
