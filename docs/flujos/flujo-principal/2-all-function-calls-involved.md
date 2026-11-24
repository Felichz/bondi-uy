# Function Analysis - Trip Flow

## Flow Description

1. User enters the trip options phase and sees the preview of the first option (with ETA)
2. User switches to the second option (no ETA)
3. User switches to the third option (with ETA)
4. User selects the third option
5. User in active trip - step: walk to stop
6. User presses the button for the next step: wait for bus at stop
7. User presses the button for the next step: go to destination stop
8. User presses the button for the next step: wait for second bus
9. User presses the button for the next step: walk to destination

## Identified Functions

### File: lib/ui/overlays/route_options_overlay.dart

#### `_initializeCarousel()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `ref.read(appLogicProvider)` - Called 100% of the time
  - `_showInitialPreview()` - Called only if `routeOptionsState != null && routeOptionsState.opcionesDeRuta.isNotEmpty`

#### `_showInitialPreview()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_showRoutePreview(_currentOptionIndex)` - Called 3 times with different delays (100ms, 800ms, 1500ms), each call conditioned on `if (mounted)`

#### `_showRoutePreview(int optionIndex)`

- **Input**:
  - `optionIndex` (int) - index of the route option
- **Functions it calls**:
  - `ref.read(appLogicProvider)` - Called 100% of the time
  - `ref.read(appLogicProvider.notifier).seleccionarOpcionDeRutaParaPrevisualizar(option.idOption)` - Called only if validations pass (routeOptionsState != null, valid index)
  - `_displayRoutePreview(option)` - Called only if validations pass

#### `_displayRoutePreview(OpcionDeRutaMostrable route)`

- **Input**:
  - `route` (OpcionDeRutaMostrable) - object with the route data
- **Functions it calls**:
  - `ref.read(mapManagerProvider)` - Called 100% of the time
  - `mapManager.showRoutePreview(route)` - Called only if `mapManager != null`

#### `build(BuildContext context)` - Main widget

- **Input**:
  - `context` (BuildContext)
- **Functions it calls**:
  - `ref.watch(appLogicProvider)` - Called 100% of the time
  - `ref.read(appLogicProvider.notifier)` - Called 100% of the time
  - `ref.listen()` with a listener for changes in `idOpcionRutaPrevisualizada` - Called 100% of the time
  - `_buildEmptyState(appLogic)` - Called only if `routeOptionsState == null || routeOptionsState.opcionesDeRuta.isEmpty`
  - UI building functions (called conditionally depending on state)

#### `_buildHeader(AppLogicNotifier appLogic, bool isSmallScreen)`

- **Input**:
  - `appLogic` (AppLogicNotifier)
  - `isSmallScreen` (bool)
- **Functions it calls**:
  - `appLogic.usuarioCanceloBusquedaOSeleccionRuta()` - Called only when the user presses the cancel button

#### `_buildModernRouteCard(OpcionDeRutaMostrable option, bool isSelected, bool isSmallScreen)`

- **Input**:
  - `option` (OpcionDeRutaMostrable)
  - `isSelected` (bool)
  - `isSmallScreen` (bool)
- **Functions it calls**:
  - `_formatDuration(option.duracionTotalSegundos)` - Called 100% of the time
  - `TimeOfDay.fromDateTime(option.horaLlegadaEstimada).format(context)` - Called 100% of the time
  - `_buildModernModeIcons()` - Called 100% of the time

#### `_buildModernModeIcons(BuildContext context, List<TypeLegTrip> modos, bool isSelected, bool isSmallScreen)`

- **Input**:
  - `context` (BuildContext)
  - `modos` (List<TypeLegTrip>)
  - `isSelected` (bool)
  - `isSmallScreen` (bool)
- **Functions it calls**: Does not call other functions

#### `_buildFooter(List<OpcionDeRutaMostrable> options, AppLogicNotifier appLogic, bool isSmallScreen)`

- **Input**:
  - `options` (List<OpcionDeRutaMostrable>)
  - `appLogic` (AppLogicNotifier)
  - `isSmallScreen` (bool)
