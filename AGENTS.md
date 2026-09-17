# Karta — Working agreement

Karta is a SwiftUI/iOS recipe app. Product scope: `docs/PRD-karta-mvp.md`.
Work is tracked as GitHub issues on `nicoamigosa/karta` and resolved by the
unattended loop in `ralph/` (see `ralph/README.md`). This file is the single
source of truth for agents; `CLAUDE.md` and `CODEX.md` only point here.

## Architecture — keep logic in KartaCore

The repo has two targets with two different build environments:

| Target | Where it lives | Builds & tests on | Command |
|---|---|---|---|
| `KartaCore` (SwiftPM library) | `KartaCore/` | Linux (WSL) **and** macOS | `cd KartaCore && swift test` |
| `Karta` (SwiftUI iOS app) | `Karta/` (not scaffolded yet — issue #1) | macOS only | `xcodebuild -scheme Karta -destination 'platform=iOS Simulator,name=iPhone 16' test` |

- **All pure domain logic lives in `KartaCore`.** It is pure and deterministic:
  no I/O, no ML, no UIKit/SwiftUI imports. Push as much as possible into it —
  if a UI issue needs new logic, add it to `KartaCore` with tests first, then
  consume it from the view.
- The iOS app is a **thin shell** over `KartaCore`: it links the local package
  and renders it. No business rules in views or view models.
- **Feed safety (intolerance filtering) is a critical guarantee.** Cover it
  exhaustively (`FeedQuerySafetyTests`) and never regress it. Never bypass
  `FeedQuery` from the UI.
- Toolchain: Swift 6.3 (`swift-tools-version: 6.0`). Tests use **Swift Testing**
  (`import Testing`, `@Test`, `#expect`/`#require`), never XCTest.
- Keep the Xcode project declarative and regenerable (XcodeGen `project.yml`)
  so it can be edited from Linux and reviewed as text.

### Environment notes

- On WSL, source Swiftly before any `swift` command:
  `. "$HOME/.local/share/swiftly/env.sh"`.
- On Linux the iOS target **cannot** be built. When reviewing a PR that touches
  `Karta/` from Linux, run `swift test` locally and rely on the `ios` CI check
  for the app target. Do not fake a simulator verification.
- Issues whose acceptance requires the simulator are only closed from a macOS
  host (the macOS VM). From Linux, such a PR says `Part of #N`, not `Closes #N`.

## Gates

Every PR must be green on all of these before merge:

1. `cd KartaCore && swift test` — the full suite, no skipped tests.
2. CI (`.github/workflows/ci.yml`): `core` job on Linux always; `ios` job on
   macOS once the app target exists.
3. The reviewer's `<verdict>PASS</verdict>` (see `ralph/prompt_review.md`).

Never weaken a gate: no skipped tests, no `@Test(.disabled)`, no lowered
expectations.

## Workflow (ralph conventions — common to all projects)

- Issues ready for an agent carry the label **`ready-for-agent`**. Issues that
  need a human decision (design sign-off, product, StoreKit) carry
  **`ralph-needs-human`** and are never picked up by the loop.
- Issue bodies declare dependencies with `## Blocked by` (`- #N` per line) and
  epics with `## Parent` (`#N`). Do not start an issue while a blocker is open.
- One branch per issue, from up-to-date trunk: **`ralph/issue-<N>`**. Never
  commit issue work to `main`.
- Build with the `tdd` skill: one failing test → minimal code → green →
  refactor. Vertical slices, one behavior at a time. Never write all tests up
  front. Match the location, naming and style of the existing tests.
- Commit body ends with `Closes #<N>` (or `Part of #<N>` when the issue is not
  verifiably done) and the `Co-Authored-By` trailer of the agent that wrote it.
- Open the PR against `main` with the sections `ralph/prompt_implement.md`
  requires (`What changed`, `Seams under test`, `How I verified`,
  `Open decisions`, `Acceptance criteria`).
- The loop merges (`--squash`) and closes the issue. Agents never merge, never
  approve, never close issues themselves.

## Pipeline

```
Nico  →  design / PRD (Claude Code)  →  GitHub issues (ready-for-agent)
      →  ralph: Codex implements (tdd) → PR → Claude reviews → PASS + CI → merge
      →  WSL for KartaCore issues · macOS VM for iOS/UI issues
```
