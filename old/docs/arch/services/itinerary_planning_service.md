# lib/services/itinerary_planning_service.dart

Este archivo define el servicio (`ItineraryPlanningService`) encargado de coordinar la obtención, procesamiento y consolidación de itinerarios de viaje.

## `ItineraryPlanningService` (Clase):

Es el orquestador principal para la planificación de rutas, utilizando otros servicios para obtener datos crudos (OTP, ETA) y aplicando lógica de negocio para generar opciones de viaje enriquecidas y consolidadas.

### Responsabilidades:

- Coordinar la comunicación con `OtpService` para obtener itinerarios iniciales basados en puntos geográficos, fecha y hora.
- Coordinar la comunicación con `ETAFetcherService` (ej. `MontevideoApiService`) para obtener información de llegada en tiempo real (ETA) para las paradas de bus relevantes encontradas en los itinerarios.
- Procesar los itinerarios crudos de OTP, calculando métricas adicionales (tiempos de caminata total y hasta el primer bus, tiempo de espera), obteniendo la ETA más relevante para el primer tramo de bus, determinando si es posible alcanzar el primer bus a tiempo (`canReachFirstBus`), y generando advertencias (`_processSingleItinerary`).
- Asignar un score a cada itinerario procesado para permitir su ordenamiento y comparación.
- Consolidar itinerarios procesados similares (especialmente aquellos que comparten el primer segmento de bus entre las mismas paradas) en `ConsolidatedItinerary`s (`_consolidateItineraries`).
- Crear tramos consolidados (`ConsolidatedItineraryLeg`) fusionando información de múltiples itinerarios cuando aplique (ej. para un tramo de bus compartido con varias líneas alternativas) (`_createFusedConsolidatedLegs`).
- Proveer el método principal `planAndConsolidateItineraries` como punto de entrada para obtener opciones de viaje listas para la UI.
- Manejar excepciones que puedan ocurrir durante la planificación.

### Propiedades Internas:

- `_otpService`: Instancia del servicio para interactuar con OTP (`OtpService`, inyectada en constructor).
- `_etaFetcherService`: Instancia del servicio para obtener ETAs (`ETAFetcherService`, inyectada en constructor). Es una abstracción que puede ser implementada por `MontevideoApiService`.
- Constantes de configuración y lógica de negocio, como `REACH_BUS_SAFETY_MARGIN_SECONDS` (margen para alcanzar el bus) y `MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP` (límite para consultas de ETA).

### Constructor:

- `ItineraryPlanningService({required OtpService otpService, required ETAFetcherService etaFetcherService})`:
  - **Descripción**: Inicializa el servicio inyectando las dependencias necesarias para interactuar con los servicios de OTP y ETA.
  - **Entradas**: Una instancia de `OtpService` y una implementación de `ETAFetcherService`.
  - **Salidas/Efectos**: Crea una instancia del servicio lista para realizar la planificación de itinerarios.

### Métodos Principales del Flujo de Planificación:

- `planAndConsolidateItineraries({required Point_dart fromPlace, required Point_dart toPlace, required DateTime dateTime, required bool arriveBy, int? numItineraries})`:

  - **Descripción**: Punto de entrada principal. Realiza la planificación de rutas completa: obtiene itinerarios crudos de OTP, los procesa con datos de ETA y advertencias, y luego los consolida en un formato amigable para el usuario.
  - **Entradas**: Puntos de origen y destino (`Point_dart`), la fecha y hora deseadas (`DateTime`), un flag `arriveBy` para indicar si `dateTime` es la hora de llegada o salida, y un número opcional de itinerarios a solicitar a OTP (`numItineraries`).
  - **Salidas**: Un `Future<List<ConsolidatedItinerary>>` que resuelve a una lista de opciones de viaje consolidadas y enriquecidas, ordenadas por score.
  - **Efectos**: Orquesta las llamadas a `getProcessedItineraries` y `_consolidateItineraries`. Retorna una lista vacía si no se encuentran itinerarios o hay errores significativos.

- `getProcessedItineraries({...})`:
  - **Descripción**: Obtiene itinerarios del `OtpService`, maneja la respuesta cruda (parseo y errores), itera sobre los itinerarios obtenidos y llama a `_processSingleItinerary` para enriquecer cada uno individualmente. Gestiona un caché y un límite para las consultas de ETA por parada.
  - **Entradas**: Similares a `planAndConsolidateItineraries` (ubicación, fecha/hora, `arriveBy`, `numItineraries`).
  - **Salidas**: Un `Future<List<ProcessedItinerary>>` que resuelve a una lista de itinerarios individualmente procesados y enriquecidos.
  - **Efectos**: Interactúa con `_otpService`, parsea datos JSON, llama a `_etaFetcherService` para obtener ETAs (con manejo de caché y límite), y transforma `Itinerary` a `ProcessedItinerary` llamando a `_processSingleItinerary`. Puede imprimir mensajes de depuración/error.

### Métodos de Procesamiento Interno:

