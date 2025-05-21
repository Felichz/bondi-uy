# Documentación del Flujo de Identificación y Seguimiento de Autobuses en BondiUY

## Archivos de Código Relevantes

Para comprender y modificar el flujo de identificación y seguimiento de autobuses, los siguientes archivos son los más importantes:

- **Gestión de Estado y Lógica de Negocio Principal:**

  - `lib/providers/map_notifier.dart`: Contiene el `MapNotifier` que gestiona el `MapState`, orquestando la búsqueda de rutas, la selección de itinerarios, el inicio de la navegación y la lógica de qué autobús rastrear.
  - `lib/state/map_state.dart`: Define la estructura de datos del estado (`MapState`) que incluye coordenadas, itinerarios, tramo seleccionado, estado de la UI, etc.

- **Pantalla Principal y UI del Mapa:**

  - `lib/screens/map_screen.dart`: El widget principal de la pantalla del mapa. Escucha los cambios de estado, interactúa con los servicios (especialmente `MapboxService` y `MontevideoApiService` indirectamente a través de callbacks o `MapNotifier`), y coordina la visualización de la ruta, los autobuses en tiempo real y las instrucciones.

- **Servicios (Interacción con APIs y Lógica Encapsulada):**

  - `lib/services/otp_service.dart`: Responsable de comunicarse con el servidor OpenTripPlanner (OTP) para obtener los itinerarios de ruta.
  - `lib/services/montevideo_api_service.dart`: Interactúa con la API de Montevideo (STM) para obtener información de paradas, líneas, Estimaciones de Tiempo de Arribo (ETA) y ubicaciones de autobuses en tiempo real.
    - El método `fetchUpcomingBusesForStopAndLine` es ahora el principal para obtener la información del próximo bus (incluyendo su ubicación y ETA en minutos) para una parada y línea específica.
    - El método `fetchRealtimeBusLocations` (que obtiene un GeoJSON con todas las ubicaciones de buses para una línea) se mantiene, pero su uso principal en el flujo de seguimiento del bus del usuario ha sido reemplazado por `fetchUpcomingBusesForStopAndLine`, quedando relegado a propósitos de depuración o visualización de todos los buses si fuera necesario.
  - `lib/services/mapbox_service.dart`: Encapsula toda la interacción directa con el controlador del mapa de Mapbox, incluyendo el dibujo de rutas, paradas, iconos de autobús, segmentos de aproximación, tooltips y el manejo de la cámara.

- **Widgets Específicos de UI para el Flujo:**

  - `lib/widgets/route_options_panel.dart`: Muestra el modal con las opciones de itinerario disponibles y la ETA inicial para los tramos de autobús.
  - `lib/widgets/search_panel.dart`: Panel para que el usuario ingrese origen y destino.
  - `lib/widgets/instructions_bar.dart`: Muestra las instrucciones del viaje, ya sea colapsada o en un bottom sheet.

- **Modelos de Datos:**

  - `lib/models/itinerary.dart`: Define la estructura de un itinerario (conjunto de tramos).
  - `lib/models/route_leg.dart`: Define la estructura detallada de un tramo de ruta (ej. caminar, autobús), incluyendo geometría, paradas, etc.
  - `lib/models/bus_realtime.dart`: Modelo para la información de ETA de los autobuses.
  - `lib/models/point_dart.dart`: Modelo para representar un punto geográfico (lat, lng).

- **Utilidades:**
  - `lib/utils/geometry_utils.dart`: Contiene funciones geométricas como `findClosestPointIndexOnShape` para encontrar el punto más cercano en una polilínea.
  - `lib/utils/haversine.dart`: Para calcular distancias entre coordenadas.

## Flujo Detallado de Identificación y Seguimiento de Autobuses

### 1. Búsqueda y Presentación de Opciones de Ruta

