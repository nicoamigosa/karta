# El catálogo se escribe en inglés con unidades americanas, sin capa de conversión

El seed estaba en español con unidades métricas (`500 g`, `200 ml`, `2 tazas cocidas`) y
etiquetas mezcladas (`one-pan` junto a `vegetariano`, comparadas como texto exacto), mientras
el PRD define el mercado como Estados Unidos, English-first. Con ocho recetas daba igual, pero
el seed es el molde con el que la editora producirá cien.

El catálogo del MVP se redacta directamente en inglés y en unidades americanas. No existe capa
de conversión de unidades ni preferencias de locale: convertir texto libre como "2 tazas
cocidas" exigiría cantidades estructuradas y raciones base, y eso es trabajo editorial, no un
parser. Las etiquetas pasan a ser un vocabulario cerrado en inglés, igual que los alérgenos;
lo que la usuaria lee es presentación, nunca el dato.

_(Sustituido por el ADR 0011: los nombres de los platos también van en inglés.)_ Los nombres propios de platos no se traducen: "Tortilla de papa" se queda. El diferenciador del
producto es la cocina American-Latina y el nombre del plato forma parte de él.

## Consequences

- Las cantidades siguen siendo texto literal y el código no puede fingir que las entiende:
  nada de inferir números de la prosa ni escalar por tamaño del hogar en este MVP.
- El seed actual hay que reescribirlo, no traducirlo mecánicamente: cambian unidades, etiquetas
  y redacción de pasos.
