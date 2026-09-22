# Qué sobrevive al cierre de la app, y qué se hace con datos que no se entienden

Ni `Cookbook`, ni `CookedEvent`, ni `OnboardingProfile` eran serializables y no existía un
snapshot: cada consumidor tendría que inventarse su restauración, empezando por quien
implemente la app iOS sin conocer ninguna de estas decisiones.

Se persiste lo que es de la usuaria y duele perder: intolerancias y hogar, el Cookbook con su
techo de cupo, el historial de vistas y cocinados con sus fechas, y los gustos de la
calibración. No se persiste lo que se recalcula o caduca solo: la posición en el feed (ADR
0009), la frontera —que se calcula siempre contra los filtros vigentes— ni el feed mismo.

Una sesión de cocina a medias **sí** se guarda, con su paso y sus temporizadores, en contra de
lo que sugería la revisión. Es el único momento en que la usuaria no puede rehacer el trabajo
perdido: la comida está en el fuego y tiene las manos ocupadas. Además sale casi gratis, porque
un temporizador ya es fecha de inicio más duración, así que al volver se sabe cuánto queda o
que ya sonó. La sesión caduca —volver seis horas después no es la misma cocción— y al restaurar
no se reanuda un temporizador corriendo, se muestra qué ocurrió durante la ausencia.

El formato guardado va a cambiar, y cuando la versión 2 añada un campo habrá datos de la
versión 1 en el teléfono. La regla es que **lo que no se entiende no se borra nunca**: se
conserva intacto y la app arranca en un estado seguro. Perder los guardados de alguien por un
cambio de formato es imperdonable y se parece demasiado a la carpeta de culpa de Instagram que
este producto quiere reemplazar.

## Consequences

- El snapshot es versionado y explícito, con DTOs propios: el modelo de dominio no se serializa
  directamente para que un refactor no cambie el formato en disco por accidente.
- Hay que probar la restauración con datos de una versión anterior y con datos corruptos, no
  sólo el round-trip feliz.
