# Análisis de Funciones - Flujo de Viaje

## Descripción del Flujo

1. Usuario entra en fase de opciones de viaje y ve preview de primera opción (con ETA)
2. Usuario cambia a segunda opción (sin ETA)
3. Usuario cambia a tercera opción (con ETA)
4. Usuario selecciona tercera opción
5. Usuario en active trip - paso: caminar hasta parada
6. Usuario presiona botón para siguiente paso: esperar bus en parada
7. Usuario presiona botón para siguiente paso: ir hasta parada destino
8. Usuario presiona botón para siguiente paso: esperar segundo bus
9. Usuario presiona botón para siguiente paso: caminar hasta destino

## Funciones Identificadas

### Archivo: lib/ui/overlays/route_options_overlay.dart

#### `_initializeCarousel()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `ref.read(appLogicProvider)` - Llamada 100% de las veces
  - `_showInitialPreview()` - Llamada solo si `routeOptionsState != null && routeOptionsState.opcionesDeRuta.isNotEmpty`

#### `_showInitialPreview()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_showRoutePreview(_currentOptionIndex)` - Llamada 3 veces con delays diferentes (100ms, 800ms, 1500ms), cada llamada condicionada a `if (mounted)`

#### `_showRoutePreview(int optionIndex)`

- **Input**:
  - `optionIndex` (int) - índice de la opción de ruta
- **Funciones que llama**:
  - `ref.read(appLogicProvider)` - Llamada 100% de las veces
  - `ref.read(appLogicProvider.notifier).seleccionarOpcionDeRutaParaPrevisualizar(option.idOpcion)` - Llamada solo si validaciones pasan (routeOptionsState != null, índice válido)
  - `_displayRoutePreview(option)` - Llamada solo si validaciones pasan

#### `_displayRoutePreview(OpcionDeRutaMostrable ruta)`

- **Input**:
  - `ruta` (OpcionDeRutaMostrable) - objeto con datos de la ruta
- **Funciones que llama**:
  - `ref.read(mapManagerProvider)` - Llamada 100% de las veces
  - `mapManager.showRoutePreview(ruta)` - Llamada solo si `mapManager != null`

#### `build(BuildContext context)` - Widget principal

- **Input**:
  - `context` (BuildContext)
- **Funciones que llama**:
  - `ref.watch(appLogicProvider)` - Llamada 100% de las veces
  - `ref.read(appLogicProvider.notifier)` - Llamada 100% de las veces
  - `ref.listen()` con listener para cambios en `idOpcionRutaPrevisualizada` - Llamada 100% de las veces
  - `_buildEmptyState(appLogic)` - Llamada solo si `routeOptionsState == null || routeOptionsState.opcionesDeRuta.isEmpty`
  - Funciones de construcción de UI (llamadas condicionalmente según estado)

#### `_buildHeader(AppLogicNotifier appLogic, bool isSmallScreen)`

- **Input**:
  - `appLogic` (AppLogicNotifier)
  - `isSmallScreen` (bool)
- **Funciones que llama**:
  - `appLogic.usuarioCanceloBusquedaOSeleccionRuta()` - Llamada solo cuando usuario presiona botón cancelar

#### `_buildModernRouteCard(OpcionDeRutaMostrable option, bool isSelected, bool isSmallScreen)`

- **Input**:
  - `option` (OpcionDeRutaMostrable)
  - `isSelected` (bool)
  - `isSmallScreen` (bool)
- **Funciones que llama**:
  - `_formatDuration(option.duracionTotalSegundos)` - Llamada 100% de las veces
  - `TimeOfDay.fromDateTime(option.horaLlegadaEstimada).format(context)` - Llamada 100% de las veces
  - `_buildModernModeIcons()` - Llamada 100% de las veces

#### `_buildModernModeIcons(BuildContext context, List<TipoTramoViaje> modos, bool isSelected, bool isSmallScreen)`

- **Input**:
  - `context` (BuildContext)
  - `modos` (List<TipoTramoViaje>)
  - `isSelected` (bool)
  - `isSmallScreen` (bool)
- **Funciones que llama**: No llama a otras funciones

#### `_buildFooter(List<OpcionDeRutaMostrable> options, AppLogicNotifier appLogic, bool isSmallScreen)`

