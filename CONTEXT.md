# Karta

Una app iOS que ayuda a decidir qué cocinar hoy y después a cocinarlo paso a paso.
Este glosario fija el vocabulario del dominio; no contiene decisiones de implementación
(ésas viven en `docs/adr/`).

## Language

### Contenido

**Receta**:
Una preparación curada y verificada por la editora, completa: foto, tiempo, dificultad,
ingredientes con cantidades y pasos ordenados.
_Avoid_: plato, contenido, post

**Paso**:
Una unidad autosuficiente de la preparación: lleva consigo el ingrediente y la cantidad
que necesita, y opcionalmente un temporizador y un clip de técnica.
_Avoid_: instrucción, paso de la receta

**Foto**:
La imagen principal de una receta. Puede ser real o generada, pero siempre la aprueba la
editora antes de publicarse: una foto que parezca falsa o genérica no se publica, y sin foto
aprobada la receta no está completa.
_Avoid_: imagen, hero, thumbnail, placeholder como foto final

**Raciones**:
Cuántas personas come una receta, declarado por la editora. Se muestra en la Card y acerca
en el orden del feed las recetas del tamaño del hogar, pero nunca las hace desaparecer.
_Avoid_: porciones, servings como filtro

**Course**:
La sección de la carta a la que pertenece una receta: `breakfast`, `lunch`, `dinner` o
`dessert`. Cada receta tiene exactamente un Course principal, elegido por la editora
respondiendo a "¿cuándo la cocinaría la usuaria?", y puede encajar además en otros Courses,
que sólo sirven para filtrar. Como en la carta de un restaurante, el principal es una
decisión editorial, no una verdad: la tortilla vive en `dinner` aunque también sirva de `lunch`.
En la Card el Course principal es el palo, igual que el tiempo es el número.
_Avoid_: comida, momento, categoría, meal type, palo como término del dominio

**Etiqueta**:
Un término de un vocabulario cerrado en inglés que nombra una restricción práctica de la
receta: `one-pan`, `oven`, `make-ahead`, `shareable`. Sólo existe si alimenta un filtro que
ayuda a decidir; no describe ánimo ni estilo, no repite lo que ya dice el tiempo, el Course o
la Dieta, y nunca aparece en la Card. Es dato, no texto de pantalla: un término desconocido
invalida la receta (ADR 0005, ADR 0013). No es un alérgeno: la seguridad nunca se decide por
etiquetas.
_Avoid_: tag libre, categoría, etiquetas en español, `quick`, `breakfast` como etiqueta

**Dieta**:
El régimen alimentario para el que una receta es apta: `vegetarian` o `vegan`, donde
vegan implica vegetarian. Es un filtro para decidir, no una garantía: la única garantía dura
es la Intolerancia.
_Avoid_: etiqueta de dieta, restricción, preferencia

**Clip de técnica**:
Un vídeo corto y reutilizable que muestra una técnica concreta (picar cebolla, comprobar
el punto del pollo). Se comparte entre muchas recetas y sólo aparece en pasos no obvios.
_Avoid_: vídeo, tutorial

**MediaReference**:
Una referencia validada a un recurso de medios: una URL `https`, una clave `local:` del
manifest de assets o una ruta `relative:` resuelta sobre la URL base inyectada.
_Avoid_: string de URL sin validar, ruta absoluta, recurso asumido

**MediaAssetManifest**:
El mapa de claves `local:` a nombres de recursos empaquetados que permite resolver medios
locales sin que el catálogo conozca un bundle concreto.
_Avoid_: bundle implícito, nombre de archivo en el catálogo, ruta fija

**LoadState**:
El estado observable de una carga de medios: inactiva, cargando, cargada o fallida, con
identidad de solicitud para descartar respuestas tardías y permitir reintentos.
_Avoid_: booleano de cargando, error silencioso, respuesta sin solicitud

### Seguridad

**Alérgeno**:
Un término de un vocabulario cerrado que identifica algo que una persona no debe comer.
Sólo existen los términos definidos; un término desconocido no se ignora, invalida la receta.
_Avoid_: tag de alergia, restricción, `contains` como texto libre

**dairy**:
El alérgeno que cubre cualquier derivado de la leche, incluidos los quesos curados de baja
lactosa. Es el término del MVP.
_Avoid_: lactose, milk, lácteo

**Intolerancia**:
Un alérgeno que la usuaria declaró y que, por tanto, nunca puede aparecer en ninguna
superficie de recetas. Es una garantía dura, nunca de pago y nunca relajable por un filtro.
_Avoid_: preferencia, restricción blanda

