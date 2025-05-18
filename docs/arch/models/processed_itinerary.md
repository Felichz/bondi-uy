# lib/models/processed_itinerary.dart

Este archivo define el modelo de datos para un itinerario de viaje que ha sido procesado para enriquecerlo con información adicional, como datos de ETA en tiempo real y advertencias.

## `ProcessedItinerary` (Clase Principal):

Representa un itinerario de viaje mejorado con métricas calculadas y información en tiempo real.

### Responsabilidades:

- Almacenar el itinerario original obtenido del planificador (`Itinerary`).
- Contener métricas calculadas como la duración total de caminata, la duración de la caminata hasta la primera parada de bus, y la duración de la espera del primer bus.
- Incluir información sobre la ETA representativa del primer bus.
- Indicar si es posible alcanzar el primer bus a tiempo.
- Almacenar una lista de advertencias relacionadas con el itinerario.
- Mantener un score asociado al itinerario (posiblemente para ordenamiento o evaluación).
- Opcionalmente, puede incluir un mapa de información procesada para tramos de bus individuales (`processedBusLegsMap`).
- Almacenar la duración total estimada del itinerario.
- Proveer un método `copyWith` para crear copias modificadas.

### Propiedades:

- `originalOtpItinerary`: El itinerario original sin procesar (`Itinerary`, requerido).
- `totalWalkDuration`: Duración total de caminata en el itinerario (`Duration`, requerido).
- `walkToFirstBusStopDuration`: Duración de la caminata hasta la primera parada de bus (`Duration`, requerido).
- `representativeFirstBusETAInfo`: Información de llegada estimada representativa para el primer bus (`BusArrivalInfo`, opcional).
- `firstBusWaitDuration`: Duración de la espera del primer bus (`Duration`, requerido).
- `canReachFirstBus`: Indica si la caminata permite llegar a tiempo al primer bus (`bool`, requerido).
- `warnings`: Lista de advertencias asociadas al itinerario (`List<ItineraryWarningType>`, por defecto vacía).
- `score`: Un valor numérico que representa la calidad o preferencia del itinerario (double, requerido).
- `processedBusLegsMap`: Un mapa con información procesada para tramos de bus específicos (Map<String, ProcessedBusLegInfo>, opcional).
- `estimatedTotalDuration`: Duración total estimada del itinerario, incluyendo esperas y transferencias (`Duration`, requerido).

### Entradas:

- El constructor requiere `originalOtpItinerary`, `totalWalkDuration`, `walkToFirstBusStopDuration`, `firstBusWaitDuration`, `canReachFirstBus`, `score`, y `estimatedTotalDuration`. Las otras propiedades son opcionales o tienen valores por defecto.
- El método `copyWith` permite crear una nueva instancia con propiedades específicas modificadas.

### Salidas/Efectos:

- Provee una representación enriquecida de un itinerario, lista para ser mostrada en la UI o utilizada en lógica de comparación y filtrado.
- Agrega contexto de tiempo real (ETA) y usabilidad (canReachFirstBus, warnings) al itinerario base.

## Clases Anidadas:

Este archivo también define las siguientes clases de soporte, marcadas con `@immutable`:

### `AlternativeBusLineInfo`:

- **Responsabilidades**: Representar información sobre una línea de bus alternativa para un tramo fusionado.
- **Propiedades**: `lineShortName` (String, requerido), `etaInfo` (BusArrivalInfo, opcional, ETA específica para esta alternativa).
- **Entradas**: Constructor.
- **Salidas/Efectos**: Provee detalles sobre opciones de líneas alternativas para un tramo de bus.

### `ProcessedBusLegInfo`:

- **Responsabilidades**: Contener información procesada detallada para un tramo específico que involucra un bus.
- **Propiedades**: `originalLegIdentifier` (String, requerido, identifica el `RouteLeg` original), `principalLineShortName` (String, requerido), `principalLineETAInfo` (BusArrivalInfo, opcional, la ETA seleccionada para este tramo si es el primero), `alternatives` (List<AlternativeBusLineInfo>, por defecto vacía).
- **Entradas**: Constructor.
- **Salidas/Efectos**: Agrupa información relevante y procesada para un tramo de bus, incluyendo alternativas de línea y su ETA.
