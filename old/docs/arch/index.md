# Visión General de la Arquitectura

Esta aplicación de planificación de rutas de transporte público en Montevideo está estructurada alrededor de varios componentes principales que interactúan para proporcionar una experiencia de usuario fluida. La gestión del estado se maneja principalmente con Riverpod, mientras que la interfaz de usuario se construye con Flutter. Los servicios externos como Mapbox, OpenTripPlanner (OTP) y la API de transporte de Montevideo son cruciales para la funcionalidad principal.

## Diagrama de Flujo de Componentes (Simplificado)

```
+---------------------+     +-------------------------+     +---------------------+
|     Usuario (UI)    |<--->|   MapScreen (Flutter)   |<--->| MapNotifier (Riverpod)|
+---------------------+     +-----------+-------------+     +----------+----------+
                                        |                               |
                                        |                               |
                                        v                               v
+---------------------+     +-------------------------+     +---------------------+
| Controladores       |     | Servicios               |     | Modelos de Datos    |
| (MapInteraction,    |<--->| (ItineraryPlanning,     |<--->| (Itinerary, RouteLeg|
|  MapZoom,           |     |  Mapbox, Geocoding,     |     |  BusArrivalInfo, etc)|
|  RouteDisplay,      |     |  Otp, MontevideoApi)    |     +---------------------+
|  BusTracking)       |     +-----------+-------------+
+---------------------+                 |
                                        |
                                        v
                        +---------------------------+
                        | APIs Externas             |
                        | (Mapbox, OTP, API MVD)    |
                        +---------------------------+
```

**Descripción de los Componentes Principales:**

1.  **Usuario (UI):**

    - Interactúa con la aplicación a través de los widgets de Flutter.
    - Ingresa origen/destino, selecciona rutas, visualiza el mapa e instrucciones.

2.  **`MapScreen` (Pantalla Principal):**

    - Widget principal de Flutter que organiza la interfaz de usuario.
    - Contiene el mapa de Mapbox, paneles de búsqueda, barras de instrucciones y modales.
    - Orquesta la inicialización y el uso de los diferentes controladores y servicios a nivel de UI.
    - Escucha los cambios de estado de `MapNotifier` para reconstruir la UI.

3.  **`MapNotifier` (Gestor de Estado - Riverpod):**

    - Clase central para la gestión del estado de la aplicación relacionado con el mapa y la planificación.
    - Mantiene el `MapState` (origen, destino, itinerarios, estado de planificación, etc.).
    - Recibe acciones de la UI (a través de `MapScreen` y sus widgets) y de los controladores.
    - Orquesta la lógica de negocio llamando a servicios (ej. `ItineraryPlanningService`).
    - Notifica a los listeners (principalmente `MapScreen`) sobre los cambios de estado.

4.  **Controladores (`BusTrackingController`, `MapInteractionController`, `MapZoomController`, `RouteDisplayController`):**

    - Encapsulan lógica específica para interactuar con el mapa o gestionar funcionalidades concretas.
      - `MapInteractionController`: Maneja taps, movimientos de cámara del usuario.
      - `MapZoomController`: Controla los niveles de zoom y objetivos de la cámara.
      - `RouteDisplayController`: Gestiona cómo se dibujan las rutas en el mapa.
      - `BusTrackingController`: Maneja el seguimiento en tiempo real de los autobuses.
    - Interactúan con `MapboxService` para operaciones de bajo nivel del mapa.
    - Pueden leer el estado de `MapNotifier` y/o enviar actualizaciones al mismo.

5.  **Servicios:**

    - **`ItineraryPlanningService`**: Orquesta la planificación de rutas.
      - Obtiene datos de `OtpService` y `ETAFetcherService` (implementado por `MontevideoApiService`).
      - Procesa, enriquece y consolida los itinerarios.
    - **`MapboxService`**: Abstrae las interacciones de bajo nivel con el SDK de Mapbox (dibujar rutas, marcadores, paradas, manejar taps en el mapa).
    - **`GeocodingService`**: Provee sugerencias de lugares usando la API de Mapbox Geocoding.
    - **`OtpService`**: Interactúa con el servidor OpenTripPlanner (OTP) para obtener planes de ruta crudos.
    - **`MontevideoApiService`**: Interactúa con la API de transporte de Montevideo para obtener ETAs, información de líneas y paradas. Implementa `ETAFetcherService`.
    - **`ETAFetcherService` (Interfaz)**: Define el contrato para obtener datos de ETA.

6.  **Modelos de Datos:**

    - Definen la estructura de los datos utilizados en la aplicación (ej. `Itinerary`, `RouteLeg`, `BusArrivalInfo`, `ConsolidatedItinerary`, `MapState`, etc.).
    - Usados por servicios, controladores y `MapNotifier` para representar y manipular la información.

7.  **APIs Externas:**
    - **Mapbox**: Para mapas base, geocodificación, y potencialmente otras funcionalidades de mapas.
    - **OpenTripPlanner (OTP)**: Para la planificación de rutas multimodales.
    - **API de Transporte de Montevideo**: Para obtener datos en tiempo real de autobuses (ETA), información de líneas y paradas.

**Flujo General Típico (Planificación de Ruta):**

1.  Usuario ingresa origen y destino en `SearchPanel` (parte de `MapScreen`).
2.  `MapScreen` notifica a `MapNotifier` las ubicaciones seleccionadas.
3.  `MapNotifier` actualiza su estado (`MapState`) y llama a `ItineraryPlanningService.planAndConsolidateItineraries()`.
4.  `ItineraryPlanningService`:
    - Llama a `OtpService` para obtener rutas crudas.
    - Llama a `MontevideoApiService` (como `ETAFetcherService`) para obtener ETAs.
    - Procesa y consolida los itinerarios, generando `ConsolidatedItinerary`s.
5.  `ItineraryPlanningService` devuelve los itinerarios consolidados a `MapNotifier`.
6.  `MapNotifier` actualiza `MapState` con los resultados y el estado de `PlanningStatus.success`.
7.  `MapScreen` (escuchando a `MapNotifier`) reconstruye la UI para mostrar las opciones de ruta (ej. usando `RouteOptionsModal`).
8.  Usuario selecciona un itinerario.
9.  `MapScreen` notifica a `MapNotifier` la selección.
10. `MapNotifier` actualiza `MapState` (ej. `selectedConsolidatedItinerary`, `representativeItinerary`).
11. `MapNotifier` instruye a `RouteDisplayController` (a través de `MapScreen` o directamente) para dibujar la ruta seleccionada en el mapa usando `MapboxService`.
12. `MapNotifier` instruye a `MapZoomController` para ajustar el zoom a la ruta.
13. Si aplica, `BusTrackingController` puede ser activado para seguir un bus en tiempo real.

Esta visión general y el diagrama deberían proporcionar una comprensión holística de cómo está estructurada la aplicación y cómo fluyen los datos y las interacciones entre sus componentes.

# lib/app.dart

Este archivo contiene la configuración inicial de la aplicación y el widget raíz `MyApp`.

## Responsabilidades:

- Configurar el token de acceso de Mapbox a través de `initializeAppConfig`.
- Definir el widget raíz `MyApp`, que establece el tema de la aplicación y la pantalla inicial (`MapScreen`).

## Entradas:

- La función `initializeAppConfig` recibe el token de acceso de Mapbox como un String.
- `MyApp` utiliza `MapScreen` como su pantalla principal.

## Salidas/Efectos:

- Configura globalmente el token de acceso para Mapbox SDK.
- Define la estructura visual inicial y el tema de la aplicación Flutter.
- Establece `MapScreen` como la pantalla que se muestra al iniciar la aplicación.

# lib/constants/api_constants.dart

Este archivo define constantes para la interacción con la API de transporte de Montevideo.

## Responsabilidades:

- Almacenar las URLs base y de autenticación de la API.
- Almacenar el ID y secreto del cliente para la autenticación.

## Entradas:

- Ninguna.

## Salidas/Efectos:

- Provee las constantes `BASE_URL`, `ACCESS_TOKEN_URL`, `CLIENT_ID`, y `CLIENT_SECRET` que serán utilizadas por los servicios o módulos encargados de comunicarse con la API de transporte.

# lib/constants/mapbox_constants.dart

Este archivo define constantes relacionadas con Mapbox.

## Responsabilidades:

- Almacenar el token de acceso de Mapbox.

## Entradas:

- Ninguna.

## Salidas/Efectos:

- Provee la constante `MAPBOX_ACCESS_TOKEN` que es utilizada en `main.dart` y potencialmente en otros lugares donde se interactúe con los servicios de Mapbox (mapa, geocoding, etc.).

# lib/constants/otp_constants.dart

Este archivo define constantes para la interacción con un servidor OpenTripPlanner (OTP) local.

## Responsabilidades:

- Almacenar la URL base del servidor OTP.
- Almacenar los endpoints específicos (REST y GraphQL) para la planificación de rutas.

## Entradas:

- La constante `OTP_BASE_URL` requiere que la IP del servidor OTP sea accesible desde el dispositivo o emulador donde corre la aplicación.

## Salidas/Efectos:

- Provee las constantes `OTP_BASE_URL`, `OTP_SERVER_URL_REST`, y `OTP_SERVER_URL_GRAPHQL` que serán utilizadas por los servicios o módulos que interactúen con el servidor OTP para obtener planes de viaje.

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

# lib/controllers/map_interaction_controller.dart

Este archivo define la clase `MapInteractionController`, responsable de manejar y responder a las interacciones del usuario con el mapa de Mapbox (movimiento de cámara, taps, long presses).

## `MapInteractionController` (Clase):

Actúa como un intermediario entre los eventos de interacción crudos del mapa y la lógica de la aplicación. Notifica a `MapNotifier` sobre el inicio y fin de la interacción del usuario y gestiona acciones específicas como la identificación de paradas de bus al hacer tap y la presentación de información relevante en modales.

### Responsabilidades:

- Escuchar y procesar los eventos de cambio de cámara (`onMapCameraChangeListener`) e inactividad del mapa (`onMapIdleListener`).
- Notificar a `MapNotifier` cuando el usuario comienza o deja de interactuar manualmente con el mapa, actualizando el estado `userMapInteraction`.
- Manejar eventos de tap en el mapa (`handleMapTapEvent`), delegando la identificación de elementos (como paradas de bus) a `MapboxService`.
- Si se identifica una parada de bus al hacer tap, obtener las líneas de bus que pasan por esa parada utilizando `MontevideoApiService` y mostrar un bottom sheet modal con la información de las líneas y sus próximas llegadas (`_requestBusLinesForStopModal`).
- Manejar eventos de pulsación larga en el mapa (`handleMapLongPressEvent`) (funcionalidad placeholder por ahora).
- Proporcionar un listener para errores de carga del mapa (`onMapLoadErrorListener`).
- Integrarse con `MapboxService` para operaciones relacionadas con la interacción con elementos del mapa.
- Acceder a servicios (como `MontevideoApiService`) y notifiers (como `MapNotifier`) a través de Riverpod.

