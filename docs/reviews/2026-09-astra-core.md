# Revisión de KartaCore — 2026-09-22

Base: `main`, commit `3e019b0eddf79a26976e530f44b2a04853f9bb85`; lectura de `AGENTS.md`, PRD, handoff, todas las fuentes y tests del paquete, seed y CI, contrastada con las issues abiertas de GitHub el 22 de septiembre de 2026.

Verificación: `swift test` con Swift 6.3.2 en Linux: **53 tests, 18 suites, cero fallos**; además, un ejecutable temporal externo al repo reprodujo los fallos señalados como comprobados y verificó Observation sin SwiftUI bajo modo Swift 6.

No se ha construido ni ejecutado iOS; este cambio entrega exclusivamente el informe, sin implementar las recomendaciones ni modificar `ralph/`.

Prioridades: P0 = seguridad; P1 = comportamiento incorrecto o contrato necesario para el MVP; P2 = robustez y reducción de iteraciones en Mac; las extracciones propuestas son diseño pendiente, no fallos de una UI que todavía no existe.

## 1. Lógica que debe bajar de la UI al paquete

1. **[P1] Frontera y targets — `KartaCore/Package.swift:9`, `RecipeCatalog.swift:16`, `TechniqueClip.swift:44`**: limitar el paquete a dominio deja lógica determinista para Mac y, además, los dos `seed()` ya hacen I/O pese al contrato de pureza.
   **Acción:** añadir `KartaPresentation → KartaCore` dentro del mismo paquete para estado, reducers, formateadores y un store con Observation, mantener consultas y reglas en Core y trasladar la carga de bundles a un adaptador de recursos separado y testable en Linux; gana una frontera verificable sin SwiftUI a cambio de otro target y sus imports, mientras que mantener un único target simplifica configuración pero mezcla presentación y dominio, y sólo quedan en la app el renderizado y los adaptadores de plataforma.

2. **[P0] Filtros y perfil — `FeedQuery.swift:4`, `Onboarding.swift:19`; #6/#10**: `FeedFilters()` permite perder las restricciones del perfil al reconstruir filtros o cambiar de pantalla.
   **Acción:** crear `FilterState`/`FilterAction` en Presentation con perfil de seguridad separado del borrador de tiempo/dificultad, derivar una única consulta efectiva y probar en Linux aplicar/cancelar/resetear preferencias, cambiar perfil y cambiar de mundo sin borrar intolerancias; en el View quedan controles y bindings, y ninguna comprobación premium puede impedir editar seguridad.

3. **[P1] Navegación — `docs/mac-handoff.md:57` y `:68`; #2/#4/#8**: clasificar detalle y top-nav como «pure UI» deja selección de mundo, rutas y restauración de posición sin pruebas baratas.
   **Acción:** crear `AppNavigationState`, `World`, `Route` y `ScrollAnchor(recipeID, relativeOffset)` por mundo en Presentation, probar For You → detalle → atrás y For You → Saved → For You conservando ancla y resolviendo IDs eliminados; en SwiftUI quedan `NavigationStack`, menú, reconocimiento de gestos y captura/aplicación de la geometría real.

4. **[P1] Consumo del feed — `FeedQuery.swift:44`; #1/#8**: la consulta devuelve un array pero no define cuándo marcar visto, mantener la tarjeta visible ni iniciar otra vuelta tras agotar el catálogo.
   **Acción:** crear `FeedState`/`FeedAction` con IDs ordenados, tarjeta activa, ventana visible y ciclo de consumo, llamar siempre a `FeedQuery`, y probar en Linux avanzar sin saltos, recomputar filtros, catálogo vacío y dos ciclos sin repetir antes de agotar elegibles; el View sólo comunica visibilidad/scroll y renderiza, sin introducir paginación de red para ocho recetas locales ni un límite diario.

