# El gusto se aprende de lo que la usuaria hace; no hay calibración

El PRD pedía una calibración de gusto en el onboarding: un mini-flujo en el que la usuaria tocaba
las recetas que le apetecían para que el primer feed no fuera genérico. En el diseño de #10 el
fundador la quitó. Cada pantalla antes de la primera receta es una pregunta que se le cobra antes
de enseñarle valor, y un toque de calibración se parecía demasiado a un "like", que el producto
no tiene.

El **Gusto** se deduce de lo que ya registramos: las Aperturas y los guardados como señal
positiva, y las Vistas sin Apertura como señal negativa suave. Sólo reordena recetas que ya son
seguras y nunca le gana a la Frontera (ADR 0004). No es un motor de recomendación ni aprendizaje
automático, que siguen fuera del MVP: es una ordenación sencilla y explicable.

## Consequences

- El primer feed de una usuaria nueva es genérico hasta que abre o guarda algo. Se acepta a
  cambio de llegar antes a la primera receta.
- `TasteCalibration` y su canal separado del Cookbook dejan de tener sentido. Los datos de
  calibración que ya estén guardados se conservan intactos (ADR 0010).
