# Estructura del Proyecto BondiUY

Este documento describe la estructura de directorios y archivos de la aplicación Flutter BondiUY, detallando el propósito y contenido de cada componente principal.

## Directorio Raíz

- **`docs/`**: Contiene documentación del proyecto.
  - `index.md`: Este archivo. Describe la estructura del proyecto.
  - `refactor.txt`: Resumen del proceso de refactorización y el estado actual del código.
  - `gtfs-doc.txt`: Documentación relacionada con el formato GTFS.
  - `prompt-base.txt`: (Propósito a determinar, posiblemente relacionado con prompts de IA).
  - `montevideo-api.txt`: Documentación o notas sobre la API de Montevideo (STM).
  - `otp2/`: (Contenido a determinar, posiblemente relacionado con OpenTripPlanner v2).
- **`lib/`**: Contiene todo el código fuente Dart de la aplicación.
- **`pubspec.yaml`**: Define las dependencias del proyecto, metadatos y configuración de Flutter.
- **Otros archivos/directorios**: Configuración de IDE, archivos de build, etc. (no detallados aquí).

## Directorio `lib/`

Contiene el código fuente principal de la aplicación, organizado por funcionalidades.

### `main.dart` (lib/main.dart)

- **Propósito**: Punto de entrada principal de la aplicación Flutter.
- **Contenido**:
  - Función `main()`:
    - Asegura la inicialización de los bindings de Flutter (`WidgetsFlutterBinding.ensureInitialized()`).
    - Llama a `initializeAppConfig()` (definida en `app.dart`) para pasar el token de acceso de Mapbox desde las constantes.
    - Ejecuta la aplicación envolviéndola en un `ProviderScope` para habilitar Riverpod (`runApp(const ProviderScope(child: MyApp()))`).
  - Importa paquetes necesarios como `flutter`, `mapbox_maps_flutter`, `flutter_riverpod`, y archivos locales como `app.dart` y constantes.

### `app.dart` (lib/app.dart)

- **Propósito**: Define el widget raíz de la aplicación (`MyApp`).
- **Contenido**:
  - `initializeAppConfig(String mapboxAccessToken)`: Función exportada que inicializa las opciones globales de Mapbox estableciendo el token de acceso (`MapboxOptions.setAccessToken`). Es llamada desde `main.dart`.
  - `MyApp` (StatelessWidget):
    - Configura el `MaterialApp`.
    - Define el título de la aplicación (`'BondiUY'`).
    - Establece un tema básico (`ThemeData` con `primarySwatch: Colors.blue`).
    - Define `MapScreen` como la pantalla principal (`home`).
  - Importa paquetes y archivos necesarios, incluyendo `material.dart`, `mapbox_maps_flutter`, y `screens/map_screen.dart`.

### `constants/` (lib/constants/)

- **Propósito**: Almacena constantes globales utilizadas en toda la aplicación.
- **Contenido**:
  - `api_constants.dart`: Define las constantes para interactuar con la API de transporte público de Montevideo (STM).
    - `BASE_URL`: URL base de la API (`https://api.montevideo.gub.uy/api/transportepublico`).
    - `ACCESS_TOKEN_URL`: URL para obtener el token de autenticación OAuth 2.0.
    - `CLIENT_ID`: Identificador de cliente para la autenticación.
    - `CLIENT_SECRET`: Secreto de cliente para la autenticación.
  - `mapbox_constants.dart`: Define las constantes relacionadas con Mapbox.
    - `MAPBOX_ACCESS_TOKEN`: Token de acceso público necesario para usar los servicios de Mapbox (Mapas, Geocodificación).
  - `otp_constants.dart`: Define las constantes para el servidor OpenTripPlanner (OTP).
    - `OTP_SERVER_URL_REST`: URL del endpoint REST para la planificación de rutas del servidor OTP local (`http://10.0.2.2:8080/otp/routers/default/plan`). La IP `10.0.2.2` es específica para acceder al `localhost` de la máquina anfitriona desde un emulador Android.

### `models/` (lib/models/)

