# Los temporizadores de cocina usan AlarmKit

Un Paso con temporizador invita a adelantar el siguiente mientras corre: doce minutos friendo
patatas son el momento de batir los huevos. Por eso el temporizador tiene que seguir visible y
sonar aunque la usuaria cambie de Paso, salga de Karta para poner música o bloquee el móvil.
Dentro de la app lo muestra la barra de progreso (el segmento del Paso pasa a ser una píldora
con el tiempo). Fuera de la app usamos AlarmKit (iOS 26): la cuenta atrás aparece en la isla
dinámica y en la pantalla de bloqueo, y al terminar suena como una alarma, también en silencio
y en modo Concentración.

## Considered Options

- **Notificación local al terminar**: más simple y sin permiso nuevo, pero no muestra la cuenta
  atrás y con el móvil en silencio no suena. Un temporizador de cocina que no suena es
  exactamente el fallo que quema la comida.
- **Sólo dentro de la app**: obliga a no salir de Karta durante toda la sesión.
- **Dibujar una cápsula propia alrededor de la isla** para que se vea con Karta en primer plano
  (la isla no muestra la actividad de la propia app mientras está abierta): depende de la
  geometría de cada modelo y no existe en los iPhone sin isla.

## Consequences

- El objetivo mínimo de la app sube de iOS 17 a iOS 26, para tener un solo camino: Karta aún
  no se ha lanzado y la usuaria objetivo tiene un iPhone reciente.
- El shell necesita una extensión de widget para la cuenta atrás y pide permiso de alarmas la
  primera vez que la usuaria arranca un temporizador, no antes.
- El estado del temporizador sigue viviendo en `CookingSession` (`KartaCore`); AlarmKit sólo lo
  refleja fuera de la app y nunca decide nada.

## Ampliación del 2026-10-29 (#5)

- **Pausa.** Un temporizador puede pausarse y reanudarse. La pausa vive en `CookingSession` (el
  tiempo que queda) y se guarda en la sesión (ADR 0010). AlarmKit pausa y reanuda su cuenta
  atrás para reflejarla, y sus propios botones de pausa y reanudación son acciones de la app
  como las de la pantalla: nunca deciden por su cuenta.
- **Stop** devuelve el temporizador a listo y para la alarma de AlarmKit si estaba sonando.
  Para la inferencia del Cocinado (ADR 0008) cuenta que se arrancó, aunque luego se pare.
- **Salir de la sesión cancela los temporizadores.** Salir termina la sesión para siempre, así
  que una alarma que sonara después no tendría a qué Paso volver. Al salir, los temporizadores
  corriendo o en pausa se cancelan con sus alarmas de AlarmKit. Hasta ahora `KartaCore` los
  dejaba correr tras salir.
- **Sin permiso de alarmas** el temporizador corre igual y sólo suena con Karta abierta. Una
  hoja lo explica una sola vez, cuando se deniega el permiso.
