# Issue #150 — The cooking session at AX3–AX5

Implementation and verification of the six signed decisions of #149:
the Temporizador label under the time, the media window's chip under the
window and the short signal chip, from AX3 (`accessibility-extra-large`)
up. AX1/AX2 and the default size do not change.

## Environment

- Simulator: iPhone 17 — iOS 27.0 (E0224A22-F874-4B8C-83FB-EB084492C493).
- Build: Xcode 27.0 RC (`/Applications/Xcode-27.0-RC.app`), Debug, bundle id
  `app.karta.Karta`, seeds via `SIMCTL_CHILD_KARTA_SEED`
  (`cooking-timer`, `cooking-t1-running`, `cooking-t1-paused`,
  `cooking-t1-done`, `cooking-clip`, `cooking-clip-unavailable`).
- Tested commit: see the branch head of `ralph/issue-150`.

## Content-size mapping

| Size | `simctl` name | UIKit constant |
|---|---|---|
| AX1 | `accessibility-medium` | `UICTContentSizeCategoryAccessibilityM` |
| AX2 | `accessibility-large` | `UICTContentSizeCategoryAccessibilityL` |
| AX3 | `accessibility-extra-large` | `UICTContentSizeCategoryAccessibilityXL` |
| AX4 | `accessibility-extra-extra-large` | `UICTContentSizeCategoryAccessibilityXXL` |
| AX5 | `accessibility-extra-extra-extra-large` | `UICTContentSizeCategoryAccessibilityXXXL` |

Every capture was taken after setting `xcrun simctl ui <device>
content_size <name>` and reading the value back. Growth is confirmed by
comparing the same Paso (Paso 2, *Fry until tender*) across the default,
AX1, AX3 and AX5 captures.

## Captures

### AX3 — `accessibility-extra-large`

- `iphone17-ios27-ax3-t1-ready.png` — ready, end of the scroll: `12:00`
  over `TIMER`, brand play circle on the right. Matches the ready state of
  `cooking-ax-timer-paused-ax3.png`'s layout.
- `iphone17-ios27-ax3-t1-running.png` — running: `11:47` over `LEFT`,
  pause circle on the right; the time does not move vs ready/paused.
  Matches `cooking-ax-timer-running.png`.
- `iphone17-ios27-ax3-t1-paused.png` — paused: `8:15` over `PAUSED`,
  reset ↺ and play circles centred on the two-line block. Matches
  `cooking-ax-timer-paused-ax3.png`.
- `iphone17-ios27-ax3-t1-done.png` — *Time's up* wraps between its two
  words; `Stop` on the right inside its pill. Matches
  `cooking-ax-timer-done.png`.
- `iphone17-ios27-ax3-photo-chip.png` — photo Paso, top of the scroll:
  the chip's text *When it looks like this, move on* sits under the
  window on the 20 pt inner edge with no fill, wrapping; the signal chip
  reads `3 more`. Matches `cooking-ax-photo.png`.
- `iphone17-ios27-ax3-short-photo.png` — the short photo Paso *Preheat
  the oven* (seed `cooking-short-photo`): the window keeps its full
  220 pt with the chip text under it and the card does not scroll — the
  give-way order (free space to 20 pt, then the window 220 → 160, then
  scroll) still holds now that the under-window chip's height counts in
  `mediaHeight`'s `rest`.

### AX5 — `accessibility-extra-extra-extra-large`

- `iphone17-ios27-ax5-t1-ready.png` — `12:00` over `TIMER`.
- `iphone17-ios27-ax5-t1-running.png` — `11:50` over `LEFT`. Matches
  `cooking-ax-timer-running.png`.
- `iphone17-ios27-ax5-t1-paused.png` — `8:15` over `PAUSED`; neither the
  time nor the label breaks in the middle; both 44 pt circles on the
  right. Matches `cooking-ax-timer-paused-ax5.png`.
- `iphone17-ios27-ax5-t1-done.png` — `Time's` / `up` wraps between
  words; `Stop` stays inside its pill. Matches `cooking-ax-timer-done.png`.
- `iphone17-ios27-ax5-clip-top.png` — clip Paso, top of the scroll: the
  signal chip reads `4 more`.
- `iphone17-ios27-ax5-clip.png` — clip Paso mid-scroll: `Flip the
  tortilla · 6 s` under the window in one line, the play circle centred
  and uncovered, `2 more` on the fade. Matches `cooking-ax-clip.png`.
- `iphone17-ios27-ax5-clip-unavailable.png` — after tapping play on the
  unavailable clip: `⊚ Clip unavailable` under the window with its
  warning glyph, the play circle gone.

### Unchanged sizes — references

- `iphone17-ios27-default-t1-paused.png` — default size (`large`): the
  chip is still a `card` pill inside the window, the zone is pinned and
  `8:15 PAUSED` sits in one row. Matches `cooking-timer-paused.png`.
- `iphone17-ios27-xxxl-t1-paused.png` — xxxL reference: same pinned zone
  and in-window chip.
- `iphone17-ios27-ax1-t1-paused.png` — AX1: the zone scrolls (#146) but
  the row stays `8:15 PAUSED` in one line and the chip stays inside the
  window. Matches `cooking-step-ax.png`.

## Findings

- All six signed decisions verified on device at the stated sizes; the
  time never moves between ready, running and paused, no word and no
  time breaks in the middle, and nothing is truncated.
- The clip's `· 6 s` tail is bound with non-breaking spaces, so it wraps
  as one unit when it wraps at all.
