# Karta — Working agreement

Karta is a SwiftUI/iOS recipe app. Product scope: `docs/PRD-karta-mvp.md`.
Work is tracked as GitHub issues on `nicoamigosa/karta`. Linux issues
(`ralph-host:linux`) are resolved by the unattended loop in `ralph/` (see
`ralph/README.md`); iOS shell issues (`ralph-host:macos`) are implemented by
Devin on macOS, outside the loop (see "The macOS side"). This file is the single
source of truth for agents; `CLAUDE.md` and `CODEX.md` only point here.

`ralph/` is an **installed release** of [`nicoamigosa/ralph`](https://github.com/nicoamigosa/ralph)
(`ralph/VERSION` says which; `ralph/MANIFEST` lists the distributed paths).
Never edit it here: fix it upstream, cut a release and run
`ralph/update.sh <VERSION>` (verifies the tarball against `SHA256SUMS` and
refuses local edits). Project-specific overrides go in `.ralph/` (see
"Niveles de configuración" in `ralph/README.md`). The hardening backlog from
the 2026-09 review (`docs/reviews/2026-09-astra-ralph.md`) is fully closed as
of v1.2.0. The loop requires a ruleset without bypass on the base branch and a
read-only reviewer token (`RALPH_REVIEWER_GH_TOKEN`). Both exist since
2026-09-22 (`docs/reviews/2026-09-astra-pipeline-runbook.md`): `main` only
accepts PRs with the `gate` check green, with no bypass for anyone.

## Architecture — rules in Core, state in Presentation, rendering in Karta

The repo has two SwiftPM library targets and one iOS app target:

| Target | Where it lives | Builds & tests on | Command |
|---|---|---|---|
| `KartaCore` (SwiftPM library) | `KartaCore/Sources/KartaCore/` | Linux (WSL) **and** macOS | `cd KartaCore && swift test` |
| `KartaPresentation` (SwiftPM library) | `KartaCore/Sources/KartaPresentation/` | Linux (WSL) **and** macOS | `cd KartaCore && swift test` |
| `Karta` (SwiftUI iOS app) | `Karta/` (not scaffolded yet — issue #1) | macOS only | CI job `ios`: `xcodebuild … test` on the first available iPhone simulator |

**Three layers, and the compiler enforces the boundary** (ADR 0001):

- **`KartaCore` — the rules.** Pure and deterministic: no I/O, no ML, no clocks
  of its own, no UIKit/SwiftUI, and no knowledge of any screen. "Is this recipe
  safe for someone with a dairy intolerance?" lives here. It never imports
  `KartaPresentation`.
- **`KartaPresentation` — the state.** Screen state, reducers, formatting, the
  observable store, and the resource adapter that loads the bundled seed.
  Bundled resources (the seed JSON) belong to this target; `KartaCore` only
  decodes `Data` (ADR 0001). Imports `KartaCore`. Everything here is still testable with `swift test` on
  Linux — that is the whole point of the split.
- **`Karta` — the shell.** Rendering, gestures, storage, media playback,
  timers, sound and haptics. No business rules in views or view models. If a UI
  issue needs new logic, it goes into one of the two packages with tests first,
  then gets consumed from the view.

If you are unsure which of the two packages something belongs in, ask: *could
this be wrong in a way a Linux test would catch?* If yes, it is not UI.
- **Feed safety (intolerance filtering) is a critical guarantee.** Cover it
  exhaustively (`FeedQuerySafetyTests`) and never regress it. Views reach
  recipes through the `KartaPresentation` store, never by calling or bypassing
  `FeedQuery` themselves.
- Toolchain: Swift 6.3 (`swift-tools-version: 6.0`). Tests use **Swift Testing**
  (`import Testing`, `@Test`, `#expect`/`#require`), never XCTest.
- Keep the Xcode project declarative and regenerable (XcodeGen `project.yml`)
  so it can be edited from Linux and reviewed as text.

### Environment notes

- On WSL, source Swiftly before any `swift` command:
  `. "$HOME/.local/share/swiftly/env.sh"`.
- On Linux the iOS target **cannot** be built. When reviewing a PR that touches
  `Karta/` from Linux, run `swift test` locally and rely on the `gate` CI check
  (which includes the iOS job) for the app target. Do not fake a simulator verification.
- Issues whose acceptance requires the simulator are only closed from a macOS
  host. From Linux, such a PR says `Part of #N`, not `Closes #N`.

## Domain

Two documents define what the words mean and why things are the way they are.
**Read both before designing anything**; they outrank this file on questions of
domain, and they outrank the older `docs/mac-handoff.md` everywhere they overlap.

- **`CONTEXT.md`** — the glossary. Use exactly these terms in code, issues,
  commits and PRs. It is opinionated: where several words exist, it names the
  one to use and lists the ones to avoid. If you need a term it does not
  define, add it there in the same PR rather than inventing a synonym.
- **`docs/adr/`** — the decisions, numbered and dated. Each one records a choice
  that was expensive to make and would otherwise look arbitrary. Do not
  silently contradict an ADR: if one is wrong, supersede it with a new ADR in
  the same PR that changes the behaviour.

Several ADRs deliberately contradict `docs/reviews/2026-09-astra-core.md`. The
review set the agenda; the ADRs hold the answers.

## Gates

Every PR must be green on all of these before merge:

1. `cd KartaCore && swift test` — the full suite, no skipped tests.
2. CI (`.github/workflows/ci.yml`): the `gate` check green. It aggregates
   `KartaCore (Linux)` and, from #1 on, the iOS Simulator job (skipped only
   for documentation-only PRs). `gate` is the only check the ruleset and ralph
   require.
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
- ralph merges its own PRs (`--squash`) and closes the issue. Devin PRs: Nico
  runs the ralph reviewer on the PR and merges only with a PASS for the current
  head and `gate` green. Implementing agents (Codex, Devin) never merge, never
  approve, never close issues themselves.
- Issues whose content needs the editor's sign-off (e.g. #32, seed and allergen
  tagging) carry `ralph-needs-human`: the loop must not merge them on its own.