- **Input**:
  - `options` (List<OpcionDeRutaMostrable>)
  - `appLogic` (AppLogicNotifier)
  - `isSmallScreen` (bool)
- **Funciones que llama**:
  - `appLogic.confirmarOpcionDeRutaEIniciarViaje(options[_currentOptionIndex].idOpcion)` - Llamada solo cuando usuario presiona botón "Confirmar"

#### `_buildEmptyState(AppLogicNotifier appLogic)`

- **Input**:
  - `appLogic` (AppLogicNotifier)
- **Funciones que llama**:
  - `appLogic.usuarioCanceloBusquedaOSeleccionRuta()` - Llamada solo cuando usuario presiona botón "Nueva Búsqueda"

#### `_formatDuration(int totalSeconds)`

- **Input**:
  - `totalSeconds` (int)
- **Funciones que llama**: No llama a otras funciones

#### Listener en `build()` para cambios en `idOpcionRutaPrevisualizada`

- **Input**: Cambios en el estado del provider
- **Funciones que llama**:
  - `ref.read(appLogicProvider)` - Llamada 100% de las veces cuando hay cambio
  - `setState()` - Llamada solo si `backendSelectedIndex >= 0 && backendSelectedIndex != _currentOptionIndex`
  - `_pageController.animateToPage()` - Llamada solo si `_pageController.hasClients` y hay cambio de índice
  - `_displayRoutePreview(option)` - Llamada solo si hay cambio de índice válido

#### PageView `onPageChanged`

- **Input**:
  - `index` (int) - nuevo índice de página
- **Funciones que llama**:
  - `setState()` - Llamada 100% de las veces
  - `_showRoutePreview(index)` - Llamada 100% de las veces

---

### Archivo: lib/ui/overlays/active_trip_overlay.dart

#### `_clearPreviousRoutePreview()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `widget.mapboxMap!.style.styleLayerExists(layerId)` - Llamada para cada layerId en previewLayerIds (múltiples veces)
  - `widget.mapboxMap!.style.removeStyleLayer(layerId)` - Llamada solo si la capa existe
  - `widget.mapboxMap!.style.styleSourceExists(sourceId)` - Llamada para cada sourceId en previewSourceIds (múltiples veces)
  - `widget.mapboxMap!.style.removeStyleSource(sourceId)` - Llamada solo si la fuente existe

#### `_initializeActiveTrip()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `ref.read(mapManagerProvider)` - Llamada 100% de las veces
  - `ref.read(appLogicProvider).datosFaseViajeActivo` - Llamada 100% de las veces
  - `mapManager.showActiveTrip(activeTripState)` - Llamada solo si `mapManager != null && activeTripState != null && activeTripState.tramosDelViaje.isNotEmpty`
  - `mapManager.updateCurrentLeg(0, activeTripState.tramosDelViaje)` - Llamada solo si las condiciones anteriores se cumplen

#### `_loadMapIcons()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_loadIconImageFromAsset('stop_icon.png')` - Llamada solo si `widget.mapboxMap != null && !_iconsLoaded`
  - `widget.mapboxMap!.style.addStyleImage()` - Llamada 2 veces (para stop y bus icons) solo si las condiciones se cumplen
  - `_loadIconImageFromAsset('incoming_bus.png')` - Llamada solo si las condiciones se cumplen

#### `_loadIconImageFromAsset(String assetName)`

- **Input**:
  - `assetName` (String) - nombre del archivo de asset
- **Funciones que llama**:
  - `rootBundle.load('assets/icons/$assetName')` - Llamada 100% de las veces
  - `ui.instantiateImageCodec(bytes)` - Llamada 100% de las veces
  - `codec.getNextFrame()` - Llamada 100% de las veces
  - `image.toByteData()` - Llamada 100% de las veces

#### `_onLegSelected(int legIndex)`

- **Input**:
  - `legIndex` (int) - índice del tramo seleccionado
- **Funciones que llama**:
  - `setState()` - Llamada 100% de las veces
  - `ref.read(mapManagerProvider)` - Llamada 100% de las veces
  - `ref.read(appLogicProvider).datosFaseViajeActivo` - Llamada 100% de las veces
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)` - Llamada solo si `mapManager != null && activeTripState != null`

#### `_updateBusTrackingForCurrentLeg()`

- **Input**: No recibe parámetros
- **Funciones que llama**: No llama a otras funciones (delegado al sistema centralizado)

#### `_findNextBusSegment(List<TramoViajeMostrable> tramos, int currentLegIndex)`

- **Input**:
  - `tramos` (List<TramoViajeMostrable>)
  - `currentLegIndex` (int)
- **Funciones que llama**: No llama a otras funciones (función eliminada/delegada)

#### `_startBusTracking(TramoViajeMostrable tramo)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
- **Funciones que llama**: No llama a otras funciones (delegado al sistema centralizado)

