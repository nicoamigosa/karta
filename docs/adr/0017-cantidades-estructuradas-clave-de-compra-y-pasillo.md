# La cantidad de cada ingrediente pasa a ser dato: número, unidad, clave de compra y pasillo

La lista de la compra (#11) tiene que sumar el mismo producto de varias recetas («1 medium» +
«1 medium» = «2 medium» de cebolla) y ordenarlo por pasillo. Con la cantidad como texto
literal (ADR 0005) eso es imposible sin adivinar. Por eso cada ingrediente de una receta
declara su cantidad como dato:

- **número** (entero o fracción: `4`, `1 1/2`, `1/3`) y **unidad** de un vocabulario cerrado
  en inglés americano: de medida (`cup`, `tbsp`, `tsp`, `oz`, `lb`, `fl oz`) o de pieza
  (`small`, `medium`, `large`, `clove`, `head`, `slice`, `link`, `sprig`, `can`, `piece`,
  y ninguna para «5» a secas);
- o bien una **cantidad sin medida** de un vocabulario cerrado (`to taste`,
  `as needed for frying`, `a pinch`, `a few sprigs`), que nunca suma;
- opcionalmente, una **forma** (`packed`, `grated`, `shaved`, `cooked`) y un **peso
  aproximado** («about 1 1/2 lb»), que el reverso enseña y la lista no suma;
- una **clave de compra**: el producto que se compra (`yellow-onion`), común a todas las
  recetas;
- un **pasillo** de un vocabulario cerrado: `produce`, `meat-and-fish`, `dairy-and-eggs`,
  `bakery`, `pantry`, `spices`, `frozen`, `other`.

El texto que se lee en el reverso («4 medium (about 1 1/2 lb)») se genera del dato; nadie lo
escribe a mano. Las cantidades de cada Paso siguen siendo texto: son lo que se usa en ese
paso, no lo que se compra, y no se suman. La lista suma solo cuando coinciden la clave de
compra y la unidad. Unidades distintas se juntan con «+» («1/2 cup + for frying») y **nunca
se convierten** (cucharadas a tazas, onzas a libras): una conversión mal hecha en la tienda
es peor que dos cantidades en la misma línea.

Este ADR sustituye en parte al 0005: sigue sin haber capa de locale ni escalado por raciones o
por tamaño del hogar (ADR 0006). Lo que cambia es que la cantidad de la receta deja de ser
texto libre.

## Considered Options

- **Leer el texto actual con un analizador.** Descartado: «2 (about 6 oz each)», «1 link
  (about 4 oz)» o «2 cups cooked» no tienen una lectura única, y un error se ve en la tienda.
- **Lista por receta, sin sumar.** Era la variante A de la ronda; el fundador eligió sumar.
- **Sumar convirtiendo unidades.** Descartado en el MVP: exige densidades por producto para
  pasar de volumen a peso, y casi nunca cambia lo que se compra.

## Consequences

- Una receta con una unidad, una cantidad sin medida, una forma o un pasillo desconocidos, o
  sin clave de compra, no decodifica, igual que una Etiqueta desconocida.
- Hay que rehacer los ingredientes del seed y, después, de las cien recetas del catálogo.
  Es trabajo editorial: la clave de compra y el pasillo los decide la editora.
- Leftovers (#9) puede comparar por clave de compra en lugar de por nombre, lo que resuelve
  su pregunta 4 («medium carrot» frente a «Nantes carrots»).
- La regla de `Cantidad` que impide repetir una palabra del nombre sigue valiendo sobre el
  texto generado.