5. **[P1] Tiempo e historial — `CookingSession.swift:94`, `LeftoversQuery.swift:14`, `FeedQuery.swift:46`; #1/#4/#9**: conjuntos de IDs sin fechas no modelan «recientemente» y trasladan al consumidor la caducidad de vistos y cocinados.
   **Acción:** añadir `CookHistoryEntry`, `SeenEntry` y `RecentHistoryPolicy` en Core con fechas, `now` y ventanas explícitas, probar límites temporales, eventos futuros y sesiones repetidas, y derivar en Presentation las entradas de ambas consultas; el shell sólo obtiene el reloj y lee/escribe snapshots, sin fijar aquí una ventana de producto inventada.

6. **[P1] Cocción y avisos — `CookingSession.swift:176` y `:195`; #4/#5**: el tiempo de permanencia llega ya calculado y los helpers de alarma miran sólo el paso actual, dejando acumulación, ciclo de vida y avisos únicos a la UI.
   **Acción:** crear `CookingReducer` con acciones de entrada/salida de paso, actividad y tick, más efectos identificados `timerElapsed` para todos los timers de la sesión, probar en Linux permanencia interrumpida, expiración fuera del paso y ticks repetidos; el shell programa ticks y ejecuta sonido/hápticos/screen-awake, mientras el View traduce gestos y dibuja cuenta atrás y prompt.

7. **[P1] Guardados y restauración — `Cookbook.swift:21`; #7/#8**: guardar ya es puro, pero resolver IDs, mostrar el bloqueo, restaurar datos y mantener Saved seguro carece de un contrato compartido.
   **Acción:** crear `CookbookPresentationState` y `UserSnapshot` versionado, probar round-trip, IDs huérfanos/duplicados, octavo guardado y ocultación segura tras cambiar perfil sin borrar los guardados, usando `FeedQuery` con `seen` vacío como elegibilidad y restaurando después el orden de `savedIDs`; al shell quedan almacenamiento y animación, y al View lista/botón/presentación del aviso.

8. **[P1] Onboarding y calibración — `Onboarding.swift:12` y `:28`; #10**: faltan la distinción entre «sin responder» y «ninguna intolerancia», validación de hogar, avance del flujo y una conexión de `likedIDs` con el ranking.
   **Acción:** crear `OnboardingState` en Presentation y `TastePreferences` consumible por el ranking de Core, probar hogar inválido, consentimiento explícito a ninguna intolerancia, calibración que altera orden sólo entre recetas seguras y cero cambios en Cookbook; el View dibuja preguntas y mini-feed, y el shell inyecta locale sin GPS.

9. **[P2] Presentación y cantidades — `Recipe.swift:8`, `:63`, `CookingSession.swift:66`; #1/#2/#4/#10**: tiempo, dificultad y cantidades son datos sin una política de presentación, y textos como `c/n` no permiten convertir unidades de forma fiable.
   **Acción:** añadir `RecipeCardPresentation`, `DurationText`, `QuantityText` y `LocalePreferences` en Presentation, probar 0/59/60/61 segundos, pluralización, etiquetas beginner/intermediate/advanced, locales US/ES y preservación literal de cantidades libres; el View sólo aplica estilo, y cualquier conversión posterior exige antes cantidades estructuradas y raciones base en Core, sin inferir números de prosa ni escalar por hogar en este MVP.

10. **[P1] Recursos, carga y errores — `Recipe.swift:7`, `TechniqueClip.swift:6`, `RecipeCatalog.swift:16`; #1/#12**: una imagen es un string sin validar, un clip no tiene fuente y no existe estado de carga/reintento.
    **Acción:** introducir `MediaReference` en Core y `MediaResolver`/`LoadState` en Presentation, inyectar manifiesto de assets/base URL y probar URL HTTPS, referencia local, recurso ausente, fallo, reintento y respuesta tardía descartada mediante ID de petición; el shell resuelve `Bundle`/red y reproduce con AVKit, y el View presenta placeholder, error o contenido.

11. **[P2] Compartir — `RecipeShare.swift:20`; #13**: concatenar un ID arbitrario con una URL fija deja delimitadores como `?`, `#` o `/` alterar la referencia.
    **Acción:** aceptar una base configurada y codificar el ID como un segmento o validarlo como slug, con tests Linux de delimitadores, Unicode y configuración ausente más un payload textual útil sin enlace; únicamente la hoja nativa queda en el View/shell, y la existencia del destino web requiere verificación externa que estos tests no acreditan.