- **Acción del Usuario**: El usuario ingresa un origen y un destino en `SearchPanel` y presiona "Buscar Ruta".
- **Disparador**: Se llama a `ref.read(mapNotifierProvider.notifier).searchRoute()`.
- **Lógica en `MapNotifier.searchRoute()`**:
  1.  Actualiza `MapState` estableciendo `isCalculatingRoute = true` y limpiando estados de ruta previos (errores, itinerarios, tramos, etc.). También se resetea `userManuallyMovedMap` y `shouldRecenterMapAfterTimeout`.
  2.  Si las coordenadas de origen o destino son nulas, se establece un `errorMessage` y se retorna.
  3.  Llama a `OtpService.planRoute()` con las coordenadas, fecha y hora actual.
  4.  **Manejo de Respuesta de OTP**:
      - Si hay un error en la consulta GraphQL, actualiza `MapState` con `isCalculatingRoute = false` y un `errorMessage`.
      - Si la respuesta es exitosa pero no contiene itinerarios (`planData['itineraries']` está vacío o es nulo), actualiza `MapState` con `isCalculatingRoute = false`, `availableItineraries = []` y un `errorMessage` indicando que no se encontraron rutas.
      - Si se encuentran itinerarios, los parsea a `List<Itinerary>` y actualiza `MapState` con `availableItineraries = itineraries` y `isCalculatingRoute = false`. Los demás estados de ruta activa (`currentRouteLegs`, `selectedLegIndex`, etc.) se mantienen limpios o en sus valores por defecto de "no ruta activa".
- **Reacción en `MapScreen`**:
  - En `initState`, un `ref.listenManual<MapState>` escucha los cambios en `mapNotifierProvider`.
  - Cuando `next.availableItineraries.isNotEmpty` y `!next.isCalculatingRoute`:
    1.  Se llama a `_clearPreviousRouteLayers()` para limpiar cualquier dibujo de ruta anterior en el mapa (vía `MapboxService`).
    2.  Se llama a `_stopTrackingBusLine()` para detener cualquier sondeo o visualización de autobús en tiempo real anterior.
    3.  Se invoca `showRouteOptionsModal()` (definido en `lib/widgets/route_options_panel.dart`).
- **Lógica en `showRouteOptionsModal()` (`lib/widgets/route_options_panel.dart`)**:
  1.  Muestra un `ModalBottomSheet`.
  2.  Itera sobre cada `Itinerary` en `availableItineraries`.
  3.  Para cada `Itinerary`, calcula la duración total y extrae sus `RouteLegs`.
  4.  **Identificación del Primer Bus y Parada para ETA Inicial**:
      - Por cada `RouteLeg` del itinerario:
        - Si el modo es `BUS` o `TRANSIT` y es el primer tramo de bus encontrado (`firstBusLeg == null`):
          - Se guarda la referencia a este `RouteLeg` como `firstBusLeg`.
          - Se obtiene `firstBusLegLineName = leg.route?.shortName`.
          - Se intenta obtener `firstBusLegFromStopId` **únicamente** desde `leg.from`:
            - Primero se prueba `_getStringValueLocal(leg.from.stopId)`.
            - Si es nulo, se prueba `_getStringValueLocal(leg.from.stopGtfsId)`.
            - Si ambos son nulos, `firstBusLegFromStopId` permanece nulo y no se podrá obtener ETA para este itinerario.
      - Se construye una fila de iconos representando los modos de cada tramo.
  5.  **Visualización de ETA Inicial**:
      - Si se obtuvieron `firstBusLeg`, `firstBusLegFromStopId` (normalizado si contiene ":"), y `firstBusLegLineName`:
        - Se utiliza un `FutureBuilder` que llama a la función `fetchUpcomingBuses` (pasada como parámetro desde `MapScreen`, que a su vez llama a `MontevideoApiService.fetchUpcomingBusesForStopAndLine`). Este método ahora devuelve la ETA en minutos y también puede incluir la `location` del bus.
        - El `FutureBuilder` muestra "Obteniendo ETA...", un mensaje de error, "No hay buses próximos", o la ETA del próximo bus (ej. "Próximo bus en X min").
  6.  Cada itinerario se muestra como un `ListTile` con su duración, secuencia de iconos y la ETA (si aplica).

### 2. Procesamiento del Itinerario Seleccionado

- **Acción del Usuario**: El usuario toca una de las opciones de itinerario en el modal.
- **Disparador**: Se ejecuta el callback `processAndDisplaySelectedItinerary(itinerary)` dentro de `showRouteOptionsModal`. Este callback apunta a `ref.read(mapNotifierProvider.notifier).processSelectedItinerary(selectedItinerary)`.
- **Lógica en `MapNotifier.processSelectedItinerary()`**:
  1.  Identifica el `firstBusLeg` dentro del `selectedItinerary.legs` y su `busLineNameToTrack = firstBusLeg.route?.shortName`.
  2.  Si el itinerario tiene tramos (`selectedItinerary.legs.isNotEmpty`):
      - Actualiza `MapState` con:
        - `currentRouteLegs = selectedItinerary.legs`.
        - `selectedLegIndex = null` (ningún tramo seleccionado aún).
        - `isInOverviewMode = true`.
        - `showCollapsedInstructionsBar = false`.
        - `userManuallyMovedMap = false`.
        - `highlightedBusPosition = null`.
        - `isCalculatingRoute = false`.
        - `legToTrackInRealtime = firstBusLeg` (el primer tramo de bus del itinerario).
        - `trackedBusLineShortName = busLineNameToTrack`.
  3.  Si el itinerario no tiene tramos, solo se actualiza `isCalculatingRoute = false` y `legToTrackInRealtime = null`.
