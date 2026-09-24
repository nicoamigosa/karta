# Los nombres de los platos también se escriben en inglés

El ADR 0005 dejaba los nombres propios de los platos sin traducir ("Tortilla de papa se
queda") porque la cocina American-Latina es el diferenciador y el nombre formaba parte de él.
Al reescribir el seed (#32) la editora los pasó a inglés, y el propio ejemplo del ADR mostró el
problema: "Tortilla de papa" es la forma latinoamericana de un plato que en España es "tortilla
de patatas" o "tortilla española". Conservar "el nombre original" obliga a elegir un original
por región, y aun así una usuaria en Estados Unidos no lo entiende en la tarjeta, que es donde
tiene que decidir en segundos.

Decidimos que el nombre del plato se escriba en inglés, como el resto del catálogo: "Spanish
Tortilla", "Lentil Stew", "Caesar Salad". El id de la receta sigue al nombre en inglés
(`spanish-tortilla`). Esto sustituye la parte del ADR 0005 sobre nombres propios; el resto de
ese ADR (inglés, unidades americanas, sin capa de conversión, etiquetas cerradas) sigue vigente.

## Considered Options

- **Nombre original, bien escrito** ("Tortilla española", con tildes). Coherente con el ADR
  0005, pero no resuelve qué original elegir ni que la tarjeta se entienda de un vistazo.
- **Nombre original con subtítulo en inglés.** Dos campos por receta y una decisión de
  presentación que nadie ha pedido todavía. Revisable si el diferenciador cultural lo exige.

## Consequences

- El carácter American-Latina tiene que venir de la selección de recetas, las fotos y la
  redacción, no del nombre.
- Cambiar el nombre de un plato publicado cambiaría su id y rompería guardados y enlaces
  compartidos; hoy no hay usuarias, así que el cambio de ids del seed es gratis. A partir del
  lanzamiento, el id es estable aunque el nombre se corrija.