**Revisión de alérgenos / Receta sin revisar**:
Una receta revisada lleva un conjunto de alérgenos, incluso si está vacío; una receta sin revisar
no es lo mismo que una receta revisada sin alérgenos. En el catálogo se escribe `contains: null`
para una receta sin revisar y `contains: []` para una receta revisada sin alérgenos. Si falta la
clave `contains`, el estado no se puede determinar y la receta no decodifica. Una receta sin
revisar no llega a ninguna superficie, conforme al ADR 0002.
_Avoid_: lista vacía como pendiente, `reviewedAt`

**Hogar**:
Para cuántas personas cocina habitualmente la usuaria. Lo único que se pregunta en el
onboarding además de las intolerancias.
_Avoid_: familia, comensales

### Superficies

**Feed**:
La secuencia de recetas elegibles que se le ofrece a la usuaria para decidir. Nunca se
limita artificialmente: limitarlo contradice el objetivo de decidir rápido.
_Avoid_: timeline, muro, recomendaciones

**Card**:
Una receta tal como se presenta en el Feed: un bloque único de foto, nombre e información
clave que ocupa la pantalla entera y se mueve entero. El Feed avanza de card en card en
vertical, como quien pasa una baraja, nunca como una lista de varias recetas a la vez. Pasar
de card no es un veredicto: no hay "sí" ni "no" al deslizar. La foto protagoniza, pero la
card no es sólo la foto. La información clave es siempre tiempo, raciones, dificultad y el
Course principal: claves para decidir si abrir la receta, no una descripción de ella; lo
descriptivo vive tras la Apertura. Como en un naipe, el tiempo es el número y el Course
principal es el palo. Toma la mecánica de los reels, pero es una foto, no un vídeo.
_Avoid_: tarjeta, carta, post, reel, celda, fila

**Vista**:
Una receta que estuvo realmente en pantalla ante la usuaria durante un instante, con su
fecha. No es una receta que el feed devolvió ni una que se abrió: pasar de largo cuenta,
y es además la señal negativa suave del PRD. Quien decide que algo fue visto es la UI, que
se lo comunica al dominio como un hecho ya resuelto, nunca como geometría.
En el Feed, una Vista es cada Card que llegó a asentarse en pantalla.
La fecha se fija la primera vez y no se renueva por volver a verla.
_Avoid_: impresión, mostrada, servida

**Apertura**:
La decisión explícita de entrar en una receta desde el feed, con su propia fecha. Se registra
además de la Vista y no renueva la fecha de esa Vista.
_Avoid_: toque, click

**Frontera**:
El punto del feed donde se acaba lo que la usuaria no ha visto todavía. Por debajo siguen
apareciendo recetas, etiquetadas como ya vistas, para que nunca se quede sin nada que cocinar.
_Avoid_: fin del feed, corte, paginación

**Mundo**:
Cada una de las tres vistas que se eligen desde el desplegable superior: For You, Saved
y Leftovers.
_Avoid_: pestaña, sección, tab

**Cookbook**:
El repertorio personal de recetas guardadas. Guardar es un acto explícito y deliberado,
distinto de que algo simplemente guste, y sólo ocurre tras la Apertura: nunca desde la Card.
_Avoid_: favoritos, likes, guardados

**Cupo**:
El techo de recetas distintas que caben en el Cookbook. Vale siete en el nivel gratuito, no
existe en premium, y al degradar queda fijado en lo que hubiera acumulado. Nunca sube al
borrar.
_Avoid_: límite, paywall del cookbook

**Calibración de gustos**:
El mini-flujo de onboarding donde la usuaria toca las recetas que le atraen. Es un canal
separado del Cookbook: un toque de calibración no es un guardado y nunca consume el cupo.
_Avoid_: like, favorito

### Cocina

**Sesión de cocina**:
El recorrido paso a paso de una receta concreta, desde que se entra hasta que se sale.
_Avoid_: modo cocina, ejecución

**Cocinado**:
El evento que registra que una receta se preparó de verdad. Es **explícito** cuando nace de
responder a "¿cómo salió?", e **inferido** cuando se deduce del recorrido de la sesión. Los
dos alimentan el repertorio y las métricas; sólo el explícito alimenta Leftovers.
_Avoid_: completado, terminado

**Leftovers**:
Las recetas que reutilizan ingredientes de lo que se cocinó recientemente. Se derivan del
historial de cocinados, nunca de un inventario que la usuaria tenga que mantener.
_Avoid_: sobras, despensa, inventario