- **Functions it calls**:
  - `appLogic.confirmarOpcionDeRutaEIniciarViaje(options[_currentOptionIndex].idOption)` - Called only when the user presses the "Confirm" button

#### `_buildEmptyState(AppLogicNotifier appLogic)`

- **Input**:
  - `appLogic` (AppLogicNotifier)
- **Functions it calls**:
  - `appLogic.usuarioCanceloBusquedaOSeleccionRuta()` - Called only when the user presses the "New Search" button

#### `_formatDuration(int totalSeconds)`

- **Input**:
  - `totalSeconds` (int)
- **Functions it calls**: Does not call other functions

#### Listener in `build()` for changes in `idOpcionRutaPrevisualizada`

- **Input**: Changes in the provider state
- **Functions it calls**:
  - `ref.read(appLogicProvider)` - Called 100% of the time when there is a change
  - `setState()` - Called only if `backendSelectedIndex >= 0 && backendSelectedIndex != _currentOptionIndex`
  - `_pageController.animateToPage()` - Called only if `_pageController.hasClients` and there is an index change
  - `_displayRoutePreview(option)` - Called only if there is a valid index change

#### PageView `onPageChanged`

- **Input**:
  - `index` (int) - new page index
- **Functions it calls**:
  - `setState()` - Called 100% of the time
  - `_showRoutePreview(index)` - Called 100% of the time

---

### File: lib/ui/overlays/active_trip_overlay.dart

#### `_clearPreviousRoutePreview()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `widget.mapboxMap!.style.styleLayerExists(layerId)` - Called for each layerId in previewLayerIds (multiple times)
  - `widget.mapboxMap!.style.removeStyleLayer(layerId)` - Called only if the layer exists
  - `widget.mapboxMap!.style.styleSourceExists(sourceId)` - Called for each sourceId in previewSourceIds (multiple times)
  - `widget.mapboxMap!.style.removeStyleSource(sourceId)` - Called only if the source exists

#### `_initializeActiveTrip()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `ref.read(mapManagerProvider)` - Called 100% of the time
  - `ref.read(appLogicProvider).datosFaseViajeActivo` - Called 100% of the time
  - `mapManager.showActiveTrip(activeTripState)` - Called only if `mapManager != null && activeTripState != null && activeTripState.tramosDelViaje.isNotEmpty`
  - `mapManager.updateCurrentLeg(0, activeTripState.tramosDelViaje)` - Called only if the previous conditions are met

#### `_loadMapIcons()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_loadIconImageFromAsset('stop_icon.png')` - Called only if `widget.mapboxMap != null && !_iconsLoaded`
  - `widget.mapboxMap!.style.addStyleImage()` - Called 2 times (for the stop and bus icons) only if the conditions are met
  - `_loadIconImageFromAsset('incoming_bus.png')` - Called only if the conditions are met

#### `_loadIconImageFromAsset(String assetName)`

- **Input**:
  - `assetName` (String) - name of the asset file
- **Functions it calls**:
  - `rootBundle.load('assets/icons/$assetName')` - Called 100% of the time
  - `ui.instantiateImageCodec(bytes)` - Called 100% of the time
  - `codec.getNextFrame()` - Called 100% of the time
  - `image.toByteData()` - Called 100% of the time

#### `_onLegSelected(int legIndex)`

- **Input**:
  - `legIndex` (int) - index of the selected leg
- **Functions it calls**:
  - `setState()` - Called 100% of the time
  - `ref.read(mapManagerProvider)` - Called 100% of the time
  - `ref.read(appLogicProvider).datosFaseViajeActivo` - Called 100% of the time
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)` - Called only if `mapManager != null && activeTripState != null`

#### `_updateBusTrackingForCurrentLeg()`

- **Input**: Receives no parameters
- **Functions it calls**: Does not call other functions (delegated to the centralized system)

#### `_findNextBusSegment(List<LegTripDisplayable> legs, int currentLegIndex)`

- **Input**:
  - `legs` (List<LegTripDisplayable>)
  - `currentLegIndex` (int)
- **Functions it calls**: Does not call other functions (removed/delegated function)

#### `_startBusTracking(LegTripDisplayable leg)`

- **Input**:
  - `leg` (LegTripDisplayable)
- **Functions it calls**: Does not call other functions (delegated to the centralized system)

#### `_stopBusTracking()`

- **Input**: Receives no parameters
- **Functions it calls**: Does not call other functions (delegated to the centralized system)

#### `_updateBusPosition(Coordinate position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordinate)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Functions it calls**: Does not call other functions (delegated to the centralized system)

