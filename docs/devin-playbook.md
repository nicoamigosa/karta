# Playbook: Devin dentro del workflow de Karta (modo manual)

Cómo llevar un issue de iOS (`ralph-host:macos`) desde que queda libre hasta que se fusiona,
con Devin trabajando en paralelo al loop de ralph. Hasta que nicoamigosa/ralph#80 lo automatice,
cada paso lo ejecuta Nico.

## 1. Reglas fijas

| | ralph (WSL) | Devin (macOS) | Nico |
|---|---|---|---|
| Issues | `ralph-host:linux` | `ralph-host:macos` | los `ralph-needs-human` |
| Carpetas que toca | `KartaCore/` (Core y Presentation), `docs/` | **sólo `Karta/`**; en #1 también `.github/workflows/ci.yml` | cualquiera, vía PR |
| Rama | `ralph/issue-<N>` | `ralph/issue-<N>` | `chore/…`, `docs/…` |
| Revisión | revisor de ralph, automático | revisor de ralph, lanzado por Nico (`scripts/devin-review.sh`) | — |
| Merge | el loop | **Nico** | Nico |

- **Nadie escribe en la carpeta del otro.** Si Devin necesita algo del store, no lo añade:
  lo pide (sección 5.1). Es lo que evita conflictos entre ralph y Devin trabajando a la vez.
- Devin nunca fusiona, aprueba ni cierra issues. `main` ya lo impide: sólo entra un PR con
  `gate` en verde.
- Una sesión de Devin por issue. Si hay varios libres e independientes, se pueden lanzar
  seguidos; no se juntan dos issues en un PR.

## 2. Estados de un issue de iOS

```
bloqueado ──(se fusiona su último blocker)──▶ libre ──(Nico lo asigna)──▶ devin-working
    ▲                                                                   │
    └──── falta contrato (5.1): nuevo issue Linux en Blocked by ◀───────┤
                                                                        ▼
                     cerrado ◀──(merge de Nico)── PASS + gate ◀── PR en revisión
```

La etiqueta `devin-working` marca que hay una sesión de Devin abierta con ese issue. Se pone
al asignarlo y se quita al fusionar o al pausar.

## 3. Ciclo normal, paso a paso

### 3.1 Elegir un issue libre

```bash
for n in $(gh issue list -l ralph-host:macos -l ready-for-agent --json number -q '.[].number'); do
  open=$(gh issue view "$n" --json body -q .body \
    | awk '/^## Blocked by/{f=1;next} /^## /{f=0} f' | grep -o '#[0-9]\+' | tr -d '#' \
    | while read -r b; do [ "$(gh issue view "$b" --json state -q .state)" = OPEN ] && echo "$b"; done)
  [ -z "$open" ] && echo "#$n libre"
done
gh issue list -l devin-working          # lo que ya está en curso
```

Antes de lanzarlo, comprobar:

- [ ] Que no tiene ya `devin-working`.
- [ ] Que `gate` está en verde en `main`: `gh run list --branch main --limit 1`.
- [ ] Que ningún PR abierto de ralph cambia lo que el issue consume. Mirar los PR abiertos
      (`gh pr list`) y, si alguno toca el store o los tipos que el issue usa, esperar a que
      se fusione.

### 3.2 Asignarlo

```bash
N=<issue>
gh issue edit "$N" --add-label devin-working
gh issue comment "$N" --body "Asignado a Devin. Base: \`$(git ls-remote origin main | cut -f1)\`."
```

### 3.3 Lanzar la sesión de Devin

Pegar el prompt de la sección 6 con `<N>` sustituido. En **#1** añadir además:

> Also add the `detect` and `ios` jobs and the extended `gate` from step 6 of
> `docs/reviews/2026-09-astra-pipeline-runbook.md` to `.github/workflows/ci.yml`, and create
> `Karta/project.yml` (XcodeGen; do not commit the generated `.xcodeproj`).

### 3.4 Mientras trabaja

- Si Devin pregunta algo de **producto o diseño**, responde Nico. Si la respuesta cambia el
  issue, se edita el issue (no basta con decírselo en la sesión).
- Si Devin dice que **le falta algo del store o de la lógica**, ir a 5.1.
- Si Devin propone tocar `KartaCore/`, se le dice que no, y se va a 5.1.

### 3.5 Recibir el PR

Comprobar antes de revisar:

- [ ] La rama es `ralph/issue-<N>` y el PR va contra `main`.
- [ ] El cuerpo tiene `What changed`, `Seams under test`, `How I verified`, `Open decisions` y
      `Acceptance criteria`.