- **Propósito**: Define las estructuras de datos (modelos) utilizadas para representar la información de la aplicación.
- **Contenido**:
  - `bus_realtime.dart`: Define la clase `BusRealtime` para la información de arribo de autobuses.
    - **Campos**:
      - `line` (String): Identificador de la línea de autobús.
      - `destination` (String): Destino del autobús.
      - `minutesToArrival` (int): Estimación de minutos restantes para la llegada a la parada.
    - **Constructores**:
      - Constructor principal que requiere todos los campos.
      - `fromJson(Map<String, dynamic> json)`: Factory constructor para crear una instancia desde JSON, con manejo de valores nulos.
  - `bus_stop.dart`: Define la clase `BusStop` para representar una parada de autobús.
    - **Campos**:
      - `id` (String): Identificador único de la parada (usualmente el `stop_id` de GTFS).
      - `name` (String): Nombre de la parada.
      - `lat` (double): Latitud de la parada.
      - `lon` (double): Longitud de la parada.
    - **Constructores**:
      - Constructor principal que requiere todos los campos.
      - `fromJson(Map<String, dynamic> json)`: Factory constructor para crear una instancia desde JSON, mapeando `stop_id` y `stop_name` y manejando nulos.
  - `itinerary.dart`: Define la clase `Itinerary`.
    - **Campos**:
      - `startTime` (int): Hora de inicio del itinerario (timestamp Unix).
    - **Métodos Estáticos**:
      - `listFromJson(List<dynamic> list)`: Método auxiliar para convertir una lista de JSON (dynamic) en una `List<Itinerary>`.
  - `point_dart.dart`: Define la clase `Point_dart` (Nota: considerar renombrar a `GeoPoint` o similar para mayor claridad).
    - **Campos**:
      - `lat` (double): Latitud del punto.
      - `lng` (double): Longitud del punto.
    - **Constructores**:
      - Constructor principal que requiere `lat` y `lng`.
  - `route_leg.dart`: Define la clase principal `RouteLeg` y varias clases anidadas para representar un tramo de un itinerario calculado por OTP.
    - **`LegEndpoint`**: Representa el punto de inicio o fin de un tramo.
      - Campos: `name`, `lon`, `lat`, `arrival` (DateTime?), `departure` (DateTime?), `stopId` (String?), `stopGtfsId` (String?).
      - `fromJson`: Parsea JSON a `LegEndpoint`, incluyendo manejo de fechas y obtención segura de `stopGtfsId` anidado.
      - `toJson`: Convierte `LegEndpoint` a JSON.
    - **`LegRoute`**: Información de la ruta (para tramos de transporte público).
      - Campos: `gtfsId` (String?), `longName` (String?), `shortName` (String?).
      - `fromJson`: Parsea JSON a `LegRoute`.
    - **`LegTrip`**: Información del viaje específico (para tramos de transporte público).
      - Campos: `gtfsId` (String?), `shapeId` (String?).
      - `fromJson`: Parsea JSON a `LegTrip`.
    - **`LegGeometry`**: Geometría del tramo.
      - Campos: `points` (String, codificado en polyline), `length` (int?).
      - `fromJson`: Parsea JSON a `LegGeometry`.
    - **`LegStep`**: Representa un paso individual dentro de un tramo a pie (`WALK`).
      - Campos: `distance`, `relativeDirection`, `streetName`, `absoluteDirection`, `stayOn`, `area`, `bogusName`, `lon`, `lat`, `elevation` (String?).
      - `fromJson`: Parsea JSON a `LegStep`, con manejo seguro de tipos numéricos y `elevation`.
    - **`IntermediatePlace`**: Representa una parada o punto intermedio por el que pasa un tramo.
      - Campos: `name`, `lon`, `lat`, `stopId`, `stopGtfsId`, `arrival` (DateTime?), `departure` (DateTime?).
      - `fromJson`: Parsea JSON a `IntermediatePlace`, incluyendo manejo de fechas y obtención de `stopGtfsId`.
    - **`RouteLeg` (Clase Principal)**:
      - Campos: `mode` (String), `startTime` (int), `endTime` (int), `duration` (double), `distance` (double), `from` (LegEndpoint), `to` (LegEndpoint), `route` (LegRoute?), `trip` (LegTrip?), `legGeometry` (LegGeometry), `steps` (List<LegStep>), `intermediatePlaces` (List<IntermediatePlace>).
      - Constructor principal que requiere la mayoría de los campos.
      - `fromJson`: Factory constructor robusto para parsear el JSON complejo de un tramo, llamando a los `fromJson` de las clases anidadas y manejando listas (`steps`, `intermediatePlaces`) y valores nulos/faltantes.
      - `listFromJson`: Método estático para convertir una lista de JSON en `List<RouteLeg>`.