#### `build(BuildContext context)` - Main widget

- **Input**:
  - `context` (BuildContext)
- **Functions it calls**:
  - `ref.watch(appLogicProvider)` - Called 100% of the time
  - `ref.read(appLogicProvider.notifier)` - Called 100% of the time
  - `ref.listen<AppUiState>(appLogicProvider, callback)` - Called 100% of the time
  - `_handleRealtimeBusUpdate(nextState)` - Called only when there are changes in real-time bus data
  - `_ActiveTripInstructionsPanel()` constructor - Called 100% of the time

#### `_handleRealtimeBusUpdate(EstadoFaseViajeActivo? activeTripState)`

- **Input**:
  - `activeTripState` (EstadoFaseViajeActivo?)
- **Functions it calls**:
  - `ref.read(mapManagerProvider)` - Called 100% of the time
  - `mapManager.busRealtime.updateBusPosition()` - Called only if `mapManager != null && activeTripState.seguimientoBusRealDisponibleEnTramoActual && activeTripState.posicionActualBusReal != null && activeTripState.minutosParaLlegadaBusReal != null`

#### `_ActiveTripInstructionsPanel.build(BuildContext context)`

- **Input**:
  - `context` (BuildContext)
- **Functions it calls**:
  - `_buildMainInstructionCard()` - Called 100% of the time
  - `_buildNavigationPanel()` - Called 100% of the time

#### `_buildMainInstructionCard(BuildContext context, LegTripDisplayable leg, ThemeData theme)`

- **Input**:
  - `context` (BuildContext)
  - `leg` (LegTripDisplayable)
  - `theme` (ThemeData)
- **Functions it calls**:
  - `_getInstructionColor(leg)` - Called 100% of the time
  - `_getInstructionIcon(leg)` - Called 100% of the time
  - `_getInstructionTitle(leg)` - Called 100% of the time
  - `appLogic.detenerSeguimientoActivo()` - Called only when the user presses the exit button
  - `_getDetailedInstruction(leg)` - Called 100% of the time
  - `_buildAdditionalInfo(context, leg, theme)` - Called 100% of the time

#### `_buildAdditionalInfo(BuildContext context, LegTripDisplayable leg, ThemeData theme)`

- **Input**:
  - `context` (BuildContext)
  - `leg` (LegTripDisplayable)
  - `theme` (ThemeData)
- **Functions it calls**:
  - `_buildCompactInfoChip()` - Called multiple times depending on the conditions:
    - For time: 100% of the time
    - For distance: only if `leg.distanceMeters > 0`
    - For bus line: only if `leg.nameLineBus != null`
    - For bus ETA: only if `leg.minutosEstimadosLlegadaBus != null`
  - `_formatDuration(leg.durationEstimatedSeconds)` - Called 100% of the time

#### `_buildCompactInfoChip({required IconData icon, required String label, required Color color, required ThemeData theme})`

- **Input**:
  - `icon` (IconData)
  - `label` (String)
  - `color` (Color)
  - `theme` (ThemeData)
- **Functions it calls**: Does not call other functions

#### `_buildNavigationPanel(BuildContext context, ThemeData theme)`

- **Input**:
  - `context` (BuildContext)
  - `theme` (ThemeData)
- **Functions it calls**:
  - `_buildCompactNavButton()` - Called 2 times (previous and next button) 100% of the time

#### `_buildCompactNavButton({required BuildContext context, required IconData icon, required bool enabled, required VoidCallback? onPressed, required ThemeData theme, required bool isPrimary})`

