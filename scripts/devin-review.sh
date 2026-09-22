#!/usr/bin/env bash
# Revisa un PR de Devin con el revisor de ralph (mismo prompt, mismo token de
# solo lectura, mismas herramientas prohibidas) y publica el veredicto en el PR
# ligado al SHA revisado. Nunca fusiona ni aprueba.
#
# Sustituto temporal de `ralph/once.sh --review-pr <N>` (nicoamigosa/ralph#81):
# cuando exista, borrar este script y usar aquél.
#
# Uso: scripts/devin-review.sh <PR>
# Salida: 0 PASS · 1 CHANGES_REQUESTED · 2 PR mal formado · 3 head cambiado · 4 sin veredicto
set -euo pipefail

pr="${1:?uso: scripts/devin-review.sh <PR>}"
repo_root="$(git rev-parse --show-toplevel)"

[ -f "$HOME/.local/share/swiftly/env.sh" ] && . "$HOME/.local/share/swiftly/env.sh"
set -a; . "$HOME/.config/ralph/reviewer.env"; set +a
: "${RALPH_REVIEWER_GH_TOKEN:?falta RALPH_REVIEWER_GH_TOKEN en ~/.config/ralph/reviewer.env}"

sha="$(gh pr view "$pr" --json headRefOid -q .headRefOid)"
branch="$(gh pr view "$pr" --json headRefName -q .headRefName)"
issue="$(gh pr view "$pr" --json body -q .body \
  | grep -oiE '(closes|part of) #[0-9]+' | head -n 1 | grep -oE '[0-9]+' || true)"
if [ -z "$issue" ]; then
  echo "❌ El PR #$pr no declara 'Closes #N' ni 'Part of #N'." >&2
  exit 2
fi

wt="$(mktemp -d "${TMPDIR:-/tmp}/devin-review-$pr.XXXXXX")"
trap 'git -C "$repo_root" worktree remove --force "$wt" >/dev/null 2>&1 || true' EXIT
git -C "$repo_root" fetch -q origin "pull/$pr/head"
git -C "$repo_root" worktree add -q --detach "$wt" "$sha"

issue_ctx="$(gh issue view "$issue" --json number,title,body,comments)"
prompt="You are reviewing ONE pull request.

Pull request: #$pr   (inspect it with: gh pr view $pr, gh pr diff $pr)
Branch under review (already checked out): $branch
Base branch:                               main

## The GitHub issue this PR must satisfy
$issue_ctx

## Review instructions
$(cat "$repo_root/ralph/prompt_review.md")"

out="$repo_root/.git/devin-review-$pr-${sha:0:7}.md"
echo "🔍 Revisando PR #$pr (issue #$issue) en $sha…"
(cd "$wt" && GH_TOKEN="$RALPH_REVIEWER_GH_TOKEN" claude \
  --model opus \
  --dangerously-skip-permissions \
  --disallowedTools "Monitor,ScheduleWakeup,CronCreate,Agent" \
  --print "$prompt") > "$out"
echo "📄 Revisión guardada en $out"

if [ "$(gh pr view "$pr" --json headRefOid -q .headRefOid)" != "$sha" ]; then
  echo "⚠️  El PR cambió de head durante la revisión: no publico nada, repite." >&2
  exit 3
fi

verdict="$(tail -n 1 "$out")"
case "$verdict" in
  "<verdict>PASS</verdict>"|"<verdict>CHANGES_REQUESTED</verdict>") ;;
  *) echo "❌ El revisor no dejó un veredicto válido; repite la revisión." >&2; exit 4 ;;
esac

{ printf 'Revisión del revisor de ralph para `%s`\n\n' "$sha"; cat "$out"; } \
  | gh pr comment "$pr" --body-file - >/dev/null

if [ "$verdict" = "<verdict>PASS</verdict>" ]; then
  echo "✅ PASS para $sha (publicado en el PR)."
  exit 0
fi
echo "🔁 CHANGES_REQUESTED (publicado en el PR): pásale la revisión a Devin."
exit 1
