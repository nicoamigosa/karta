# En Leftovers la Card nombra lo que sobra, y el Mundo se acaba en su última carta

El ADR 0012 fija que la Card da claves para decidir si abrir una receta y que no lleva
ingredientes. En el Mundo Leftovers (#9) la clave para decidir es justo un ingrediente: qué
sobró de lo que se cocinó. Sin decirlo en la Card, cada carta de Leftovers parece una carta
cualquiera de For You y la usuaria tiene que abrirla para saber por qué está ahí.

Por eso, sólo en Leftovers, la Card lleva una ficha más en la fila de raciones y dificultad:
el nombre corto del ingrediente principal que sobra y cuántos más (*potatoes + 1*). Es una
píldora de contorno, no una ficha rellena, para que no se lea como otra clave de la receta, y
no es una Etiqueta (ADR 0013): no sale del catálogo de etiquetas ni alimenta ningún filtro. El
fundador exigió que la foto mida lo mismo que en la Card firmada, así que la píldora tiene que
caber junto a las fichas: lo comprueba el validador del catálogo, no un tope de caracteres. Sólo
cuando no cabe (de AX1 en adelante) baja a su propia línea.

Leftovers es una lista corta ordenada por coincidencia, no un feed que se renueva: no tiene
Frontera (ADR 0004) y se acaba en su última receta, que no se puede pasar y rebota. Nunca
termina en una carta sin palo.

## Considered Options

- **La ficha en su propia línea siempre.** Encoge la foto unos 40 pt; el fundador lo rechazó.
- **Un mazo más alto sólo en Leftovers.** Cabía la línea sin encoger la foto, pero cambiaba la
  geometría firmada del mazo y escondía las cartas de detrás.
- **La etiqueta sobre la foto.** Mantenía la foto, pero la tapaba; el fundador prefirió la fila.
- **Explicarlo sólo en el reverso.** Es la nota que también se firmó, pero no basta para decidir
  sin abrir.
- **Una carta final sin palo**, o seguir con For You tras la última. Descartadas: la primera no
  es una receta y la segunda mezcla los dos Mundos.

## Consequences

- El ADR 0012 queda enmendado para Leftovers; en For You, el Cookbook y el reverso la Card no
  cambia.
- Cada clave de compra (ADR 0017) necesita un nombre corto revisado por la editora, y el
  validador del catálogo mide la píldora junto a las fichas de cada receta.
- **(Por defecto)** el final absoluto de For You, cuando también se acaba lo ya visto, se
  comporta como la última carta de Leftovers.
