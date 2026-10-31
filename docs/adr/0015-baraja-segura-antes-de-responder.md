# Antes de responder a las intolerancias se ofrece una baraja segura, no un feed vacío

El #47 fijó que "sin responder" y "respondido: ninguna" son estados distintos y que sólo el
segundo produce feed: hasta que la usuaria declarase sus intolerancias no se le enseñaba ninguna
receta. En el diseño de la primera apertura (#10) el fundador eligió abrir la app directamente en
la baraja, sin pantalla de bienvenida, y señalar con un recorrido corto el filtro donde se
declaran las intolerancias. Con la regla del #47 esa baraja tendría que estar boca abajo hasta
responder.

Cambiamos la regla: **mientras no ha respondido, cada superficie que propone recetas ofrece la
baraja segura**, sólo recetas revisadas con `contains: []`. Es decir, "sin responder" se trata
como si la usuaria tuviera las cinco intolerancias a la vez. La garantía de seguridad no se
relaja: ninguna receta con un alérgeno llega a nadie que no haya dicho que lo come. Lo que cambia
es que la pantalla deja de estar vacía, y una persona sin intolerancias puede decidir qué cocinar
antes de contestar nada.

"Sin responder" y "respondido: ninguna" siguen siendo estados distintos: el primero ofrece la
baraja segura, el segundo todo el catálogo revisado.

## Considered Options

- **Primera carta boca abajo hasta responder** (la regla del #47 tal cual): la más estricta, pero
  obliga a responder antes de ver ninguna receta.
- **Una carta-pregunta como primera carta**: misma regla, con la pregunta dentro de la baraja;
  no enseñaba dónde se cambia después.

## Consequences

- La baraja segura puede ser pequeña: depende de cuántas recetas del catálogo no tienen ningún
  alérgeno. Si no hay ninguna, se muestra el vacío por perfil (ADR 0004).
- Antes de responder ya se puede abrir, guardar y cocinar. Esas Vistas, Aperturas y guardados se
  persisten aunque el perfil esté sin responder (ADR 0010).
- Las recetas guardadas desde la baraja segura no tienen ningún alérgeno, así que ninguna puede
  chocar con una intolerancia declarada después.