- **Input**:
  - `context` (BuildContext)
  - `icon` (IconData)
  - `enabled` (bool)
  - `onPressed` (VoidCallback?)
  - `theme` (ThemeData)
  - `isPrimary` (bool)
- **Functions it calls**:
  - `onLegSelected(currentLegIndex - 1)` - Called only when the previous button is enabled and the user presses it
  - `onLegSelected(currentLegIndex + 1)` - Called only when the next button is enabled and the user presses it

#### `_getInstructionTitle(LegTripDisplayable leg)`

- **Input**:
  - `leg` (LegTripDisplayable)
- **Functions it calls**: Does not call other functions

#### `_getInstructionIcon(LegTripDisplayable leg)`

- **Input**:
  - `leg` (LegTripDisplayable)
- **Functions it calls**: Does not call other functions

#### `_getInstructionColor(LegTripDisplayable leg)`

- **Input**:
  - `leg` (LegTripDisplayable)
- **Functions it calls**: Does not call other functions

#### `_getDetailedInstruction(LegTripDisplayable leg)`

- **Input**:
  - `leg` (LegTripDisplayable)
- **Functions it calls**: Does not call other functions

#### `_formatDuration(int totalSeconds)` (in \_ActiveTripInstructionsPanel)

- **Input**:
  - `totalSeconds` (int)
- **Functions it calls**: Does not call other functions

---

### File: lib/providers/app_providers.dart

#### `seleccionarOpcionDeRutaParaPrevisualizar(String idOpcionRuta)`

- **Input**:
  - `idOpcionRuta` (String) - ID of the route option to preview
- **Functions it calls**:
  - `_updateState()` - Called 100% of the time

#### `confirmarOpcionDeRutaEIniciarViaje(String idOpcionRuta)`

- **Input**:
  - `idOpcionRuta` (String) - ID of the confirmed route option
- **Functions it calls**:
  - `_appUiStateNotifier.state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhere()` - Called 100% of the time
  - `_updateState()` - Called 100% of the time

#### `usuarioCanceloBusquedaOSeleccionRuta()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_updateState()` - Called 100% of the time

#### `iniciarSeguimientoBusTiempoReal({required String idViajeActivo, required String idTramoBus})`

- **Input**:
  - `idViajeActivo` (String) - ID of the active trip
  - `idTramoBus` (String) - ID of the bus leg
- **Functions it calls**:
  - `_updateState()` - Called 2 times (initial and after the delay)
  - `Future.delayed(Duration(seconds: 5))` - Called 100% of the time

#### `detenerSeguimientoBusTiempoReal()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_updateState()` - Called 100% of the time

#### `usuarioSeleccionoTramoDelViaje(String idViajeActivo, String idTramoSeleccionado)`

- **Input**:
  - `idViajeActivo` (String) - ID of the active trip
  - `idTramoSeleccionado` (String) - ID of the selected leg
- **Functions it calls**:
  - `_updateState()` - Called 100% of the time

#### `detenerSeguimientoActivo()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `detenerSeguimientoBusTiempoReal()` - Called 100% of the time
  - `usuarioCanceloBusquedaOSeleccionRuta()` - Called 100% of the time

#### `navegarAAnteriorPasoInstrucciones()`

- **Input**: Receives no parameters
- **Functions it calls**: Does not call other functions (TODO: implement logic)

#### `navegarASiguientePasoInstrucciones()`

- **Input**: Receives no parameters
- **Functions it calls**: Does not call other functions (TODO: implement logic)

#### `usuarioSeleccionoPasoInstrucciones(int indicePaso)`

- **Input**:
  - `indicePaso` (int) - index of the selected step
- **Functions it calls**: Does not call other functions (TODO: implement logic)

#### `_updateState(AppUiState newState)`

- **Input**:
  - `newState` (AppUiState) - new application state
- **Functions it calls**:
  - `_appUiStateNotifier.updateState(newState)` - Called 100% of the time

