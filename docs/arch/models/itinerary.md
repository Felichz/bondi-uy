# lib/models/itinerary.dart

Este archivo define el modelo de datos para un itinerario de viaje individual, generalmente obtenido de un planificador de rutas como OTP.

## Responsabilidades:

- Representar un plan de viaje completo desde un origen hasta un destino.
- Contener una lista ordenada de tramos (`RouteLeg`) que componen el viaje.
- Proveer getters para calcular la duración total y el tiempo total de caminata del itinerario.
- Permitir la creación de objetos `Itinerary` a partir de datos JSON.

## Propiedades:

- `startTime`: Marca de tiempo de inicio del itinerario (int, en milisegundos).
- `endTime`: Marca de tiempo de fin del itinerario (int, en milisegundos).
- `legs`: Lista de objetos `RouteLeg` que representan los tramos individuales del itinerario (List<RouteLeg>).

## Getters:

- `duration`: Calcula la duración total del itinerario en segundos.
- `walkTime`: Calcula el tiempo total de caminata dentro del itinerario en segundos, usando `LegModeConstants.walk`.

## Entradas:

- El constructor requiere `startTime`, `endTime`, y una lista de `legs`.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` que representa un itinerario en formato JSON.
- El método estático `listFromJson` toma una `List<dynamic>` de objetos JSON y devuelve una lista de objetos `Itinerary`.

## Salidas/Efectos:

- Provee una estructura de datos para organizar y presentar los planes de viaje obtenidos.
- Los getters ofrecen resúmenes rápidos de la duración y el tiempo de caminata.
- Los métodos `fromJson` y `listFromJson` facilitan la integración con respuestas de APIs de planificación de rutas.