- **Reacción en `MapScreen`**:
  - Un `ref.listen<MapState>` en el método `build` de `MapScreen` detecta cambios. Específicamente, si `routeChanged && next.currentRouteLegs.isNotEmpty && next.isInOverviewMode`:
    - Se llama a `_processAndDisplaySelectedItineraryUI(next.currentRouteLegs)` (en `MapScreen`) dentro de un `WidgetsBinding.instance.addPostFrameCallback` para asegurar que se ejecute después de la fase de construcción.
- **Lógica en `_MapScreenState._processAndDisplaySelectedItineraryUI()`**:
  1.  Verifica que `mapboxMap` y `_mapboxService` no sean nulos y que haya tramos.
  2.  Itera sobre cada `RouteLeg` en `legs`:
      - Decodifica la `polylineString` del tramo a una `List<Position>`.
      - Determina el color y grosor de línea según el modo (`WALK`, `BUS`/`TRANSIT`).
      - Llama a `_mapboxService.drawRouteSegment()` para dibujar el tramo en el mapa, pasándole un `legIndex` único.
  3.  Llama a `_mapboxService.displayRelevantStops(legs)` para mostrar las paradas de inicio/fin de los tramos de bus.
  4.  Llama a `_mapboxService.zoomToRouteBounds(legs)` para ajustar la vista del mapa al itinerario completo.
  5.  Llama a `_mapboxService.applyOverviewRouteStyle()` para aplicar un estilo visual de "resumen" a todos los tramos.
  6.  Oculta la capa general de paradas de la ciudad (`MapboxService.STOPS_LAYER_ID`) para no saturar el mapa.

### 3. Inicio de Navegación Detallada

- **Acción del Usuario**: El usuario presiona el botón "Iniciar Viaje" (visible cuando `isInOverviewMode == true` y `currentRouteLegs.isNotEmpty`).
- **Disparador**: Se llama a `mapNotifier.startDetailedNavigation()`.
- **Lógica en `MapNotifier.startDetailedNavigation()`**:
  1.  Verifica que `state.currentRouteLegs` no esté vacío.
  2.  Identifica el `legToTrack` y `busLineNameToTrack` para el inicio de la navegación:
      - Si `currentRouteLegs.first.mode` es `BUS`, ese es el `legToTrack`.
      - Si `currentRouteLegs.first.mode` es `WALK` y existe un segundo tramo que es `BUS`, el segundo tramo es el `legToTrack`.
      - En otros casos, `legToTrack` será `null`.
  3.  Actualiza `MapState` con:
      - `isInOverviewMode = false`.
      - `selectedLegIndex = 0` (selecciona el primer tramo).
      - `showCollapsedInstructionsBar = true`.
      - `userManuallyMovedMap = false`.
      - `legToTrackInRealtime = legToTrack` (actualizado según la lógica anterior).
      - `trackedBusLineShortName = busLineNameToTrack`.
- **Reacción en `MapScreen` (`initState`)**:
  - Un `ref.listenManual<MapState>` detecta el cambio a `!next.isInOverviewMode && next.selectedLegIndex == 0`.
    - Dentro de un `WidgetsBinding.instance.addPostFrameCallback`:
      - Se resetea `userManuallyMovedMap` a `false` en el `MapNotifier`.
      - Se llama a `_zoomToLeg(0)` para centrar el mapa en el primer tramo.
      - Se llama a `_updateMapRouteHighlight()` para resaltar el primer tramo.
  - **Importante**: Otro `ref.listenManual<RouteLeg?>` (escuchando `mapNotifierProvider.select((s) => s.legToTrackInRealtime)`) detecta el cambio en `legToTrackInRealtime` (que acaba de ser actualizado por `startDetailedNavigation`).
    - Si `nextLeg` (el nuevo `legToTrackInRealtime`) no es nulo, llama a `_startTrackingBusLine(nextLeg)` después de un breve delay (`Future.delayed`).
    - Si es nulo, llama a `_stopTrackingBusLine()`.