### Propiedades Internas:

- `mapboxService`: Instancia de `MapboxService` para interactuar con el mapa.
- `ref`: Referencia a `WidgetRef` de Riverpod para acceder a otros providers.

### Constructor:

- `MapInteractionController({required this.mapboxService, required this.ref})`:
  - **Descripción**: Inicializa el controlador inyectando las dependencias necesarias: una instancia de `MapboxService` y una referencia a `WidgetRef` de Riverpod.
  - **Entradas**: `mapboxService` (instancia de `MapboxService`), `ref` (referencia a `WidgetRef`).
  - **Salidas/Efectos**: Crea una instancia del controlador lista para manejar interacciones.

### Métodos:

- `onMapCameraChangeListener(CameraChangedEventData eventData)`:

  - **Descripción**: Callback llamado cuando la cámara del mapa cambia. Si el estado actual indica que el usuario estaba inactivo, asume que el cambio fue iniciado manualmente por el usuario y notifica a `MapNotifier` que la interacción ha comenzado.
  - **Entradas**: `eventData` (Datos del evento de cambio de cámara).
  - **Salidas**: Ninguna.
  - **Efectos**: Lee el estado de `MapNotifier`. Llama a `mapInteractionStarted` en `MapNotifier` si el estado es inactivo.

- `onMapIdleListener(MapIdleEventData data)`:

  - **Descripción**: Callback llamado cuando el mapa se vuelve inactivo (después de un movimiento o animación). Notifica a `MapNotifier` que la interacción ha terminado.
  - **Entradas**: `data` (Datos del evento de inactividad del mapa).
  - **Salidas**: Ninguna.
  - **Efectos**: Llama a `mapInteractionEnded` en `MapNotifier`.

- `handleMapTapEvent(MapContentGestureContext mapTapContext, BuildContext uiContext)`:

  - **Descripción**: Maneja un evento de tap en el mapa. Notifica a `MapNotifier` sobre el inicio y fin de la interacción. Llama a `MapboxService.handleMapTap` para identificar si se ha tocado un elemento interactivo (como una parada) y, si es así, ejecuta un callback proporcionado que a su vez llama a `_requestBusLinesForStopModal` para mostrar información de la parada.
  - **Entradas**: `mapTapContext` (Contexto del gesto de tap en el mapa), `uiContext` (Contexto del widget de la UI necesario para mostrar modales).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Llama a `mapInteractionStarted` y `mapInteractionEnded` en `MapNotifier`. Llama a `MapboxService.handleMapTap`. Puede desencadenar la presentación de un modal.

- `handleMapLongPressEvent(MapContentGestureContext context)`:

  - **Descripción**: Maneja un evento de pulsación larga en el mapa. Actualmente solo registra las coordenadas y notifica el inicio/fin de la interacción. Es un placeholder para futuras funcionalidades (ej. colocar un pin de ubicación).
  - **Entradas**: `context` (Contexto del gesto de pulsación larga).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Imprime mensajes de depuración. Llama a `mapInteractionStarted` y `mapInteractionEnded` en `MapNotifier`.

- `onMapLoadErrorListener(MapLoadingErrorEventData data)`:

  - **Descripción**: Callback para manejar errores durante la carga del mapa. Actualmente solo imprime detalles del error en la consola.
  - **Entradas**: `data` (Datos del evento de error de carga del mapa).
  - **Salidas**: Ninguna.
  - **Efectos**: Imprime un mensaje de error.

- `_requestBusLinesForStopModal(String stopId, String stopName, BuildContext uiContext)` (Método Privado):

  - **Descripción**: Obtiene la lista de líneas de bus para una parada específica utilizando `MontevideoApiService` y muestra un `showModalBottomSheet` para presentar esta información al usuario. Dentro del modal, permite expandir cada línea para ver las próximas llegadas (ETAs), obteniendo estos datos también a través del servicio de ETA. Gestiona el estado de carga y los mensajes de error dentro del modal.
  - **Entradas**: `stopId` (ID de la parada), `stopName` (Nombre de la parada), `uiContext` (Contexto del widget de la UI necesario para mostrar el modal).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Llama a `MontevideoApiService.fetchBusLinesForStop`. Llama a `ETAFetcherService.getUpcomingBusesForStop`. Muestra un `showModalBottomSheet`. Gestiona el estado y la visualización dentro del modal (carga, lista de líneas, lista de ETAs). Puede imprimir mensajes de depuración/error.

- `dispose()`:
  - **Descripción**: Método para liberar recursos si fuera necesario. Actualmente no realiza ninguna acción específica.
  - **Entradas**: Ninguna.
  - **Salidas**: Ninguna.
  - **Efectos**: Ninguno significativo en la implementación actual.

## Entradas:

- Depende de una instancia de `MapboxService` y una referencia a `WidgetRef` (Riverpod) inyectadas en el constructor.
- Recibe eventos de interacción del mapa (cambio de cámara, idle, tap, long press).
- Recibe un `BuildContext` para mostrar modales (`handleMapTapEvent`, `_requestBusLinesForStopModal`).

## Salidas/Efectos:

- Notifica a `MapNotifier` sobre el estado de interacción del usuario (`userMapInteraction`).
- Puede desencadenar la identificación de elementos del mapa (`MapboxService.handleMapTap`).
- Muestra un bottom sheet modal con información de paradas y ETAs de buses (`_requestBusLinesForStopModal`).
- Imprime mensajes de depuración y error.

# lib/controllers/map_zoom_controller.dart

Este archivo define la clase `MapZoomController`, encargada de gestionar los diferentes niveles y objetivos de zoom del mapa en la aplicación, basándose en el estado de la UI y las interacciones del usuario.

## `MapZoomController` (Clase):

Coordina las acciones de zoom del mapa para centrar la vista en puntos específicos (origen/destino), la ruta completa, un tramo individual de la ruta, o volver a la vista inicial. Utiliza `MapboxService` para las operaciones de zoom de bajo nivel y `MapNotifier` para leer el estado relevante del mapa.

### Responsabilidades:

- Manejar diferentes tipos de objetivos de zoom (`ZoomTargetType`).
- Implementar un mecanismo de "debounce" para agrupar múltiples solicitudes de zoom consecutivas y ejecutar solo la última, mejorando el rendimiento.
- Realizar transiciones de cámara suaves (flyTo) a las ubicaciones o rutas deseadas.
- Ajustar el zoom para que se ajusten a la pantalla puntos específicos (origen, destino, ambos) o la extensión de la ruta.
- Gestionar el zoom a un tramo individual de la ruta, potencialmente incluyendo la posición actual de un bus rastreado si aplica.
- Evitar realizar zooms automáticos si el usuario está interactuando manualmente con el mapa.
- Acceder al estado global del mapa (`MapState`) a través de Riverpod para obtener la información necesaria (ubicaciones de origen/destino, itinerarios, índice del tramo seleccionado, estado de interacción del usuario, posición del bus en tiempo real).

### Propiedades Internas:

- `mapboxMap`: Instancia del controlador del mapa de Mapbox para ejecutar comandos de cámara.
- `mapboxService`: Instancia de `MapboxService`, utilizada para métodos de zoom y ajuste a límites más complejos (`zoomToFitPositions`, `zoomToRouteBounds`, `zoomToLeg`).
- `ref`: Referencia a `WidgetRef` de Riverpod para leer el estado de la aplicación.
- `_zoomDebounceTimer`: Un `Timer` para implementar el retardo (debounce) en las acciones de zoom.
- `initialCameraOptions`: Una constante estática que define la vista de cámara inicial por defecto (centrada en Montevideo).

### Constructor:

- `MapZoomController({required this.mapboxMap, required this.mapboxService, required this.ref})`:
  - **Descripción**: Inicializa el controlador inyectando las dependencias necesarias: la instancia del mapa de Mapbox, una instancia de `MapboxService`, y una referencia a `WidgetRef` de Riverpod.
  - **Entradas**: `mapboxMap` (instancia de `MapboxMap`), `mapboxService` (instancia de `MapboxService`), `ref` (referencia a `WidgetRef`).
  - **Salidas/Efectos**: Crea una instancia del controlador lista para gestionar el zoom.

### Métodos:

- `handleZoomTarget(ZoomTargetType zoomTargetType)`:

  - **Descripción**: Es el punto de entrada principal para solicitar una acción de zoom. Aplica un retardo (`_debounceZoom`) antes de ejecutar la acción de zoom real (`_performZoom`) para evitar zooms excesivos si el estado cambia rápidamente.
  - **Entradas**: `zoomTargetType` (Un valor del enum `ZoomTargetType` que indica el objetivo del zoom).
  - **Salidas**: Ninguna (la acción es asíncrona y no retorna un valor directamente).
  - **Efectos**: Inicia o cancela un `Timer`. Llama a `_performZoom` después del retardo.

- `_debounceZoom(VoidCallback zoomAction)` (Método Privado):

  - **Descripción**: Implementa la lógica del debounce. Cancela cualquier timer anterior y programa una nueva ejecución de `zoomAction` después de un corto retraso.
  - **Entradas**: `zoomAction` (La función a ejecutar después del debounce).
  - **Salidas**: Ninguna.
  - **Efectos**: Manipula el `_zoomDebounceTimer`.

- `_performZoom(ZoomTargetType zoomTargetType)` (Método Privado):

  - **Descripción**: Ejecuta la acción de zoom real basada en el `zoomTargetType` proporcionado. Lee el estado actual del mapa desde Riverpod y utiliza `MapboxMap` o `MapboxService` para realizar la transición de cámara correspondiente (zoom a puntos, zoom a ruta, zoom a tramo, etc.). Incluye lógica para evitar el zoom automático si el usuario está interactuando y para incluir la posición del bus si se hace zoom a un tramo de bus con seguimiento en tiempo real disponible.
  - **Entradas**: `zoomTargetType` (Un valor del enum `ZoomTargetType`).
  - **Salidas**: Un `Future<void>` que completa cuando la acción de zoom ha terminado.
  - **Efectos**: Lee el estado global (`MapState`). Llama a métodos de `MapboxMap` (`flyTo`) o `MapboxService` (`zoomToFitPositions`, `zoomToRouteBounds`, `zoomToLeg`) para modificar la vista del mapa.

- `_zoomToLeg(List<RouteLeg> legs, int legIndex, Position? busToInclude)` (Método Privado):

  - **Descripción**: Método helper para hacer zoom específicamente a un tramo de ruta. Calcula los límites del tramo y llama a `MapboxService.zoomToLeg` para ajustar la cámara. Considera si se debe incluir la posición de un bus (`busToInclude`) en el cálculo de los límites y ajusta el padding en función de si el panel de instrucciones está colapsado o expandido.
  - **Entradas**: `legs` (Lista de `RouteLeg`s del itinerario), `legIndex` (Índice del tramo a enfocar), `busToInclude` (Posición opcional de un bus a incluir en la vista).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Lee el estado del panel de instrucciones. Llama a `mapboxService.zoomToLeg`.