### Running ralph in Karta

```bash
. "$HOME/.local/share/swiftly/env.sh"
set -a; . ~/.config/ralph/reviewer.env; set +a      # RALPH_REVIEWER_GH_TOKEN (read-only)
RALPH_REQUIRED_CHECKS_JSON='["gate"]' \
RALPH_TDD_SKILL=$HOME/.codex/skills/tdd/SKILL.md \
./ralph/once.sh
```

Add `RALPH_DRY_RUN=1` first to check the preflight and the plan. Host routing
is active (ralph ≥ 1.2): every open issue carries exactly one
`ralph-host:linux` or `ralph-host:macos`, and ralph on WSL only takes the
Linux ones. `RALPH_ISSUE_ORDER` only orders.

### The macOS side

There is no macOS host running this loop. Everything that needs Xcode, a
simulator, gestures, media playback or accessibility is handed to **Devin**,
which does **not** run ralph: it receives an already-verified contract and
builds the shell against it. Devin never merges and never closes issues.

The step-by-step procedure (states, review, merge, and what to do when Devin
needs contract or a ralph PR breaks the app) is `docs/devin-playbook.md`.

Devin works issue by issue, as soon as its Linux blockers are merged (the
`## Blocked by` of every macOS issue lists them). To see which macOS issues are
free:

```bash
for n in $(gh issue list -l ralph-host:macos -l ready-for-agent --json number -q '.[].number'); do
  open=$(gh issue view "$n" --json body -q .body \
    | awk '/^## Blocked by/{f=1;next} /^## /{f=0} f' | grep -o '#[0-9]\+' | tr -d '#' \
    | while read -r b; do [ "$(gh issue view "$b" --json state -q .state)" = OPEN ] && echo "$b"; done)
  [ -z "$open" ] && echo "#$n free for Devin"
done
```

Devin uses the same branch (`ralph/issue-<N>`), PR sections and
`Closes`/`Part of` rules as the loop. Its PR is reviewed with the ralph
reviewer (`scripts/devin-review.sh <PR>` until `once.sh --review-pr <N>`,
nicoamigosa/ralph#81, exists) and merged by Nico. Devin only changes `Karta/`
(plus the CI workflow in #1); ralph never touches `Karta/`.

That is the reason for the `KartaCore` / `KartaPresentation` split: the state
and the rules have to be verifiable here, on Linux, because we cannot check
them over there. Mac time comes out of Devin's plan and is spent on what only
a Mac can do.
Anything we can settle with `swift test` must be settled before it is handed
over — sending the shell back to be rebuilt is the one cost we cannot pay.

## Pipeline

```
Nico  →  design / PRD (Claude Code)  →  GitHub issues (ready-for-agent)
      →  ralph: Codex implements (tdd) → PR → Claude reviews → PASS + gate → merge
      →  WSL for KartaCore / KartaPresentation issues · Devin for iOS/UI issues
```