### 4. Inicio del Rastreo en Tiempo Real (`_MapScreenState._startTrackingBusLine`)

- **Disparador**: Llamado por el listener de `legToTrackInRealtime` cuando este se establece a un `RouteLeg` de autobús válido.
- **Lógica**:
  1.  Llama a `_stopTrackingBusLine()` para limpiar cualquier rastreo anterior.
  2.  Extrae `lineShortName` y `otpShapeId` (normalizado si contiene ":") del `busLegToTrack`.
  3.  Asegura que `_shapesLoaded` sea `true` (carga `assets/data/shapes.geojson` en `_shapeGeometries` si no lo está).
  4.  **Búsqueda del Shape y Paradas Clave en el Shape**:
      - Si el `shapeIdToSearch` existe en `_shapeGeometries`, asigna la lista de `Position` a `_currentFullShapeForBusLeg`.
      - Obtiene las coordenadas de la parada de subida (`busLegToTrack.from`) y bajada (`busLegToTrack.to`).
      - Llama a `findClosestPointIndexOnShape` (de `geometry_utils.dart`) para encontrar `_originStopIndexOnShape` y `_destinationStopIndexOnShape` dentro de `_currentFullShapeForBusLeg`. Estos índices representan las posiciones más cercanas en la geometría de la línea a las paradas reales de subida y bajada del usuario.
  5.  **Visualización del Shape Completo de la Línea**:
      - Si `_currentFullShapeForBusLeg` es válido, se guarda el `shapeIdToSearch` en `_currentFullLineShapeId`.
      - Llama a `_mapboxService.drawFullBusLineShape()` para dibujar la geometría completa de la línea de autobús en el mapa con un estilo atenuado (ej. gris claro, delgado). Esto ayuda al usuario a visualizar todo el recorrido de esa línea, no solo su tramo.
  6.  **Inicio del Sondeo de Buses**:
      - Realiza una llamada inmediata a `_fetchAndDisplayRealtimeBusLocations()`.
      - Inicia un `_realtimeBusTimer` que llamará a `_fetchAndDisplayRealtimeBusLocations()` periódicamente (ej. cada 30 segundos), siempre que el `legToTrackInRealtime` actual coincida con el `busLegToTrack` original para el que se inició el timer.

### 5. Obtención y Visualización de Buses en Tiempo Real (`_MapScreenState._fetchAndDisplayRealtimeBusLocations`)

- **Disparador**: Llamado inmediatamente por `_startTrackingBusLine` y luego periódicamente por `_realtimeBusTimer`.
- **Lógica Principal con Endpoint de ETA**:
  1.  Verifica que `mapboxMap` y `_mapboxService` no sean nulos.
  2.  Obtiene el `legBeingTracked` actual desde `MapState`. Si es nulo, su `lineShortNameToFetch`, o su `legBeingTracked.from.stopId` son nulos, retorna.
  3.  Llama a `montevideoApiService.fetchUpcomingBusesForStopAndLine(stopId, lineShortNameToFetch)` para obtener una lista de los próximos buses para la parada y línea especificadas. Esta respuesta ya incluye la ETA en minutos y la ubicación (`location`) del bus o buses.
  4.  **Identificación del Bus Relevante ("Closest Upcoming")**:
      - Si la respuesta de `fetchUpcomingBusesForStopAndLine` (`upcomingBusesData`) no está vacía, se considera el _primer autobús_ de la lista (`upcomingBusesData.first`) como el más cercano y relevante.
      - Se extrae su ubicación (`location.coordinates`) y su ETA (`minutesToArrival`) directamente de este objeto.
      - Esta ubicación se convierte en `newHighlightedBusPosition`.
  5.  **Actualización de `highlightedBusPosition` en `MapState`**:
      - Si `newHighlightedBusPosition` es diferente de `mapState.highlightedBusPosition`, se actualiza `mapState.highlightedBusPosition` a través del `mapNotifier`.
  6.  **Visualización del Segmento de Aproximación**:
      - Llama a `_mapboxService.drawIncomingBusSegment(newHighlightedBusPosition, _currentFullShapeForBusLeg, _originStopIndexOnShape)`. `_currentFullShapeForBusLeg` y `_originStopIndexOnShape` se siguen utilizando para saber _hacia dónde_ dibujar la línea verde desde el bus.
  7.  **Actualización de Fuente y Capas de Buses**:
      - Se crea un GeoJSON `feature` artificialmente para el `newHighlightedBusPosition` (el bus obtenido de la API de ETA).
      - A este `feature` se le añaden propiedades como `isRelevantToUserPath: true`, `isClosestUpcoming: true`, y la `eta` en minutos.
      - Este GeoJSON (usualmente con una sola `feature`) se usa para actualizar la fuente `REALTIME_BUS_SOURCE_ID` en el mapa.
      - Llama a `_updateRealtimeBusLayers()` con esta lista de `features` (generalmente una sola).
  8.  **Manejo de No Buses Encontrados por ETA**: Si `fetchUpcomingBusesForStopAndLine` devuelve una lista vacía:
      - Se limpia `highlightedBusPosition` en `MapState`.
      - Se intenta remover las capas de buses.
      - Se detiene la animación del tooltip.
      - Se llama a `_mapboxService.drawIncomingBusSegment(null, null, null)` para limpiar el segmento verde.
  9.  **(Depuración) Llamada al Endpoint Original de GeoJSON de todos los buses**:
      - De forma separada y principalmente para depuración, se puede mantener una llamada a `montevideoApiService.fetchRealtimeBusLocations(lineShortNameToFetch)`.
      - La respuesta de este endpoint (un GeoJSON con _todos_ los buses de la línea) se imprime en consola para comparar y entender discrepancias, pero _no_ es la fuente primaria para `highlightedBusPosition` ni para la ETA mostrada al usuario en el contexto del seguimiento del _próximo_ bus.

