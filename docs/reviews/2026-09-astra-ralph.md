# Review de ralph (Astra, 2026-09)

Revisión externa de `ralph/` en `222ef71` (HEAD de PR #25). Procesada el 2026-09-17: el código pasó a [`nicoamigosa/ralph`](https://github.com/nicoamigosa/ralph) como release `v1.0.0` y cada hallazgo está triado en la tabla del final.

---

La versión actual no cumple todavía la promesa de “PASS + CI verde” ni la de reanudación segura entre hosts. No la ejecutaría desatendida
  antes de corregir los bloqueantes siguientes.

  Revisé los seis archivos en 222ef71, HEAD de PR #25. Ejecuté bash -n y reproducciones aisladas de los parsers; no ejecuté el loop, agentes de
  pago ni operaciones de escritura en GitHub. Contrasté también las interfaces instaladas: Codex 0.154.0, Claude Code 2.1.276 y gh 2.45.0. No
  verifiqué ejecución real en macOS.

  Los fragmentos siguientes son cambios propuestos, no aplicados.

  ## 1. Portabilidad entre hosts

  1. P1 — Bash de macOS incompatible. ralph/once.sh:1 usa /bin/bash, pero los arrays asociativos de las líneas 565 y 568 requieren Bash 4 o
     posterior. Acción: exigir Bash ≥5 instalado con Homebrew en macOS; conservar Bash evita reescribir arrays, PIPESTATUS, funciones y control
     del loop en POSIX.

     Sustituir el encabezado y colocar la comprobación antes de cualquier operación:

     #!/usr/bin/env bash
     set -uo pipefail

     if (( BASH_VERSINFO[0] < 5 )); then
       printf '%s\n' \
         'Ralph requiere Bash >=5; en macOS: brew install bash y anteponer su bin al PATH.' >&2
       exit 2
     fi

     El lanzador de la VM debe configurar ese PATH: cambiar el shebang por sí solo no selecciona Homebrew.

  2. P1 — Bash moderno no arregla BSD date. ralph/once.sh:156, 197 y 213 usan date -d, inexistente en BSD date. Acción: eliminar la
     interpretación de horas humanas al adoptar resets estructurados —punto 3— y usar este helper únicamente para presentar epochs:

     format_epoch() {
       case "$(uname -s)" in
         Darwin) date -r "$1" '+%Y-%m-%d %H:%M:%S %Z' ;;
         *)      date -d "@$1" '+%Y-%m-%d %H:%M:%S %Z' ;;
       esac
     }

     Sustituir ambas interpolaciones date -d "@..." por format_epoch "$target" y format_epoch "$RESET_EPOCH".

  3. P1 — Hay otro GNUismo y un error de delimitación. ralph/once.sh:147 usa /I de GNU sed y su rango incluye el siguiente encabezado: reproduje
     que ## Related #999 se interpreta como blocker. Acción: reemplazar section_refs por un parser awk que corte antes del siguiente encabezado
     y acepte exclusivamente el formato documentado:

     section_refs() {
       LC_ALL=C awk -v wanted="$1" '
         {
           sub(/\r$/, "")
           if ($0 ~ /^##[[:space:]]+/) {
             heading = $0
             sub(/^##[[:space:]]+/, "", heading)
             sub(/[[:space:]]+$/, "", heading)
             active = (tolower(heading) == tolower(wanted))
             next
           }
           if (active &&
               $0 ~ /^[[:space:]]*(-[[:space:]]+)?#[0-9]+[[:space:]]*$/) {
             value = $0
             sub(/^[^#]*#/, "", value)
             sub(/[[:space:]]*$/, "", value)
             print value
           }
         }
       '
     }

     Añadir validación separada que rechace entradas malformadas dentro de Blocked by; ignorarlas silenciosamente volvería a abrir el gate.

  4. P2 — No todos los comandos señalados son incompatibles. Los sleep actuales son enteros; grep -oE, tail -n, los usos de tr y TZ=… date
     funcionan en ambos hosts, mientras mktemp -t tiene semántica distinta aunque estas llamadas funcionan. Acción: mantener los primeros,
     evitar sleeps fraccionales y uniformar los temporales comprobando errores:

     AGENT_LOG="$(mktemp "${TMPDIR:-/tmp}/ralph-agent.XXXXXX")" \
       || fail "No pude crear el log temporal."
     LAST_MSG="$(mktemp "${TMPDIR:-/tmp}/ralph-lastmsg.XXXXXX")" \
       || fail "No pude crear el resultado temporal."

     Mover fail antes de estas llamadas; no instalar GNU sed, grep y date para resolver diferencias que caben en dos helpers.

  ## 2. Fail-closed de verdad

  1. P0 — CI ausente autoriza merge. ralph/once.sh:320 devuelve éxito después de dos respuestas no checks reported, incluso si el workflow
     todavía no arrancó o desapareció del PR. Acción: default RALPH_CI_POLICY=required, checks esperados declarados por proyecto y ausencia
     tratada como pendiente hasta un timeout; permitir RALPH_CI_POLICY=none solo como excepción explícita para repos sin CI.

     Eliminar inmediatamente este bypass:

     # Sustituye el return 0 de la rama «no checks reported».
     echo "CI ausente: no se autoriza el merge." >&2
     return 2

     Distinguir después 2 = pendiente/infraestructura de 1 = fallo real; no mandar a Codex a corregir una caída de GitHub.

  2. P0 — “Comando checks exitoso” no expresa todos los gates del proyecto. ralph/once.sh:320 no comprueba que estén todos los checks esperados
     ni exige éxito explícito frente a estados omitidos, neutral o skipped. Acción: contrastar RALPH_REQUIRED_CHECKS_JSON con resultados del SHA
     revisado y exigir SUCCESS para cada gate; default sin excepciones de skipped/neutral y sin permitir que un check adicional exitoso
     sustituya uno obligatorio.

     GitHub distingue pass, fail, pending, skipping y cancel; no son equivalentes. El gh instalado aquí ni siquiera ofrece gh pr checks --json,
     por lo que ese parche necesita actualizar gh o consultar la API directamente. Referencia de checks.

  3. P0 — Un error de agente puede convertirse en aprobación. ralph/once.sh:245, 257 y 446–451 pierden el exit code, buscan etiquetas por todo
     el log y luego cualquier etiqueta fuerza rc=0; reproduje tanto exit 42 → éxito como una cita de PASS aceptada antes de un error. Acción:
     conservar el estado del proceso y validar únicamente su resultado final estructurado; eliminar incondicionalmente [ -n "$verdict" ] &&
     rc=0, sin opción configurable que lo restaure.

     Si se mantiene tee, capturar ambos estados inmediatamente:

     # Inmediatamente después del pipeline agente | tee:
     local statuses=( "${PIPESTATUS[@]}" )
     (( statuses[1] == 0 )) || return 70
     agent_rc="${statuses[0]}"

     La clasificación del error puede decidir reintentar, pero nunca convertir un resultado incompleto en PASS.

  4. P0 — El código probado puede diferir del mergeado. ralph/once.sh:279, 283, 311 y 543 ignoran fallos de fetch/push, mientras la línea 463 no
     fija el SHA aprobado. Acción: hacer fatales esos errores, verificar igualdad entre HEAD local y headRefOid antes y después de la revisión,
     y ligar revisión, CI y merge al mismo SHA; esta invariante no debe ser configurable.

     Capturar antes de revisar:

     reviewed_sha="$(git rev-parse HEAD)" || return 70
     remote_sha="$(gh pr view "$pr" --json headRefOid --jq .headRefOid)" \
       || return 70
     [[ "$reviewed_sha" == "$remote_sha" ]] || return 70

     Antes del merge, repetir la igualdad, comprobar árbol limpio y usar:

     gh pr merge "$pr" "$MERGE_METHOD" \
       --match-head-commit "$reviewed_sha"

     Validar previamente MERGE_METHOD contra --squash|--merge|--rebase; hoy su expansión sin comillas admite argumentos adicionales.

  5. P0 — El servidor no garantiza el PASS del revisor. ralph/once.sh:463 depende de un control local y ambos agentes tienen capacidad de
     ejecutar gh con credenciales del entorno. Acción: exigir protección/ruleset sin bypass para la identidad de merge y una aprobación o check
     ralph-review ligado al SHA, emitido por una identidad que el implementador no controle; default RALPH_REQUIRE_PROTECTION=1, desactivable
     únicamente para el sandbox de pruebas.

     La ausencia de --auto no es por sí misma un bypass: el merge inmediato también respeta las reglas aplicables; --auto tampoco crea reglas ni
     convierte un comentario PASS en required review. Referencia de merge.

  6. P1 — Aceptar una solicitud de merge no prueba que se haya mergeado. ralph/once.sh:463 borra la rama y cierra el issue al recibir éxito,
     pero un repositorio con merge queue puede quedar encolado. Acción: default merge inmediato, y en cualquier modalidad consultar hasta
     state=MERGED con mergeCommit.oid válido antes de borrar ramas, ejecutar el hook o cerrar el issue; si vence el plazo, registrar
     merge_pending.

  7. P1 — El autocommit incorpora cualquier residuo. ralph/once.sh:401 y 539 hacen git add -A, incluyendo archivos ajenos al issue o secretos
     nuevos. Acción: eliminar ambos bloques, preservar los archivos y detener la corrida si el agente deja cambios sin commit; no ofrecer
     autocommit general como configuración.

     status="$(git status --porcelain)" || return 70
     if [[ -n "$status" ]]; then
       echo "El agente dejó cambios sin commit; estado preservado." >&2
       return 70
     fi

  8. P1 — Los errores de estado Git no detienen la cadena. ralph/once.sh:301 y 305 recurren a reset --hard, y 467 permite seguir tras un pull
     --ff-only fallido. Acción: quitar el reset destructivo, conservar conflictos para recuperación y detener toda la corrida ante fallos de
     checkout/fetch/push/pull; además hacer que el bucle exterior propague cualquier error distinto de los reintentos reconocidos.

  9. P1 — Una lectura fallida elimina dependencias y exclusiones. ralph/once.sh:561 no excluye ralph-needs-human del issue, y 571 permite que un
     body fallido se vuelva vacío. Acción: leer y validar cuerpo, estado y labels antes de crear ramas; ante error API detener la pasada, y
     revalidar elegibilidad inmediatamente antes de invocar agentes.

  10. P1 — Los cierres ignoran aceptación pendiente. ralph/once.sh:480 cierra siempre y ralph/prompt_implement.md:84 exige Closes, incluso
     cuando Karta exige Part of por falta de simulador. Acción: usar RALPH_CLOSE_POLICY=verified por defecto y never para trabajos parciales; el
     cierre requiere aceptación completa y host válido, y never debe prohibir también keywords de autocierre en commits y PR.

  11. P1 — La revisión entregada a Codex puede ser de otra persona. ralph/once.sh:493 cuenta comentarios indiscriminadamente y 521 toma el
     último comentario público. Acción: guardar el resultado exacto del revisor junto con PR/SHA/ronda y usarlo para la revisión siguiente;
     publicar ese mismo cuerpo desde el orquestador y conservar el ID devuelto.

  ## 3. Detección de topes de uso

  1. P1 — El clasificador confunde contenido con errores del proveedor. ralph/once.sh:166 interpreta una implementación de “rate limit” como
     tope —reproduje rc=8— y pierde mensajes localizados, formatos distintos o errores fuera de las últimas 40 líneas. Acción: separar stdout
     estructurado, stderr diagnóstico y exit status; detectar límites exclusivamente en eventos de error o metadatos del proveedor, nunca dentro
     de respuestas, diffs o salida de herramientas.

  2. P1 — El reset calculado no es fiable. ralph/once.sh:152 toma la primera hora AM/PM, fija Nueva York, descarta fecha/zona y suma 86.400
     segundos incluso al cruzar cambios de horario. Acción: borrar ese parser y aceptar solamente epoch o timestamp con zona proporcionados por
     una señal reconocida; un reset desconocido queda null, sin inventar sesión/semanal a partir de ocho horas.

  3. P1 — JSON mejora la fiabilidad, pero no garantiza un reset universal. ralph/once.sh:235 y 250 usan texto mezclado aunque Codex ofrece
     eventos JSONL y Claude resultados JSON. Acción: sustituir las invocaciones por captura separada y adaptadores pequeños, probados contra las
     versiones soportadas:

     # Mantener los flags de modelo/sandbox del runner.
     codex exec --json -o "$LAST_MSG" "$prompt" \
       >"$RUN_DIR/codex.events.jsonl" \
       2>"$RUN_DIR/codex.stderr.log"
     agent_rc=$?

     claude --print --output-format json \
       --model "$CLAUDE_MODEL" "$prompt" \
       >"$RUN_DIR/claude.result.json" \
       2>"$RUN_DIR/claude.stderr.log"
     agent_rc=$?

     Codex documenta turn.completed, turn.failed, error y uso de tokens; Claude ofrece resultado, metadatos y salida ajustada a JSON Schema.
     Codex no interactivo, Claude programático.

     El contrato interno propuesto, no un formato nativo de ambos proveedores, sería:

     {
       "status": "rate_limited",
       "retry_at": null,
       "limit_scope": "unknown",
       "retryable": true,
       "exit_code": 1
     }

     Éxito requiere proceso exitoso y evento/resultado final válido; exit code no cero no distingue por sí solo cuota, autenticación, red o
     configuración, y usage no equivale a cupo restante.

  4. P1 — Un límite desconocido reintenta indefinidamente. ralph/once.sh:184 convierte cualquier coincidencia ambigua en límite de sesión y 607
     repite sin techo. Acción: default tres reintentos acotados por el tiempo total; con reset fiable esperar solo hasta ese plazo, con error de
     autenticación/configuración parar y con clasificación desconocida registrar el error sin fabricar una fecha.

     Mantendría Bash: no migraría el loop entero a un SDK solo para esto.

  ## 4. Separación común / por proyecto

  1. P2 — La carpeta promete ser común pero incluye instrucciones de Karta y configuración solo por terminal. ralph/README.md:33 y ralph/
     once.sh:53 mezclan adopción y defaults. Acción: mantener ralph/ idéntica y colocar los overrides versionados en .ralph/, dejando la
     configuración del host fuera del repositorio.

      Nivel           Ubicación                           Contenido
     ━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      Común           ralph/                              Script, prompts, contratos, tests, updater, VERSION
     ──────────────  ──────────────────────────────────  ─────────────────────────────────────────────────────────────
      Proyecto        .ralph/config.env                   Base, labels, checks obligatorios, política de cierre, hook
     ──────────────  ──────────────────────────────────  ─────────────────────────────────────────────────────────────
      Proyecto        .ralph/prompt_*.local.md            Restricciones concretas de implementación/revisión
     ──────────────  ──────────────────────────────────  ─────────────────────────────────────────────────────────────
      Host            ~/.config/ralph/host.env            Capacidad Linux/macOS, rutas, límites locales
     ──────────────  ──────────────────────────────────  ─────────────────────────────────────────────────────────────
      Credenciales    Login/keychain/entorno protegido    Autenticación; nunca config versionada

  2. P2 — Hace falta precedencia explícita. ralph/once.sh:52 resuelve defaults antes de poder cargar configuración. Acción: insertar este bloque
     antes de las asignaciones actuales; precedencia: entorno explícito > host > proyecto > defaults.

     SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
     REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)" || exit 2
     cd "$REPO_ROOT" || exit 2

     # Archivos shell de confianza: las asignaciones de entorno explícitas ganan.
     declare -A incoming=()
     while IFS= read -r key; do
       incoming["$key"]="${!key}"
     done < <(compgen -A variable RALPH_)

     host_config="${RALPH_HOST_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/ralph/host.env}"

     if [[ -f "$REPO_ROOT/.ralph/config.env" ]]; then
       source "$REPO_ROOT/.ralph/config.env" || exit 2
     fi
     if [[ -f "$host_config" ]]; then
       source "$host_config" || exit 2
     fi

     for key in "${!incoming[@]}"; do
       printf -v "$key" '%s' "${incoming[$key]}"
     done

     Documentar que .env aquí es código shell confiable, no un parser de datos, y validar valores/enums/números después de cargarlo.

  3. P2 — Los prompts no tienen punto de extensión. ralph/once.sh:106 carga exclusivamente la plantilla común. Acción: sustituir esas cuatro
     lecturas por composición común + extensión local:

     load_prompt() {
       local name="$1"
       cat "$SCRIPT_DIR/$name.md" || return
       if [[ -f "$REPO_ROOT/.ralph/$name.local.md" ]]; then
         printf '\n\n# Project-specific requirements\n\n'
         cat "$REPO_ROOT/.ralph/$name.local.md" || return
       fi
     }

     PROMPT_IMPLEMENT="$(load_prompt prompt_implement)" || fail "Prompt inválido."
     PROMPT_REVIEW="$(load_prompt prompt_review)" || fail "Prompt inválido."
     PROMPT_REVISE="$(load_prompt prompt_revise)" || fail "Prompt inválido."
     PROMPT_CONFLICTS="$(load_prompt prompt_conflicts)" || fail "Prompt inválido."

     Cargar todo desde la base confiable antes de cambiar a una rama de trabajo, como ya hace parcialmente el script.

  ## 5. Distribución y actualización

  1. P2 — Copiar sin versión produce divergencia invisible. ralph/README.md:18 recomienda copiar sin mecanismo de actualización. Acción: usar un
     repo propio con releases etiquetadas y ralph/update.sh VERSION, que descargue una release concreta, verifique su SHA-256, rechace
     modificaciones locales en archivos comunes y aplique exclusivamente los archivos del manifiesto de distribución.

     Incluir:

     ralph/VERSION

     Con contenido inicial:

     1.0.0

     El updater debe preservar runs/, checkpoints y toda .ralph/, no actualizar mientras corre el loop y dejar el diff para un PR normal; nunca
     autoactualizar durante una corrida.

  2. P2 — No hay detección de versiones atrasadas. ralph/README.md:113 no define mantenimiento. Acción: añadir ralph/update.sh --check, comparar
     VERSION con la última release estable y emitir “actual”, “actualización disponible” o “consulta fallida”; una consulta fallida no significa
     estar actualizado.

     Recomendación: release fijada + updater con checksum y manifiesto.
      - Descarto git subtree: añade operaciones e historial de sincronización innecesarios para una carpeta pequeña que debe permanecer
        idéntica.

      - Descarto submodule: complica clones y checkouts en ambos hosts.
      - Descarto copiar desde main o curl | bash: no fija ni verifica la versión que se ejecuta.

  ## 6. Enrutado por host

  1. P1 — Prioridad no selecciona host. ralph/README.md:37 propone RALPH_ISSUE_ORDER="1 2 8" en macOS, pero el resto de issues continúa detrás y
     WSL puede recoger los de UI. Acción: mantener ready-for-agent como elegibilidad y añadir un label independiente ralph-host:macos o ralph-
     host:linux; sin label significa cualquier host.

     Detectar el host real y filtrar antes de dependencias:

     case "$(uname -s)" in
       Darwin) HOST_KIND=macos ;;
       Linux)  HOST_KIND=linux ;;
       *) fail "Host no soportado." ;;
     esac

     Dos labels de host contradictorios deben bloquear el issue; ## Blocked by conserva exactamente su función actual y se evalúa después del
     filtro.

  2. P1 — WSL y macOS pueden procesar el mismo issue. ralph/once.sh:556 carece de exclusión entre corridas y hosts. Acción: para v1 imponer un
     único loop activo por repositorio, con un coordinador o bloqueo remoto atómico; un lock local o añadir un label no evita la carrera entre
     máquinas.

  3. P1 — La reanudación entre hosts no recupera ramas remotas. ralph/once.sh:351 solo comprueba ramas locales y crea una nueva aunque el PR
     remoto ya exista. Acción: hacer fetch obligatorio, recuperar la rama remota con tracking y verificar coincidencia local/remota antes de
     revisar; consultar también PRs merged/closed y su asociación al issue antes de volver a implementar.

     Sin esa reconciliación, un corte después del merge pero antes del cierre puede provocar trabajo duplicado.

  ## 7. Observabilidad y cierre de la corrida

  1. P2 — Se borra la evidencia y el cierre es engañoso. ralph/once.sh:74 elimina logs, 207 solo genera checkpoint en algunas paradas y 626 dice
     que no quedan issues listos aunque hubo fallos. Acción: crear una carpeta por corrida con log, eventos y resumen, y cerrar siempre con
     causa explícita.

     MVP de captura, después del preflight y fuera de dry-run:

     umask 077
     RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-$$"
     RUN_DIR="$SCRIPT_DIR/runs/$RUN_ID"
     mkdir -p "$RUN_DIR" || fail "No pude crear el directorio de corrida."
     exec > >(tee -a "$RUN_DIR/run.log") 2>&1

     Añadir /ralph/runs/ al ignore distribuido y comprobar que no ensucia git status; no reemplazar el trap existente sin integrar limpieza y
     resumen.

  2. P2 — Falta un resultado estructurado persistente. ralph/once.sh:608 solo propaga dos códigos especiales. Acción: registrar eventos por
     issue/PR y generar summary.json + summary.md mediante un trap de salida que preserve el código original:

     {
       "run_id": "20260917T120000Z-1234",
       "stop_reason": "max_issues",
       "merged": [],
       "open_prs": [],
       "needs_human": [],
       "blocked": [],
       "errors": [],
       "elapsed_seconds": 0,
       "usage": {
         "codex_tokens": null,
         "claude_estimated_usd": null
       }
     }

     Separar coste estimado de facturación real; un dato ausente es null, no cero, y una suscripción no permite deducir coste marginal por
     corrida.

  3. P2 — El resumen no tiene canal de entrega. ralph/README.md:113 no define dónde verlo. Acción: primero archivo local y ruta final en stdout;
     opcionalmente RALPH_REPORT_ISSUE=<número> publica únicamente el resumen en un issue “Ralph runs”, conservando el archivo si la publicación
     falla.

     No empezaría por Discussions o notificaciones externas: el comentario usa las credenciales y API existentes y deja historial consultable.

  4. P1 — Los contadores desaparecen al reiniciar. ralph/once.sh:419 reinicia las rondas incluso tras un límite de sesión. Acción: persistir
     fase, ronda, SHA revisado y estado de merge por PR; reconstruirlos desde un registro remoto identificable cuando cambia el host y nunca
     reiniciar el presupuesto de revisiones por un error de infraestructura.

  ## 8. Prompts y requisitos

  1. P1 — La skill requerida no se verifica. ralph/prompt_implement.md:44 y ralph/prompt_revise.md:24 exigen tdd, pero el preflight solo
     comprueba ejecutables. Acción: declarar una ruta explícita RALPH_TDD_SKILL, comprobar que existe y añadirla al contexto del implementador;
     el prompt de Claude actual no exige esa skill, así que no impondría instalarla en ambos por defecto.

     [[ -n "${RALPH_TDD_SKILL:-}" && -r "$RALPH_TDD_SKILL" ]] \
       || fail "Configura RALPH_TDD_SKILL con un SKILL.md legible."

     Si un proyecto añade skills al revisor, declararlas y verificarlas por separado.

  2. P1 — “Ejecutable encontrado” no prueba autenticación ni capacidades. ralph/once.sh:84 acepta versiones incompatibles y sesiones sin login.
     Acción: comprobar codex login status, claude auth status, gh auth status, flags utilizados y jq; registrar versiones y probar el contrato
     JSON con fixtures de esas versiones.

     La disponibilidad efectiva de un modelo requiere una llamada real: hacerla opcional como smoke test presupuestado y tratar un modelo
     inaccesible como error de configuración, nunca como revisión rechazada.

  3. P1 — El revisor tiene instrucciones incompatibles con gates estrictos y hosts parciales. ralph/prompt_review.md:29 exige ejecutar todo
     localmente y 52 permite no bloquear por gates previamente fallidos. Acción: reemplazar esa excepción por un contrato que enumere gates
     locales y gates delegados a CI, vinculados al SHA:

     Run every gate assigned to this host.
     Verify every CI-only gate against the exact PR head SHA.
     A missing, failing, skipped, or unverifiable required gate prevents PASS,
     including failures that predate this change.
     Do not modify tracked files or create commits while reviewing.

     En Karta, Linux puede ejecutar KartaCore y comprobar CI iOS; eso no sustituye aceptación que requiera usar el simulador.

  4. P1 — Misma cuenta impide required reviews reales. ralph/prompt_review.md:57 evita deliberadamente gh pr review, por lo que un PASS en
     comentario no satisface una aprobación requerida. Acción: usar una identidad/bot distinta para revisar y una credencial de merge separada
     del proceso implementador; verificar identidades mediante gh api user y comprobar que el revisor no es el autor del PR.

     La aprobación debe señalar el commit revisado y descartarse cuando cambie el HEAD; si se mantiene una sola cuenta, declarar expresamente el
     modo “comentario” y no presentarlo como equivalente a required reviews.

  5. P1 — El revisor obtiene permisos irrestrictos. ralph/once.sh:255 usa --dangerously-skip-permissions, aunque su tarea consiste en
     inspeccionar y ejecutar gates. Acción: ejecutar la revisión en un entorno aislado con credenciales GitHub de lectura y publicar el
     resultado desde el orquestador; los tests también ejecutan código, por lo que una allowlist de nombres de comandos no sustituye el
     aislamiento.

  6. P2 — La política de conflictos inventa reglas de dominio. ralph/prompt_conflicts.md:11 exige conservar ambos lados, tratar versiones como
     totales y renumerar migraciones automáticamente. Acción: retirar esas reglas universales y sustituirlas por:

     Preserve the intended behavior of both branches, not necessarily both texts.
     Apply the repository's documented policy for versions, migrations and IDs.
     Never renumber an applied migration.
     If the repository does not define a safe resolution, stop and report the conflict.

  ## 9. Control de gasto y límites de corrida

  1. P1 — El loop no tiene límites globales. ralph/once.sh:558 procesa todo lo disponible y sus esperas pueden durar indefinidamente. Acción:
     defaults conservadores RALPH_MAX_ISSUES=5, RALPH_MAX_RUN_SECONDS=14400, RALPH_AGENT_TIMEOUT_SECONDS=1800 y RALPH_CI_TIMEOUT_SECONDS=1800;
     contar issues únicos iniciados y comprobar el deadline antes de cada agente, espera y nuevo issue.

  2. P1 — Ninguna invocación de agente tiene timeout. ralph/once.sh:238 y 253 pueden bloquear toda la corrida. Acción: usar GNU timeout en Linux
     y gtimeout de Homebrew coreutils en macOS, con TERM seguido de KILL y duración limitada al tiempo restante de la corrida.

     if command -v gtimeout >/dev/null 2>&1; then
       TIMEOUT_BIN=gtimeout
     elif command -v timeout >/dev/null 2>&1; then
       TIMEOUT_BIN=timeout
     else
       fail "Falta GNU timeout; en macOS: brew install coreutils."
     fi

     run_bounded() {
       local remaining seconds
       remaining=$((RUN_DEADLINE - $(date +%s)))
       (( remaining > 0 )) || return 124
       seconds=$RALPH_AGENT_TIMEOUT_SECONDS
       (( seconds <= remaining )) || seconds=$remaining
       "$TIMEOUT_BIN" --kill-after=30s "${seconds}s" "$@"
     }

     Aplicar límites también a checks, hooks y reintentos; no confundir timeout con cuota de proveedor.

  3. P2 — No hay presupuesto monetario verificable para ambos agentes. ralph/once.sh:61 fija modelo/esfuerzo pero no registra consumo. Acción:
     añadir presupuesto de Claude mediante --max-budget-usd, acumular su estimación y tokens de Codex, y cortar antes de la siguiente invocación
     cuando se alcance el límite configurado; para un techo monetario duro de Codex usar controles del proveedor, no una estimación posterior.

     Claude documenta el flag para modo print; no lo presentaría como presupuesto conjunto ni como medición exacta de facturación. Referencia
     CLI de Claude.

  4. P2 — La selección limitada puede esconder trabajo sin procesar. ralph/once.sh:561 usa el límite predeterminado del listado y 570 detecta
     padres solo entre esos candidatos. Acción: paginar todos los candidatos, separar el límite de ejecución del límite de consulta y detectar
     Parent usando todos los hijos relevantes, incluidos los cerrados o no etiquetados; no añadir un lenguaje nuevo de dependencias.

     Además, dejar de tratar CLOSED como estado irreversible en la caché: los issues pueden reabrirse.

  ## 10. Cómo testear ralph

  1. P2 — No existe una inspección segura del plan. ralph/once.sh:111 ya publica una base ausente y 118 crea labels antes de seleccionar issues.
     Acción: añadir RALPH_DRY_RUN=1 que haga solo lecturas y muestre prioridad, host, padres, blockers, exclusión humana y PR existente,
     terminando antes de push, labels, checkout, agentes o merge.

     if [[ "${RALPH_DRY_RUN:-0}" == 1 ]]; then
       # Aquí se invoca el selector compartido, en modo de impresión.
       print_plan
       exit $?
     fi

     print_plan sería una extracción pequeña del selector existente, no una segunda implementación; dry-run no debe exigir login de Codex/Claude
     ni simular que se cierran blockers.

  2. P1 — Falta probar los caminos negativos del gate. Los fallos reproducidos afectan funciones pequeñas de ralph/once.sh:146, 166, 235 y 445.
     Acción: añadir tests de shell con fixtures de gh, Codex y Claude y ejecutarlos en Linux/Bash 5 y macOS/Bash Homebrew con utilidades BSD.

     Casos mínimos obligatorios:
      - PASS citado + error del agente: ningún merge.
      - JSON truncado o sin resultado final: ningún merge.
      - Sin checks, check obligatorio ausente, skipped, pending o failed: ningún merge.
      - Cambio de HEAD después de PASS o fallo de push: ningún merge.
      - API de issue fallida: no implementar sin dependencias.
      - needs-human en issue o PR: no invocar agentes.
      - Merge encolado: no cerrar issue ni borrar rama.
      - Tope, timeout y reinicio: conservar ronda y fase.
      - Solo rama remota: recuperar su trabajo.
      - Más de 30 issues y padres con hijos fuera de candidatos: selección completa.
      - Dry-run: cero llamadas mutantes.

  3. P2 — Los mocks solos no prueban comportamiento de GitHub. El workflow mezcla Git local y estados remotos en ralph/once.sh:340. Acción:
     añadir una suite de integración en un repo sandbox con CI y protección reales, sustituyendo agentes por scripts mediante PATH.

     PATH="$PWD/tests/ralph/fakes:$PATH" \
     RALPH_MAX_ISSUES=1 \
     RALPH_MAX_RUN_SECONDS=300 \
     ./ralph/once.sh

     El Codex falso crea un cambio trivial, commit y PR; el Claude falso emite fixtures JSON de PASS/rechazo/error, y cada escenario comprueba
     el estado remoto final.

     El harness debe verificar que el slug pertenece al sandbox permitido antes de cualquier escritura; CI normal ejecuta mocks sin
     credenciales, y el sandbox real se ejecuta explícitamente.

  ## Cambios que haría antes de correr ralph en macOS

  1. Bash ≥5, shebang/preflight, sustitución de /I y eliminación de date -d directo.
  2. Preservar exit codes y exigir resultado final válido; quitar el PASS por grep y el bypass sin CI.
  3. Fijar SHA revisado/validado/mergeado, hacer fatales errores Git y comprobar MERGED.
  4. Eliminar autocommit y reset --hard; preservar trabajo ante errores.
  5. Filtrar host y needs-human, recuperar ramas remotas y respetar Part of.
  6. Añadir timeout/deadline y ejecutar los casos negativos en ambos hosts.

  ## Cambios para la versión común v1

  1. ralph/ versionada e idéntica; .ralph/ para proyecto y archivo externo para host.
  2. Contratos JSON de agentes, política CI explícita y protección server-side del merge.
  3. Estado persistente por PR/ronda/SHA y una sola corrida activa por repo.
  4. Release fijada, VERSION, updater verificable y --check.
  5. Logs/resumen por corrida, presupuesto temporal y dry-run.
  6. Tests con agentes falsos y sandbox GitHub.

  ## Lo que dejaría como está

  1. Bash como orquestador: no hace falta reescribirlo en POSIX, Python o TypeScript.
  2. Implementador y revisor separados, tres rondas por defecto y escalado humano.
  3. ## Blocked by y ## Parent, corrigiendo parser y cobertura de la consulta.
  4. Prioridad separada de dependencias mediante RALPH_ISSUE_ORDER.
  5. Merge de base sin rebase y hook post-merge opcional.
  6. Inferir herramientas desde las instrucciones del proyecto, con gates y limitaciones del host declarados explícitamente.