### `providers/` (lib/providers/)

- **Propósito**: Define los proveedores de Riverpod para la gestión del estado y la inyección de dependencias.
- **Contenido**:
  - `map_notifier.dart`: Define el `StateNotifier` principal para el estado del mapa.
    - `mapNotifierProvider`: El `StateNotifierProvider` que expone `MapNotifier` y `MapState`.
    - `MapNotifier` (extiende `StateNotifier<MapState>`):
      - **Dependencias**: Recibe `Ref` para leer otros proveedores (servicios).
      - **Estado**: Gestiona una instancia de `MapState`.
      - **Métodos Principales**: Contiene la lógica de negocio para interactuar con la UI y los servicios.
        - `setOrigenCoordinates`, `setDestinoCoordinates`: Actualizan las coordenadas en el estado.
        - `clearRouteState`: Resetea el estado relacionado con la ruta actual.
        - `setUserManuallyMovedMap`: Actualiza flag cuando el usuario mueve el mapa.
        - `setSelectedLegIndex`: Actualiza el índice del tramo seleccionado.
        - `setAvailableItineraries`: Guarda los itinerarios encontrados.
        - `processSelectedItinerary`: Procesa el itinerario elegido por el usuario, actualizando los tramos (`currentRouteLegs`) y entrando en modo `overview`.
        - `startDetailedNavigation`: Inicia la vista detallada de instrucciones para el primer tramo.
        - `searchRoute()`: Método asíncrono clave. Llama a `OtpService.planRoute` con las coordenadas de origen/destino y la hora actual. Parsea la respuesta GraphQL, actualiza `availableItineraries` en el estado o maneja errores guardándolos en `errorMessage`.
        - `clearErrorMessage`: Limpia el mensaje de error del estado.
      - **Gestión Interna**: Puede incluir lógica de debounce (ej. `_debounceTimer`), aunque parte de la gestión de timers (como el de bus en tiempo real) se delega al widget.
      - `dispose()`: Cancela timers internos.
  - `service_providers.dart`: Define los proveedores (`Provider`) para inyectar las instancias de los servicios en la aplicación.
    - `montevideoApiServiceProvider`: Proveedor para `MontevideoApiService`. Crea una instancia simple.
    - `otpGraphQLClientProvider`: Proveedor para el `GraphQLClient` necesario para `OtpService`.
      - Configura el `HttpLink` con la URL del endpoint GraphQL de OTP (actualmente hardcodeada, con IP `10.0.2.2` para emulador Android).
      - Crea el `GraphQLClient` con el link y una caché en memoria.
    - `otpServiceProvider`: Proveedor para `OtpService`.
      - Obtiene (`ref.watch`) la instancia de `GraphQLClient` del proveedor `otpGraphQLClientProvider`.
      - Crea y retorna la instancia de `OtpService` pasándole el cliente GraphQL.
    - `geocodingServiceProvider`: Proveedor para `GeocodingService`. Crea una instancia simple (el token se maneja internamente).
    - **Nota**: Explícitamente menciona que `MapboxService` no se provee aquí, ya que requiere una instancia del `MapboxMapController` que se obtiene en el widget.

### `screens/` (lib/screens/)