#### `AppUiStateNotifier.updateState(AppUiState newState)`

- **Input**:
  - `newState` (AppUiState) - new state
- **Functions it calls**: Does not call other functions (updates state directly)

---

### File: lib/map_manager/map_manager.dart

#### `initialize()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_iconsLoader.loadAllIcons()` - Called only if `!_isInitialized && mapboxMap != null`
  - `_hideCityLabels()` - Called only if the previous conditions are met

#### `showRoutePreview(OpcionDeRutaMostrable route)`

- **Input**:
  - `route` (OpcionDeRutaMostrable) - route option to show
- **Functions it calls**:
  - `initialize()` - Called only if `!_isInitialized`
  - `_cleanup.clearRoute()` - Called only if `_currentPreviewOptionId != route.idOption`
  - `_routeRenderer.renderRoute(route.tramosParaPreview)` - Called only if `needsRedraw || _activeLayers.isEmpty`
  - `_busRealtime.displayRealtimeBusesForPreview(route)` - Called only if the previous conditions are met
  - `_cameraController.zoomToRoutePreview(route)` - Called 100% of the time

#### `showActiveTrip(EstadoFaseViajeActivo activeTripState)`

- **Input**:
  - `activeTripState` (EstadoFaseViajeActivo) - active trip state
- **Functions it calls**:
  - `initialize()` - Called only if `!_isInitialized`
  - `_startActiveTripTracking(activeTripState)` - Called only if `_currentPhase == 'route_preview'`
  - `_cleanup.clearAll()` - Called only if `_currentPhase != 'route_preview'`
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)` - Called only if it is not a transition from preview
  - `_busRealtime.initializeActiveTripTracking(activeTripState)` - Called only if it is not a transition from preview

#### `_startActiveTripTracking(EstadoFaseViajeActivo activeTripState)`

- **Input**:
  - `activeTripState` (EstadoFaseViajeActivo)
- **Functions it calls**:
  - `_busRealtime.stopPreviewAnimations()` - Called 100% of the time
  - `_busRealtime.initializeActiveTripTracking(activeTripState)` - Called 100% of the time
  - `_cameraController.zoomToActiveTrip(activeTripState.tramosDelViaje)` - Called 100% of the time
  - `_cleanup.clearAll()` - Called only on error (fallback)
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)` - Called only on error (fallback)

#### `updateCurrentLeg(int legIndex, List<LegTripDisplayable> legs)`

- **Input**:
  - `legIndex` (int) - index of the current leg
  - `legs` (List<LegTripDisplayable>) - list of legs
- **Functions it calls**:
  - `_routeRenderer.highlightCurrentLeg(legIndex, legs)` - Called only if `_currentPhase == 'active_trip'`
  - `_cameraController.zoomToCurrentLeg(legIndex, legs)` - Called only if `_currentPhase == 'active_trip'`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, legs)` - Called only if `_currentPhase == 'active_trip'`

#### `updateBusPosition(Coordinate position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordinate)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Functions it calls**:
  - `_busRealtime.updateBusPosition(position, etaMinutes, isRealTime)` - Called 100% of the time

#### `showInitialPhase()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `initialize()` - Called only if `!_isInitialized`
  - `_cleanup.clearAll()` - Called 100% of the time

#### `clearAll()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_cleanup.clearAll()` - Called 100% of the time

#### `registerSource(String sourceId)`

- **Input**:
  - `sourceId` (String)
- **Functions it calls**: Does not call other functions

#### `registerLayer(String layerId)`

- **Input**:
  - `layerId` (String)
- **Functions it calls**: Does not call other functions

#### `clearRegistrations()`

- **Input**: Receives no parameters
- **Functions it calls**: Does not call other functions

#### `_hideCityLabels()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `mapboxMap!.style.styleLayerExists(layerId)` - Called for each layerId in labelLayerIds (multiple times)
  - `mapboxMap!.style.setStyleLayerProperty()` - Called only if the layer exists

#### `getCurrentBusPosition()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_busRealtime.currentBusPosition` - Called 100% of the time (getter)

---