- `dispose()`:
  - **Descripción**: Cancela el timer de debounce para evitar fugas de memoria.
  - **Entradas**: Ninguna.
  - **Salidas**: Ninguna.
  - **Efectos**: Cancela `_zoomDebounceTimer`.

## Entradas:

- Depende de instancias de `MapboxMap`, `MapboxService`, y `WidgetRef` (Riverpod) inyectadas en el constructor.
- Recibe el tipo de objetivo de zoom (`ZoomTargetType`) a través de `handleZoomTarget`.
- Lee el estado global del mapa (`MapState`) desde Riverpod.

## Salidas/Efectos:

- Controla la vista de la cámara del mapa de Mapbox (posición, zoom, animación).
- Ajusta los límites visibles del mapa para incluir puntos o rutas específicas.
- Se adapta a la interacción del usuario para evitar zooms automáticos intrusivos.
- Utiliza el estado de la aplicación para determinar el objetivo de zoom adecuado y los datos necesarios (ubicaciones, ruta, tramo seleccionado).

# lib/controllers/route_display_controller.dart

Este archivo define la clase `RouteDisplayController`, responsable de gestionar la visualización de rutas de transporte público en el mapa utilizando la API de Mapbox.

## `RouteDisplayController` (Clase):

Encapsula la lógica para dibujar, actualizar y limpiar las capas de ruta en el mapa, basándose en los itinerarios planificados. Trabaja en conjunto con `MapboxService` para las operaciones de bajo nivel de Mapbox y con `MapNotifier` para acceder al estado actual de la aplicación.

### Responsabilidades:

- Limpiar cualquier capa de ruta previamente mostrada en el mapa.
- Procesar una lista de `RouteLeg`s (tramos de ruta) y dibujar cada segmento en el mapa con el estilo apropiado según el modo de transporte (caminar, bus, etc.).
- Decodificar las polilíneas de los tramos para obtener las coordenadas geográficas.
- Ocultar/mostrar las paradas relevantes en el mapa en función de la visualización de la ruta.
- Aplicar estilos de visualización de ruta (ej. vista general).
- Resaltar un tramo específico de la ruta seleccionada en el mapa.
- Integrarse con `MapboxService` para las interacciones directas con el mapa.
- Acceder al estado global de la aplicación a través de Riverpod (`MapNotifier`) para determinar qué ruta y qué tramo deben ser visualizados o resaltados.

### Propiedades Internas:

- `mapboxService`: Instancia de `MapboxService` para interactuar con la API de Mapbox.
- `ref`: Referencia a `WidgetRef` de Riverpod, utilizada para leer el estado (`MapState`) a través de `mapNotifierProvider`.
- Constantes estáticas (`OTP_ROUTE_SOURCE_PREFIX`, `OTP_ROUTE_LAYER_PREFIX`) para nombrar las fuentes y capas de datos de la ruta en Mapbox.

### Constructor:

- `RouteDisplayController({required this.mapboxService, required this.ref})`:
  - **Descripción**: Inicializa el controlador inyectando las dependencias necesarias: una instancia de `MapboxService` y una referencia a `WidgetRef` de Riverpod.
  - **Entradas**: `mapboxService` (instancia de `MapboxService`), `ref` (referencia a `WidgetRef`).
  - **Salidas/Efectos**: Crea una instancia del controlador lista para gestionar la visualización de rutas.

### Métodos:

- `clearPreviousRouteLayers()`:

  - **Descripción**: Elimina todas las capas y fuentes de datos de ruta previamente añadidas al mapa y restaura la visibilidad de la capa de paradas (si existe).
  - **Entradas**: Ninguna.
  - **Salidas**: Un `Future<void>` que completa cuando las capas han sido eliminadas.
  - **Efectos**: Llama a métodos de `MapboxService` para interactuar con el estilo del mapa. Puede imprimir errores de depuración.

- `dispose()`:

  - **Descripción**: Método para liberar recursos si fuera necesario. Actualmente no realiza ninguna acción específica.
  - **Entradas**: Ninguna.
  - **Salidas**: Ninguna.
  - **Efectos**: Ninguno significativo en la implementación actual.

- `processAndDisplaySelectedItineraryUI(List<RouteLeg> legs)`:

  - **Descripción**: Dibuja los tramos de una lista de `RouteLeg`s en el mapa. Itera sobre cada tramo, decodifica su polilínea, determina el color y estilo de la línea según el modo de transporte y utiliza `MapboxService` para dibujar el segmento correspondiente. También oculta la capa general de paradas y muestra las paradas relevantes para la ruta.
  - **Entradas**: `legs` (Una lista de objetos `RouteLeg`).
  - **Salidas**: Un `Future<bool>` que resuelve a `true` si la ruta fue procesada y dibujada con éxito, `false` si la lista de tramos está vacía.
  - **Efectos**: Interactúa extensivamente con `MapboxService` para dibujar líneas y gestionar la visibilidad de capas. Decodifica polilíneas. Aplica estilos de línea.

- `applyOverviewRouteStyle()`:

  - **Descripción**: Aplica un estilo de visualización que muestra la ruta completa (vista general).
  - **Entradas**: Ninguna.
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Llama a `mapboxService.applyOverviewRouteStyle()`.

- `updateMapRouteHighlight()`:
  - **Descripción**: Resalta el tramo de ruta actualmente seleccionado en el mapa. Lee el índice del tramo seleccionado del estado de Riverpod (`mapNotifierProvider`) y llama a `MapboxService` para aplicar el resaltado visual.
  - **Entradas**: Ninguna (lee el estado directamente).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Lee el estado global. Llama a `mapboxService.updateMapRouteHighlight()` para modificar el estilo visual de las capas de ruta.

## Entradas:

- Depende de una instancia de `MapboxService` y una referencia a `WidgetRef` (Riverpod) inyectadas en el constructor.
- Recibe una lista de `RouteLeg`s para dibujar (`processAndDisplaySelectedItineraryUI`).
- Lee el estado global de la aplicación (`MapState`) a través de Riverpod para determinar qué tramo resaltar (`updateMapRouteHighlight`).

## Salidas/Efectos:

- Modifica visualmente el mapa de Mapbox añadiendo, eliminando, o actualizando capas de línea y puntos.
- Oculta o muestra capas existentes (ej. capa de paradas).
- Abstracta la complejidad de la interacción de bajo nivel con la API de Mapbox para la visualización de rutas.
- Proporciona métodos para controlar la apariencia de la ruta en respuesta a las acciones del usuario (selección de itinerario, selección de tramo).

# lib/main.dart

Este archivo es el punto de entrada principal de la aplicación Flutter.

## Responsabilidades:

- Inicialización de los bindings de Flutter (`WidgetsFlutterBinding.ensureInitialized`).
- Inicialización de la configuración de la aplicación, incluyendo el token de acceso de Mapbox (`initializeAppConfig`).
- Ejecución del widget raíz de la aplicación (`MyApp`), envuelto en un `ProviderScope` para la gestión del estado con Riverpod.

## Entradas:

- Depende de `MAPBOX_ACCESS_TOKEN` definido en `constants/mapbox_constants.dart` para la configuración de Mapbox.
- Importa y utiliza `initializeAppConfig` y `MyApp` desde `app.dart`.
- Utiliza `ProviderScope` de `flutter_riverpod`.

## Salidas/Efectos:

- Inicia el ciclo de vida de la aplicación Flutter.
- Establece el `ProviderScope` que estará disponible para toda la jerarquía de widgets, habilitando el uso de Riverpod.

# lib/models/bus_arrival_info.dart

Este archivo define un modelo de datos detallado para la información de llegada de un autobús.

## Responsabilidades:

- Representar toda la información relevante sobre la llegada de un autobús a una parada, incluyendo tiempo estimado, si es en tiempo real, información de la línea, posición, etc.
- Proveer métodos para convertir la información desde y hacia formato JSON (`fromJson`, `toJson`).
- Permitir la creación de copias del objeto con propiedades modificadas (`copyWith`).

## Propiedades:

- `minutesToArrival`: Minutos estimados para la llegada (int, requerido).
- `isReal`: Indica si la información es en tiempo real (bool, requerido).
- `lineShortName`: Nombre corto de la línea de autobús (String, requerido).
- `destination`: Destino del autobús (String, opcional).
- `position`: Posición geográfica actual del autobús (Position de mapbox_maps_flutter, opcional).
- `requestTime`: Momento en que se solicitó la información (DateTime, opcional).
- `arrivalTime`: Momento estimado de llegada (DateTime, opcional).
- `lineVariantCode`: Código de variante de la línea (String, opcional).
- `isClosestUpcoming`: Indica si es la llegada más próxima (bool, opcional).

## Entradas:

- El constructor principal requiere `minutesToArrival`, `isReal`, y `lineShortName`.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` que generalmente proviene de una fuente externa (e.g., API).
- El método `copyWith` toma parámetros opcionales para sobreescribir las propiedades existentes.

## Salidas/Efectos:

- Provee una estructura de datos comprensiva para manejar información de llegadas de autobuses.
- El método `toJson` permite exportar los datos del objeto a formato JSON, útil para depuración, almacenamiento o comunicación.
- El método `copyWith` devuelve una nueva instancia de `BusArrivalInfo`.

# lib/models/bus_realtime.dart

Este archivo define el modelo de datos para la información de llegada de autobuses en tiempo real.

## Responsabilidades:

- Representar la información en tiempo real de un autobús, incluyendo su línea, destino y tiempo estimado de llegada.
- Proveer un método `fromJson` para deserializar datos JSON en un objeto `BusRealtime`.

## Propiedades:

- `line`: Número o identificador de la línea de autobús (String).
- `destination`: Destino del autobús (String).
- `minutesToArrival`: Minutos estimados para la llegada del autobús (int).

## Entradas:

- El constructor requiere `line`, `destination`, y `minutesToArrival`.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` que contiene los datos en formato JSON.

## Salidas/Efectos:

- Provee una estructura de datos para manejar la información de llegadas de autobuses en tiempo real.
- Permite la creación de objetos `BusRealtime` a partir de respuestas de APIs que proporcionan estos datos.

# lib/models/bus_stop.dart

Este archivo define el modelo de datos para una parada de autobús.

## Responsabilidades:

- Representar la información de una parada de autobús, incluyendo su identificador, nombre, latitud y longitud.
- Proveer un método `fromJson` para deserializar datos JSON en un objeto `BusStop`.

## Propiedades:

- `id`: Identificador único de la parada (String).
- `name`: Nombre de la parada (String).
- `lat`: Latitud de la parada (double).
- `lon`: Longitud de la parada (double).

## Entradas:

- El constructor requiere `id`, `name`, `lat`, y `lon`.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` (generalmente de una respuesta API).

## Salidas/Efectos:

- Provee una estructura de datos para manejar información de paradas de autobús.
- Permite la creación de objetos `BusStop` a partir de datos JSON, facilitando la integración con APIs que retornan esta estructura.

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

# lib/models/consolidated_itinerary_leg.dart

Este archivo define el modelo de datos para un tramo individual (`ConsolidatedItineraryLeg`) dentro de un itinerario consolidado. Estos tramos son componentes de un `ConsolidatedItinerary` y pueden representar segmentos simples (como caminar o esperar) o segmentos más complejos (como un tramo de bus que agrupa múltiples líneas).

## `ConsolidatedItineraryLeg` (Clase):

Representa un segmento consolidado de un viaje, diseñado para la presentación en la interfaz de usuario de un itinerario consolidado.

### Responsabilidades:

- Representar un tramo del itinerario que puede ser de diferentes modos (caminata, bus, espera, etc.).
- Para tramos de bus consolidados, agrupar información de las líneas alternativas y mantener referencias a los tramos originales.
- Almacenar la duración y distancia del tramo.
- Contener los puntos de inicio y fin del tramo.
- Proveer información relevante para la UI, como el nombre de la línea (si aplica) y el color de la ruta.

### Propiedades:

- `mode`: El modo de transporte o tipo de tramo (String, ej. 'WALK', 'BUS', utilizando constantes de `LegModeConstants`).
- `duration`: Duración del tramo (`Duration`, requerido).
- `distance`: Distancia cubierta en el tramo (double, requerido).
- `from`: Punto de inicio del tramo (`LegEndpoint`, requerido).
- `to`: Punto de fin del tramo (`LegEndpoint`, requerido).
- `alternativeLineShortNames`: Lista de nombres cortos de líneas alternativas para tramos de bus consolidados (`List<String>`, opcional).
- `originalBusLegs`: Lista de los objetos `RouteLeg` originales que este tramo consolida (solo para tramos de bus) (`List<RouteLeg>`, por defecto vacía).
- `headsign`: El destino o dirección principal del tramo de bus (String, opcional).
- `routeColor`: Color asociado a la ruta principal del tramo (Color de Flutter, opcional).

### Getters:

- `isConsolidatedBusLeg`: Indica si este tramo es un tramo de bus consolidado (tiene múltiples líneas alternativas).
- `representativeRoute`: Devuelve el objeto `LegRoute` del primer `originalBusLeg`, útil para obtener información de la línea representativa.

### Entradas:

- El constructor requiere `mode`, `duration`, `distance`, `from`, y `to`. Las propiedades específicas de bus y `headsign`/`routeColor` son opcionales o tienen valores por defecto.

### Salidas/Efectos:

- Provee una representación simplificada y agrupada de un tramo de viaje, adecuada para mostrar en la interfaz de usuario.
- Permite el acceso a detalles subyacentes (via `originalBusLegs`) si es necesario.

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

# lib/models/itinerary_warning.dart

Este archivo define estructuras de datos para representar advertencias relacionadas con los itinerarios de viaje.

## Responsabilidades:

- Definir los posibles tipos de advertencias que pueden ocurrir en un itinerario (`ItineraryWarningType`).
- Representar una advertencia específica con su tipo y un mensaje descriptivo (`ItineraryWarning`).

## `ItineraryWarningType` (Enum):

Enumera las posibles condiciones de advertencia, como tiempo de caminata excesivo, problemas con la información de llegada en tiempo real, errores de API, etc.

## `ItineraryWarning` (Clase):

### Propiedades:

- `type`: El tipo de advertencia, tomado del enum `ItineraryWarningType` (requerido).
- `message`: Un mensaje descriptivo detallando la advertencia (String, requerido).

### Entradas:

- El constructor requiere un `type` y un `message`.

### Salidas/Efectos:

- Provee una estructura estandarizada para reportar y manejar advertencias dentro de la lógica de procesamiento de itinerarios.
- La implementación de `toString`, `==`, y `hashCode` facilita la depuración y comparación de advertencias.

# lib/models/leg_mode_constants.dart

Este archivo define constantes de cadena para representar los diferentes modos de transporte o tipos de tramos (legs) utilizados en los itinerarios.

## Responsabilidades:

- Proveer un conjunto centralizado de constantes para los modos de transporte y tipos de tramos.

## `LegModeConstants` (Clase):

Contiene solo constantes estáticas.

### Propiedades (Constantes Estáticas):

- `walk`: Representa un tramo a pie ('WALK').
- `bus`: Representa un tramo en autobús ('BUS').
- `subway`: Representa un tramo en metro ('SUBWAY') (ejemplo).
- `train`: Representa un tramo en tren ('TRAIN') (ejemplo).
- `tram`: Representa un tramo en tranvía ('TRAM') (ejemplo).
- `bicycle`: Representa un tramo en bicicleta ('BICYCLE') (ejemplo).
- `car`: Representa un tramo en coche ('CAR') (ejemplo).
- `transit`: Representa un tramo general de tránsito ('TRANSIT').
- `wait`: Representa un período de espera ('WAIT').

## Entradas:

- Ninguna.

## Salidas/Efectos:

- Provee un conjunto de constantes que pueden ser utilizadas a lo largo de la aplicación para identificar o comparar modos de transporte y tipos de tramos de manera consistente.

# lib/models/point_dart.dart

Este archivo define un modelo simple para representar un punto geográfico.

## Responsabilidades:

- Almacenar una latitud y una longitud.

## Propiedades:

- `lat`: Latitud (double).
- `lng`: Longitud (double).

## Entradas:

- El constructor requiere una latitud y una longitud.

## Salidas/Efectos:

- Provee una estructura de datos para representar ubicaciones geográficas. Es utilizado por otros modelos o clases que necesiten manejar coordenadas.

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

# lib/models/route_leg.dart

Este archivo define el modelo de datos para un tramo individual (`RouteLeg`) dentro de un itinerario de viaje. Incluye detalles sobre el origen, destino, modo de transporte, duración, distancia, geometría, pasos (para caminatas) y lugares intermedios.

## `RouteLeg` (Clase Principal):

Representa un segmento único de un viaje, como caminar de A a B o tomar un bus de C a D.

### Responsabilidades:

- Almacenar toda la información detallada sobre un tramo específico del itinerario.
- Facilitar la deserialización de un tramo desde formato JSON.

### Propiedades:

- `mode`: Modo de transporte o tipo de tramo (String, ej. 'WALK', 'BUS', usando constantes de `LegModeConstants`).
- `startTime`: Marca de tiempo de inicio del tramo (int, en milisegundos).
- `endTime`: Marca de tiempo de fin del tramo (int, en milisegundos).
- `duration`: Duración del tramo (double, en segundos).
- `distance`: Distancia cubierta en el tramo (double, en metros).
- `from`: Punto de inicio del tramo (`LegEndpoint`).
- `to`: Punto de fin del tramo (`LegEndpoint`).
- `route`: Información de la ruta para tramos de transporte público (`LegRoute`, opcional).
- `trip`: Información específica del viaje (ej. identificador GTFS del vehículo) para tramos de transporte público (`LegTrip`, opcional).
- `legGeometry`: Geometría del tramo, generalmente como una cadena codificada de puntos (`LegGeometry`).
- `steps`: Lista de pasos individuales para tramos de caminata (`List<LegStep>`).
- `intermediatePlaces`: Lista de puntos intermedios o paradas por las que pasa el tramo (`List<IntermediatePlace>`).

### Entradas:

- El constructor requiere todas las propiedades principales (`mode`, `startTime`, `endTime`, `duration`, `distance`, `from`, `to`, `legGeometry`, `steps`). `route`, `trip` e `intermediatePlaces` son opcionales.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` que contiene los datos del tramo en formato JSON.
- El método estático `listFromJson` toma una lista de objetos JSON y devuelve una lista de objetos `RouteLeg`.

### Salidas/Efectos:

- Provee una estructura de datos granular para analizar y visualizar cada parte de un itinerario.
- La información detallada (como steps y geometry) es crucial para la representación en el mapa y la navegación.

## Clases Anidadas:

Este archivo también define las siguientes clases de soporte:

### `LegEndpoint`:

- **Responsabilidades**: Representar el punto de inicio o fin de un tramo.
- **Propiedades**: `name` (String), `lon` (double), `lat` (double), `arrival` (DateTime, opcional), `departure` (DateTime, opcional), `stopId` (String, opcional, para paradas), `stopGtfsId` (String, opcional, para paradas GTFS).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee detalles de ubicación y tiempo en los extremos de un tramo.

### `LegRoute`:

