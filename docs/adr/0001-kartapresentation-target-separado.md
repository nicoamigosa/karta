# KartaCore y KartaPresentation son dos targets del mismo paquete

`KartaCore` contenía todas las reglas y, al aparecer estado de pantalla (feed activo,
filtros en edición, navegación, ancla de scroll), nada impedía mezclarlo con el dominio:
la frontera sólo existía como una frase en `AGENTS.md`, ya incumplida por el I/O de
`RecipeCatalog.seed()`. Partimos el paquete en `KartaCore` (reglas puras, sin I/O) y
`KartaPresentation → KartaCore` (estado, reducers, formateo, store observable), de modo
que el compilador rechace una regla de dominio que dependa de la pantalla.

Esto importa especialmente porque la app iOS la implementa otro agente en un host macOS
que no compartimos: el contrato entre dominio y UI tiene que ser verificable desde Linux,
no una promesa en un documento.

## Considered Options

- **Un único target.** Cero configuración, pero la frontera sólo se respeta por disciplina
  y nada avisa cuando se rompe.
- **Tres targets** (Core / Presentation / adaptador de recursos). Es lo que pediría la
  pureza estricta, pero la única I/O real son dos `Bundle.module` sobre un bundle que vive
  físicamente en `KartaCore/Resources`; separarlo hoy obliga a mover `.process("Resources")`
  y rehacer los tests de seed a cambio de un beneficio nominal. El adaptador de recursos
  queda como un tipo dentro de Presentation, revisable más adelante.

## Consequences

- `AGENTS.md` afirma que toda la lógica vive en `KartaCore`; ralph lee ese archivo en cada
  iteración, así que debe corregirse en el mismo cambio o el loop seguirá metiendo reducers
  en Core.
- Los tests actuales usan `@testable import KartaCore` y no ejercitan la API pública. El
  test target de Presentation debe usar `import` normal para que la frontera se pruebe de verdad.