#### `_stopBusTracking()`

- **Input**: No recibe parámetros
- **Funciones que llama**: No llama a otras funciones (delegado al sistema centralizado)

#### `_updateBusPosition(Coordenada position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordenada)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Funciones que llama**: No llama a otras funciones (delegado al sistema centralizado)

#### `build(BuildContext context)` - Widget principal

- **Input**:
  - `context` (BuildContext)
- **Funciones que llama**:
  - `ref.watch(appLogicProvider)` - Llamada 100% de las veces
  - `ref.read(appLogicProvider.notifier)` - Llamada 100% de las veces
  - `ref.listen<AppUiState>(appLogicProvider, callback)` - Llamada 100% de las veces
  - `_handleRealtimeBusUpdate(nextState)` - Llamada solo cuando hay cambios en datos de bus en tiempo real
  - `_ActiveTripInstructionsPanel()` constructor - Llamada 100% de las veces

#### `_handleRealtimeBusUpdate(EstadoFaseViajeActivo? activeTripState)`

- **Input**:
  - `activeTripState` (EstadoFaseViajeActivo?)
- **Funciones que llama**:
  - `ref.read(mapManagerProvider)` - Llamada 100% de las veces
  - `mapManager.busRealtime.updateBusPosition()` - Llamada solo si `mapManager != null && activeTripState.seguimientoBusRealDisponibleEnTramoActual && activeTripState.posicionActualBusReal != null && activeTripState.minutosParaLlegadaBusReal != null`

#### `_ActiveTripInstructionsPanel.build(BuildContext context)`

- **Input**:
  - `context` (BuildContext)
- **Funciones que llama**:
  - `_buildMainInstructionCard()` - Llamada 100% de las veces
  - `_buildNavigationPanel()` - Llamada 100% de las veces

#### `_buildMainInstructionCard(BuildContext context, TramoViajeMostrable tramo, ThemeData theme)`

- **Input**:
  - `context` (BuildContext)
  - `tramo` (TramoViajeMostrable)
  - `theme` (ThemeData)
- **Funciones que llama**:
  - `_getInstructionColor(tramo)` - Llamada 100% de las veces
  - `_getInstructionIcon(tramo)` - Llamada 100% de las veces
  - `_getInstructionTitle(tramo)` - Llamada 100% de las veces
  - `appLogic.detenerSeguimientoActivo()` - Llamada solo cuando usuario presiona botón salir
  - `_getDetailedInstruction(tramo)` - Llamada 100% de las veces
  - `_buildAdditionalInfo(context, tramo, theme)` - Llamada 100% de las veces

#### `_buildAdditionalInfo(BuildContext context, TramoViajeMostrable tramo, ThemeData theme)`

- **Input**:
  - `context` (BuildContext)
  - `tramo` (TramoViajeMostrable)
  - `theme` (ThemeData)
- **Funciones que llama**:
  - `_buildCompactInfoChip()` - Llamada múltiples veces según las condiciones:
    - Para tiempo: 100% de las veces
    - Para distancia: solo si `tramo.distanciaMetros > 0`
    - Para línea de bus: solo si `tramo.nombreLineaBus != null`
    - Para ETA del bus: solo si `tramo.minutosEstimadosLlegadaBus != null`
  - `_formatDuration(tramo.duracionEstimadaSegundos)` - Llamada 100% de las veces

#### `_buildCompactInfoChip({required IconData icon, required String label, required Color color, required ThemeData theme})`

- **Input**:
  - `icon` (IconData)
  - `label` (String)
  - `color` (Color)
  - `theme` (ThemeData)
- **Funciones que llama**: No llama a otras funciones

#### `_buildNavigationPanel(BuildContext context, ThemeData theme)`

- **Input**:
  - `context` (BuildContext)
  - `theme` (ThemeData)