- **Responsabilidades**: Representar información de la ruta de transporte público (ej. nombre corto/largo).
- **Propiedades**: `gtfsId` (String, opcional), `longName` (String, opcional), `shortName` (String, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee metadatos sobre la ruta de transporte utilizada en el tramo.

### `LegTrip`:

- **Responsabilidades**: Representar información específica del viaje de transporte público (ej. identificador de viaje).
- **Propiedades**: `gtfsId` (String, opcional), `shapeId` (String, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee identificadores para el viaje específico, útil para rastreo o información en tiempo real.

### `LegGeometry`:

- **Responsabilidades**: Representar la forma geográfica del tramo.
- **Propiedades**: `points` (String, requerido, típicamente codificado), `length` (int, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee los datos necesarios para dibujar el tramo en un mapa.

### `LegStep`:

- **Responsabilidades**: Representar un paso individual dentro de un tramo de caminata, incluyendo instrucciones de navegación.
- **Propiedades**: `distance` (double), `relativeDirection` (String, opcional), `streetName` (String, opcional), `absoluteDirection` (String, opcional), `stayOn` (bool, opcional), `area` (bool, opcional), `bogusName` (bool, opcional), `lon` (double), `lat` (double), `elevation` (String, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee instrucciones detalladas para la navegación a pie.

### `IntermediatePlace`:

- **Responsabilidades**: Representar un punto intermedio por el que pasa el tramo, como una parada de autobús.
- **Propiedades**: `name` (String, opcional), `lon` (double), `lat` (double), `stopId` (String, opcional), `stopGtfsId` (String, opcional), `arrival` (DateTime, opcional), `departure` (DateTime, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee detalles sobre los puntos de paso en el tramo, relevante para tramos de transporte público con múltiples paradas.

# lib/providers/map_notifier.dart

Este archivo define `MapNotifier`, un `StateNotifier` de Riverpod encargado de gestionar el estado del mapa, la interacción del usuario, la planificación de itinerarios y la visualización de rutas y datos de transporte en el mapa.

## `MapNotifier` (Clase):

Extiende `StateNotifier<MapState>` y utiliza Riverpod para notificar a los listeners sobre los cambios en el estado del mapa (`MapState`). Orquesta diversas acciones como la planificación de rutas, la gestión de la interacción del usuario con el mapa, la selección y visualización de itinerarios, y la integración con el seguimiento de buses en tiempo real.

### Responsabilidades:

- Gestionar el estado actual del mapa, incluyendo la ubicación de origen y destino, la lista de itinerarios disponibles, el itinerario seleccionado, el tramo actual, y el estado de la planificación y seguimiento en tiempo real (`MapState`).
- Responder a eventos de interacción del usuario con el mapa (inicio y fin de movimiento manual) e implementar lógica de auto-zoom basada en el estado de la aplicación (`mapInteractionStarted`, `mapInteractionEnded`, `_triggerAutoZoomLogic`).
- Gestionar la configuración y limpieza de los puntos de origen y destino (`setOrigin`, `setDestination`, `clearOrigin`, `clearDestination`, `swapOriginAndDestination`).
- Iniciar el proceso de planificación de rutas llamando a `ItineraryPlanningService` (`planRoute`).
- Procesar los resultados de la planificación de rutas, actualizando el estado con los itinerarios consolidados y controlando el modo de visualización del mapa.
- Limpiar el estado relacionado con las rutas y el seguimiento de buses (`clearRouteState`).
- Manejar la selección de un itinerario consolidado por parte del usuario (`processSelectedItinerary`), preparando los datos para su visualización detallada y, si aplica, iniciando el seguimiento en tiempo real del primer bus.
- Gestionar la selección de tramos individuales de un itinerario (`setSelectedLegIndex`), incluyendo la lógica para cambiar al modo de seguimiento por tramo (`switchToLegTracking`) si se selecciona un tramo de bus.
- Integrarse con `BusTrackingController` para iniciar o detener el seguimiento en tiempo real y recibir actualizaciones de estado (`updateRealtimeTrackingStatus`, `setTrackedBusLineShortName`, `updateRepresentativeETA`).
- Manejar la lógica de simulación de bus (usada en desarrollo/depuración) (`updateBusSimulationState`, `clearHighlightedBusMarkerAndSegment`).
- Forzar el estado de inactividad del mapa y controlar el objetivo de zoom programáticamente (`forceMapIdleAndZoomTo`).
- Almacenar las opciones actuales de la cámara del mapa (`storeCurrentCameraOptions`).
- Controlar la visibilidad del panel de instrucciones (`toggleInstructionsPanel`).
- Actualizar la información de ETA representativa cuando `BusTrackingController` notifica nuevos datos.

### Constructor:

- `MapNotifier(this._ref, this._itineraryPlanningService) : super(MapState())`:
  - **Descripción**: Inicializa el `MapNotifier` con una referencia a Riverpod (`Ref`) y una instancia de `ItineraryPlanningService`. Establece el estado inicial a `MapState()`.
  - **Entradas**: Una instancia de `Ref` (para poder leer otros providers si es necesario) y una instancia de `ItineraryPlanningService`.
  - **Salidas/Efectos**: Crea una instancia del notificador de estado con el estado inicial del mapa.

### Propiedades Internas Clave:

- `_ref`: Referencia a Riverpod, utilizada para leer otros providers (ej. servicios) declarados en `service_providers.dart`.
- `_itineraryPlanningService`: Instancia del servicio principal de planificación de itinerarios, utilizada para obtener las opciones de ruta.
- `_manualMoveCooldownTimer`: Timer utilizado para implementar un retraso después de que el usuario deja de interactuar manualmente con el mapa antes de activar la lógica de auto-zoom.

### Métodos de Interacción con Servicios y Otros Controladores:

- `planRoute`: Llama a `_itineraryPlanningService.planAndConsolidateItineraries`.
- `processSelectedItinerary`: Interactúa con `MapboxService` para dibujar la ruta y con `BusTrackingController` para iniciar el seguimiento.
- `clearRouteState`: Interactúa con `MapboxService` para limpiar capas del mapa y con `BusTrackingController` para detener el seguimiento.
- `setSelectedLegIndex`: Interactúa con `MapboxService` para resaltar tramos.
- `switchToLegTracking`: Interactúa con `MapboxService` y `BusTrackingController` para gestionar el seguimiento por tramo.
- `updateRealtimeTrackingStatus`, `setTrackedBusLineShortName`, `updateRepresentativeETA`: Métodos llamados por `BusTrackingController` para actualizar el estado de seguimiento en tiempo real.

### Entradas Generales del Notificador:

- Recibe instancias de `Ref` e `ItineraryPlanningService` en su constructor.
- Recibe eventos de interacción del mapa (cambio de cámara, selección de itinerarios/tramos).
- Recibe datos de ubicación (origen/destino) y opcionalmente información de ETA/ubicación de `BusTrackingController`.
- Recibe instancias de `MapboxService` y `BusTrackingController` como parámetros en varios métodos, ya que estos servicios/controladores están asociados a la UI del mapa y no son proveedores directos que el Notifier observaría globalmente.

## Salidas/Efectos Generales del Notificador:

- Emite nuevos estados (`MapState`) a través de Riverpod, notificando a los widgets que observan `mapNotifierProvider` para que reconstruyan su UI en consecuencia.
- Controla qué itinerarios o tramos se muestran en el mapa.
- Activa o desactiva el seguimiento de buses en tiempo real a través de `BusTrackingController`.
- Ajusta el objetivo de zoom del mapa (`currentZoomTarget`) para guiar la visualización del usuario.
- Gestiona el estado visual de la aplicación relacionado con el mapa (modos de visualización, visibilidad de paneles).

## Integración con Riverpod:

- `mapNotifierProvider`: `StateNotifierProvider` que provee una instancia de `MapNotifier`, dependiendo de `itineraryPlanningServiceProvider`.

# lib/services/eta_fetcher_service.dart

Este archivo define una interfaz (clase abstracta) para los servicios encargados de obtener la información de llegada estimada (ETA) de los autobuses.

## `ETAFetcherService` (Clase Abstracta):

Define el contrato que cualquier implementador de un servicio de obtención de ETAs debe seguir.

### Responsabilidades:

- Especificar la funcionalidad principal para obtener información de llegadas de buses.

### Métodos:

- `getUpcomingBusesForStop(String stopId)`:
  - **Descripción**: Obtiene una lista de información de llegadas de buses (`BusArrivalInfo`) para una parada específica identificada por `stopId`.
  - **Entradas**: `stopId` (String), el identificador de la parada de autobús.
  - **Salidas**: Un `Future` que resuelve a una `List<BusArrivalInfo>` con la información de las próximas llegadas a esa parada.
  - **Efectos**: Interactúa con una fuente externa (API, base de datos, etc.) para obtener los datos de ETA.

## Entradas:

- Depende del modelo `BusArrivalInfo`.

## Salidas/Efectos:

- Define una interfaz estándar para la funcionalidad de obtención de ETA, permitiendo diferentes implementaciones (ej. un servicio que llama a una API real, un mock para pruebas).

# lib/services/geocoding_service.dart

Este archivo define un servicio para realizar operaciones de geocodificación, específicamente para obtener sugerencias de lugares utilizando la API de Mapbox Geocoding.

## `GeocodingService` (Clase):

Encapsula la lógica para interactuar con el servicio de geocodificación de Mapbox.

### Responsabilidades:

- Realizar llamadas a la API de Mapbox Geocoding para obtener sugerencias de lugares.
- Procesar la respuesta de la API y retornar una lista de resultados.

### Métodos:

- `fetchSuggestions(String query)`:
  - **Descripción**: Busca sugerencias de lugares (direcciones, puntos de interés, etc.) basándose en una cadena de texto de consulta.
  - **Entradas**: `query` (String), la cadena de texto a buscar.
  - **Salidas**: Un `Future` que resuelve a una `List<Map<String, dynamic>>`, donde cada mapa representa una sugerencia de lugar con sus detalles. Retorna una lista vacía en caso de error o no encontrar resultados.
  - **Efectos**: Realiza una solicitud HTTP GET a la API de Mapbox Geocoding. Depende de `MAPBOX_ACCESS_TOKEN` de `mapbox_constants.dart` para la autenticación.

## Entradas:

- Depende de `mapbox_constants.dart` para el token de acceso a Mapbox.
- Utiliza la librería `http` para realizar solicitudes web.

## Salidas/Efectos:

- Provee una funcionalidad para autocompletar entradas de ubicación o buscar puntos geográficos.
- Los resultados obtenidos (`List<Map<String, dynamic>>`) contienen información estructurada sobre los lugares encontrados (nombre, coordenadas, etc.), que puede ser utilizada por otras partes de la aplicación (ej. la UI o servicios de planificación de rutas).

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

# lib/services/montevideo_api_service.dart

Este archivo define el servicio (`MontevideoApiService`) que interactúa con la API de transporte público de la Intendencia de Montevideo para obtener datos de autobuses. Implementa la interfaz `ETAFetcherService`.

## `MontevideoApiService` (Clase):

Encapsula la lógica para comunicarse con la API de Montevideo, incluyendo la gestión de la autenticación (tokens) y la obtención de datos de transporte.

### Responsabilidades:

- Obtener y gestionar tokens de acceso para la API de Montevideo, manejando su expiración y refresco.
- Implementar la interfaz `ETAFetcherService` para proveer información de llegada de buses (`getUpcomingBusesForStop`).
- Obtener la lista de líneas de bus que pasan por una parada específica (`fetchBusLinesForStop`).
- Obtener información detallada de llegadas de buses para una parada específica, incluyendo datos en tiempo real y posición (`_fetchArrivalsForStop`).
- Obtener la ubicación en tiempo real de los buses de una línea específica (`fetchRealtimeBusLocations`).
- Manejar errores de la API (ej. 401, 403, 404, 429) y realizar reintentos cuando sea apropiado.
- Parsear las respuestas JSON de la API a formatos utilizables por la aplicación (Listas de Mapas o `BusArrivalInfo`).

### Propiedades Internas:

- `_accessToken`: Almacena el token de acceso actual (String, opcional).
- `_tokenExpiration`: Almacena la fecha y hora de expiración del token (`DateTime`, opcional), utilizada para determinar si se necesita obtener un nuevo token.

### Métodos:

- `getApiToken()`:

  - **Descripción**: Gestiona la obtención de un token de acceso de la API. Si el token existente es válido y no ha expirado, lo devuelve. De lo contrario, realiza una solicitud POST para obtener un nuevo token y actualiza las propiedades internas.
  - **Entradas**: Ninguna explícita, utiliza las constantes de autenticación definidas en `api_constants.dart` (`CLIENT_ID`, `CLIENT_SECRET`, `ACCESS_TOKEN_URL`).
  - **Salidas**: Un `Future<String?>` que resuelve al token de acceso válido o null si falla la obtención.
  - **Efectos**: Realiza una solicitud HTTP POST a la URL de autenticación. Actualiza `_accessToken` y `_tokenExpiration`. Puede imprimir mensajes de depuración o error.

- `fetchBusLinesForStop(String stopId)`:

  - **Descripción**: Consulta la API para obtener la lista de líneas de bus asociadas a una parada específica (`/busservice/lines/{stopId}`).
  - **Entradas**: `stopId` (String), el identificador de la parada.
  - **Salidas**: Un `Future<List<Map<String, dynamic>>>` que resuelve a una lista de mapas (representando líneas de bus) o una lista vacía en caso de error o no encontrar líneas.
  - **Efectos**: Realiza una solicitud HTTP GET autenticada utilizando el token obtenido por `getApiToken`. Incluye lógica de reintento en caso de token inválido/expirado. Depende de `BASE_URL` de `api_constants.dart` para la URL base del endpoint.

- `getUpcomingBusesForStop(String stopId)` (Implementación de `ETAFetcherService`):

  - **Descripción**: Obtiene y procesa la información de próximas llegadas de buses para una parada específica. Este método implementa el contrato definido en `ETAFetcherService`.
  - **Entradas**: `stopId` (String).
  - **Salidas**: Un `Future<List<BusArrivalInfo>>` que resuelve a una lista de objetos `BusArrivalInfo`, conteniendo detalles como minutos para llegar, si es en tiempo real, línea y posición.
  - **Efectos**: Internamente llama a `_fetchArrivalsForStop` para obtener los datos crudos y luego los mapea a la lista de `BusArrivalInfo`. Incluye lógica robusta para parsear las coordenadas de posición desde diferentes posibles formatos de la API y maneja los tipos de datos de la respuesta.

- `_fetchArrivalsForStop(String stopId)` (Método Privado):

  - **Descripción**: Realiza la llamada HTTP directa al endpoint de la API de Montevideo para obtener los datos de próximas llegadas a una parada específica (`/transporteRest/siguientesParada/{stopId}`). Este endpoint parece ser una excepción en la estructura de URLs base.
  - **Entradas**: `stopId` (String).
  - **Salidas**: Un `Future<List<Map<String, dynamic>>>` con la respuesta cruda de la API (una lista de mapas) o una lista vacía en caso de error o formato inesperado.
  - **Efectos**: Realiza una solicitud HTTP GET autenticada. Maneja errores de red, errores HTTP (incluyendo 401/403 con reintento), y verifica que el cuerpo de la respuesta sea una lista JSON. Imprime mensajes de depuración/error.

- `fetchRealtimeBusLocations(String lineShortName)`:
  - **Descripción**: Obtiene la ubicación en tiempo real de los buses que están actualmente en operación para una línea específica (`/busservice/realtimelocations/{lineShortName}`).
  - **Entradas**: `lineShortName` (String), el nombre corto de la línea de bus.
  - **Salidas**: Un `Future<Map<String, dynamic>?>` que resuelve a un mapa (representando los datos de ubicación en tiempo real) o null si falla o no hay datos para esa línea.
  - **Efectos**: Realiza una solicitud HTTP GET autenticada. Incluye lógica de reintento en caso de token inválido/expirado y manejo de otros errores HTTP. Espera un objeto JSON como respuesta.

## Entradas:

- Depende de `api_constants.dart` para las URLs base y credenciales de autenticación.
- Utiliza la librería `http` para todas las operaciones de red.
- Depende de los modelos `BusArrivalInfo` y `Position` (de mapbox_maps_flutter) para procesar los datos de llegada.

## Salidas/Efectos:

- Provee acceso a los datos de transporte público de la API de Montevideo a otras partes de la aplicación.
- Abstracta la complejidad de la autenticación y la estructura específica de los endpoints de la API de Montevideo.
- Los datos de llegada procesados (`List<BusArrivalInfo>`) y la información de ubicación en tiempo real pueden ser consumidos por servicios de planificación de itinerarios (como `ItineraryPlanningService`) o directamente por la UI que necesite mostrar esta información.

# lib/services/otp_service.dart

Este archivo define un servicio (`OtpService`) encargado de interactuar con un servidor OpenTripPlanner (OTP) utilizando consultas GraphQL para planificar rutas de viaje.

## `OtpService` (Clase):

Encapsula la lógica para enviar consultas de planificación de rutas al servidor OTP.

### Responsabilidades:

- Realizar consultas GraphQL al endpoint de planificación de un servidor OTP.
- Manejar la comunicación con el cliente GraphQL.

### Constructor:

- `OtpService(this.client)`:
  - **Descripción**: Inicializa el servicio con una instancia de `GraphQLClient`.
  - **Entradas**: `client` (GraphQLClient), un cliente configurado para comunicarse con el servidor GraphQL de OTP.
  - **Salidas/Efectos**: Crea una instancia del servicio lista para realizar consultas.

### Métodos:

- `planRoute({required double fromLat, required double fromLon, required double toLat, required double toLon, required String date, required String time, int numItineraries = 3})`:
  - **Descripción**: Envía una consulta GraphQL al servidor OTP para encontrar itinerarios entre dos puntos en una fecha y hora específicas.
  - **Entradas**:
    - `fromLat` (double): Latitud del punto de origen.
    - `fromLon` (double): Longitud del punto de origen.
    - `toLat` (double): Latitud del punto de destino.
    - `toLon` (double): Longitud del punto de destino.
    - `date` (String): Fecha del viaje (formato YYYY-MM-DD).
    - `time` (String): Hora del viaje (formato HH:MM).
    - `numItineraries` (int, opcional, por defecto 3): Número máximo de itinerarios a solicitar.
  - **Salidas**: Un `Future<QueryResult>` que contiene la respuesta del servidor OTP, incluyendo los itinerarios encontrados o información de errores.
  - **Efectos**: Ejecuta una operación de consulta GraphQL. Depende de la configuración del `GraphQLClient` provisto en el constructor (que a su vez depende de la URL del servidor OTP, probablemente de `otp_constants.dart`). Puede imprimir mensajes de depuración o error en la consola.

## Entradas:

- Depende de `graphql_flutter` para la funcionalidad de cliente GraphQL.
- Recibe parámetros de ubicación, fecha y hora para la planificación.

## Salidas/Efectos:

- Provee la funcionalidad central para obtener opciones de rutas de transporte público y/o a pie desde el servidor OTP.
- El resultado (`QueryResult`) contiene los datos estructurados de los itinerarios que deben ser procesados por otras partes de la aplicación (ej. `ItineraryPlanningService`).

# lib/state/map_state.dart

Este archivo define el estado global relacionado con el mapa y la planificación de itinerarios en la aplicación. Utiliza una clase inmutable (`MapState`) y varios enums para representar los diferentes aspectos del estado.

## `MapState` (Clase):

Es una clase inmutable que contiene todas las propiedades relevantes para describir el estado actual del mapa, la interacción del usuario, las opciones de ruta, la planificación y el seguimiento en tiempo real. Se utiliza junto con un `StateNotifier` (como `MapNotifier`) en Riverpod para gestionar y propagar los cambios de estado.

### Propiedades:

- `origin`: `Position?` - La ubicación de origen seleccionada por el usuario.
- `destination`: `Position?` - La ubicación de destino seleccionada por el usuario.
- `originAddress`: `String?` - El nombre de la dirección del origen.
- `destinationAddress`: `String?` - El nombre de la dirección del destino.
- `userMapInteraction`: `UserMapInteractionState` - Indica si el usuario está interactuando con el mapa (idle, manualMoveInProgress, manualMoveCooldown).
- `currentDisplayMode`: `MapDisplayMode` - Define el modo de visualización actual del mapa (ej. blank, originSelected, routeOverview, legTracking).
- `currentZoomTarget`: `ZoomTargetType` - Indica el objetivo de zoom actual que el controlador de zoom debería intentar alcanzar.
- `currentCameraOptions`: `CameraOptions?` - Las opciones de cámara actuales del mapa (puede ser útil para guardar el estado).
- `consolidatedItineraries`: `List<ConsolidatedItinerary>` - La lista de opciones de ruta consolidadas obtenidas del servicio de planificación.
- `selectedConsolidatedItinerary`: `ConsolidatedItinerary?` - La opción de ruta consolidada que el usuario ha seleccionado para visualizar en detalle.
- `representativeItinerary`: `Itinerary?` - El itinerario representativo del `selectedConsolidatedItinerary` (el que tiene el mejor score).
- `representativeFirstBusETAInfo`: `BusArrivalInfo?` - La información de ETA (real o programada) para el primer tramo de bus del `representativeItinerary`.
- `planningStatus`: `PlanningStatus` - El estado actual del proceso de planificación de rutas (idle, loading, success, error).
- `currentLegIndex`: `int?` - El índice del tramo de ruta (`RouteLeg`) actualmente seleccionado o resaltado dentro del `representativeItinerary`.
- `showInstructionsPanel`: `bool` - Indica si el panel de instrucciones de la ruta debe estar visible.
- `trackedBusLineShortName`: `String?` - El nombre corto de la línea de bus que se está rastreando en tiempo real (si aplica).
- `realDebugBusPosition`: `Position?` - Posición de depuración de un bus real (usado en desarrollo/depuración).
- `realDebugEtaMinutes`: `int?` - Minutos de depuración para la ETA real (usado en desarrollo/depuración).
- `realDebugIsReal`: `bool?` - Indica si la ETA de depuración es real (usado en desarrollo/depuración).
- `simulatedBusPosition`: `Position?` - Posición actual de un bus simulado (usado en desarrollo/depuración).
- `busSpeedMetersPerSecond`: `double?` - Velocidad calculada del bus simulado (usado en desarrollo/depuración).
- `lastSpeedCalculationTime`: `DateTime?` - Marca de tiempo de la última vez que se calculó la velocidad simulada (usado en desarrollo/depuración).
- `simulationSegmentOriginPoint`: `Position?` - Punto de origen del segmento de simulación actual (usado en desarrollo/depuración).
- `maxSimulationTravelDistance`: `double?` - Distancia máxima que el bus simulado puede recorrer en su segmento actual (usado en desarrollo/depuración).
- `realtimeTrackingAvailable`: `bool` - Indica si el seguimiento en tiempo real está disponible para el tramo seleccionado.
- `realtimeTrackingAttempted`: `bool` - Indica si se ha intentado iniciar el seguimiento en tiempo real para el tramo seleccionado.

### Constructor:

- `MapState({...})`:
  - **Descripción**: Constructor que permite inicializar el estado con valores específicos. Define valores por defecto para la mayoría de las propiedades.
  - **Entradas**: Valores opcionales para todas las propiedades de la clase.
  - **Salidas/Efectos**: Crea una nueva instancia inmutable de `MapState`.

### Método `copyWith`:

- `copyWith({...})`:
  - **Descripción**: Crea una nueva instancia de `MapState` copiando las propiedades de la instancia actual y aplicando las modificaciones proporcionadas. Incluye parámetros `clearX` para poder establecer propiedades opcionales a `null` explícitamente.
  - **Entradas**: Valores opcionales para las propiedades a modificar, y booleanos `clearX`.
  - **Salidas**: Una nueva instancia inmutable de `MapState` con los valores actualizados.
  - **Efectos**: Facilita la creación de nuevos estados a partir del actual con cambios específicos.

### Operadores `==` y `hashCode`:

- `@override bool operator ==(Object other)`:
  - **Descripción**: Implementa la comparación de igualdad entre dos objetos `MapState`, comparando todas sus propiedades para determinar si son lógicamente iguales.
- `@override int get hashCode`:
  - **Descripción**: Implementa el cálculo del código hash para un objeto `MapState`, combinando los códigos hash de todas sus propiedades. Es necesario para que `==` funcione correctamente en conjuntos y mapas.

## Enums:

- `UserMapInteractionState`: Define los posibles estados de interacción del usuario con el mapa (idle, manualMoveInProgress, manualMoveCooldown).
- `PlanningStatus`: Define los posibles estados del proceso de planificación de rutas (idle, loading, success, error).
- `ZoomTargetType`: Define los posibles objetivos de zoom que el controlador de zoom puede manejar (initial, origenSelection, destinationSelection, points, overview, leg, none).
- `MapDisplayMode`: Define los diferentes modos de visualización en los que puede estar el mapa, afectando qué elementos se muestran y cómo se comporta la UI (blank, originSelected, destinationSelected, routeOverview, legTracking, legHighlight, routeStaticWithInstructions).

## Dependencias:

- Depende de los modelos `ConsolidatedItinerary`, `Itinerary`, `RouteLeg`, `BusArrivalInfo` y `Point_dart` para representar los datos.
- Utiliza `mapbox_maps_flutter` para el tipo `Position` y `CameraOptions`.
- Utiliza `package:flutter/foundation.dart` para `listEquals` (usado en `==`).

## Utilización:

- Esta clase es típicamente observada por widgets de UI a través de Riverpod para actualizar su presentación en respuesta a los cambios en el estado del mapa y la ruta.
- Los `StateNotifier`s (como `MapNotifier`) son responsables de crear y emitir nuevas instancias de `MapState` cuando ocurren eventos o se completan operaciones asíncronas (como la planificación de rutas o las actualizaciones de ETA).
- Otras partes de la lógica de la aplicación (como controladores o servicios) pueden leer el estado actual a través del `StateNotifier` para tomar decisiones.

# lib/utils/geometry_utils.dart

Este archivo contiene funciones de utilidad relacionadas con cálculos geométricos y geográficos, principalmente utilizadas para procesar y manipular datos de polilíneas y coordenadas en el contexto de la visualización de rutas y el seguimiento de vehículos.

## Funciones:

- `findClosestPointIndexOnShape(List<Position> shapePoints, Point_dart targetPoint)`:

  - **Descripción**: Encuentra el índice del punto más cercano a un `targetPoint` dado dentro de una lista de puntos que definen una forma (polilínea), calculando la distancia utilizando la fórmula de Haversine.
  - **Entradas**: `shapePoints` (Lista de `Position` que forman la polilínea), `targetPoint` (Un objeto `Point_dart` con las coordenadas del punto objetivo).
  - **Salidas**: Un `int` que representa el índice (base 0) del punto más cercano en `shapePoints`, o -1 si la lista `shapePoints` está vacía.
  - **Efectos**: Realiza un cálculo iterativo de distancias Haversine.

- `calculateBoundsForPositions(List<Position> positions)`:

  - **Descripción**: Calcula los límites geográficos mínimos y máximos (`CoordinateBounds`) que engloban una lista de `Position`s. Ajusta los límites mínimamente si todos los puntos coinciden para asegurar un área visible.
  - **Entradas**: `positions` (Lista de `Position`).
  - **Salidas**: Un `Future<CoordinateBounds?>` que resuelve a los límites calculados, o `null` si la lista de posiciones está vacía.
  - **Efectos**: Itera sobre la lista de posiciones para encontrar los valores mínimos y máximos de latitud y longitud.

- `calculateBoundsForLeg(List<RouteLeg> currentRouteLegs, int legIndex, {Position? additionalPoint})`:

  - **Descripción**: Calcula los límites geográficos (`CoordinateBounds`) necesarios para mostrar un tramo de ruta específico (`RouteLeg`) en el mapa. Decodifica la polilínea del tramo y opcionalmente incluye un punto adicional (ej. la posición de un bus en tiempo real) en el cálculo de los límites. Utiliza `calculateBoundsForPositions` internamente.
  - **Entradas**: `currentRouteLegs` (Lista de `RouteLeg`s), `legIndex` (Índice del tramo a calcular los límites), `additionalPoint` (Opcional, una `Position` a incluir en los límites).
  - **Salidas**: Un `Future<CoordinateBounds?>` que resuelve a los límites calculados para el tramo y el punto adicional (si se proporcionó), o `null` si el índice del tramo es inválido o el tramo no contiene información de posición.
  - **Efectos**: Decodifica polilíneas. Llama a `calculateBoundsForPositions`.

- `calculateBoundsForRoute(List<RouteLeg> legs)`:

  - **Descripción**: Calcula los límites geográficos (`CoordinateBounds`) necesarios para mostrar una ruta completa compuesta por una lista de `RouteLeg`s. Itera sobre todos los tramos, decodifica sus polilíneas (o usa los puntos de inicio/fin si no hay polilínea) y calcula los límites mínimos y máximos que engloban todos los puntos de la ruta. Utiliza `calculateBoundsForPositions` internamente.
  - **Entradas**: `legs` (Lista de `RouteLeg`s).
  - **Salidas**: Un `Future<CoordinateBounds?>` que resuelve a los límites calculados para la ruta completa, o `null` si la lista de tramos está vacía.
  - **Efectos**: Itera sobre los tramos. Decodifica polilíneas. Llama a `calculateBoundsForPositions`.

- `getDistanceAlongPolylineSegment(List<Position> polyline, int startIndex, int endIndex)`:

  - **Descripción**: Calcula la distancia total a lo largo de un segmento de una polilínea, definido por un índice de inicio y un índice de fin. Utiliza la fórmula de Haversine para sumar las distancias entre puntos consecutivos dentro del segmento.
  - **Entradas**: `polyline` (Lista de `Position` que forman la polilínea completa), `startIndex` (Índice del punto de inicio del segmento), `endIndex` (Índice del punto de fin del segmento).
  - **Salidas**: Un `double` que representa la distancia total en metros del segmento de la polilínea.
  - **Efectos**: Itera sobre los puntos del segmento y suma las distancias Haversine.

- `getPointAtDistanceAlongPolyline(List<Position> polyline, int startIndexOnPolyline, double distanceToTravel)`:
  - **Descripción**: Encuentra una `Position` específica a lo largo de una polilínea, comenzando desde un `startIndexOnPolyline` dado y avanzando una `distanceToTravel` especificada en metros. Si la distancia excede la longitud restante de la polilínea desde el índice de inicio, devuelve el último punto. Realiza interpolación lineal entre los puntos de la polilínea.
  - **Entradas**: `polyline` (Lista de `Position` que forman la polilínea completa), `startIndexOnPolyline` (Índice del punto en la polilínea desde donde comenzar a medir), `distanceToTravel` (Distancia en metros a avanzar).
  - **Salidas**: Una `Position` que representa el punto en la polilínea a la distancia especificada del punto de inicio del segmento.
  - **Efectos**: Itera sobre los segmentos de la polilínea, calcula distancias Haversine, realiza interpolación.

## Dependencias:

- Depende de `mapbox_maps_flutter` para el tipo `Position` y `CoordinateBounds`.
- Depende del modelo `Point_dart` para representar puntos.
- Depende de la función `calculateHaversineDistance` definida en `haversine.dart`.
- Utiliza `flutter_polyline_points` para decodificar polilíneas.
- Utiliza `dart:math` para `math.min`/`max` (aunque no directamente visible en los snippets proporcionados, es común en utilidades geométricas).
- Depende del modelo `RouteLeg`.

## Utilización:

- Estas funciones son utilizadas por controladores (como `MapZoomController`, `BusTrackingController`) y servicios (`MapboxService`) para realizar cálculos necesarios para la visualización precisa y el control del mapa.

# lib/utils/haversine.dart

Este archivo contiene una función de utilidad para calcular la distancia geodésica entre dos puntos en la superficie de la Tierra utilizando la fórmula de Haversine.

## Función:

- `calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2)`:
  - **Descripción**: Calcula la distancia en metros entre dos puntos geográficos especificados por sus coordenadas de latitud y longitud, aplicando la fórmula de Haversine. Esta fórmula es comúnmente utilizada para calcular distancias de "gran círculo" entre dos puntos en una esfera, lo cual es una buena aproximación para la distancia en la superficie de la Tierra.
  - **Entradas**: `lat1`, `lon1` (Latitud y longitud del primer punto en grados decimales), `lat2`, `lon2` (Latitud y longitud del segundo punto en grados decimales).
  - **Salidas**: Un `double` que representa la distancia calculada entre los dos puntos en metros.
  - **Efectos**: Realiza cálculos matemáticos utilizando trigonometría y constantes geográficas (radio de la Tierra). Convierte grados a radianes internamente para los cálculos trigonométricos.

## Dependencias:

- Utiliza la librería `dart:math` (importada como `math`) para funciones matemáticas como `sin`, `cos`, `atan2`, y `sqrt`, así como para la constante `math.pi`.

## Utilización:

- Esta función es utilizada por otras partes de la aplicación, particularmente en las utilidades geométricas (`geometry_utils.dart`), para calcular distancias entre puntos, como la distancia entre paradas de bus o la distancia a lo largo de un tramo de polilínea. Es fundamental para funcionalidades como encontrar puntos cercanos en formas o calcular la distancia recorrida.

# compose_with_origin.dart

**Ruta:** lib/widgets/compose_with_origin.dart

**Responsabilidad:**
Este widget `ComposeWithOrigin` proporciona un campo de texto (`TextField`) con funcionalidad de autocompletado avanzada, diseñado específicamente para la entrada de ubicaciones (origen o destino) en la aplicación. Se integra con un servicio de geocodificación para ofrecer sugerencias en tiempo real mientras el usuario escribe. Muestra las sugerencias en un overlay y permite al usuario seleccionar una, actualizando el campo de texto y notificando al widget padre sobre la ubicación seleccionada.

**Propiedades:**

- `controller`: `TextEditingController` para gestionar el texto del campo.
- `focusNode`: `FocusNode` para gestionar el foco del campo.
- `labelText`: Etiqueta para el campo de texto (por defecto 'Origen').
- `hintText`: Texto de sugerencia dentro del campo de texto.
- `onLocationSelected`: Callback que se ejecuta cuando una sugerencia es seleccionada, pasando el nombre completo del lugar y sus coordenadas (`[lng, lat]`).
- `geocodingService`: Instancia del servicio de geocodificación (`GeocodingService`) utilizado para obtener sugerencias.

**Estado Local:**

- `_layerLink`: `LayerLink` para posicionar el overlay de sugerencias correctamente.
- `_overlayEntry`: `OverlayEntry` que representa el overlay actualmente mostrado.
- `_debounceTimer`: `Timer` para implementar un retardo (debounce) en las llamadas al servicio de geocodificación.
- `_suggestions`: Lista de mapas (`List<Map<String, dynamic>>`) que almacena las sugerencias obtenidas del servicio de geocodificación.
- `_isLoading`: Booleano para indicar si se está cargando la lista de sugerencias (para mostrar un indicador).

**Entradas:**

- Entrada de texto del usuario en el `TextField`.
- Cambios en el foco del campo.
- Selección de una sugerencia de la lista.
- Resultados asíncronos del servicio de geocodificación.

**Salidas:**

- Actualizaciones en el `TextField` con el texto seleccionado.
- Visualización/ocultación del overlay de sugerencias.
- Llamada al callback `onLocationSelected` con los detalles de la ubicación seleccionada.
- Manejo del estado de carga.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `dart:async`
- El servicio de geocodificación proporcionado a través de `geocodingService`.

# instructions_bar.dart

**Ruta:** lib/widgets/instructions_bar.dart

**Responsabilidad:**
Este widget es responsable de mostrar la barra de instrucciones de viaje en la parte inferior de la pantalla del mapa cuando una ruta ha sido planificada y un tramo específico está seleccionado. Proporciona una interfaz colapsada para navegar entre los tramos de la ruta y un bottom sheet expandido que muestra la lista completa de instrucciones del itinerario seleccionado. También muestra información de ETA en tiempo real si está disponible para el tramo de autobús actual.

**Propiedades:**

- `currentRouteLegs`: Lista de objetos `RouteLeg` que representan los tramos de la ruta actual.
- `selectedLegIndex`: El índice del tramo de ruta actualmente seleccionado/resaltado.
- `showCollapsedInstructionsBar`: Booleano para controlar la visibilidad de la barra colapsada.
- `origenControllerText`, `destinoControllerText`: Texto de los controladores de origen y destino para mostrar nombres de lugares ingresados por el usuario si no hay nombres disponibles en los datos de la ruta.
- `isInOverviewMode`: Booleano que indica si el mapa está en modo de vista general de la ruta completa.
- `onLegSelectedInBottomSheet`: Callback que se llama cuando un tramo es seleccionado en el bottom sheet expandido.
- `onNavigateToPreviousLeg`: Callback para navegar al tramo anterior.
- `onNavigateToNextLeg`: Callback para navegar al tramo siguiente.
- `onExpandInstructionsTap`: Callback opcional que se llama al tocar la barra colapsada (alternativa a abrir el bottom sheet).
- `realtimeEtaMinutes`: Minutos estimados de llegada en tiempo real para el tramo de autobús seleccionado (si aplica).
- `isHighlightedBusReal`: Booleano que indica si el autobús del ETA es un vehículo real rastreado o una estimación programada.

**Entradas:**

- Interacciones del usuario (tap en la barra, tap en los botones de navegación, tap en los ítems de la lista en el bottom sheet).
- Datos de la ruta (`currentRouteLegs`, `selectedLegIndex`).
- Estado de visualización del mapa (`showCollapsedInstructionsBar`, `isInOverviewMode`).
- Información de ETA en tiempo real.

**Salidas:**

- Llamadas a los callbacks proporcionados para navegar entre tramos o seleccionar un tramo desde la lista.
- Presentación del bottom sheet con la lista completa de instrucciones.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `dart:math`
- `../models/route_leg.dart`

# route_options_panel.md

**Ruta:** lib/widgets/route_options_panel.dart

**Responsabilidad:**
Este archivo contiene la función `showRouteOptionsModal` que presenta un bottom sheet modal al usuario con las diferentes opciones de ruta (itinerarios consolidados) encontradas por el servicio de planificación. Muestra un resumen de cada opción, incluyendo la duración total, los modos de transporte utilizados, información de ETA para el primer bus (si aplica) y advertencias relevantes. Permite al usuario seleccionar una de las opciones para visualizarla en el mapa.

**Función Principal (`showRouteOptionsModal`):**

- Recibe el `BuildContext` y un callback `processAndDisplaySelectedItinerary`.
- Utiliza `showModalBottomSheet` para mostrar el modal.
- Dentro del modal, usa un `Consumer` de Riverpod para observar el estado de planificación (`planningStatus`) y la lista de itinerarios consolidados (`consolidatedItineraries`) desde `mapNotifierProvider`.
- Muestra un indicador de carga, un mensaje de error o la lista de itinerarios según el estado de planificación.
- La lista de itinerarios se construye utilizando el widget helper `_buildContent`.

**Función Helper (`_buildContent`):**

- Recibe el contexto, el estado de planificación, la lista de itinerarios consolidados y el callback de selección.
- Construye la lista de `ListTile` para cada itinerario consolidado.
- Cada `ListTile` muestra un resumen visual del itinerario con iconos de modo de transporte, duración, y información adicional como tiempo de caminata, espera del primer bus, ETAs alternativas y advertencias.
- Llama al callback `processAndDisplaySelectedItinerary` cuando se selecciona un itinerario de la lista.

**Función Helper (`_getWarningMessage`):**

- Traduce los tipos de advertencia (`ItineraryWarningType`) a mensajes de texto amigables para el usuario.

**Entradas:**

- `BuildContext`.
- Callback `processAndDisplaySelectedItinerary`.
- Estado de Riverpod (`PlanningStatus`, `consolidatedItineraries`, `representativeFirstBusETAInfo`, `alternativeFirstBusETAs`, `warnings`).

**Salidas:**

- Presentación del modal de opciones de ruta.
- Llamada al callback `processAndDisplaySelectedItinerary` con el itinerario seleccionado por el usuario.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `../models/processed_itinerary.dart`
- `../models/consolidated_itinerary.dart`
- `../models/consolidated_itinerary_leg.dart`
- `../models/route_leg.dart`
- `../models/leg_mode_constants.dart`
- `../providers/map_notifier.dart`
- `../state/map_state.dart`
- `../models/itinerary_warning.dart`

# search_panel.md

**Ruta:** lib/widgets/search_panel.dart

**Responsabilidad:**
Este widget proporciona la interfaz de usuario para que el usuario ingrese el origen y el destino de su viaje. Tiene dos estados: colapsado (mostrando solo el origen y destino seleccionados) y expandido (mostrando campos de entrada interactivos con sugerencias de geocodificación y un botón para buscar ruta). Gestiona la interacción con los campos de texto, integra el servicio de geocodificación para autocompletar y notifica al padre (MapScreen) sobre las selecciones de ubicación y el inicio de la búsqueda de ruta.

**Propiedades:**

- `origenController`, `destinoController`: `TextEditingController` para los campos de entrada de texto.
- `origenFocusNode`, `destinoFocusNode`: `FocusNode` para gestionar el foco de los campos de texto.
- `origenCoordinates`, `destinoCoordinates`: Coordenadas (`Point_dart`) de las ubicaciones seleccionadas.
- `geocodingService`: Instancia del servicio de geocodificación para obtener sugerencias.
- `isCalculatingRoute`: Booleano que indica si el proceso de búsqueda de ruta está en curso (para deshabilitar el botón).
- `onSearchRoute`: Callback que se ejecuta cuando el usuario presiona el botón "Buscar Ruta".
- `onOrigenSelected`, `onDestinoSelected`: Callbacks que se ejecutan cuando el usuario selecciona una sugerencia para el origen o destino, pasando las coordenadas (`Point_dart`) y el nombre de la dirección.
- `initialExpandedState`: Booleano para establecer el estado inicial de expansión del panel.
- `onOrigenClear`, `onDestinoClear`: Callbacks para manejar la limpieza de los campos de origen y destino.
- `onSwap`: Callback opcional para intercambiar origen y destino.
- `onToggleExpansion`: Callback opcional que se llama cuando el panel cambia su estado de expansión.

**Estado Local:**

- `_isSearchPanelExpanded`: Booleano para controlar el estado actual de expansión del panel.

**Entradas:**

- Entrada de texto del usuario en los campos de origen y destino.
- Selección de sugerencias de la lista desplegable.
- Tap en el botón "Buscar Ruta".
- Tap para colapsar/expandir el panel.
- Estado de carga del proceso de búsqueda de ruta (`isCalculatingRoute`).

**Salidas:**

- Actualizaciones en los campos de texto y la lista de sugerencias.
- Llamadas a los callbacks (`onOrigenSelected`, `onDestinoSelected`, `onSearchRoute`, `onOrigenClear`, `onDestinoClear`, `onSwap`, `onToggleExpansion`) para comunicar las acciones y selecciones al widget padre.
- Cambios visuales entre el estado colapsado y expandido.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `package:flutter_typeahead/flutter_typeahead.dart`
- `../services/geocoding_service.dart`
- `../models/point_dart.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `../providers/service_providers.dart`

# trip_instructions_sheet.md

**Ruta:** lib/widgets/trip_instructions_sheet.dart

**Responsabilidad:**
Este widget define el contenido del bottom sheet que se muestra al usuario cuando se expanden las instrucciones de la ruta. Presenta una lista detallada de cada tramo del itinerario seleccionado, incluyendo el modo de transporte, la distancia, la duración y los puntos de origen/destino de cada tramo. Permite al usuario seleccionar un tramo de la lista para resaltarlo en el mapa.

**Propiedades:**

- `legs`: Lista de objetos `RouteLeg` que componen el itinerario.
- `origenControllerText`, `destinoControllerText`: Texto de los controladores de origen y destino para mejorar la visualización de los nombres de inicio y fin de la ruta.
- `routeDisplayController`: Instancia del controlador de visualización de rutas (aunque parece que su uso directo dentro de este widget es limitado, se pasa como propiedad).
- `onLegSelected`: Callback que se ejecuta cuando el usuario selecciona un tramo de la lista, pasando el índice del tramo seleccionado.

**Estado Local:**

- `_pageController`: `PageController` utilizado potencialmente para controlar el desplazamiento si se usara un `PageView` (aunque actualmente se usa un `ListView`).

**Entradas:**

- La lista de tramos de la ruta (`legs`).
- El texto ingresado en los campos de origen y destino.
- La selección de un tramo por parte del usuario en la lista.
- Cambios en el estado global del tramo seleccionado (`currentLegIndex`) a través de `mapNotifierProvider`.

**Salidas:**

- Llamada al callback `onLegSelected` con el índice del tramo elegido.
- Visualización de la lista de instrucciones del itinerario.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `package:bondi_uy/models/route_leg.dart`
- `package:bondi_uy/providers/map_notifier.dart`
- `package:bondi_uy/controllers/route_display_controller.dart`
