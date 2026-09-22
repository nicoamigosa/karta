# El feed tiene una frontera entre lo nuevo y lo ya visto, y cruzarla no re-marca

Cuando ya no quedaban recetas sin ver, `FeedQuery` volvía a devolverlas todas en silencio:
nadie decidió eso, salió de que el array no podía quedar vacío. Pero el PRD promete a la vez
un feed "fresco día tras día" y un feed que nunca se limita, porque una pantalla vacía en el
momento de decidir la cena es el fracaso del producto.

Adoptamos el patrón de Instagram: el feed se ordena como lo nuevo, una **frontera** explícita
("estás al día") y a continuación lo ya visto, etiquetado como tal. El dominio distingue los
dos tramos y lo dice; la UI decide cómo dibujarlo. Y cruzar la frontera **no** vuelve a marcar
como vistas esas recetas: la fecha de vista se fija la primera vez y nunca se renueva.

Esa última regla es la que sostiene todo lo demás. Si mirar por debajo de la frontera renovara
la fecha, una receta que se ve cada día nunca saldría de la ventana, el tramo "nuevo" quedaría
vacío para siempre y la frontera acabaría pegada al principio del feed. Abrir una receta sí
cuenta, porque abrir es una decisión y no un "pasar de largo".

## Consequences

- La frontera se calcula contra los filtros activos, no es una posición guardada: al endurecer
  un filtro puede aparecer de inmediato, y eso es información útil ("con 30 minutos tienes 3
  recetas más") en lugar de un callejón sin salida.
- Las recetas nuevas del catálogo entran arriba y empujan la frontera hacia abajo solas.
- "Agotado" y "no hay ninguna receta compatible con tu perfil" son estados distintos: el
  segundo es un fallo de contenido y debe ser visible desde el primer día.
