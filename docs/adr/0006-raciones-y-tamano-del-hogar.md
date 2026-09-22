# Las recetas declaran raciones; el tamaño del hogar etiqueta y ordena, pero no filtra

El onboarding preguntaba el tamaño del hogar y ningún código lo leía: existía para escalar
cantidades, y las cantidades son texto literal sin estructura (ver ADR 0005). Era una pregunta
cobrada a la usuaria antes de enseñarle valor, sin contrapartida.

En lugar de quitarla, cada receta pasa a declarar cuántas raciones da, y el tamaño del hogar
se usa para dos cosas: mostrar "Serves N" en la tarjeta, que responde directamente a "¿esto da
para mi familia?", y **ordenar** el feed acercando las recetas de tamaño parecido. Nada
desaparece del feed por este motivo.

Descartamos usarlo como filtro duro en el MVP: la mayoría de la cocina casera son recetas de
4 a 6 raciones, y un hogar de dos perdería casi el catálogo entero justo en el producto cuyo
objetivo es decidir rápido. Una receta de 4 se cocina para 2 sin drama, y lo que sobra es
precisamente el mundo Leftovers. Queda como filtro opcional para más adelante, cuando el
catálogo sea lo bastante grande como para que restringir no vacíe la pantalla.

## Consequences

- Campo nuevo en el catálogo y trabajo editorial en las cien recetas.
- Leftovers gana una señal que antes no tenía: cocinar una receta de 6 siendo dos personas
  predice sobras de verdad, en vez de limitarse a cruzar ingredientes.