---

## Triaje (2026-09-17)

Cubos: **DIRECTO** = aplicado en el commit inicial de `nicoamigosa/ralph` (`v1.0.0`) · **ISSUE** = issue `ready-for-agent` en `nicoamigosa/ralph` (todos bloqueados por #1, el harness) · **DECISIÓN** = requiere criterio humano · **DESCARTADO** = motivo en una línea.

Mecanismo de distribución elegido (§5): release etiquetada + `update.sh` con checksum y manifiesto. En Karta, `ralph/` es la copia idéntica de `v1.0.0`; lo específico de Karta vive en `AGENTS.md` y, cuando exista la carga por capas (#18), en `.ralph/`.

| Hallazgo | Cubo | Acción |
|---|---|---|
| Harness de tests | ISSUE [#1](https://github.com/nicoamigosa/ralph/issues/1) | bats + `codex`/`claude`/`gh` falsos por PATH + `RALPH_DRY_RUN` + CI ubuntu/macos. Bloquea a todos los demás. |
| §1.1 Bash de macOS | ISSUE #2 | `#!/usr/bin/env bash` + preflight Bash ≥5. |
| §1.2 BSD `date` | ISSUE #2 | `format_epoch`; el parser de horas humanas se elimina en #6. |
| §1.3 `sed /I` y rango | ISSUE #3 | `section_refs` en awk + validación de `Blocked by`. |
| §1.4 `mktemp`, sleeps, `fail` | ISSUE #2 | Temporales uniformes con comprobación de error. |
| §2.1 CI ausente autoriza merge | ISSUE #7 | `RALPH_CI_POLICY=required`, ausencia = pendiente, rc 2 ≠ 1. |
| §2.2 Checks obligatorios | ISSUE #8 | `RALPH_REQUIRED_CHECKS_JSON` contra el SHA vía API, `SUCCESS` estricto. |
| §2.3 Exit code perdido / verdict fuerza rc=0 | ISSUE #4 | `PIPESTATUS`; veredicto sólo del resultado final; sin opción de restaurar. |
| §2.4 SHA probado ≠ mergeado | ISSUE #10 | `reviewed_sha`, igualdad local/remoto, `--match-head-commit`, validar `MERGE_METHOD`. |
| §2.5 Sin protección server-side | ISSUE #12 | Preflight `RALPH_REQUIRE_PROTECTION=1`; identidad separada → D1. |
| §2.6 Merge aceptado ≠ mergeado | ISSUE #11 | Poll hasta `MERGED` + `mergeCommit.oid`; `merge_pending`. |
| §2.7 Autocommit | ISSUE #9 | Eliminado; árbol sucio → preservar y `70`. |
| §2.8 `reset --hard`, errores git | ISSUE #9 | Sin reset destructivo; git fatal; bucle propaga. |
| §2.9 Lectura fallida / needs-human en issue | ISSUE #13 | Validar body/estado/labels antes de crear rama; revalidar antes de agentes. |
| §2.10 Cierre ignora aceptación pendiente | ISSUE #15 | `RALPH_CLOSE_POLICY=verified` / `never`. |
| §2.11 Revisión ajena a Codex | ISSUE #16 | Orquestador publica y guarda ID/PR/SHA/ronda (con §7.4). |
| §3.1 Clasificador confunde contenido | ISSUE #6 | Sólo eventos/metadatos del proveedor. |
| §3.2 Reset no fiable | ISSUE #6 | Parser AM/PM borrado; `retry_at` sólo de señal reconocida. |
| §3.3 Texto mezclado | ISSUE #5 | `--json` / `--output-format json`, stdout/stderr separados, contrato interno. |
| §3.4 Reintentos sin techo | ISSUE #6 | 3 reintentos acotados por deadline; auth/config para. |
| §4.1 Común vs proyecto vs host | DIRECTO | README: tabla de niveles; sale lo específico de Karta. |
| §4.2 Precedencia de configuración | ISSUE #18 | `.ralph/config.env` + `host.env`, entorno gana, validación. |
| §4.3 Prompts sin extensión | ISSUE #18 | `load_prompt` común + `.ralph/prompt_*.local.md`. |
| §5.1 Copia sin versión | DIRECTO + ISSUE #19 | `VERSION=1.0.0` y README de distribución ya; `update.sh <VERSION>` como issue. |
| §5.2 Detección de atraso | ISSUE #20 | `update.sh --check` con tres salidas. |
| §6.1 Prioridad no selecciona host | ISSUE #21 | Labels `ralph-host:*`, `HOST_KIND`, filtro previo a dependencias. |
| §6.2 Dos hosts, mismo issue | ISSUE #22 | Lock remoto atómico por repo. |
| §6.3 Reanudación sin ramas remotas | ISSUE #23 | Fetch obligatorio, tracking, PRs merged/closed. |
| §7.1 Se borra la evidencia | ISSUE #24 | `runs/<RUN_ID>/run.log`, `runs/` ignorado, causa explícita. |
| §7.2 Sin resultado estructurado | ISSUE #25 | `summary.json` + `summary.md` por trap. |
| §7.3 Sin canal de entrega | ISSUE #26 | Ruta en stdout; `RALPH_REPORT_ISSUE`. |
| §7.4 Contadores se pierden | ISSUE #16 | Fase/ronda/SHA/merge persistidos por PR. |
| §8.1 Skill tdd no verificada | ISSUE #27 | `RALPH_TDD_SKILL` legible y en contexto. |
| §8.2 Ejecutable ≠ autenticado | ISSUE #27 | Auth de codex/claude/gh, `jq`, versiones, smoke test opcional. |
| §8.3 Excepción de gates previos | DIRECTO | `prompt_review.md`: contrato de gates locales/CI ligados al SHA. |
| §8.4 Misma cuenta | DECISIÓN D1 | Ver abajo. |
| §8.5 Revisor sin restricciones | ISSUE #17 | `RALPH_REVIEWER_GH_TOKEN` de sólo lectura; orquestador publica. |
| §8.6 Conflictos con reglas inventadas | DIRECTO | `prompt_conflicts.md`: cuatro reglas propuestas. |
| §9.1 Sin límites globales | ISSUE #28 | `RALPH_MAX_ISSUES`, `RALPH_MAX_RUN_SECONDS`, deadline. |
| §9.2 Agentes sin timeout | ISSUE #29 | `run_bounded` con `timeout`/`gtimeout`. |
| §9.3 Sin presupuesto | ISSUE #30 | `--max-budget-usd`, tokens de Codex, corte previo. |
| §9.4 Selección limitada | ISSUE #14 | Paginar, padres entre todos los hijos, no cachear CLOSED. |
| §10.1 Sin inspección segura | ISSUE #1 | `RALPH_DRY_RUN` dentro del harness. |
| §10.2 Caminos negativos | ISSUE (repartido) | Cada caso es criterio de aceptación del issue que lo cubre: PASS+error → #4; JSON truncado → #5; checks → #7/#8; HEAD cambiado → #10; API fallida y needs-human → #13; encolado → #11; tope/reinicio → #16; rama remota → #23; >30 issues → #14; dry-run → #1. |
| §10.3 Mocks no prueban GitHub | ISSUE #31 | Suite de integración contra `nicoamigosa/ralph-sandbox` con allowlist. |
| §8.5 (parte) Aislar en contenedor | DESCARTADO | v1 corre en hosts dedicados; el token de lectura (#17) cubre el riesgo de credenciales. |
| §1.4 (parte) GNU sed/grep/date en macOS | DESCARTADO | El propio review lo descarta: dos helpers bastan. |
| §5 (parte) subtree / submodule / `curl \| bash` | DESCARTADO | No fijan ni verifican versión. |

### Decisión D1 — identidad separada para revisar y mergear (§8.4, §2.5)

Recomendación aceptada el 2026-09-17: crear una GitHub App (o cuenta bot) que revise y mergee, y activar en `karta` un ruleset sin bypass con required status checks y required review. **Pendiente de ejecución humana** (crear la App/token y el ruleset); hasta entonces el ruleset sólo exige status checks y `ralph/README.md` declara el "modo comentario" como no equivalente a required reviews. #12 y #17 consumen esa identidad cuando exista.

### Supuestos aplicados

- Tag inicial `v1.0.0`: baseline versionada que convive con P0 abiertos; no correr desatendido hasta cerrarlos.
- El repo ralph lleva `AGENTS.md` propio (gates: `bash -n`, `shellcheck`, `bats tests/`) y labels `ready-for-agent` / `ralph-needs-human`, para que ralph pueda resolver sus propios issues una vez exista el harness.
- Sandbox de integración: `nicoamigosa/ralph-sandbox` (a crear cuando se aborde #31).
