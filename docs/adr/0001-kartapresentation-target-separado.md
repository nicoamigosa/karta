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
  pureza estricta, pero la única I/O real son dos lecturas de JSON empaquetados; un target
  propio para ellas no aporta nada que Presentation no dé ya. El adaptador de recursos
  queda como un tipo dentro de Presentation, revisable más adelante.

## Los recursos pertenecen a Presentation

`Bundle.module` es el bundle del target que lo invoca, no el del paquete: un adaptador en
Presentation no puede leer recursos declarados en Core. Por eso los dos JSON del seed
(`seed-recipes.json`, `seed-clips.json`) y el `.process("Resources")` se mueven a
`KartaPresentation`. `KartaCore` conserva sólo la conversión pura de datos a modelos y sus
reglas de validación, sin `Bundle` ni acceso a archivos.

## Consequences

- `AGENTS.md` afirma que toda la lógica vive en `KartaCore`; ralph lee ese archivo en cada
  iteración, así que debe corregirse en el mismo cambio o el loop seguirá metiendo reducers
  en Core.
- Los tests actuales usan `@testable import KartaCore` y no ejercitan la API pública. El
  test target de Presentation debe usar `import` normal para que la frontera se pruebe de verdad.
