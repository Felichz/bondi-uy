# lib/controllers/bus_tracking_controller.dart

Este archivo define la clase `BusTrackingController`, responsable de gestionar el seguimiento en tiempo real de autobuses en el mapa y la visualización de su posición actualizada y el segmento de la línea que aún no ha recorrido.

## `BusTrackingController` (Clase):

Controla el inicio, la detención y la actualización periódica del seguimiento de un bus específico asociado a un tramo de ruta planificado. Utiliza datos de ETA en tiempo real (si están disponibles) para mostrar la posición del bus en el mapa y resaltar el tramo restante de la línea hasta la parada del usuario. Se integra con `MapboxService` para las operaciones de visualización en el mapa y con Riverpod (`MapNotifier`, `etaFetcherServiceProvider`) para acceder y actualizar el estado de la aplicación y obtener datos de ETA.

### Responsabilidades:

- Cargar y parsear las geometrías completas de las líneas de bus desde un archivo GeoJSON local (`shapes.geojson`).
- Iniciar el seguimiento de un bus específico cuando se selecciona un itinerario y tramo que ofrece datos de ETA en tiempo real con posición (`startTrackingBusLine`).
- Detener el seguimiento del bus (`stopTrackingBusLine`), limpiando los marcadores y capas asociados del mapa.
- Configurar un temporizador para solicitar periódicamente actualizaciones de ETA para el bus rastreado (`_realtimeBusTimer`).
- Procesar las actualizaciones de ETA recibidas, actualizar la posición del marcador del bus en el mapa y dibujar/actualizar el segmento de la línea que representa el recorrido restante hasta la parada del usuario (`updateRealtimeBusMarkerAndSegment`, `drawIncomingBusSegment` a través de `MapboxService`).
- Identificar el segmento de la línea completa de bus relevante para el tramo rastreado y dibujarlo en el mapa como referencia (`drawFullBusLineShape` a través de `MapboxService`).
- Acceder al servicio de obtención de ETA (`ETAFetcherService`) a través de Riverpod para obtener las actualizaciones periódicas.
- Notificar a `MapNotifier` sobre el estado del seguimiento en tiempo real y la ETA representativa actualizada.

### Propiedades Internas:

- `_ref`: Referencia a `WidgetRef` de Riverpod para acceder a otros providers.
- `_mapboxService`: Instancia de `MapboxService` para interactuar con el mapa.
- `_shapeGeometries`: Mapa que almacena las geometrías completas de las líneas de bus cargadas desde `shapes.geojson`.
- `_shapesLoaded`: Booleano que indica si las geometrías de las líneas han sido cargadas.
- `_currentTrackedBusLeg`: El `RouteLeg` del bus que se está rastreando actualmente.
- `_currentTrackedETAInfo`: El `BusArrivalInfo` actual del bus rastreado, incluyendo su posición si está disponible.
- `_currentTrackingStopId`, `_currentTrackingLineShortName`: Identificadores del tramo y la línea que se están rastreando, utilizados para las solicitudes de actualización de ETA.
- `_currentFullShapeForBusLeg`: La geometría completa de la línea de bus correspondiente al tramo rastreado.
- `_originStopIndexOnShape`, `_destinationStopIndexOnShape`: Índices que indican la posición de la parada de origen y destino del tramo de bus dentro de la geometría completa de la línea.
- `_currentFullLineShapeId`: El ID de la geometría completa de la línea de bus dibujada en el mapa.
- `_realtimeBusTimer`: `Timer` utilizado para programar las actualizaciones periódicas de ETA.
- Constantes estáticas para los IDs de las capas y fuentes de datos de Mapbox utilizadas para el bus en tiempo real y la línea completa.

### Constructor:

- `BusTrackingController({required WidgetRef ref, required MapboxService mapboxService})`:
  - **Descripción**: Inicializa el controlador inyectando las dependencias de Riverpod (`ref`) y el servicio de Mapbox (`mapboxService`). Inicia el proceso asíncrono de carga de las geometrías de las líneas de bus.
  - **Entradas**: `ref` (referencia a `WidgetRef`), `mapboxService` (instancia de `MapboxService`).
  - **Salidas/Efectos**: Crea una instancia del controlador e inicia la carga de datos GeoJSON.