### 6. Actualización de Capas de Buses en Tiempo Real (`_MapScreenState._updateRealtimeBusLayers`)

- **Disparador**: Llamado por `_fetchAndDisplayRealtimeBusLocations` después de obtener y procesar los datos del bus (ahora, principalmente el único bus relevante del endpoint de ETA).
- **Lógica**:
  1.  Elimina las capas `REALTIME_BUS_LAYER_ID`, `REALTIME_BUS_DOTS_LAYER_ID` si existen, para asegurar una recreación limpia. La capa de tooltip (`MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID`) también se maneja con lógica de eliminación/adición.
  2.  Si no hay `features` (normalmente solo el bus del ETA) para mostrar, retorna.
  3.  **Capa `REALTIME_BUS_LAYER_ID` (Iconos Principales)**:
      - Se añade.
      - `sourceId`: `REALTIME_BUS_SOURCE_ID`.
      - `filter`: Muestra solo buses con `['get', 'isRelevant'] == true` (el bus del ETA siempre se marca así).
      - `iconImageExpression`: Usa `MapboxService.INCOMING_BUS_ICON_ID` si `['get', 'isClosestUpcoming'] == true` (el bus del ETA siempre se marca así).
      - `iconSizeExpression`: Usa un tamaño mayor si `['get', 'isClosestUpcoming'] == true`.
  4.  **Capa `REALTIME_BUS_DOTS_LAYER_ID` (Puntos para No Relevantes)**:
      - Esta capa tendría menos uso si solo se procesa el bus del ETA. Si el GeoJSON de depuración (con todos los buses) se llegara a combinar o mostrar, esta capa seguiría aplicando para los buses no relevantes de esa fuente.
  5.  **Capa `MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID` (Tooltip Flotante)**:
      - `sourceId`: `REALTIME_BUS_SOURCE_ID`.
      - `filter`: Muestra solo si `['get', 'isRelevant'] == true` Y `['get', 'isClosestUpcoming'] == true`.
      - `iconImage`: `MapboxService.INCOMING_BUS_TOOLTIP_ICON_ID`.
      - Si debe mostrarse el tooltip (hay un bus "closest upcoming"):
        - Se añade la capa si no existe, o se actualiza su filtro si ya existe.
        - Llama a `_mapboxService.startTooltipFloatingAnimation()`.
      - Si no debe mostrarse:
        - Se remueve la capa si existe.
        - Llama a `_mapboxService.stopTooltipFloatingAnimation()`.

### 7. Manejo de Cambios de Tramo y Detención del Rastreo

- **Acción del Usuario**: El usuario navega al tramo anterior/siguiente usando los botones en `InstructionsBar`.
- **Disparador**: Se llaman `_navigateToPreviousLeg()` o `_navigateToNextLeg()` en `MapScreen`.
- **Lógica en `_navigateToPreviousLeg()` / `_navigateToNextLeg()`**:
  1.  Resetea `userManuallyMovedMap` a `false` en `MapNotifier`.
  2.  Calcula el `newLegIndex`.
  3.  Llama a `mapNotifier.setSelectedLegIndex(newLegIndex)`.
  4.  Llama a `_updateMapRouteHighlight()` para actualizar el resaltado visual del tramo.
  5.  Llama a `_zoomToLeg(newLegIndex)` para centrar el mapa en el nuevo tramo.