### File: lib/map_manager/map_route_renderer.dart

#### `renderRoute(List<LegTripDisplayable> legs)`

- **Input**:
  - `legs` (List<LegTripDisplayable>) - list of trip legs
- **Functions it calls**:
  - `_drawWalkSegment(leg, i)` - Called for each WALK leg
  - `_drawBusSegment(leg, i)` - Called for each IN_BUS_TRAVEL leg
  - `_drawWaitPoint(leg, i)` - Called for each WAIT_BUS leg
  - `_addBusStopsForSegment(leg, i)` - Called for each IN_BUS_TRAVEL leg
  - `_startArrowAnimation()` - Called 100% of the time at the end

#### `highlightCurrentLeg(int legIndex, List<LegTripDisplayable> legs)`

- **Input**:
  - `legIndex` (int) - index of the current leg
  - `legs` (List<LegTripDisplayable>) - list of legs
- **Functions it calls**:
  - `mapboxMap!.style.styleLayerExists(layerId)` - Called for each leg (multiple times)
  - `mapboxMap!.style.setStyleLayerProperty()` - Called only if the layer exists

#### `_drawWalkSegment(LegTripDisplayable leg, int index)`

- **Input**:
  - `leg` (LegTripDisplayable)
  - `index` (int)
- **Functions it calls**:
  - `_coordenadasToGeoJsonPositionList(leg.geometryPolyline!)` - Called only if `leg.geometryPolyline != null && !leg.geometryPolyline!.isEmpty`
  - `mapboxMap!.style.addSource()` - Called 100% of the time if the conditions are met
  - `mapManager.registerSource(sourceId)` - Called 100% of the time if the conditions are met
  - `mapboxMap!.style.addLayer()` - Called 2 times (shadow and main) if the conditions are met
  - `mapManager.registerLayer()` - Called 2 times if the conditions are met

#### `_drawBusSegment(LegTripDisplayable leg, int index)`

- **Input**:
  - `leg` (LegTripDisplayable)
  - `index` (int)
- **Functions it calls**:
  - `_coordenadasToGeoJsonPositionList(leg.geometryPolyline!)` - Called only if `leg.geometryPolyline != null && !leg.geometryPolyline!.isEmpty`
  - `mapboxMap!.style.addSource()` - Called 100% of the time if the conditions are met
  - `mapManager.registerSource(sourceId)` - Called 100% of the time if the conditions are met
  - `mapboxMap!.style.addLayer()` - Called 2 times (shadow and main) if the conditions are met
  - `mapManager.registerLayer()` - Called 2 times if the conditions are met

#### `_drawWaitPoint(LegTripDisplayable leg, int index)`

- **Input**:
  - `leg` (LegTripDisplayable)
  - `index` (int)
- **Functions it calls**:
  - `mapboxMap!.style.addSource()` - Called only if `leg.positionPunto != null`
  - `mapManager.registerSource(sourceId)` - Called only if the conditions are met
  - `mapboxMap!.style.addLayer()` - Called only if the conditions are met
  - `mapManager.registerLayer(layerId)` - Called only if the conditions are met

#### `_addBusStopsForSegment(LegTripDisplayable leg, int segmentIndex)`

- **Input**:
  - `leg` (LegTripDisplayable)
  - `segmentIndex` (int)
- **Functions it calls**:
  - `_addBusStopMarker()` - Called 2 times (boarding and alighting) only if `mapManager.iconsLoader.areIconsLoaded && leg.geometryPolyline != null && !leg.geometryPolyline!.isEmpty`

#### `_addBusStopMarker(String sourceId, String layerId, double lat, double lng, String label)`

- **Input**:
  - `sourceId` (String)
  - `layerId` (String)
  - `lat` (double)
  - `lng` (double)
  - `label` (String)
- **Functions it calls**:
  - `mapboxMap!.style.addSource()` - Called 100% of the time if `mapboxMap != null`
  - `mapManager.registerSource(sourceId)` - Called 100% of the time if the conditions are met
  - `mapboxMap!.style.addLayer()` - Called 100% of the time if the conditions are met
  - `mapManager.registerLayer(layerId)` - Called 100% of the time if the conditions are met