### Métodos:

- `_loadAndParseShapesGeoJson()` (Método Privado):

  - **Descripción**: Carga el contenido del archivo `assets/data/shapes.geojson`, lo parsea y almacena las polilíneas asociadas a cada `shape_id` en `_shapeGeometries`.
  - **Entradas**: Ninguna (lee de `rootBundle`).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Lee un archivo local, decodifica JSON, popula `_shapeGeometries`, actualiza `_shapesLoaded`. Puede imprimir errores.

- `startTrackingBusLine(RouteLeg busLegToTrack, BusArrivalInfo? etaInfo)`:

  - **Descripción**: Inicia el seguimiento de un bus. Detiene cualquier seguimiento anterior, guarda los datos del tramo y ETA inicial, busca y dibuja la geometría completa de la línea si está disponible, dibuja el marcador del bus y el segmento restante (si hay ETA en tiempo real con posición), y configura el timer para las actualizaciones periódicas.
  - **Entradas**: `busLegToTrack` (El `RouteLeg` del bus a rastrear), `etaInfo` (La información inicial de `BusArrivalInfo`, opcional).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Cancela timers, actualiza propiedades internas, llama a métodos de `MapboxService` para dibujar en el mapa, configura `_realtimeBusTimer`. Puede imprimir mensajes de depuración/error.

- `stopTrackingBusLine()`:

  - **Descripción**: Detiene el seguimiento del bus. Cancela el timer de actualización, limpia las propiedades internas relacionadas con el seguimiento y elimina del mapa el marcador del bus, el segmento restante y la geometría completa de la línea si fueron dibujados.
  - **Entradas**: Ninguna.
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Cancela `_realtimeBusTimer`, resetea propiedades internas, llama a métodos de `MapboxService` para limpiar el mapa.

- Método del `Timer` (dentro de `startTrackingBusLine`):

  - **Descripción**: Se ejecuta periódicamente (cada 10 segundos). Solicita la ETA actualizada para la parada y línea rastreadas utilizando `ETAFetcherService`. Si encuentra una ETA en tiempo real con posición, actualiza la posición del bus en el mapa y notifica a `MapNotifier`. Si no encuentra una actualización válida, detiene el seguimiento.
  - **Entradas**: Ninguna (utiliza las propiedades internas `_currentTrackingStopId`, `_currentTrackingLineShortName`).
  - **Salidas**: Ninguna (asíncrono).
  - **Efectos**: Llama a `ETAFetcherService.getUpcomingBusesForStop`, procesa la respuesta, actualiza `_currentTrackedETAInfo`, llama a métodos de `MapboxService` para actualizar el mapa, notifica a `MapNotifier`, cancela el timer y llama a `stopTrackingBusLine` si no hay actualización válida o ocurre un error.

- `dispose()`:
  - **Descripción**: Cancela el timer de actualización en tiempo real cuando el controlador ya no es necesario para evitar fugas de memoria.
  - **Entradas**: Ninguna.
  - **Salidas**: Ninguna.
  - **Efectos**: Cancela `_realtimeBusTimer`.

## Entradas:

- Depende de `WidgetRef` (Riverpod) y una instancia de `MapboxService` inyectadas en el constructor.
- Recibe el `RouteLeg` y opcionalmente `BusArrivalInfo` iniciales para iniciar el seguimiento.
- Accede a `ETAFetcherService` a través de Riverpod para las actualizaciones.
- Lee las geometrías de las líneas de bus desde un archivo local.

## Salidas/Efectos:

- Dibuja y actualiza la posición de un marcador de bus y un segmento de línea en el mapa de Mapbox.
- Dibuja la geometría completa de la línea de bus como contexto visual.
- Notifica a `MapNotifier` sobre el estado del seguimiento en tiempo real y las ETAs actualizadas, permitiendo que la UI refleje estos cambios.
- Gestiona la lógica de temporización para las actualizaciones periódicas.
- Maneja errores durante la obtención de actualizaciones de ETA.