- **Propósito**: Contiene los widgets que representan las pantallas completas de la aplicación.
- **Contenido**:
  - `map_screen.dart`: Define `MapScreen` (`ConsumerStatefulWidget`) y `_MapScreenState`. Es la pantalla principal de la aplicación.
    - **Propósito**: Define `MapScreen`, la pantalla principal de la aplicación que muestra el mapa interactivo y coordina las interacciones del usuario con la planificación de rutas y la visualización de información del transporte.
    - **Contenido**:
      - **`_MapScreenState`**: Clase principal que gestiona el estado y la lógica de la UI del mapa.
        - **Inicialización**: Configura el controlador del mapa Mapbox (`MapboxMap`), controladores de texto para origen/destino (`_origenController`, `_destinoController`), y nodos de foco. Carga geometrías de las líneas de autobús (`_loadAndParseShapesGeoJson`).
        - **Gestión del Estado (Riverpod)**: Utiliza `ref.watch` y `ref.read` para interactuar con `MapNotifier` y obtener el estado actual (`MapState`). Usa `ref.listenManual` para reaccionar a cambios específicos del estado, como mostrar opciones de ruta, iniciar navegación detallada o mostrar errores.
        - **Interacción con `MapboxService`**: Crea una instancia local de `MapboxService` y delega las operaciones directas sobre el mapa (carga de estilo, dibujo de capas, manejo de toques).
        - **Controladores de Eventos del Mapa**: Implementa callbacks para eventos del mapa (`_onMapCreated`, `_onStyleLoadedListener`, `_handleMapTapEvent`, etc.) que interactúan con `MapboxService` y `MapNotifier`.
        - **UI Components**: Construye la interfaz usando `MapboxMap` y superponiendo otros widgets como `SearchPanel`, `InstructionsBar`, etc.
        - **Funcionalidad Específica**: Lógica para mostrar líneas de bus en paradas, gestionar zoom/cámara, controlar rastreo en tiempo real de buses, limpiar capas.
        - **Limpieza**: En `dispose`, libera recursos (controladores, timers, mapa).

### `services/` (lib/services/)

- **Propósito**: Encapsula la lógica de negocio, interacciones con APIs externas y lógica compleja separada de la UI.
- **Contenido**:
  - `geocoding_service.dart`: Servicio para realizar geocodificación (convertir direcciones a coordenadas) y autocompletar direcciones utilizando la API de Mapbox.
    - **Propósito**: Proporciona funcionalidad de geocodificación y autocompletado de direcciones utilizando la API de Mapbox Geocoding.
    - **Contenido**:
      - **Clase `GeocodingService`**:
        - **Método `fetchSuggestions(String query)`**: Toma una consulta de búsqueda, llama a la API de Mapbox Geocoding v5 (`mapbox.places`) filtrando por Uruguay y español, con autocompletar habilitado, y devuelve una lista de hasta 5 sugerencias (`features`) o una lista vacía en caso de error.
  - `mapbox_service.dart`: **Servicio crucial** que encapsula **toda** la interacción directa con el `MapboxMapController`.
    - **Propósito**: Encapsular toda la interacción directa con el objeto `MapboxMapController` (`mapboxMap`). Actúa como una capa de abstracción entre la lógica de la pantalla (`MapScreen`) y las operaciones específicas de la API de Mapbox Maps SDK. Gestiona la adición, actualización y eliminación de elementos visuales en el mapa (fuentes, capas, imágenes).
    - **Contenido**:
      - **Inicialización**: Recibe `MapboxMapController`. Define constantes para IDs de capas/fuentes y mantiene estado interno (imágenes cargadas, paradas cargadas, IDs de capas dinámicas, estado de animación).
      - **`handleStyleLoaded()`**: Añade imágenes personalizadas (iconos) al estilo y carga los datos iniciales de paradas (`loadStopsData`). Oculta la barra de escala.
      - **`loadStopsData()`**: Carga paradas desde `stops.geojson`, añade la fuente GeoJSON (`STOPS_SOURCE_ID`) y la capa de símbolos (`STOPS_LAYER_ID`) para mostrarlas.
      - **Dibujo de Rutas**: Contiene métodos para dibujar elementos de la ruta:
        - **`drawRouteSegment(...)`**: Dibuja un tramo de ruta (línea principal y sombra) y registra sus IDs.
        - **`displayRelevantStops(...)`**: Muestra las paradas de inicio/fin de los tramos de bus de una ruta en una capa separada (`ROUTE_MAIN_STOPS_LAYER_ID`).
        - **`drawFullBusLineShape(...)`**: Dibuja la geometría completa de una línea de autobús.
        - **`drawIncomingBusSegment(...)`**: Dibuja un segmento especial (verde) desde la posición de un bus en tiempo real hasta la parada de origen.
      - **Estilo y Resaltado**: Métodos para controlar la apariencia de la ruta:
        - **`updateMapRouteHighlight(...)`**: Resalta el tramo seleccionado atenuando los demás.
        - **`applyOverviewRouteStyle()`**: Aplica un estilo uniforme a toda la ruta para la vista general.
      - **Limpieza**: `clearAllRouteLayersAndSources()` elimina todas las capas y fuentes dinámicas asociadas a una ruta.
      - **Control de Cámara**: Métodos para ajustar la vista del mapa:
        - **`zoomToRouteBounds(...)`**: Ajusta la cámara para mostrar la ruta completa.
        - **`zoomToLeg(...)`**: Ajusta la cámara para mostrar un tramo específico (considerando la posición del bus si aplica).
      - **Animación**: `startTooltipFloatingAnimation()` y `stopTooltipFloatingAnimation()` manejan la animación vertical del icono del tooltip del bus.
      - **Interacción**: `handleMapTap(...)` detecta toques sobre las paradas y ejecuta un callback con la información de la parada.
      - **Utilidades**: `getStringValue(...)` para conversión segura a String.
  - `montevideo_api_service.dart`: Servicio para interactuar con la API de STM (Sistema de Transporte Metropolitano de Montevideo).
    - **Propósito**: Servicio para interactuar con la API de transporte público de Montevideo (STM). Encapsula la lógica para obtener el token de autenticación y realizar llamadas a los diferentes endpoints de la API.
    - **Contenido**:
      - **Clase `MontevideoApiService`**:
        - **Autenticación (`getApiToken`)**: Obtiene y cachea el token de acceso OAuth 2.0 necesario para las demás llamadas a la API.
        - **`fetchBusLinesForStop(String stopId)`**: Obtiene las líneas de autobús que pasan por una parada específica.
        - **`fetchUpcomingBusesForStopAndLine(String stopId, String lineShortName)`**: Obtiene los próximos arribos (ETA) para una línea en una parada. Maneja la invalidación de token en caso de error 401/403.
        - **`fetchRealtimeBusLocations(String lineShortName)`**: Obtiene la ubicación en tiempo real (GeoJSON) de los autobuses para una línea. Incluye lógica de reintento automático con nuevo token si la primera solicitud falla por autenticación.
        - (Nota: El archivo original no incluía `fetchBusLines` ni `fetchShapes` directamente, esos eran endpoints posibles mencionados en la descripción inicial pero no implementados en el archivo leído).
  - `otp_service.dart`: Servicio para interactuar con el servidor OpenTripPlanner (OTP).
    - **Propósito**: Servicio para interactuar con un servidor OpenTripPlanner (OTP) a través de GraphQL. Se encarga de planificar rutas entre dos puntos.
    - **Contenido**:
      - **Clase `OtpService`**:
        - **Constructor**: Recibe una instancia de `GraphQLClient`.
        - **Método `planRoute(...)`**: Construye y ejecuta una consulta GraphQL (`PlanRuta`) al servidor OTP para obtener hasta 3 itinerarios de viaje entre un origen y un destino, para una fecha y hora dadas, considerando los modos de transporte `WALK` y `BUS`. Especifica detalladamente los campos a retornar para cada itinerario y sus tramos (coordenadas, tiempos, distancias, geometría, información de ruta y viaje, pasos, etc.). Utiliza `FetchPolicy.networkOnly`.