- **Funciones que llama**:
  - `_buildCompactNavButton()` - Llamada 2 veces (botón anterior y siguiente) 100% de las veces

#### `_buildCompactNavButton({required BuildContext context, required IconData icon, required bool enabled, required VoidCallback? onPressed, required ThemeData theme, required bool isPrimary})`

- **Input**:
  - `context` (BuildContext)
  - `icon` (IconData)
  - `enabled` (bool)
  - `onPressed` (VoidCallback?)
  - `theme` (ThemeData)
  - `isPrimary` (bool)
- **Funciones que llama**:
  - `onLegSelected(currentLegIndex - 1)` - Llamada solo cuando botón anterior está habilitado y usuario lo presiona
  - `onLegSelected(currentLegIndex + 1)` - Llamada solo cuando botón siguiente está habilitado y usuario lo presiona

#### `_getInstructionTitle(TramoViajeMostrable tramo)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
- **Funciones que llama**: No llama a otras funciones

#### `_getInstructionIcon(TramoViajeMostrable tramo)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
- **Funciones que llama**: No llama a otras funciones

#### `_getInstructionColor(TramoViajeMostrable tramo)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
- **Funciones que llama**: No llama a otras funciones

#### `_getDetailedInstruction(TramoViajeMostrable tramo)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
- **Funciones que llama**: No llama a otras funciones

#### `_formatDuration(int totalSeconds)` (en \_ActiveTripInstructionsPanel)

- **Input**:
  - `totalSeconds` (int)
- **Funciones que llama**: No llama a otras funciones

---

### Archivo: lib/providers/app_providers.dart

#### `seleccionarOpcionDeRutaParaPrevisualizar(String idOpcionRuta)`

- **Input**:
  - `idOpcionRuta` (String) - ID de la opción de ruta a previsualizar
- **Funciones que llama**:
  - `_updateState()` - Llamada 100% de las veces

#### `confirmarOpcionDeRutaEIniciarViaje(String idOpcionRuta)`

- **Input**:
  - `idOpcionRuta` (String) - ID de la opción de ruta confirmada
- **Funciones que llama**:
  - `_appUiStateNotifier.state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhere()` - Llamada 100% de las veces
  - `_updateState()` - Llamada 100% de las veces

#### `usuarioCanceloBusquedaOSeleccionRuta()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_updateState()` - Llamada 100% de las veces

#### `iniciarSeguimientoBusTiempoReal({required String idViajeActivo, required String idTramoBus})`

- **Input**:
  - `idViajeActivo` (String) - ID del viaje activo
  - `idTramoBus` (String) - ID del tramo de bus
- **Funciones que llama**:
  - `_updateState()` - Llamada 2 veces (inicial y después del delay)
  - `Future.delayed(Duration(seconds: 5))` - Llamada 100% de las veces

#### `detenerSeguimientoBusTiempoReal()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_updateState()` - Llamada 100% de las veces

#### `usuarioSeleccionoTramoDelViaje(String idViajeActivo, String idTramoSeleccionado)`

- **Input**:
  - `idViajeActivo` (String) - ID del viaje activo
  - `idTramoSeleccionado` (String) - ID del tramo seleccionado
- **Funciones que llama**:
  - `_updateState()` - Llamada 100% de las veces

#### `detenerSeguimientoActivo()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `detenerSeguimientoBusTiempoReal()` - Llamada 100% de las veces
  - `usuarioCanceloBusquedaOSeleccionRuta()` - Llamada 100% de las veces

#### `navegarAAnteriorPasoInstrucciones()`

- **Input**: No recibe parámetros
- **Funciones que llama**: No llama a otras funciones (TODO: implementar lógica)

#### `navegarASiguientePasoInstrucciones()`

- **Input**: No recibe parámetros
- **Funciones que llama**: No llama a otras funciones (TODO: implementar lógica)

#### `usuarioSeleccionoPasoInstrucciones(int indicePaso)`

- **Input**:
  - `indicePaso` (int) - índice del paso seleccionado
- **Funciones que llama**: No llama a otras funciones (TODO: implementar lógica)

#### `_updateState(AppUiState newState)`

- **Input**:
  - `newState` (AppUiState) - nuevo estado de la aplicación
- **Funciones que llama**:
  - `_appUiStateNotifier.updateState(newState)` - Llamada 100% de las veces

