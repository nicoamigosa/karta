# El Feed es una baraja vertical de Cards a pantalla completa, sin veredicto al deslizar

La primera versión del shell (PR #78) mostró el Feed como una página web con varias recetas
a la vez, porque el PRD sólo decía "vertical feed of cards". Decidimos que cada receta ocupa
la pantalla entera como un bloque único (foto, nombre, tiempo, raciones y dificultad) y que
el Feed avanza de Card en Card en vertical, con la sensación de pasar una baraja: la mecánica
de los reels, que la usuaria ya conoce, pero con foto y no con vídeo.

## Considered Options

- **Lista con scroll libre** (lo que salió en #78): permite comparar varias recetas a la vez,
  pero se siente como una web genérica y diluye cada receta.
- **Swipe horizontal tipo Tinder**, sugerido por el nombre de la marca: se descartó porque
  deslizar a la derecha ya significa abrir la receta en el Feed y pasar al siguiente Paso en
  la Sesión de cocina, y porque en Tinder cada gesto es un veredicto sí/no. En Karta pasar de
  largo es una señal negativa suave (la Vista) y el "sí" es deliberado (Apertura, Guardado).

## Consequences

- La metáfora de baraja vive en la transición y el relieve (la carta siguiente asoma debajo),
  no en la dirección del gesto. Es trabajo de interfaz a medida, no un paginado estándar.
- La Card da claves para decidir si abrir, no describe: sin Etiquetas ni ingredientes, y
  sin botón de Guardar; guardar ocurre sólo tras la Apertura.
- Una Vista en el Feed es una Card que llegó a asentarse en pantalla.