### `state/` (lib/state/)

- **Propósito**: Define las clases de estado utilizadas por los `StateNotifier` de Riverpod.
- **Contenido**:
  - `map_state.dart`: Define la clase `MapState`.
    - **Propósito**: Define la clase `MapState`, que representa el estado inmutable de la UI y los datos relacionados con el mapa y la planificación de rutas. Esta clase es utilizada por `MapNotifier` (Riverpod) para gestionar el estado de la aplicación.
    - **Contenido**:
      - **Clase `MapState` (@immutable)**:
        - **Campos**: `origenCoordinates` (Point_dart?), `destinoCoordinates` (Point_dart?), `isCalculatingRoute` (bool), `showCollapsedInstructionsBar` (bool), `currentRouteLegs` (List<RouteLeg>), `selectedLegIndex` (int?), `isInOverviewMode` (bool), `availableItineraries` (List<Itinerary>), `trackedBusLineShortName` (String?), `highlightedBusPosition` (Position?), `userManuallyMovedMap` (bool), `errorMessage` (String?).
        - **Constructor**: Permite inicializar todas las propiedades, con valores por defecto para la mayoría.
        - **Método `copyWith(...)`**: Permite crear una nueva instancia de `MapState` basada en la actual, modificando solo las propiedades deseadas, asegurando la inmutabilidad.

### `utils/` (lib/utils/)