#### `AppUiStateNotifier.updateState(AppUiState newState)`

- **Input**:
  - `newState` (AppUiState) - nuevo estado
- **Funciones que llama**: No llama a otras funciones (actualiza state directamente)

---

### Archivo: lib/map_manager/map_manager.dart

#### `initialize()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_iconsLoader.loadAllIcons()` - Llamada solo si `!_isInitialized && mapboxMap != null`
  - `_hideCityLabels()` - Llamada solo si las condiciones anteriores se cumplen

#### `showRoutePreview(OpcionDeRutaMostrable route)`

- **Input**:
  - `route` (OpcionDeRutaMostrable) - opción de ruta a mostrar
- **Funciones que llama**:
  - `initialize()` - Llamada solo si `!_isInitialized`
  - `_cleanup.clearRoute()` - Llamada solo si `_currentPreviewOptionId != route.idOpcion`
  - `_routeRenderer.renderRoute(route.tramosParaPreview)` - Llamada solo si `needsRedraw || _activeLayers.isEmpty`
  - `_busRealtime.displayRealtimeBusesForPreview(route)` - Llamada solo si las condiciones anteriores se cumplen
  - `_cameraController.zoomToRoutePreview(route)` - Llamada 100% de las veces

#### `showActiveTrip(EstadoFaseViajeActivo activeTripState)`

- **Input**:
  - `activeTripState` (EstadoFaseViajeActivo) - estado del viaje activo
- **Funciones que llama**:
  - `initialize()` - Llamada solo si `!_isInitialized`
  - `_startActiveTripTracking(activeTripState)` - Llamada solo si `_currentPhase == 'route_preview'`
  - `_cleanup.clearAll()` - Llamada solo si `_currentPhase != 'route_preview'`
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)` - Llamada solo si no es transición desde preview
  - `_busRealtime.initializeActiveTripTracking(activeTripState)` - Llamada solo si no es transición desde preview

#### `_startActiveTripTracking(EstadoFaseViajeActivo activeTripState)`

- **Input**:
  - `activeTripState` (EstadoFaseViajeActivo)
- **Funciones que llama**:
  - `_busRealtime.stopPreviewAnimations()` - Llamada 100% de las veces
  - `_busRealtime.initializeActiveTripTracking(activeTripState)` - Llamada 100% de las veces
  - `_cameraController.zoomToActiveTrip(activeTripState.tramosDelViaje)` - Llamada 100% de las veces
  - `_cleanup.clearAll()` - Llamada solo si hay error (fallback)
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)` - Llamada solo si hay error (fallback)

#### `updateCurrentLeg(int legIndex, List<TramoViajeMostrable> tramos)`

- **Input**:
  - `legIndex` (int) - índice del tramo actual
  - `tramos` (List<TramoViajeMostrable>) - lista de tramos
- **Funciones que llama**:
  - `_routeRenderer.highlightCurrentLeg(legIndex, tramos)` - Llamada solo si `_currentPhase == 'active_trip'`
  - `_cameraController.zoomToCurrentLeg(legIndex, tramos)` - Llamada solo si `_currentPhase == 'active_trip'`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, tramos)` - Llamada solo si `_currentPhase == 'active_trip'`

#### `updateBusPosition(Coordenada position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordenada)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Funciones que llama**:
  - `_busRealtime.updateBusPosition(position, etaMinutes, isRealTime)` - Llamada 100% de las veces

#### `showInitialPhase()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `initialize()` - Llamada solo si `!_isInitialized`
  - `_cleanup.clearAll()` - Llamada 100% de las veces

#### `clearAll()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_cleanup.clearAll()` - Llamada 100% de las veces

#### `registerSource(String sourceId)`

- **Input**:
  - `sourceId` (String)
- **Funciones que llama**: No llama a otras funciones

#### `registerLayer(String layerId)`

- **Input**:
  - `layerId` (String)
- **Funciones que llama**: No llama a otras funciones

#### `clearRegistrations()`

- **Input**: No recibe parámetros
- **Funciones que llama**: No llama a otras funciones

#### `_hideCityLabels()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `mapboxMap!.style.styleLayerExists(layerId)` - Llamada para cada layerId en labelLayerIds (múltiples veces)
  - `mapboxMap!.style.setStyleLayerProperty()` - Llamada solo si la capa existe

