# El cocinado se infiere de la sesión completa, y sólo el explícito alimenta Leftovers

`CookingSession` infería "probablemente cocinado" tras veinte segundos de permanencia en el
último paso. El número apareció sin decidirse y mide lo que no debe: estar veinte segundos en
un paso que suele decir "sirve caliente" indica que se llegó al final, no que se cocinara.
El evento no es cosmético — alimenta el repertorio, Leftovers y la métrica north-star — así
que un umbral malo envenena las tres cosas a la vez, y el riesgo concreto es sugerirle
ingredientes de una receta que nunca preparó.

La inferencia pasa a evaluar la sesión entera: el recorrido por los pasos, los temporizadores
que se arrancaron y la duración de la sesión en relación con el tiempo declarado de la receta.
Una receta de treinta minutos despachada en noventa segundos es alguien ojeando. Esas señales
ya existen en el estado de la sesión y son mucho más difíciles de disparar por accidente que
un cronómetro en una pantalla.

Un cocinado inferido y uno explícito no valen lo mismo. Leftovers sólo consume los explícitos:
sugerir compras a partir de una suposición es justo donde la app perdería credibilidad. El
repertorio y las métricas sí aceptan ambos, distinguiéndolos.

## Considered Options

- **Subir el umbral de permanencia** (de 20 s a dos o tres minutos). Parchea el síntoma y deja
  intacto el problema de medir la señal equivocada.
- **No inferir nada**, contar sólo el 👍/👎. Datos impecables, pero pierde a quien cocina de
  verdad y cierra la app con las manos sucias, que es exactamente el escenario para el que se
  diseñó el modo cocina.