#### `_startArrowAnimation()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_stopArrowAnimation()` - Called 100% of the time
  - `Timer.periodic()` with `_updateArrowAnimation()` - Called 100% of the time

#### `_stopArrowAnimation()`

- **Input**: Receives no parameters
- **Functions it calls**: Does not call other functions

#### `_updateArrowAnimation()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `mapboxMap!.style.styleLayerExists(layerId)` - Called for each layerId in \_animatedArrowLayerIds
  - `mapboxMap!.style.setStyleLayerProperty()` - Called only if the layer exists

#### `_coordenadasToGeoJsonPositionList(List<Coordinate> coordenadas)`

- **Input**:
  - `coordenadas` (List<Coordinate>)
- **Functions it calls**: Does not call other functions

#### `dispose()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_stopArrowAnimation()` - Called 100% of the time

---

### File: lib/map_manager/map_bus_realtime.dart

#### `updateBusPosition(Coordinate position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordinate)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Functions it calls**:
  - `_tryUpdatePreviewBusElements(position, etaMinutes, isRealTime)` - Called 100% of the time
  - `_displayBusOnMap(position)` - Called only if `!usingPreviewElements`
  - `_updateBusApproachLineForActiveTrip(position, _currentStopPosition!)` - Called only if `_currentStopPosition != null && _currentTrackedSegment != null`

#### `_findNextBusSegment(List<LegTripDisplayable> legs, int currentLegIndex)`

- **Input**:
  - `legs` (List<LegTripDisplayable>)
  - `currentLegIndex` (int)
- **Functions it calls**: Does not call other functions (internal search logic)

#### `_startBusTracking(LegTripDisplayable leg)`

- **Input**:
  - `leg` (LegTripDisplayable)
- **Functions it calls**:
  - `_busTrackingTimer?.cancel()` - Called 100% of the time
  - `Timer.periodic()` with `_fetchBusUpdate(leg)` - Called only if `leg.type == TypeLegTrip.VIAJE_EN_BUS`

#### `_stopBusTracking()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_busTrackingTimer?.cancel()` - Called 100% of the time
  - `_clearBusDisplay()` - Called 100% of the time

#### `_fetchBusUpdate(LegTripDisplayable leg)`

- **Input**:
  - `leg` (LegTripDisplayable)
- **Functions it calls**: Does not call other functions (delegated to the centralized system)

#### `_displayBusOnMap(Coordinate position)`

- **Input**:
  - `position` (Coordinate)
- **Functions it calls**:
  - `mapboxMap!.style.styleSourceExists()` - Called 100% of the time if `mapboxMap != null`
  - `mapboxMap!.style.getSource().updateGeoJSON()` - Called only if the source exists
  - `mapboxMap!.style.addSource()` - Called only if the source does not exist
  - `mapManager.registerSource()` - Called only if a new source is created
  - `mapboxMap!.style.styleLayerExists()` - Called to check existing layers
  - `mapboxMap!.style.addLayer()` - Called only if the layers do not exist
  - `mapManager.registerLayer()` - Called only if new layers are created
  - `_startTooltipFloatingAnimation()` - Called 100% of the time

#### `_clearBusDisplay()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_stopTooltipFloatingAnimation()` - Called 100% of the time
  - `mapboxMap!.style.styleLayerExists()` - Called multiple times for different layers
  - `mapboxMap!.style.removeStyleLayer()` - Called only if the layers exist
  - `mapboxMap!.style.styleSourceExists()` - Called multiple times for different sources
  - `mapboxMap!.style.removeStyleSource()` - Called only if the sources exist

#### `_updateBusApproachLineForActiveTrip(Coordinate busPosition, Coordinate stopPosition)`

- **Input**:
  - `busPosition` (Coordinate)
  - `stopPosition` (Coordinate)
