# El historial lleva fechas y el reloj se inyecta

El PRD promete que el feed no repita lo visto "recientemente", pero `FeedQuery` recibía
`seen` como un conjunto de IDs sin fechas, con el que sólo se puede expresar "alguna vez".
`LeftoversQuery` tenía el mismo problema: necesita lo cocinado esta semana, no lo de marzo.
Y como `seen` sólo crecía, el feed acababa agotándose y reiniciándose entero.

Las vistas y los cocinados pasan a ser entradas con fecha, y "recientemente" es una ventana
temporal explícita, parametrizada, evaluada contra un reloj que se inyecta desde fuera. El
valor concreto de la ventana es una decisión editorial sobre el catálogo real, no una
constante del dominio.

## Considered Options

- **Ventana por cantidad** ("no repitas las últimas N vistas"). Más simple, pero falla con
  esta persona: cocina dos veces al día y una sola tarde de scroll agota N, evaporando el
  bloqueo. La pregunta real es "¿comí esto esta semana?", no "¿lo vi hace N tarjetas?".
- **Dejar `seen` sin fechas.** Con cien recetas tarda en doler, pero el PRD quedaría
  incumplido y el reinicio del feed seguiría siendo inevitable.

## Consequences

- Ninguna regla de dominio puede llamar a `Date()` por su cuenta: el reloj entra siempre como
  parámetro, o los tests dejan de ser deterministas.
- Cambiar la ventana de 7 a 14 días debe ser cambiar un parámetro, nunca reescribir una consulta.