#### `getCurrentBusPosition()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_busRealtime.currentBusPosition` - Llamada 100% de las veces (getter)

---

### Archivo: lib/map_manager/map_route_renderer.dart

#### `renderRoute(List<TramoViajeMostrable> tramos)`

- **Input**:
  - `tramos` (List<TramoViajeMostrable>) - lista de tramos del viaje
- **Funciones que llama**:
  - `_drawWalkSegment(tramo, i)` - Llamada para cada tramo de tipo CAMINAR
  - `_drawBusSegment(tramo, i)` - Llamada para cada tramo de tipo VIAJE_EN_BUS
  - `_drawWaitPoint(tramo, i)` - Llamada para cada tramo de tipo ESPERAR_BUS
  - `_addBusStopsForSegment(tramo, i)` - Llamada para cada tramo de tipo VIAJE_EN_BUS
  - `_startArrowAnimation()` - Llamada 100% de las veces al final

#### `highlightCurrentLeg(int legIndex, List<TramoViajeMostrable> tramos)`

- **Input**:
  - `legIndex` (int) - índice del tramo actual
  - `tramos` (List<TramoViajeMostrable>) - lista de tramos
- **Funciones que llama**:
  - `mapboxMap!.style.styleLayerExists(layerId)` - Llamada para cada tramo (múltiples veces)
  - `mapboxMap!.style.setStyleLayerProperty()` - Llamada solo si la capa existe

#### `_drawWalkSegment(TramoViajeMostrable tramo, int index)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
  - `index` (int)
- **Funciones que llama**:
  - `_coordenadasToGeoJsonPositionList(tramo.geometriaPolilinea!)` - Llamada solo si `tramo.geometriaPolilinea != null && !tramo.geometriaPolilinea!.isEmpty`
  - `mapboxMap!.style.addSource()` - Llamada 100% de las veces si condiciones se cumplen
  - `mapManager.registerSource(sourceId)` - Llamada 100% de las veces si condiciones se cumplen
  - `mapboxMap!.style.addLayer()` - Llamada 2 veces (shadow y main) si condiciones se cumplen
  - `mapManager.registerLayer()` - Llamada 2 veces si condiciones se cumplen

#### `_drawBusSegment(TramoViajeMostrable tramo, int index)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
  - `index` (int)
- **Funciones que llama**:
  - `_coordenadasToGeoJsonPositionList(tramo.geometriaPolilinea!)` - Llamada solo si `tramo.geometriaPolilinea != null && !tramo.geometriaPolilinea!.isEmpty`
  - `mapboxMap!.style.addSource()` - Llamada 100% de las veces si condiciones se cumplen
  - `mapManager.registerSource(sourceId)` - Llamada 100% de las veces si condiciones se cumplen
  - `mapboxMap!.style.addLayer()` - Llamada 2 veces (shadow y main) si condiciones se cumplen
  - `mapManager.registerLayer()` - Llamada 2 veces si condiciones se cumplen

#### `_drawWaitPoint(TramoViajeMostrable tramo, int index)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
  - `index` (int)
- **Funciones que llama**:
  - `mapboxMap!.style.addSource()` - Llamada solo si `tramo.posicionPunto != null`
  - `mapManager.registerSource(sourceId)` - Llamada solo si condiciones se cumplen
  - `mapboxMap!.style.addLayer()` - Llamada solo si condiciones se cumplen
  - `mapManager.registerLayer(layerId)` - Llamada solo si condiciones se cumplen

#### `_addBusStopsForSegment(TramoViajeMostrable tramo, int segmentIndex)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
  - `segmentIndex` (int)
- **Funciones que llama**:
  - `_addBusStopMarker()` - Llamada 2 veces (boarding y alighting) solo si `mapManager.iconsLoader.areIconsLoaded && tramo.geometriaPolilinea != null && !tramo.geometriaPolilinea!.isEmpty`

#### `_addBusStopMarker(String sourceId, String layerId, double lat, double lng, String label)`

- **Input**:
  - `sourceId` (String)
  - `layerId` (String)
  - `lat` (double)
  - `lng` (double)
  - `label` (String)
- **Funciones que llama**:
  - `mapboxMap!.style.addSource()` - Llamada 100% de las veces si `mapboxMap != null`
  - `mapManager.registerSource(sourceId)` - Llamada 100% de las veces si condiciones se cumplen
  - `mapboxMap!.style.addLayer()` - Llamada 100% de las veces si condiciones se cumplen
  - `mapManager.registerLayer(layerId)` - Llamada 100% de las veces si condiciones se cumplen

