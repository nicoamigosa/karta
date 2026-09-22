# La posición en el feed es memoria de sesión, no dato persistido

Abrir una receta y volver al principio del feed sería el peor fallo posible en un producto
cuyo objetivo es decidir rápido, y ocurriría en cada apertura. Así que la posición se conserva
al abrir una receta y volver, y también al cambiar de mundo y volver: en ambos casos es la
misma decisión y la misma sesión mental.

No se conserva entre sesiones. Al abrir la app al día siguiente se empieza arriba, porque el
feed de hoy no es el de ayer: la ventana de historial ha caducado vistas, ha podido entrar
catálogo nuevo y la frontera se ha movido. Restaurar "la posición cuatro" devolvería a un
punto de una lista que ya no existe, y además ayer esa decisión ya se tomó. Esto tiene una
consecuencia útil: la posición vive en memoria y no hay que persistirla ni versionarla.

Tampoco sobrevive a un cambio de filtros. Filtrar es pedir una lista nueva, la receta anclada
puede haber desaparecido de ella, y fingir continuidad sobre una lista distinta desorienta más
que empezar limpio.
