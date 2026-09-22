# Bajar de premium no borra guardados: el cupo se convierte en un techo que no sube

El cupo gratis son siete recetas y premium es ilimitado, pero nadie había decidido qué ocurre
al degradar, que es justo lo que le pasa a casi todo el que prueba los siete días gratis. Con
veintitrés recetas guardadas, borrar hasta dejar siete destruiría el repertorio que el PRD
describe como "una lista de confianza": exactamente la traición que hace desinstalar.

Al bajar a gratis se conservan todas las recetas guardadas y simplemente no se pueden añadir
más. El cupo deja de ser un número fijo y pasa a ser un techo igual a lo que se tenía al
degradar. Borrar una receta no devuelve el hueco: el techo baja con ella, hasta llegar al
suelo de siete, que es el cupo gratis normal. Así nadie queda atrapado sin poder borrar y el
cupo gratis sigue significando algo.

Es además el mejor negocio: la usuaria sigue viendo cada día lo que acumuló, y cada intento de
guardar le recuerda lo que tenía. Ocultar los guardados que exceden el cupo se descartó por ser
lo mismo que borrarlos, con peor sabor: enseñarle una caja fuerte con sus cosas dentro.

## Consequences

- El cupo debe contar recetas únicas, no filas: hoy `Cookbook` acepta IDs duplicados al
  restaurar, y siete copias de la misma receta bloquean guardar la segunda receta distinta.
- El techo forma parte del estado persistido, no se puede derivar del nivel de suscripción.