#### `_startArrowAnimation()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_stopArrowAnimation()` - Llamada 100% de las veces
  - `Timer.periodic()` con `_updateArrowAnimation()` - Llamada 100% de las veces

#### `_stopArrowAnimation()`

- **Input**: No recibe parámetros
- **Funciones que llama**: No llama a otras funciones

#### `_updateArrowAnimation()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `mapboxMap!.style.styleLayerExists(layerId)` - Llamada para cada layerId en \_animatedArrowLayerIds
  - `mapboxMap!.style.setStyleLayerProperty()` - Llamada solo si la capa existe

#### `_coordenadasToGeoJsonPositionList(List<Coordenada> coordenadas)`

- **Input**:
  - `coordenadas` (List<Coordenada>)
- **Funciones que llama**: No llama a otras funciones

#### `dispose()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_stopArrowAnimation()` - Llamada 100% de las veces

---

### Archivo: lib/map_manager/map_bus_realtime.dart

#### `updateBusPosition(Coordenada position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordenada)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Funciones que llama**:
  - `_tryUpdatePreviewBusElements(position, etaMinutes, isRealTime)` - Llamada 100% de las veces
  - `_displayBusOnMap(position)` - Llamada solo si `!usingPreviewElements`
  - `_updateBusApproachLineForActiveTrip(position, _currentStopPosition!)` - Llamada solo si `_currentStopPosition != null && _currentTrackedSegment != null`

#### `_findNextBusSegment(List<TramoViajeMostrable> tramos, int currentLegIndex)`

- **Input**:
  - `tramos` (List<TramoViajeMostrable>)
  - `currentLegIndex` (int)
- **Funciones que llama**: No llama a otras funciones (lógica de búsqueda interna)

#### `_startBusTracking(TramoViajeMostrable tramo)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
- **Funciones que llama**:
  - `_busTrackingTimer?.cancel()` - Llamada 100% de las veces
  - `Timer.periodic()` con `_fetchBusUpdate(tramo)` - Llamada solo si `tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS`

#### `_stopBusTracking()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_busTrackingTimer?.cancel()` - Llamada 100% de las veces
  - `_clearBusDisplay()` - Llamada 100% de las veces

#### `_fetchBusUpdate(TramoViajeMostrable tramo)`

- **Input**:
  - `tramo` (TramoViajeMostrable)
- **Funciones que llama**: No llama a otras funciones (delegado al sistema centralizado)

#### `_displayBusOnMap(Coordenada position)`

- **Input**:
  - `position` (Coordenada)
- **Funciones que llama**:
  - `mapboxMap!.style.styleSourceExists()` - Llamada 100% de las veces si `mapboxMap != null`
  - `mapboxMap!.style.getSource().updateGeoJSON()` - Llamada solo si la fuente existe
  - `mapboxMap!.style.addSource()` - Llamada solo si la fuente no existe
  - `mapManager.registerSource()` - Llamada solo si se crea nueva fuente
  - `mapboxMap!.style.styleLayerExists()` - Llamada para verificar capas existentes
  - `mapboxMap!.style.addLayer()` - Llamada solo si las capas no existen
  - `mapManager.registerLayer()` - Llamada solo si se crean nuevas capas
  - `_startTooltipFloatingAnimation()` - Llamada 100% de las veces

#### `_clearBusDisplay()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_stopTooltipFloatingAnimation()` - Llamada 100% de las veces
  - `mapboxMap!.style.styleLayerExists()` - Llamada múltiples veces para diferentes capas
  - `mapboxMap!.style.removeStyleLayer()` - Llamada solo si las capas existen
  - `mapboxMap!.style.styleSourceExists()` - Llamada múltiples veces para diferentes fuentes
  - `mapboxMap!.style.removeStyleSource()` - Llamada solo si las fuentes existen

#### `_updateBusApproachLineForActiveTrip(Coordenada busPosition, Coordenada stopPosition)`

- **Input**:
  - `busPosition` (Coordenada)
  - `stopPosition` (Coordenada)