- **Functions it calls**:
  - `loadShapeGeometries()` - Called 100% of the time if `mapboxMap != null && _currentTrackedSegment != null`
  - `getFullShapeGeometry(_currentTrackedSegment!.shapeId)` - Called only if `_currentTrackedSegment!.shapeId != null`
  - `findClosestPointIndexOnShape()` - Called 2 times if there is full shape geometry
  - `getGeometrySegment()` - Called only if the indices are valid
  - `_tryUpdatePreviewApproachLine(geoJsonFeatureCollection)` - Called 100% of the time
  - `_updateOrCreateActiveTripApproachLine(geoJsonFeatureCollection)` - Called only if `!updatedPreviewLine`

#### `_tryUpdatePreviewApproachLine(Map<String, dynamic> geoJsonFeatureCollection)`

- **Input**:
  - `geoJsonFeatureCollection` (Map<String, dynamic>)
- **Functions it calls**:
  - `mapboxMap!.style.styleSourceExists(sourceId)` - Called for each sourceId in previewApproachSourceIds
  - `mapboxMap!.style.getSource(sourceId).updateGeoJSON()` - Called only if the source exists

#### `_updateOrCreateActiveTripApproachLine(Map<String, dynamic> geoJsonFeatureCollection)`

- **Input**:
  - `geoJsonFeatureCollection` (Map<String, dynamic>)
- **Functions it calls**:
  - `mapboxMap!.style.styleSourceExists()` - Called 100% of the time if `mapboxMap != null`
  - `mapboxMap!.style.getSource().updateGeoJSON()` - Called only if the source exists
  - `mapboxMap!.style.addSource()` - Called only if the source does not exist
  - `mapManager.registerSource()` - Called only if a new source is created
  - `mapboxMap!.style.addLayer()` - Called 2 times (shadow and main) only if a new source is created
  - `mapManager.registerLayer()` - Called 2 times only if new layers are created

#### `_startTooltipFloatingAnimation()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_stopTooltipFloatingAnimation()` - Called 100% of the time
  - `Timer.periodic()` with a callback that calls `mapboxMap!.style.styleLayerExists()` and `mapboxMap!.style.setStyleLayerProperty()` - Called 100% of the time

#### `_startTooltipFloatingAnimationPreview()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_stopTooltipFloatingAnimation()` - Called 100% of the time
  - `Timer.periodic()` with a callback that calls `mapboxMap!.style.styleLayerExists()` and `mapboxMap!.style.setStyleLayerProperty()` for multiple layers - Called 100% of the time

#### `_stopTooltipFloatingAnimation()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_tooltipFloatTimer?.cancel()` - Called 100% of the time
  - `mapboxMap!.style.styleLayerExists()` and `mapboxMap!.style.setStyleLayerProperty()` - Called to reset tooltip positions

#### `_tryUpdatePreviewBusElements(Coordinate position, int etaMinutes, bool isRealTime)`

- **Input**:
  - `position` (Coordinate)
  - `etaMinutes` (int)
  - `isRealTime` (bool)
- **Functions it calls**:
  - `mapboxMap!.style.styleSourceExists(sourceId)` - Called for each sourceId in previewBusSourceIds
  - `mapboxMap!.style.getSource(sourceId).updateGeoJSON()` - Called only if the source exists

#### `stopPreviewAnimations()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_stopTooltipFloatingAnimation()` - Called 100% of the time

#### `dispose()`

- **Input**: Receives no parameters
- **Functions it calls**:
  - `_stopBusTracking()` - Called 100% of the time
  - `_stopTooltipFloatingAnimation()` - Called 100% of the time

---

## Full Flow Summary

The trip flow involves a complex interaction between several layers of the application:

1. **UI Layer**: `route_options_overlay.dart` and `active_trip_overlay.dart` handle the user interface
2. **State Management**: `app_providers.dart` handles the application state
3. **Map Management**: `map_manager.dart`, `map_route_renderer.dart`, and `map_bus_realtime.dart` handle the map display
4. **Business Logic**: The backend providers handle the business logic

Each function is carefully documented with its inputs and the functions it calls, including the exact conditions under which those calls are made.

---