12. **[P1] Handoff — `docs/mac-handoff.md:3`, `:47`, `:57`, `:68`; `AGENTS.md`, «Running ralph in Karta»**: el handoff presupone el Mac de Nico y presenta trabajo de estado como exclusivo de UI, mientras AGENTS sigue mostrando el loop en la VM, en conflicto con el reparto WSL/ralph y Devin/macOS de este encargo.
    **Acción:** actualizar ambos documentos para asignar tipos/tests a WSL, entregar a Devin un contrato verificado y reservarle compilación, gestos, accesibilidad, medios y simulador, sin ejecutar ralph allí ni autorizar al agente a hacer merge; reflejar también que #6 depende de #3 según la issue, no de #1 como afirma el handoff.

## 2. API pública vista desde SwiftUI

1. **[P1] Pasos autosuficientes — `CookingSession.swift:7`, `Resources/seed-recipes.json:58` y `:110`**: un único `ingredient` opcional no representa pasos que añaden cebolla y curry o mezclan cuatro ingredientes, y muchos pasos del seed no llevan cantidades.
   **Acción:** modelar `[StepIngredientUse]` con referencia estable al ingrediente y cantidad utilizada, migrar los pasos que usan ingredientes y comprobar referencias/cantidades en Linux, permitiendo lista vacía sólo en acciones que no incorporan ingredientes.

2. **[P2] Identidad y Hashable — `Recipe.swift:4` y `:63`, `CookingSession.swift:5`, `TechniqueClip.swift:6`**: Recipe y TechniqueClip ya son `Identifiable`/`Sendable`, pero ingredientes y pasos no ofrecen identidad para filas repetidas y Recipe no puede ser directamente el valor Hashable de una ruta.
   **Acción:** navegar mediante `Route: Hashable` con IDs, proporcionar filas identificadas por receta+índice para arrays inmutables y por ID editorial si pasan a editarse, y probar nombres/pasos duplicados; conservar los value types y evitar exigir `Hashable` a todo Recipe sólo para navegación.

3. **[P2] Observation y concurrencia — `CookingSession.swift:112`, `Cookbook.swift:13`, `docs/mac-handoff.md:154`**: los tipos de estado ya son `Equatable`/`Sendable`, y la instrucción de reasignar tras cada mutación es innecesaria para una propiedad almacenada observable, como confirmó `withObservationTracking` en Linux.
   **Acción:** exponer en Presentation un `@MainActor @Observable final class KartaStore` con estado de valor `private(set)` y `send(Action)` que aplique reducers puros, probar seguimiento de `store.cookbook.save(...)` y `session.next()` en Linux, y pasar valores `Sendable` a tareas externas sin `@unchecked Sendable` en producción.

4. **[P1] Persistencia como contrato — `Cookbook.swift:13`, `CookingSession.swift:94`, `Onboarding.swift:6`**: Cookbook, CookedEvent y OnboardingProfile no son Codable y no existe un snapshot versionado, de modo que cada consumidor debe inventar su restauración.
   **Acción:** definir DTOs Codable explícitos para guardados, perfil e historial con validación/migración pura y tests de datos anteriores o corruptos, conservando fuera del modelo la escritura y sin serializar automáticamente timers o sesiones activas cuya restauración no pide el MVP.

## 3. Package.swift y consumo desde Xcode

1. **[P1] Deployment target — `KartaCore/Package.swift:4`**: omitir `platforms` no impide importar el paquete, pero deja mínimos implícitos que no expresan la decisión de usar Observation en SwiftUI.
   **Acción:** fijar `platforms: [.iOS(.v17), .macOS(.v14)]` al incorporar el store observable y alinear el app target en iOS 17, aceptando perder iOS 16 para evitar otra capa de observación; Linux sigue siendo plataforma de pruebas y el mínimo macOS permite probar el paquete con Observation en ese host ([Apple: Observation](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro), [SwiftPM: platforms](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)).