- [ ] Dice `Closes #<N>` sólo si cumple todos los criterios; si no, `Part of #<N>`.
- [ ] Sólo cambia `Karta/` (y el workflow en #1): `gh pr diff <PR> --name-only`.
- [ ] Trae capturas o una grabación del simulador para cada criterio visual, con el SHA probado.
- [ ] `gate` en verde en el último commit: `gh pr checks <PR>`.

Si falla algo de esta lista, se le devuelve a Devin sin gastar una revisión.

### 3.6 Revisar

```bash
scripts/devin-review.sh <PR>
```

El script usa el mismo prompt y el mismo token de solo lectura que el revisor del loop,
publica el veredicto en el PR ligado al SHA y termina con `0` si hay PASS y `1` si hay
CHANGES_REQUESTED. Cuando exista `ralph/once.sh --review-pr` (ralph#81), se usa aquél.

- **CHANGES_REQUESTED:** pegar la revisión (el comentario del PR) en la **misma** sesión de
  Devin, esperar el nuevo commit y volver a 3.5. Un commit nuevo invalida cualquier PASS.
- **Tres rondas sin PASS:** parar. Quitar `devin-working`, poner `ralph-needs-human` y decidir
  si se corrige el issue, se parte en dos o falta contrato (5.1).

### 3.7 Fusionar

Sólo si se cumplen las dos cosas: **PASS para el head actual y `gate` en verde en ese head.**

```bash
PR=<pr>; N=<issue>
gh pr view "$PR" --json headRefOid -q .headRefOid     # debe ser el SHA del comentario de PASS
gh pr merge "$PR" --squash --delete-branch
gh issue edit "$N" --remove-label devin-working
gh issue view "$N" --json state -q .state             # CLOSED si el PR decía Closes #N
```

Con `Part of #N` el issue sigue abierto: se anota en él qué falta y se vuelve a 3.2 más adelante.
Después, volver a 3.1: el merge puede haber liberado otros issues.

## 4. Coordinación con el loop de ralph

- **El loop no necesita pararse** mientras Devin trabaja: ralph sólo coge issues de Linux y
  nunca toca `Karta/`.
- **El orden lo marcan los `Blocked by`.** Cada merge de ralph puede liberar un issue de iOS;
  conviene mirar 3.1 al final de cada corrida del loop (el summary de la corrida lista los
  issues cerrados).
- **Desde #1, iOS está en `gate`**, también para los PR de ralph. Un cambio en
  `KartaPresentation` que rompa la app deja rojo el PR de ralph (caso 5.2).
- **Issues con firma editorial** (`ralph-needs-human`, p. ej. #32 y las fotos de #51) bloquean a
  los de iOS igual que los de Linux. Hacerlos pronto: #1 depende de ambos.

## 5. Casos de dependencia

### 5.1 A Devin le falta algo del contrato

Por ejemplo, la pantalla necesita un dato o una acción que el store no expone.

1. Devin **no** lo implementa en la vista. Lo describe en `Open decisions` (o en la sesión).
2. Nico crea un issue de Linux con `ready-for-agent` y `ralph-host:linux`, con el criterio
   concreto, y lo añade al `## Blocked by` del issue de iOS.
3. El trabajo de Devin se queda en su rama: se pausa la sesión, o se fusiona lo que ya esté bien
   como `Part of #N` si pasa revisión y `gate`.
4. Se quita `devin-working`. Cuando ralph fusione el nuevo issue, el de iOS vuelve a estar libre
   (3.1) y se retoma, a ser posible en la misma sesión de Devin.

### 5.2 Un PR de ralph rompe la app

`gate` sale rojo por el job de iOS en un PR de ralph. Codex no puede compilar iOS, así que el
loop agotará sus rondas y dejará el PR con `ralph-needs-human`.

- **Si el cambio de API no era necesario:** comentar en el PR que mantenga la API anterior
  (añadir en lugar de cambiar), quitar `ralph-needs-human` y dejar que el loop lo retome.
- **Si el cambio era intencionado:** lanzar Devin **sobre la rama de ralph**, con la única tarea
  de adaptar `Karta/` a la nueva API. Después `scripts/devin-review.sh <PR>` y merge de Nico con
  PASS y `gate` en verde. El issue de Linux lo cierra ese merge.

Regla para los issues de Linux escritos después de #1: los cambios a la API pública de
`KartaPresentation` que ya consume la app son **aditivos**, salvo que el issue diga lo contrario
y lo marque como caso 5.2.

### 5.3 El PR de Devin tiene conflictos con `main`

`main` no exige que la rama esté al día, así que sólo hace falta actuar si GitHub marca conflicto.
Pedirle a Devin que haga rebase sobre `main` y vuelva a pasar los tests. El nuevo head exige
revisión nueva (3.6).

### 5.4 Cambia un issue de iOS ya asignado

Si un ADR o un issue de Linux cambia lo que un issue de iOS en curso tiene que hacer, se edita el
issue de iOS **antes** de decírselo a Devin, y se le pasa el enlace. El issue es el contrato: la
revisión se hace contra él, no contra la conversación con Devin.

## 6. Prompt para Devin

```text
You are implementing GitHub issue #<N> in nicoamigosa/karta, an iOS app (SwiftUI).

Read first, in this order: AGENTS.md, CONTEXT.md, docs/adr/, then the issue
(gh issue view <N> --comments). They are the contract; docs/mac-handoff.md is
partly outdated and loses wherever they disagree.

Rules:
- Branch ralph/issue-<N> from current main. Open one PR against main.
- Only change files under Karta/. Never touch KartaCore/ (rules and state live
  there and are built by another agent on Linux). If the screen needs data or an
  action the KartaPresentation store does not expose, stop and describe it under
  "Open decisions"; do not add logic in views.
- Views read the store and send actions. Never call FeedQuery or filter recipes
  in a view. Feed safety (intolerances) must never be bypassed.
- Tests use Swift Testing (import Testing), never XCTest. Never disable tests.
- The PR body has: What changed, Seams under test, How I verified, Open
  decisions, Acceptance criteria (one line per criterion with its evidence).
- Use "Closes #<N>" only if every criterion is verified; otherwise "Part of #<N>".
- Attach simulator screenshots or a recording for every visual criterion, and
  state the simulator, Xcode version and the tested commit SHA.
- The PR needs the CI check "gate" green. Do not merge, approve or close anything.
- If review comments arrive, fix them with new commits on the same branch.
```

## 7. Resumen de una línea por paso

1. `3.1` issue libre, sin `devin-working`, `main` verde.
2. `3.2` etiqueta y comentario con el SHA base.
3. `3.3` prompt de la sección 6.
4. `3.5` checklist del PR, antes de revisar.
5. `3.6` `scripts/devin-review.sh <PR>`; hasta 3 rondas.
6. `3.7` merge con PASS del head y `gate` en verde; quitar etiqueta; volver a 1.
