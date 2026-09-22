# Revisión 2/2 — decisiones y runbook

Resultado del grilling del 22 de septiembre de 2026 sobre
[`2026-09-astra-pipeline.md`](2026-09-astra-pipeline.md). Primero las decisiones y después
los pasos para ejecutarlas, en orden.

## Decisiones

| # | Tema | Decisión |
|---|---|---|
| 1 | Runner `wsl-nico` | Se da de baja; Linux pasa a `ubuntu-24.04` |
| 2 | Checks | Un único check agregador `gate`, patrón por defecto de ralph (ralph#83) |
| 3 | iOS en CI | Mientras no exista la app, `gate` sólo mira `core`. Desde #1, iOS es obligatorio salvo en PRs que sólo cambian documentación |
| 4 | `main` | Ruleset: sólo por PR, `gate` obligatorio, sin bypass para nadie |
| 5 | Token del revisor | Ya provisionado (`~/.config/ralph/reviewer.env`) |
| 6 | Routing por host | `ralph-host:linux` en #29–#49, `ralph-host:macos` en #1, #2 y #4–#15 (aplicado) |
| 7 | Recursos del seed | Los JSON pasan a `KartaPresentation` (ADR 0001 y #31, aplicado) |
| 8 | Devin | A mano, por dependencias (opción A); dependencias añadidas a los issues de iOS. Automatizarlo con la API de Devin: ralph#80 |
| 9 | PRs de Devin | Los revisa el revisor de ralph (`--review-pr`, ralph#81) y Nico fusiona si hay PASS del head y `gate` en verde |
| 10 | Fotos | Empaquetadas en la app, reales o generadas pero siempre aprobadas por la editora (#51; término **Foto** en `CONTEXT.md`) |
| 11 | Contenido con firma | #32 queda como `ralph-needs-human`; el patrón general es `ralph-needs-approval` (ralph#82) |
| 12 | Versiones de Xcode | Siempre las últimas (`macos-latest`); el simulador se elige automáticamente |
| — | Política de runners | Hospedados en repos públicos y self-hosted sólo en privados (ralph#84) |

Pasos 1–4 ejecutados el 2026-09-22: PR #52 (CI y `gate`), runner `wsl-nico` dado de baja en GitHub (falta parar el servicio local con `sudo`), ruleset `main-gate-no-bypass` (id 23841861) activo, y el PR de documentación.

Ya aplicado en GitHub: las etiquetas de host, las correcciones de #1, #4 y #31, las
dependencias de los issues de iOS, #51 y la reetiqueta de #32. `CONTEXT.md` (Foto) y ADR
0001 van en el PR de documentación.

## Paso 1 — PR de CI

```bash
git switch -c chore/ci-gate
```

Sustituir `.github/workflows/ci.yml` por:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  core:
    name: KartaCore (Linux)
    runs-on: ubuntu-24.04
    container: swift:6.3
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - name: swift test
        run: swift test --package-path KartaCore

  # The only check that the ruleset and ralph require. It fails unless every
  # required job succeeded. Issue #1 adds detect + ios to its needs.
  gate:
    name: gate
    runs-on: ubuntu-24.04
    timeout-minutes: 2
    needs: [core]
    if: always()
    steps:
      - name: Require every job
        shell: bash
        env:
          CORE_RESULT: ${{ needs.core.result }}
        run: test "$CORE_RESULT" = success
```

```bash
git add .github/workflows/ci.yml
git commit -m "ci: Linux en runners hospedados y check agregador gate"
git push -u origin chore/ci-gate
gh pr create --fill
gh pr checks --watch          # tienen que salir "KartaCore (Linux)" y "gate" en verde
gh pr merge --squash --delete-branch
```

## Paso 2 — Dar de baja el runner

Justo después de fusionar el paso 1, para que ningún job siga apuntando a `self-hosted`:

```bash
cd ~/actions-runner-karta
sudo ./svc.sh stop
sudo ./svc.sh uninstall
./config.sh remove --token "$(gh api -X POST repos/nicoamigosa/karta/actions/runners/remove-token -q .token)"
gh api repos/nicoamigosa/karta/actions/runners -q .total_count     # debe dar 0
```

Después se puede borrar `~/actions-runner-karta`. Si `docker` sólo se usaba para el runner,
también se puede parar.

## Paso 3 — Proteger `main`

Cuando `gate` ya haya salido al menos una vez en `main` (el push del merge del paso 1):

```bash
gh api -X POST repos/nicoamigosa/karta/rulesets --input - <<'EOF'
{
  "name": "main-gate-no-bypass",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0,
      "dismiss_stale_reviews_on_push": true,
      "require_code_owner_review": false,
      "require_last_push_approval": false,
      "required_review_thread_resolution": false}},
    {"type": "required_status_checks", "parameters": {
      "strict_required_status_checks_policy": false,
      "required_status_checks": [{"context": "gate", "integration_id": 15368}]}}
  ]
}
EOF
gh api repos/nicoamigosa/karta/rules/branches/main -q '.[].type'   # deletion, non_fast_forward, pull_request, required_status_checks
```

`15368` es la app de GitHub Actions: así sólo cuenta un `gate` publicado por Actions. No
se exige que la rama esté al día con `main` (`strict: false`). Si se exigiera, ralph tendría
que actualizar la rama y volver a pasar CI después de cada merge.

A partir de aquí ya no se puede hacer push directo a `main`, tampoco desde el paso 4.

## Paso 4 — PR de documentación

```bash
git switch main && git pull
git switch -c docs/pipeline-decisions
```

Ya está en local: `CONTEXT.md` (Foto), ADR 0001 y este runbook. Cambios en `AGENTS.md`:

1. **Introducción:** «resolved by the unattended loop in `ralph/`» pasa a «Linux issues run
   through ralph; iOS shell issues (`ralph-host:macos`) are implemented by Devin on macOS».
   Quitar el párrafo que obliga a `RALPH_REQUIRE_PROTECTION=0 RALPH_REQUIRE_REVIEWER_TOKEN=0`
   mientras falte D1: D1 ya está resuelto.
2. **Architecture:** el título pasa a «rules in Core, state in Presentation, rendering in
   Karta». «two targets» pasa a «two SwiftPM library targets and one iOS app target». En la
   fila de `Karta`, el comando fijo con `iPhone 16` se cambia por «CI picks the first
   available iPhone simulator». Añadir: «Bundled resources (the seed JSON) belong to
   `KartaPresentation`; `KartaCore` only decodes `Data`». «Never bypass `FeedQuery` from
   the UI» pasa a «views reach recipes through the store, never by calling `FeedQuery`».
3. **Gates:** el punto 2 pasa a «CI check `gate` green (it aggregates `KartaCore (Linux)`
   and, from #1, the iOS job)».
4. **Workflow:** «The loop merges…» pasa a «ralph merges its own PRs. Devin PRs: Nico runs
   the ralph reviewer on the PR and merges only with PASS for the current head and `gate`
   green. Neither agent merges, approves or closes issues».
5. **Running ralph in Karta:** sustituir el bloque y la frase de «host routing pending
   upstream» por:

   ```bash
   . "$HOME/.local/share/swiftly/env.sh"
   set -a; . ~/.config/ralph/reviewer.env; set +a
   RALPH_REQUIRED_CHECKS_JSON='["gate"]' \
   RALPH_TDD_SKILL=$HOME/.codex/skills/tdd/SKILL.md \
   ./ralph/once.sh
   ```

   Añadir: «Host routing is active (ralph ≥ 1.2): every open issue carries exactly one
   `ralph-host:linux` or `ralph-host:macos`».
6. **The macOS side:** añadir cómo se ve qué issue de macOS está libre:

   ```bash
   for n in $(gh issue list -l ralph-host:macos -l ready-for-agent --json number -q '.[].number'); do
     open=$(gh issue view "$n" --json body -q .body \
       | awk '/^## Blocked by/{f=1;next} /^## /{f=0} f' | grep -o '#[0-9]\+' | tr -d '#' \
       | while read -r b; do [ "$(gh issue view "$b" --json state -q .state)" = OPEN ] && echo "$b"; done)
     [ -z "$open" ] && echo "#$n libre para Devin"
   done
   ```

7. **Pipeline:** en el diagrama, «PASS + CI» pasa a «PASS + gate».

En `docs/mac-handoff.md`, quitar `open Karta.xcodeproj` desde una ruta ambigua y el recuento
histórico de tests, y remitir a `AGENTS.md`.

```bash
git add CONTEXT.md docs/adr/0001-kartapresentation-target-separado.md AGENTS.md \
  docs/mac-handoff.md docs/reviews/
git commit -m "docs: decisiones de la revisión del pipeline"
git push -u origin docs/pipeline-decisions
gh pr create --fill && gh pr checks --watch && gh pr merge --squash --delete-branch
```

Este PR tiene que estar fusionado **antes de lanzar el loop**, para que ralph lea el ADR 0001
corregido al coger #31.

## Paso 5 — Lanzar el loop

```bash
RALPH_DRY_RUN=1 RALPH_REQUIRED_CHECKS_JSON='["gate"]' \
  RALPH_TDD_SKILL=$HOME/.codex/skills/tdd/SKILL.md ./ralph/once.sh
```

Comprobar en el dry-run que el preflight pasa (ruleset y token) y que sólo aparecen issues
`host=linux`. Después, lanzar el comando del paso 4.5.

## Paso 6 — Lo que añadirá #1 (para Devin)

El PR de #1 cambia el CI para que iOS sea obligatorio. Añadir estos dos jobs y sustituir
`gate`:

```yaml
  detect:
    name: Detect docs-only
    runs-on: ubuntu-24.04
    timeout-minutes: 3
    outputs:
      run_ios: ${{ steps.check.outputs.run_ios }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false
      - id: check
        shell: bash
        env:
          BASE: ${{ github.event.pull_request.base.sha || github.event.before }}
        run: |
          set -euo pipefail
          run_ios=true
          if [ -n "$BASE" ] && git cat-file -e "$BASE^{commit}" 2>/dev/null; then
            changed="$(git diff --name-only "$BASE"...HEAD)"
            if [ -n "$changed" ] && ! grep -vqE '^docs/|\.md$|^\.github/ISSUE_TEMPLATE/' <<<"$changed"; then
              run_ios=false
            fi
          fi
          echo "run_ios=$run_ios" >> "$GITHUB_OUTPUT"

  ios:
    name: Karta app (iOS Simulator)
    needs: detect
    if: needs.detect.outputs.run_ios == 'true'
    runs-on: macos-latest
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - run: brew install xcodegen xcbeautify
      - name: Generate project (fails if the scaffold is missing)
        run: xcodegen generate --spec Karta/project.yml
      - name: Test on the first available iPhone
        shell: bash
        run: |
          set -euo pipefail
          udid="$(xcrun simctl list devices available -j \
            | jq -r '[.devices[][] | select(.name | startswith("iPhone"))][0].udid')"
          [ -n "$udid" ] && [ "$udid" != null ]
          mkdir -p artifacts
          xcodebuild -project Karta/Karta.xcodeproj -scheme Karta \
            -destination "id=$udid" -resultBundlePath artifacts/Karta.xcresult \
            CODE_SIGNING_ALLOWED=NO test 2>&1 \
            | tee artifacts/xcodebuild.log | xcbeautify --renderer github-actions
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: ios-results
          path: artifacts
          retention-days: 7

  gate:
    name: gate
    runs-on: ubuntu-24.04
    timeout-minutes: 2
    needs: [core, detect, ios]
    if: always()
    steps:
      - name: Require every job
        shell: bash
        env:
          CORE_RESULT: ${{ needs.core.result }}
          DETECT_RESULT: ${{ needs.detect.result }}
          RUN_IOS: ${{ needs.detect.outputs.run_ios }}
          IOS_RESULT: ${{ needs.ios.result }}
        run: |
          set -euo pipefail
          test "$CORE_RESULT" = success
          test "$DETECT_RESULT" = success
          case "$RUN_IOS:$IOS_RESULT" in
            true:success|false:skipped) ;;
            *) exit 1 ;;
          esac
```

Conviene pegar este bloque en el cuerpo de #1 como criterio («CI: añadir `detect` + `ios` y
sustituir `gate` por este»), junto con `Karta/project.yml`. El `project.yml` de la revisión
sirve de punto de partida, pero sin fijar versiones (decisión 12).