- `_processSingleItinerary(Itinerary itinerary, RouteLeg? firstBusLeg, String? stopIdForETA, String? lineShortNameForETA, List<BusArrivalInfo>? upcomingBusesAtStop, bool etaLookupAttempted)`:

  - **Descripción**: Realiza el procesamiento y enriquecimiento de un único `Itinerary` de OTP. Calcula tiempos de caminata y espera, busca la información de ETA más relevante en la lista proporcionada para el primer tramo de bus (si existe), determina si es posible alcanzar el primer bus a tiempo considerando un margen de seguridad, y genera advertencias (`ItineraryWarning`) basadas en las condiciones encontradas (errores de ETA, ETA no encontrada, tiempo de caminata excesivo, etc.). Finalmente, calcula un score para el itinerario.
  - **Entradas**: Un objeto `Itinerary` crudo, información sobre el primer tramo de bus, detalles de la parada y línea para la ETA, la lista de `BusArrivalInfo` obtenida para esa parada, y un booleano indicando si se intentó consultar la ETA.
  - **Salidas**: Un objeto `ProcessedItinerary` con métricas calculadas, ETA representativa del primer bus, estado de alcanzabilidad, advertencias y score.
  - **Efectos**: Realiza cálculos aritméticos sobre duraciones y tiempos, lógica condicional para buscar la ETA y determinar la alcanzabilidad, y lógica para asignar penalizaciones al score basadas en advertencias.

- `_getNormalizedStopId(LegEndpoint endpoint)`:
  - **Descripción**: Método helper privado utilizado para extraer un identificador de parada consistente y útil (GTFS ID o ID de agencia) de un `LegEndpoint`, manejando posibles formatos diferentes y priorizando identificadores más completos.
  - **Entradas**: Un objeto `LegEndpoint`.
  - **Salidas**: Un String que representa el identificador normalizado de la parada o un valor por defecto (`"unknown_stop_id"`).
  - **Efectos**: Lógica de validación y selección de cadenas.

### Métodos de Consolidación:

- `_consolidateItineraries(List<ProcessedItinerary> processedItineraries)`:

  - **Descripción**: Agrupa una lista de `ProcessedItinerary`s basándose principalmente en la similitud de su primer segmento de bus (misma parada de origen y destino del bus) o los agrupa individualmente si no tienen tramos de bus. Para cada grupo, selecciona un itinerario representativo (el de mejor score) y llama a `_createFusedConsolidatedLegs` para construir los tramos consolidados. Recopila las ETAs alternativas para el segmento de bus fusionado y crea el objeto `ConsolidatedItinerary` correspondiente. Finalmente, ordena la lista de itinerarios consolidados por score.
  - **Entradas**: Una lista de `ProcessedItinerary`s.
  - **Salidas**: Una lista de `ConsolidatedItinerary`s, ordenados por score.
  - **Efectos**: Utiliza `groupBy` para la agrupación. Genera objetos `ConsolidatedItinerary`s y `ConsolidatedItineraryLeg`s. Recopila y procesa ETAs alternativas.

- `_createFusedConsolidatedLegs(ProcessedItinerary representativeItinerary, List<ProcessedItinerary> allItinerariesInGroup, String? busSegmentKey)`:
  - **Descripción**: Construye la lista de tramos consolidados (`ConsolidatedItineraryLeg`s) para un grupo específico de itinerarios procesados. Si el grupo corresponde a un segmento de bus clave (`busSegmentKey` no nulo), fusiona los tramos de bus de todos los itinerarios del grupo que coinciden con ese segmento, recopilando los nombres cortos de las líneas y referencias a los `RouteLeg`s originales. Para los tramos que no son el segmento de bus clave (o si `busSegmentKey` es nulo), crea un `ConsolidatedItineraryLeg` simple basado en el itinerario representativo.
  - **Entradas**: El itinerario representativo del grupo, la lista completa de itinerarios en ese grupo, y la clave del segmento de bus para la fusión (String con formato "SEGMENT:fromId>toId" o null).
  - **Salidas**: Una lista de `ConsolidatedItineraryLeg`s que representan los tramos de la opción consolidada.
  - **Efectos**: Itera sobre los tramos del itinerario representativo. Busca tramos de bus coincidentes en los otros itinerarios del grupo. Crea instancias de `ConsolidatedItineraryLeg`, poblando `alternativeLineShortNames` y `originalBusLegs` cuando fusiona tramos de bus.

## Entradas Generales del Servicio:

- Depende de las instancias de `OtpService` y `ETAFetcherService` inyectadas.
- Depende de varios modelos definidos en `lib/models` para representar y procesar datos de itinerarios, tramos, llegadas y advertencias.
- Recibe parámetros de entrada para la planificación (ubicación, fecha/hora, etc.).

## Salidas/Efectos Generales del Servicio:

- Provee a la UI (o a otros componentes) una lista de `ConsolidatedItinerary`s, que son representaciones de opciones de viaje enriquecidas, procesadas y agrupadas para facilitar la selección por parte del usuario.
- Enriquece los datos de planificación básicos (solo tiempo y distancia) con información de tiempo real (ETA), estado de alcanzabilidad y advertencias relevantes.
- Abstracta la complejidad de interactuar con múltiples servicios externos (OTP, API Montevideo) y la lógica de procesamiento y agrupación.
- Puede lanzar excepciones de tipo `ItineraryPlanningException` para indicar fallos en el proceso de planificación.
