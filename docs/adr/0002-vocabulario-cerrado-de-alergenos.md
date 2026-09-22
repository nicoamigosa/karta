# El etiquetado de alérgenos es un vocabulario cerrado y "sin revisar" no es representable como "sin alérgenos"

El filtro de seguridad comparaba cadenas sueltas: el perfil pedía `dairy`, el seed etiquetaba
`lactose`, y pasta al pesto, panqueques y ensalada César llegaban a una usuaria intolerante.
Además `contains: []` significaba a la vez "revisado, no lleva nada" y "nadie lo ha etiquetado
todavía", y el pipeline del PRD (IA formatea → editora revisa y etiqueta a mano) produce
justamente ese estado intermedio.

Decidimos que los alérgenos sean un vocabulario cerrado y tipado, compartido por perfil,
catálogo y controles, con `dairy` como término del MVP en lugar de `lactose` por ser el más
amplio y el que ya nombra el PRD; un término desconocido invalida la receta en vez de
ignorarse. Y el etiquetado deja de ser una lista: una receta está revisada con un conjunto de
alérgenos, o está sin revisar, y sobre una sin revisar no se puede formular la pregunta
"¿contiene X?". Una receta sin revisar no llega a ninguna superficie.

## Considered Options

- **Un campo `reviewedAt` aparte.** La protección dependería de que cada consulta se acuerde
  de comprobarlo, y ya hay tres superficies (`FeedQuery`, `LeftoversQuery`, la restauración
  del Cookbook). Olvidarlo en una sola es una fuga de seguridad.
- **Dos tipos, `RecipeDraft` y `Recipe`.** Es la forma correcta cuando existan UGC y
  cuarentena de verdad, pero con ocho recetas en un JSON es peso muerto. Revisable cuando
  entre contenido de terceros.

## Consequences

- El decoder deja de aceptar el seed actual: hay que migrar `lactose` → `dairy` editorialmente
  (la editora decide caso por caso, no es un reemplazo automático) y declarar el estado de
  revisión de cada receta.
- Una receta cuyo estado de revisión no se pueda determinar falla ruidosamente al decodificar;
  nunca se asume "sin alérgenos".
- El coco de la crema de coco queda pendiente de criterio editorial si algún día entra `nuts`:
  la FDA lo clasifica como fruto seco.
