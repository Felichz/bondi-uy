# lib/models/consolidated_itinerary.dart

Este archivo define el modelo de datos para un itinerario consolidado. Un itinerario consolidado agrupa múltiples `ProcessedItinerary` individuales que son similares en sus tramos principales, presentando una opción de viaje principal al usuario con posibles alternativas dentro de ella.

## `ConsolidatedItinerary` (Clase):

Representa un conjunto de opciones de viaje relacionadas presentadas como una única unidad.

### Responsabilidades:

- Agrupar itinerarios procesados similares para simplificar la presentación al usuario.
- Contener una lista de tramos consolidados (`ConsolidatedItineraryLeg`).
- Mantener una referencia al `ProcessedItinerary` que mejor representa al grupo (`representativeProcessedItinerary`).
- Opcionalmente, almacenar la lista de todos los `ProcessedItinerary` originales agrupados (`originalProcessedItineraries`).
- Resumir métricas clave como duración total, tiempo de caminata, tiempo de espera, etc., para el grupo.
- Incluir información consolidada de ETA para el primer bus y alternativas.
- Presentar un score y advertencias consolidadas.
- Proveer un identificador único.

### Propiedades:

- `id`: Identificador único para el itinerario consolidado (String, requerido).
- `legs`: Lista de tramos consolidados (`List<ConsolidatedItineraryLeg>`, requerido).
- `representativeProcessedItinerary`: El `ProcessedItinerary` que representa al grupo (`ProcessedItinerary`, requerido).
- `originalProcessedItineraries`: Lista de todos los `ProcessedItinerary` agrupados (`List<ProcessedItinerary>`, requerido).
- `estimatedTotalDuration`: Duración total estimada del itinerario consolidado (`Duration`, requerido).
- `totalWalkDuration`: Duración total de caminata consolidada (`Duration`, requerido).
- `walkToFirstBusStopDuration`: Duración de la caminata hasta la primera parada de bus consolidada (`Duration`, requerido).
- `firstBusWaitDuration`: Duración de la espera del primer bus consolidada (`Duration`, requerido).
- `representativeFirstBusETAInfo`: ETA representativa del primer bus (`BusArrivalInfo`, opcional).
- `alternativeFirstBusETAs`: Lista de ETAs alternativas para el primer bus (`List<BusArrivalInfo>`, por defecto vacía).
- `canReachFirstBus`: Indica si se puede alcanzar el primer bus (considerando alternativas) (`bool`, requerido).
- `warnings`: Lista de advertencias consolidadas (`List<ItineraryWarningType>`, por defecto vacía).
- `score`: Puntuación del itinerario consolidado (double, requerido).

### Getters:

- `startTime`: Hora de inicio del itinerario consolidado (basado en `representativeProcessedItinerary`).
- `endTime`: Hora de fin del itinerario consolidado (basado en `representativeProcessedItinerary`).
- `isWalkOnly`: Indica si el itinerario consolidado consiste únicamente en un tramo a pie.

### Entradas:

- El constructor requiere `id`, `legs`, `representativeProcessedItinerary`, `originalProcessedItineraries`, `estimatedTotalDuration`, `totalWalkDuration`, `walkToFirstBusStopDuration`, `firstBusWaitDuration`, `canReachFirstBus`, y `score`. `representativeFirstBusETAInfo` y `alternativeFirstBusETAs`, y `warnings` son opcionales o tienen valores por defecto.

### Salidas/Efectos:

- Provee una representación de alto nivel y resumida de opciones de viaje, diseñada para la interfaz de usuario.
- Facilita la comparación y selección entre diferentes opciones de ruta agrupadas.