- **Propósito**: Contiene funciones de utilidad reutilizables en diferentes partes de la aplicación.
- **Contenido**:
  - `geometry_utils.dart`: Funciones relacionadas con cálculos geométricos y geográficos.
    - **Propósito**: Contiene funciones de utilidad relacionadas con cálculos geométricos y geográficos, principalmente para trabajar con coordenadas, geometrías de líneas (shapes/polylines) y calcular cuadros delimitadores (bounds).
    - **Contenido**:
      - **`findClosestPointIndexOnShape(...)`**: Encuentra el índice del punto más cercano en una línea (shape) a un punto dado, usando distancia Haversine.
      - **`calculateBoundsForPositions(...)`**: Calcula el `CoordinateBounds` (cuadro delimitador) para una lista de `Position`.
      - **`calculateBoundsForLeg(...)`**: Calcula el `CoordinateBounds` para un tramo específico (`RouteLeg`), decodificando su polyline y opcionalmente incluyendo un punto adicional.
      - **`calculateBoundsForRoute(...)`**: Calcula el `CoordinateBounds` para una ruta completa (`List<RouteLeg>`), considerando las polylines de todos sus tramos.
  - `haversine.dart`: Contiene la función `calculateHaversineDistance`.
    - **Propósito**: Proporciona una única función para calcular la distancia geodésica entre dos puntos en la superficie de la Tierra utilizando la fórmula de Haversine.
    - **Contenido**:
      - **Función `calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2)`**: Toma las latitudes y longitudes de dos puntos, las convierte a radianes y aplica la fórmula de Haversine para retornar la distancia entre ellos en metros.

### `widgets/` (lib/widgets/)