2. **[P2] Productos y tests públicos — `KartaCore/Package.swift:6`, `:14`**: el producto de biblioteca y `.process("Resources")` ya son correctos, pero los tests existentes usan `@testable import` y no verifican la futura frontera pública de Presentation.
   **Acción:** exportar `KartaPresentation`, añadir su test target con `import KartaCore`/`import KartaPresentation`, verificar construcción pública y reducers con `swift test`, y conservar Swift 6 como modo de lenguaje, que ya corresponde al tools-version 6.0 sin añadir flags experimentales ([SwiftPM: manifest](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)).

3. **[P1] Integración local — `.github/workflows/ci.yml:35` y `:55`, `docs/mac-handoff.md:23`**: CI busca y construye el proyecto dentro de `Karta/`, mientras el handoff propone abrirlo en la raíz.
   **Acción:** declarar en `Karta/project.yml` el paquete local `../KartaCore`, enlazar los productos y generar esquema compartido `Karta`, entregando a Devin una única verificación de build/tests, bundle de recursos e interacción del simulador con un Xcode compatible con Swift 6; comprobar Linux aquí no sustituye ese gate Mac.

## 4. Calidad, invariantes y cobertura

1. **[P0, comprobado] Datos sin seguridad se admiten — `Recipe.swift:31` y `:56`**: `contains` omitido o null se transforma en `[]`, y una tortilla cuyo campo se elimina pasa el filtro `egg`.
   **Acción:** exigir etiquetado explícito validado al construir/decodificar recetas publicables, distinguir desconocido de vacío verificado y rechazar o poner en cuarentena desconocidos, con tests de campo ausente, null, vacío explícito y vocabulario inválido.

2. **[P0, comprobado] Vocabulario incompatible — `FeedQuery.swift:33`, `Resources/seed-recipes.json:95`; #6**: el filtro `dairy` exigido por la issue devuelve pasta al pesto, panqueques y ensalada César porque el seed sólo etiqueta `lactose` y se comparan strings exactos.
   **Acción:** definir un vocabulario tipado compartido entre perfil, catálogo y controles, revisar editorialmente las etiquetas de lácteos del seed sin tratar dairy y lactose como sinónimos automáticos, y probar cada opción pública, mayúsculas/espacios en la entrada y rechazo de tags desconocidos.

3. **[P1] La exhaustividad declarada es parcial — `Tests/KartaCoreTests/FeedQuerySafetyTests.swift:51` y `:64`**: el test combinatorio sólo usa `seen: []`, omite fish/dairy, incluye soy ausente del etiquetado del seed y su bucle de aserciones también pasa si el resultado es vacío.
   **Acción:** derivar casos del vocabulario canónico, exigir IDs seguros esperados y cruzar restricciones con historial parcial/agotado y catálogo totalmente incompatible, cubriendo también Leftovers y el futuro reducer; el fallback actual sí opera sobre `eligible`, por lo que se trata de cobertura faltante y no de una fuga observada en ese fallback.

4. **[P1, comprobado] Salida no terminal para todas las acciones — `CookingSession.swift:180` y `:190`**: después de `exit()` en el último paso todavía se emite inferencia y se puede iniciar un timer, aunque navegación y respuesta ya están bloqueadas.
   **Acción:** añadir la guarda `!isExited` a ambas mutaciones y tests exit → infer/start, manteniendo explícita la política independiente de los timers que ya estaban iniciados.

5. **[P1, comprobado] Resultado duplicable — `CookingSession.swift:145` y `:151`**: dos `respond(.thumbsUp)` devuelven dos eventos y el prompt sigue visible, por lo que persistir cada devolución duplica una cocción.
   **Acción:** identificar la sesión/evento, hacer idempotente la respuesta explícita y cerrar el prompt tras ella, permitiendo enriquecer una inferencia previa mediante actualización del mismo evento y probando doble tap e inferencia → respuesta.

6. **[P1, comprobado] Restauración consume plazas ficticias — `Cookbook.swift:21`, `Onboarding.swift:31`**: los inicializadores aceptan IDs duplicados y siete copias del mismo guardado bloquean la segunda receta distinta, aunque `save` y `tap` prometen idempotencia.
   **Acción:** deduplicar conservando orden, validar cap no negativo y hogar positivo en sus entradas, y probar restauración con duplicados y más guardados que el cap sin borrar recetas previamente adquiridas al pasar de premium a free.

