# Las etiquetas se separan en Course, Dieta y Etiquetas prácticas

El vocabulario de etiquetas mezclaba cosas de naturaleza distinta: el momento (`breakfast`),
la dieta (`vegetarian`), el ánimo (`hearty`, `fresh`, `classic`), lo que ya dice el tiempo
(`quick`) y restricciones prácticas (`one-pan`, `oven`). Al diseñar la Card como carta de una
baraja, con el Course principal como palo, esa mezcla dejó de sostenerse. Separamos tres
dimensiones con vocabulario cerrado propio: **Course** (`breakfast`, `lunch`, `dinner`,
`dessert`; uno principal más los que también encajan), **Dieta** (`vegetarian`, `vegan`) y
**Etiquetas prácticas** (`one-pan`, `oven`, `make-ahead`, `shareable`). Una Etiqueta sólo
existe si alimenta un filtro que ayuda a decidir.

## Considered Options

- **Una lista plana de etiquetas**: más simple de escribir, pero no permite que la Card
  muestre un único palo ni que un filtro sepa qué valores se excluyen entre sí.
- **Papel en el menú** (`main`, `side`, `appetizer`) como cuarta dimensión: aplazado; todo el
  catálogo del MVP son platos principales y la dimensión estaría vacía. `entree` se evita
  porque en inglés americano y en francés significa cosas opuestas.

## Consequences

- Salen `quick`, `classic`, `hearty`, `fresh` y `sweet`; `breakfast` pasa a ser un Course.
- La Dieta es un filtro, nunca una garantía de seguridad: esa sólo la dan los alérgenos (ADR 0002).
- El palo sólo luce con variedad: la editora debe equilibrar Courses en el catálogo.