- **Propósito**: Contiene widgets reutilizables que componen la interfaz de usuario.
- **Contenido**:
  - `compose_with_origin.dart`: Widget complejo (`StatefulWidget`) que implementa un campo de texto con autocompletado para direcciones/lugares.
    - **Propósito**: Crear un campo de entrada de texto (`TextField`) reutilizable que proporciona sugerencias de autocompletado de direcciones/lugares a medida que el usuario escribe, utilizando un servicio de geocodificación.
    - **Contenido**:
      - **Clase `ComposeWithOrigin`**: Define los parámetros (controlador, nodo de foco, etiquetas, callback `onLocationSelected`, instancia de `geocodingService`).
      - **Clase `_ComposeWithOriginState`**: Gestiona el estado del widget.
        - Muestra/oculta un `OverlayEntry` con la lista de sugerencias debajo del campo de texto.
        - Utiliza un `Timer` (`_debounceTimer`) para retrasar las llamadas a `geocodingService.fetchSuggestions` mientras el usuario escribe.
        - Muestra un indicador de carga (`CircularProgressIndicator`) y un botón de limpiar en el `TextField`.
        - Formatea y muestra las sugerencias en un `ListView` dentro del overlay.
        - Al seleccionar una sugerencia, actualiza el texto del campo, llama a `onLocationSelected` con el nombre y las coordenadas, y oculta el overlay.
        - Incluye la función `_buildHighlightedText` para resaltar la parte de la consulta dentro del texto de cada sugerencia en la lista, usando `RichText`.
  - `instructions_bar.dart`: Widget (`ConsumerWidget`) que muestra las instrucciones paso a paso para el itinerario seleccionado. Consume `MapState` para obtener el itinerario y tramo actual. Muestra detalles del tramo, permite navegar entre tramos y puede incluir opciones como ver alternativas o cerrar la vista de instrucciones.
    - **Propósito**: Mostrar las instrucciones detalladas de un itinerario de viaje, permitiendo al usuario ver los diferentes tramos y navegar entre ellos. Se presenta como una barra colapsada en la parte inferior o como un panel modal (BottomSheet) con la lista completa.
    - **Contenido**:
      - **Clase `TripInstructions` (StatelessWidget)**:
        - **Parámetros**: `currentRouteLegs` (List<RouteLeg>), `selectedLegIndex` (int?), `showCollapsedInstructionsBar` (bool), textos de origen/destino, `isInOverviewMode` (bool), y callbacks para selección de tramo, navegación entre tramos y expansión.
        - **`_buildInstructionListTiles(...)`**: Genera una lista de `ListTile` para cada paso del itinerario (Origen, Tramos, Destino), con formato, iconos y manejo de selección.
        - **`_showTripInstructionsBottomSheet(...)`**: Muestra un `ModalBottomSheet` con la lista completa de instrucciones (usando `_buildInstructionListTiles`).
        - **`_buildCollapsedInstructionsBar(...)`**: Construye la UI de la barra inferior que muestra el tramo actual con su icono, descripción, y botones para navegar al tramo anterior/siguiente. Al tocar el área central de esta barra, se muestra el `BottomSheet` con todas las instrucciones.
        - **`build(...)`**: Retorna la barra de instrucciones colapsada.
  - `route_options_modal.dart`: Modal (`ConsumerWidget`) que muestra los detalles de los tramos de una ruta seleccionada, incluyendo intentos de obtener ETA para tramos de autobús.
    - **Propósito**: Mostrar los detalles de una ruta específica (compuesta por varios tramos `RouteLeg`) en un modal, incluyendo información básica de cada tramo y una sección para mostrar el tiempo estimado de llegada (ETA) para los tramos de autobús.
    - **Contenido**:
      - **Clase `RouteOptionsModal` (ConsumerWidget)**:
        - **Parámetros**: `legs` (List<RouteLeg>).
        - **`build(...)`**: Construye un `Scaffold` con un `ListView` que muestra una `Card` por cada tramo (`leg`). Cada card contiene:
          - Información del tramo: modo, nombres de origen/destino, duración (formateada), distancia.
          - **Sección ETA (si es BUS)**: Llama a `_buildEtaSection` si hay `stopGtfsId` en el punto de origen.
          - **Instrucciones (si hay `steps`)**: Muestra los pasos detallados para tramos a pie.
        - **`_buildEtaSection(...)`**: Widget interno que usa `ref.watch` para llamar a `MontevideoApiService.fetchUpcomingBusesForStopAndLine`. Usa `FutureBuilder` para mostrar el estado de carga, errores, o la información de ETA (hora de llegada y desviación) formateada.
  - `route_options_panel.dart`: Define la función `showRouteOptionsModal` que presenta un panel modal con las opciones de itinerario disponibles.
    - **Propósito**: Proporcionar una función (`showRouteOptionsModal`) que muestra un panel modal (`ModalBottomSheet`) para presentar al usuario las diferentes opciones de itinerario (`List<Itinerary>`) encontradas, permitiendo seleccionar una.
    - **Contenido**:
      - **Función `showRouteOptionsModal(...)`**: Recibe el contexto, la lista de itinerarios y un callback `processAndDisplaySelectedItinerary`.
        - Muestra un `ModalBottomSheet` con título y un `ListView.separated`.
        - Cada item del `ListView` representa un itinerario y muestra:
          - Número de opción y duración total (ej., "Opción 1: 25 min").
          - Una secuencia horizontal de iconos que representan los modos de transporte de cada tramo (ej., Icono Caminar -> Icono Bus (Linea X) -> Icono Caminar).
        - Al tocar un itinerario (`onTap`), cierra el modal y ejecuta el callback `processAndDisplaySelectedItinerary` con el itinerario elegido.
  - `search_panel.dart`: Widget (`ConsumerStatefulWidget`) principal para la búsqueda de rutas, con estados compacto y expandido.
    - **Propósito**: Proporcionar la interfaz principal para que el usuario busque una ruta. Permite ingresar direcciones de origen y destino con autocompletado, y disparar la búsqueda. Puede mostrarse en un estado compacto o expandido.
    - **Contenido**:
      - **Clase `SearchPanel`**: Define parámetros como controladores de texto, nodos de foco, coordenadas, instancia de `GeocodingService`, estado de carga, y callbacks para acciones de búsqueda y selección.
      - **Clase `_SearchPanelState`**: Gestiona el estado de expansión del panel.
        - **`_buildCompactSearchPanelUI()`**: UI para el estado colapsado, muestra origen y destino actuales y un botón para expandir.
        - **`_buildExpandedSearchPanelUI()`**: UI para el estado expandido, muestra campos de texto para origen y destino (usando `_buildTypeAheadField`) y un botón "Buscar Ruta".
        - **`_buildTypeAheadField(...)`**: Construye un campo de texto con funcionalidad de autocompletado usando `flutter_typeahead`. Llama a `GeocodingService` (obtenido vía `ref.read`) para las sugerencias y maneja la selección.
        - **`build(...)`**: Decide qué UI mostrar (compacta o expandida).