7. **[P1] Calibración sin efecto y test desconectado — `Onboarding.swift:28`, `FeedQuery.swift:44`, `Tests/KartaCoreTests/OnboardingTests.swift:43`**: `likedIDs` no entra en la consulta y el test del cap sólo observa un Cookbook que ninguna acción recibe, por lo que no detectará que la futura UI conecte calibrar con guardar.
   **Acción:** verificar ambos estados mediante acciones del mismo reducer y comparar feeds de preferencias distintas manteniendo seguridad, sin presentar el test actual de intolerancias como prueba de personalización por gustos.

8. **[P1] Validación del catálogo insuficiente — `RecipeCatalog.swift:11`, `CookingSession.swift:21`, `TechniqueClip.swift:24`, `Tests/KartaCoreTests/RecipeCatalogTests.swift:15`**: el decode admite IDs repetidos/vacíos, duración negativa y contenido vacío, la biblioteca oculta clips duplicados y el test del seed ni siquiera exige las ocho recetas actuales.
   **Acción:** añadir validación estructural de catálogo y referencias con errores localizables, exigir cantidades/duraciones válidas y el conjunto esperado del seed, y probar rechazo de fixtures inválidas sin convertir un clip ausente en un fallo de navegación.

9. **[P2] Ranking incompleto — `FeedQuery.swift:57`, `Recipe.swift:19`, `LeftoversQuery.swift:28`**: el feed sólo ordena por popularidad pese al PRD de popularidad/frescura, y Leftovers cuenta filas repetidas del mismo ingrediente como coincidencias adicionales.
   **Acción:** incorporar fecha editorial y una política determinista de frescura con reloj inyectado, calcular overlap mediante conjuntos de IDs de ingrediente y probar empates estables y duplicados, implementándolo en Core al abordar esas slices sin imponerlo como requisito del scaffold.

10. **[P2] Aserciones que admiten falsos positivos — `Tests/KartaCoreTests/TechniqueClipTests.swift:29`, `Tests/KartaCoreTests/SeedIntegrationTests.swift:33`**: comparar dos opcionales de clip acepta `nil == nil` y comprobar sólo orden de puntuaciones acepta un feed vacío, aunque otros tests cubran casos relacionados.
    **Acción:** usar `#require` para ambos clips y comparar identidad/contenido esperado, y exigir en el test de ranking cardinalidad e IDs además del orden para que cada prueba falle cuando se rompe su contrato.

## Cambios en KartaCore que haría antes de tocar #1

1. **[Linux]** Cerrar la admisión de recetas sin etiquetado y unificar el vocabulario de seguridad con migración editorial del seed.
2. **[Linux]** Reforzar `FeedQuerySafetyTests` con resultados exactos, opciones públicas, fallback agotado y catálogo totalmente incompatible.
3. **[Linux]** Crear `KartaPresentation`, su producto/test target y la frontera de efectos, dejando Core sin I/O y preservando tests de recursos en el adaptador.
4. **[Linux]** Añadir `FilterState` y una única composición de restricciones de perfil para todas las superficies de recetas.
5. **[Linux]** Añadir el mínimo de `FeedState` y navegación por IDs/anclas necesario para consumir tarjetas y volver al mismo punto.
6. **[Linux]** Definir validación de catálogo, referencias de imagen y estados de carga/error para que el primer feed tenga un contrato completo.
7. **[Linux]** Añadir presentación de tarjeta y tiempos con locale inyectado, preservando cantidades textuales y sin introducir conversión de unidades.
8. **[Linux]** Incorporar el store observable y probar que mutaciones de valores notifican, usando únicamente APIs públicas entre targets.
9. **[Linux]** Corregir salida terminal y emisión idempotente de cocción antes de publicar ese contrato a Devin.
10. **[Linux]** Declarar iOS 17/macOS 14 y actualizar el handoff WSL → Devin con los contratos anteriores; la comprobación **[Mac]** de proyecto, recursos, gestos y simulador corresponde a #1, no puede adelantarse fingiendo un target inexistente.
