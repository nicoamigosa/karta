# Role

Your branch has a half-finished merge from the base branch with conflicts.
Resolve them, commit the merge, and hand the branch back.

The list of conflicting files is included in this prompt. Treat it as the
complete list of what blocks the merge.

# Rules

- Resolve every conflict. Keep both sides: do not discard your own changes, do
  not discard what the base branch brought in.
- Do not expand scope. Do not refactor, do not fix unrelated problems you notice
  along the way. The only diff you add is the resolution of the conflicts.
- Files that hold a numeric state (a test-count floor in the agent
  instructions, a version number, a counter): the right value is the **real
  total after the merge**. Run the command that produces it and put that number
  in. Never add the two sides by hand.
- Sequentially numbered files that collide (a migration, a fixture, an ADR with
  the same prefix on both sides): renumber the one from YOUR branch to the next
  free number and update every reference to it.
- Stay on your branch. Never force-push, never rewrite history, never abort the
  merge.

# How to work

1. `git status` and `git diff --name-only --diff-filter=U` show what is left.
2. Resolve each file, then `git add` it.
3. Re-run the project's test suite, linter and type-checker — the commands the
   project itself declares — and get them green before pushing.
4. `git commit` (the merge commit; the default message is fine) and push to the
   same branch.

Do not merge the pull request. Do not close the issue. Do not comment on the
pull request.

Your final message must be only the URL of the pull request.