- **Lógica en `MapNotifier.setSelectedLegIndex()`**:
  1.  Actualiza `selectedLegIndex` en `MapState`.
  2.  Resetea `userManuallyMovedMap = false`.
  3.  **Recalcula `legToTrackInRealtime` y `trackedBusLineShortName`**:
      - Si el nuevo `selectedLeg` es `BUS`, ese es el `legToTrack`.
      - Si el nuevo `selectedLeg` es `WALK` y el _siguiente_ tramo es `BUS`, el _siguiente_ tramo es el `legToTrack`.
      - Sino, `legToTrack` es `null`.
- **Reacción en `MapScreen` (`initState`)**:
  - El listener de `legToTrackInRealtime` (mencionado en el punto 3) se activa nuevamente:
    - Si el nuevo `legToTrackInRealtime` es un bus válido, llama a `_startTrackingBusLine()` (que a su vez llama a `_stopTrackingBusLine()` primero).
    - Si el nuevo `legToTrackInRealtime` es `null` (ej. el nuevo tramo es a pie y no hay un bus siguiéndole, o se llegó al final de la ruta), llama a `_stopTrackingBusLine()`.
- **Lógica en `_MapScreenState._stopTrackingBusLine()`**:
  1.  Cancela `_realtimeBusTimer`.
  2.  Establece `mapState.highlightedBusPosition` a `null` a través del `mapNotifier`.
  3.  Llama a `_mapboxService.stopTooltipFloatingAnimation()`.
  4.  Limpia variables locales: `_currentFullShapeForBusLeg`, `_originStopIndexOnShape`, `_destinationStopIndexOnShape`, `_currentFullLineShapeId`.
  5.  Elimina del mapa las capas relacionadas con el bus en tiempo real:
      - `REALTIME_BUS_LAYER_ID`, `REALTIME_BUS_DOTS_LAYER_ID`, `MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID`.
      - La capa del shape completo de la línea de bus (identificada por `_currentFullLineShapeId`).
      - El segmento verde de aproximación (llamando a `_mapboxService.drawIncomingBusSegment(null, null, null)`).

### Resumen de la Lógica Clave de Identificación del Bus Específico del Usuario

- **Durante el Rastreo Activo (para el `legToTrackInRealtime`)**:
  1.  **Shape de la Línea**: Se obtiene la geometría completa (`_currentFullShapeForBusLeg`) de la línea de autobús que el usuario está supuesto a tomar, desde `assets/data/shapes.geojson` usando el `shapeId` del `RouteLeg`.
  2.  **Parada de Origen en el Shape**: Se identifica la posición (`_originStopIndexOnShape`) de la parada donde el usuario debe subir (`legToTrackInRealtime.from`) _dentro de esa geometría de línea_. Esto sigue siendo crucial para dibujar la línea verde de aproximación _hacia_ la parada.
  3.  **Parada de Destino en el Shape** (Opcional): Se identifica la posición (`_destinationStopIndexOnShape`) de la parada donde el usuario debe bajar (`legToTrackInRealtime.to`) _dentro de esa geometría de línea_.
  4.  **Bus en Tiempo Real (ETA)**: Se llama al endpoint `fetchUpcomingBusesForStopAndLine` de la API de Montevideo con el ID de la parada de origen y la línea. Este endpoint directamente proporciona la información del próximo bus o buses, incluyendo su ubicación (`location`) y tiempo estimado de arribo (`eta` en segundos, que el servicio convierte a minutos).
  5.  **Identificación del Bus del Usuario**: El primer bus devuelto por el endpoint de ETA se considera el bus que el usuario debe tomar. Su ubicación se convierte en `highlightedBusPosition`.
  6.  **Propiedades para Visualización**: Al `feature` del GeoJSON creado para este bus se le asignan propiedades como `isRelevantToUserPath: true` y `isClosestUpcoming: true` para controlar su estilo en el mapa.
  7.  **Visualización**:
      - El autobús (`highlightedBusPosition`) recibe un icono especial y más grande.
      - Se dibuja una línea verde (`drawIncomingBusSegment`) desde este autobús resaltado hasta la `_originStopIndexOnShape` en el mapa, usando la geometría de la línea (`_currentFullShapeForBusLeg`).

Este flujo detallado debería proporcionar una base sólida para cualquier mejora o modificación que desees implementar.