- **Funciones que llama**:
  - `loadShapeGeometries()` - Llamada 100% de las veces si `mapboxMap != null && _currentTrackedSegment != null`
  - `getFullShapeGeometry(_currentTrackedSegment!.shapeId)` - Llamada solo si `_currentTrackedSegment!.shapeId != null`
  - `findClosestPointIndexOnShape()` - Llamada 2 veces si hay geometría completa
  - `getGeometrySegment()` - Llamada solo si los índices son válidos
  - `_tryUpdatePreviewApproachLine(geoJsonFeatureCollection)` - Llamada 100% de las veces
  - `_updateOrCreateActiveTripApproachLine(geoJsonFeatureCollection)` - Llamada solo si `!updatedPreviewLine`

#### `_tryUpdatePreviewApproachLine(Map<String, dynamic> geoJsonFeatureCollection)`

- **Input**:
  - `geoJsonFeatureCollection` (Map<String, dynamic>)
- **Funciones que llama**:
  - `mapboxMap!.style.styleSourceExists(sourceId)` - Llamada para cada sourceId en previewApproachSourceIds
  - `mapboxMap!.style.getSource(sourceId).updateGeoJSON()` - Llamada solo si la fuente existe

#### `_updateOrCreateActiveTripApproachLine(Map<String, dynamic> geoJsonFeatureCollection)`

- **Input**:
  - `geoJsonFeatureCollection` (Map<String, dynamic>)
- **Funciones que llama**:
  - `mapboxMap!.style.styleSourceExists()` - Llamada 100% de las veces si `mapboxMap != null`
  - `mapboxMap!.style.getSource().updateGeoJSON()` - Llamada solo si la fuente existe
  - `mapboxMap!.style.addSource()` - Llamada solo si la fuente no existe
  - `mapManager.registerSource()` - Llamada solo si se crea nueva fuente
  - `mapboxMap!.style.addLayer()` - Llamada 2 veces (shadow y main) solo si se crea nueva fuente
  - `mapManager.registerLayer()` - Llamada 2 veces solo si se crean nuevas capas

#### `_startTooltipFloatingAnimation()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_stopTooltipFloatingAnimation()` - Llamada 100% de las veces
  - `Timer.periodic()` con callback que llama `mapboxMap!.style.styleLayerExists()` y `mapboxMap!.style.setStyleLayerProperty()` - Llamada 100% de las veces

#### `_startTooltipFloatingAnimationPreview()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_stopTooltipFloatingAnimation()` - Llamada 100% de las veces
  - `Timer.periodic()` con callback que llama `mapboxMap!.style.styleLayerExists()` y `mapboxMap!.style.setStyleLayerProperty()` para múltiples capas - Llamada 100% de las veces

#### `_stopTooltipFloatingAnimation()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_tooltipFloatTimer?.cancel()` - Llamada 100% de las veces
  - `mapboxMap!.style.styleLayerExists()` y `mapboxMap!.style.setStyleLayerProperty()` - Llamada para resetear posiciones de tooltips

#### `_tryUpdatePreviewBusElements(Coordenada position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordenada)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Funciones que llama**:
  - `mapboxMap!.style.styleSourceExists(sourceId)` - Llamada para cada sourceId en previewBusSourceIds
  - `mapboxMap!.style.getSource(sourceId).updateGeoJSON()` - Llamada solo si la fuente existe

#### `stopPreviewAnimations()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_stopTooltipFloatingAnimation()` - Llamada 100% de las veces

#### `dispose()`

- **Input**: No recibe parámetros
- **Funciones que llama**:
  - `_stopBusTracking()` - Llamada 100% de las veces
  - `_stopTooltipFloatingAnimation()` - Llamada 100% de las veces

---

## Resumen del Flujo Completo

El flujo de viaje involucra una compleja interacción entre múltiples capas de la aplicación:

1. **UI Layer**: `route_options_overlay.dart` y `active_trip_overlay.dart` manejan la interfaz de usuario
2. **State Management**: `app_providers.dart` maneja el estado de la aplicación
3. **Map Management**: `map_manager.dart`, `map_route_renderer.dart`, y `map_bus_realtime.dart` manejan la visualización del mapa
4. **Business Logic**: Los providers del backend manejan la lógica de negocio

Cada función está cuidadosamente documentada con sus inputs y las funciones que llama, incluyendo las condiciones exactas bajo las cuales se realizan esas llamadas.

---
