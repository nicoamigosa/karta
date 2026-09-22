# Revisión 2/2 — Scaffold iOS, pipeline de agentes y CI

Eres un revisor senior de tooling iOS (Xcode, XcodeGen, xcodebuild, GitHub Actions) que trabaja con agentes autónomos. Tienes acceso al repo **público** `nicoamigosa/karta`, rama `main`. Voy a retomar el proyecto y quiero fijar bases sólidas ANTES de seguir implementando. No reescribas nada: dame hallazgos concretos y accionables, ordenados por impacto, cada uno con archivo/línea, qué está mal y qué cambiar. Nada de "considera" ni "quizás": si no es accionable, omítelo.

## Contexto

- Lee primero `AGENTS.md` (fuente única de instrucciones para agentes), luego `CONTEXT.md` (glosario del dominio), `docs/adr/0001`–`0010` (las decisiones vigentes) y `docs/PRD-karta-mvp.md`. `docs/mac-handoff.md` ya lleva un banner de obsolescencia y una tabla de qué invalida cada ADR: **no gastes el encargo en detectar esas contradicciones, ya están listadas**; señala sólo las que queden sin cubrir.
- **El paquete pasa a tener dos targets** (ADR 0001): `KartaCore` (reglas puras, sin I/O ni relojes propios) y `KartaPresentation → KartaCore` (estado de pantalla, reducers, store observable, adaptador de recursos). Ambos se compilan y testean en Linux con `cd KartaCore && swift test` (Swift 6.3, Swift Testing). El segundo target aún no está creado: lo crea una issue abierta, así que **asume los dos productos en todo lo que propongas**, empezando por el `project.yml`.
- El recuento de tests está en movimiento (eran 53 antes de esta tanda de issues); verifícalo tú si puedes ejecutar, y no lo uses como cifra de referencia.
- El target iOS (SwiftUI) **no existe todavía**. La issue #1 lo crea: scaffold + feed vertical de recetas desde el seed, enlazando **los dos** productos del paquete local.

### Topología de ejecución (cambió, y es lo que más afecta a esta revisión)

- El desarrollador trabaja en WSL Linux y **no tiene Mac**.
- **Issues de lógica → `ralph/` sobre Linux.** `ralph/` es una release instalada (v1.2.1) de `nicoamigosa/ralph`, se revisa aparte como herramienta genérica y **no debe revisarse aquí**: sólo su encaje con este repo. El loop es Codex implementa con TDD → PR → Claude Opus revisa → merge automático con PASS + CI verde. Sus prompts leen `AGENTS.md` para deducir comandos y estándares.
- **Issues de UI → una sesión de Devin sobre una VM macOS en la nube, pagada por uso.** Devin **no** ejecuta `ralph/`: es otro agente con otro contrato, sin el gate de revisión del loop. **Minimizar minutos de macOS es un objetivo de primer orden** del diseño.
- `ralph/` soporta routing por host con labels `ralph-host:linux` / `ralph-host:macos`, pero **esos labels aún no existen** en el repo.
- El repo **acaba de pasar de privado a público**. Consecuencias vivas: `ubuntu-latest` y `macos-latest` pasan a ser gratis; existe un runner self-hosted heredado (`wsl-nico`, la máquina personal del desarrollador) que los jobs `core` y `detect` siguen usando; y los rulesets de rama, antes inaccesibles por plan, ahora sí se pueden crear (`main` hoy no tiene ninguno).

## Qué quiero que revises (en este orden)

1. **Estructura del scaffold para #1.** Propón la estructura del target iOS: XcodeGen `Karta/project.yml` (para que el proyecto sea texto revisable y editable desde Linux), cómo linkear el paquete local con **sus dos productos** (`KartaCore` y `KartaPresentation`), esquema, bundle id, deployment target (ADR 0001 fija iOS 17 / macOS 14 por el uso de Observation), cómo cargar `seed-recipes.json` desde el bundle del paquete (`Bundle.module`) teniendo en cuenta que el adaptador de recursos vive en `KartaPresentation` y no en `KartaCore`, y qué test unitario mínimo del target iOS tiene sentido en CI. **Dame el `project.yml` completo.** Añade explícitamente: cómo organizar el target para que la mayor cantidad posible de código sea compilable y testeable en Linux y sólo lo irreductible requiera Xcode.
2. **`AGENTS.md` como contrato para DOS ejecutores distintos.** Hoy `AGENTS.md` asume que `ralph/` corre en ambos hosts; eso ya no es cierto (Linux = ralph, macOS = Devin). ¿Qué le falta o le sobra para que **(a)** `ralph/` resuelva issues de `KartaCore` en Linux sin ambigüedad, y **(b)** una sesión de Devin resuelva #1 en macOS **sin preguntar nada** — comandos exactos, versión de Xcode y simulador, instalación y uso de XcodeGen, dónde va el target, qué test escribir, cómo verificar cada criterio de aceptación, y cuándo corresponde `Closes #N` frente a `Part of #N`? `AGENTS.md` **se acaba de reescribir** con esa separación (tres capas, sección «Domain» que apunta a `CONTEXT.md` y a los ADR, y el reparto WSL/ralph frente a Devin): revísalo como está hoy, no como se describía antes. ¿Qué instrucciones siguen siendo ambiguas o contradictorias entre `AGENTS.md`, `CONTEXT.md`, los ADR y los cuerpos de los issues? Propón el texto concreto de las secciones que cambiarías.
3. **CI (`.github/workflows/ci.yml`) tras el paso a público.**
   a. Los jobs `core` y `detect` corren en `runs-on: self-hosted` (`wsl-nico`). En un repo público, un PR desde un fork puede ejecutar código arbitrario en esa máquina. Di exactamente qué hacer y con qué configuración.
   b. ¿El job `ios` en `macos-latest` está bien planteado (XcodeGen + `xcodebuild`)? ¿`xcpretty` sigue siendo la opción correcta o conviene `xcbeautify`?
   c. ¿Qué falta para que sea una **gate real**: checks requeridos por nombre, filtros `paths` para no gastar macOS en PRs que sólo tocan `KartaCore`, caché de DerivedData/SwiftPM, timeouts, `concurrency` para cancelar runs obsoletos?
   d. Ahora que los rulesets son accesibles, **qué ruleset mínimo sin bypass** poner en `main` para que `ralph/` pueda correr con `RALPH_REQUIRE_PROTECTION=1` y `RALPH_REQUIRE_REVIEWER_TOKEN=1` (hoy corre con ambos en `0`, que la propia herramienta sólo admite para sandbox).

Formato de respuesta: una sección por punto, ítems numerados, máximo una frase de diagnóstico y una de acción por ítem. Termina con un bloque **"Cambios en AGENTS.md / CI que haría antes de lanzar el loop"** con los 5-10 ítems prioritarios.

**Entrega:** además de responder aquí, escribe el reporte completo en el repo como `docs/reviews/2026-09-astra-pipeline.md` (la carpeta ya existe), sobre la rama `main` o en un PR que toque **sólo** ese archivo. Si no puedes escribir en el repo, dilo al principio de tu respuesta.
