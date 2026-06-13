# Karta — Working agreement

Karta is a SwiftUI/iOS recipe app. See `docs/PRD-karta-mvp.md` for product scope.
Work is tracked as GitHub issues on `nicoamigosa/karta`, labeled `agent-ready`
(pure logic — do it here) or `hitl` (needs human/design/Mac decisions).

## Per-issue workflow (follow for EVERY open issue)

Process each open `agent-ready` issue, one at a time, lowest unblocked number first:

1. **Branch.** From up-to-date `main`, open one branch per issue:
   `git switch main && git pull && git switch -c issue-<N>-<slug>`
   (e.g. `issue-4-cooking-state-machine`). Never commit issue work to `main`.
2. **Build it with TDD.** One failing test → minimal code → green → refactor.
   Vertical slices, one behavior at a time. Never write all tests up front.
3. **Verify.** `swift test` must be fully green before committing. No green, no commit.
4. **Commit.** One focused commit (or a few) on the issue branch. End the body with
   `Closes #<N>` and the `Co-Authored-By` trailer (see below).
5. **Push & PR.** `git push -u origin issue-<N>-<slug>`, then open a PR targeting `main`
   with `gh pr create`. Merging the PR into `main` closes the issue via `Closes #<N>`.
6. **Close the issue.** It auto-closes on merge. If work is complete but cannot be
   verified here (UI/simulator), say so and leave the issue open — do not fake-close it.

Then return to step 1 for the next issue. Respect `Blocked by` links in each issue:
do not start an issue until its blockers are merged.

### Commit / PR conventions
- Commit body ends with: `Closes #<N>` then
  `Co-Authored-By: Claude <noreply@anthropic.com>`
- Only `Closes #<N>` when the issue is genuinely, verifiably done. Otherwise write
  `Part of #<N>` and keep the issue open.
- Commit or push only what the current issue covers.

## Architecture — keep logic in KartaCore

Nico develops on **WSL Linux** and uses his **Mac as little as possible**. So:

- All pure domain logic lives in the **SwiftPM package `KartaCore/`** — it compiles
  and tests on Linux with no Xcode. Push as much as possible into it.
- The SwiftUI/iOS target is a thin shell over `KartaCore` and is the **only** part that
  needs the Mac (rendering + simulator). Issues whose acceptance is purely UI stay open
  until verified on the Mac.

### Running tests (WSL)
Swift is installed via Swiftly. Source it before any swift command:

```bash
. "/home/nico/.local/share/swiftly/env.sh"
cd KartaCore && swift test
```

- Toolchain: Swift 6.3.2. Test framework: **Swift Testing** (`import Testing`, `@Test`,
  `#expect`/`#require`) — not XCTest.
- Engine logic is pure and deterministic (no I/O, no ML). Feed safety (intolerance
  filtering) is a **critical guarantee** — cover it exhaustively and never regress it.
