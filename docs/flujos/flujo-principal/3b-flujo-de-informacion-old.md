# Complete Information Flow - User Navigation (9 Steps)

## Step 1: User enters the trip options phase and sees the preview of the first option (with ETA)

### User Action

The user arrives at the route options screen after performing a search.

### Information Flow

**1. `RouteOptionsOverlay.initState()`**

- **Input:** None
- **Calls:**
  - `super.initState()`: 100% of the time. Input: None
  - `WidgetsBinding.instance.addPostFrameCallback(...)`: 100% of the time. Input: Callback that calls `_initializeCarousel()`

**2. `RouteOptionsOverlay._initializeCarousel()`**

- **Input:** None
- **Calls:**
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `print`: 100% of the time. Input: String
  - `_showInitialPreview()`: If `routeOptionsState != null && routeOptionsState.opcionesDeRuta.isNotEmpty`. Input: None

**3. `RouteOptionsOverlay._showInitialPreview()`**

- **Input:** None
- **Calls:**
  - `Future.delayed(Duration(milliseconds: 100)).then(...)`: If `mounted` is true
    - `_showRoutePreview(_currentOptionIndex)`: Input: `_currentOptionIndex` (int)
  - `Future.delayed(Duration(milliseconds: 800)).then(...)`: If `mounted` is true
    - `_showRoutePreview(_currentOptionIndex)`: Input: `_currentOptionIndex` (int)
  - `Future.delayed(Duration(milliseconds: 1500)).then(...)`: If `mounted` is true
    - `_showRoutePreview(_currentOptionIndex)`: Input: `_currentOptionIndex` (int)
  - `print`: 100% of the time. Input: String

**4. `RouteOptionsOverlay._showRoutePreview()`**

- **Input:** `optionIndex` (int) = 0 (first option)
- **Calls:**
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `print`: 100% of the time. Input: String
  - `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar(option.idOption)`: If `routeOptionsState` is not null and `optionIndex` is in a valid range. Input: `option.idOption`
  - `_displayRoutePreview(option)`: If `routeOptionsState` is not null and `optionIndex` is in a valid range. Input: `option` (OpcionDeRutaMostrable)

**5. `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar()`**

- **Input:** `idOpcionRuta` (String) = ID of the first option
- **Calls:**
  - `state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhereOrNull(...)`: 100% of the time if `state.datosFaseOpcionesRuta` is not null. Input: Callback `(opt) => opt.idOption == idOpcionRuta`
  - `todosLosPuntosDeLaRuta.addAll(...)`: If `leg.geometryPolyline` is not null (inside loop). Input: `leg.geometryPolyline`
  - `todosLosPuntosDeLaRuta.add(...)`: If `leg.positionPunto` is not null (inside loop). Input: `leg.positionPunto`
  - `state = state.copyWith(...)`: If `mounted` is true and `todosLosPuntosDeLaRuta` is not empty. Input: Named parameters to update the state

**6. `RouteOptionsOverlay._displayRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = first option with ETA
- **Calls:**
  - `print`: 100% of the time. Input: String
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `MapManager.showRoutePreview(route)`: If `mapManager` is not null (inside `try` block). Input: `route` (OpcionDeRutaMostrable)

**7. `MapManager.showRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = first option with ETA
- **Calls:**
  - `initialize()`: If `!_isInitialized`. Input: None
  - `print`: 100% of the time. Input: String
  - `_cleanup.clearRoute()`: If `_currentPreviewOptionId != route.idOption`. Input: None
  - `_routeRenderer.renderRoute(route.tramosParaPreview)`: If `needsRedraw || _activeLayers.isEmpty`. Input: `route.tramosParaPreview`
  - `_busRealtime.displayRealtimeBusesForPreview(route)`: If `needsRedraw || _activeLayers.isEmpty`. Input: `route`
  - `_cameraController.zoomToRoutePreview(route)`: 100% of the time. Input: `route`

**8. `MapBusRealtime.displayRealtimeBusesForPreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = first option with ETA
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null. Input: String
  - `_addRealtimeBusToPreview(leg, i)`: For each `leg` in `route.tramosParaPreview` if `mapboxMap` is not null and `leg.esTiempoRealBus` is true and `leg.minutosEstimadosLlegadaBus` is not null and `leg.minutosEstimadosLlegadaBus > 0`. Input: `leg`, `i`

---

## Step 2: User switches to the second option (no ETA)

### User Action

The user swipes the carousel or taps to switch to the second route option.

### Information Flow

**9. `PageView.onPageChanged` callback in `RouteOptionsOverlay.build()`**

- **Input:** `index` (int) = 1 (second option)
- **Calls:**
  - `setState(...)`: 100% of the time. Input: Callback that updates `_currentOptionIndex = index`
  - `_showRoutePreview(index)`: 100% of the time. Input: `index` (int) = 1

**10. `RouteOptionsOverlay._showRoutePreview()`**

- **Input:** `optionIndex` (int) = 1 (second option)
- **Calls:**
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `print`: 100% of the time. Input: String
  - `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar(option.idOption)`: If `routeOptionsState` is not null and `optionIndex` is in a valid range. Input: `option.idOption` (ID of second option)
  - `_displayRoutePreview(option)`: If `routeOptionsState` is not null and `optionIndex` is in a valid range. Input: `option` (OpcionDeRutaMostrable of second option)

**11. `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar()`**

- **Input:** `idOpcionRuta` (String) = ID of the second option
- **Calls:**
  - `state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhereOrNull(...)`: 100% of the time if `state.datosFaseOpcionesRuta` is not null. Input: Callback `(opt) => opt.idOption == idOpcionRuta`
  - `todosLosPuntosDeLaRuta.addAll(...)`: If `leg.geometryPolyline` is not null (inside loop). Input: `leg.geometryPolyline`
  - `todosLosPuntosDeLaRuta.add(...)`: If `leg.positionPunto` is not null (inside loop). Input: `leg.positionPunto`
  - `state = state.copyWith(...)`: If `mounted` is true and `todosLosPuntosDeLaRuta` is not empty. Input: Named parameters to update the state

**12. `RouteOptionsOverlay._displayRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = second option without ETA
- **Calls:**
  - `print`: 100% of the time. Input: String
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `MapManager.showRoutePreview(route)`: If `mapManager` is not null (inside `try` block). Input: `route` (OpcionDeRutaMostrable)

**13. `MapManager.showRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = second option without ETA
- **Calls:**
  - `initialize()`: If `!_isInitialized`. Input: None
  - `print`: 100% of the time. Input: String
  - `_cleanup.clearRoute()`: If `_currentPreviewOptionId != route.idOption`. Input: None
  - `_routeRenderer.renderRoute(route.tramosParaPreview)`: If `needsRedraw || _activeLayers.isEmpty`. Input: `route.tramosParaPreview`
  - `_busRealtime.displayRealtimeBusesForPreview(route)`: If `needsRedraw || _activeLayers.isEmpty`. Input: `route`
  - `_cameraController.zoomToRoutePreview(route)`: 100% of the time. Input: `route`

**14. `MapBusRealtime.displayRealtimeBusesForPreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = second option without ETA
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null. Input: String
  - `_addRealtimeBusToPreview(leg, i)`: For each `leg` in `route.tramosParaPreview` if `mapboxMap` is not null and `leg.esTiempoRealBus` is true and `leg.minutosEstimadosLlegadaBus` is not null and `leg.minutosEstimadosLlegadaBus > 0`. Input: `leg`, `i`
  - **Note:** Since this option has no ETA, no real-time buses will be rendered.

---

## Step 3: User switches to the third option (with ETA)

### User Action

The user swipes the carousel or taps to switch to the third route option.

### Information Flow

**15. `PageView.onPageChanged` callback in `RouteOptionsOverlay.build()`**

- **Input:** `index` (int) = 2 (third option)
- **Calls:**
  - `setState(...)`: 100% of the time. Input: Callback that updates `_currentOptionIndex = index`
  - `_showRoutePreview(index)`: 100% of the time. Input: `index` (int) = 2

**16. `RouteOptionsOverlay._showRoutePreview()`**

- **Input:** `optionIndex` (int) = 2 (third option)
- **Calls:**
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `print`: 100% of the time. Input: String
  - `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar(option.idOption)`: If `routeOptionsState` is not null and `optionIndex` is in a valid range. Input: `option.idOption` (ID of third option)
  - `_displayRoutePreview(option)`: If `routeOptionsState` is not null and `optionIndex` is in a valid range. Input: `option` (OpcionDeRutaMostrable of third option)

**17. `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar()`**

- **Input:** `idOpcionRuta` (String) = ID of the third option
- **Calls:**
  - `state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhereOrNull(...)`: 100% of the time if `state.datosFaseOpcionesRuta` is not null. Input: Callback `(opt) => opt.idOption == idOpcionRuta`
  - `todosLosPuntosDeLaRuta.addAll(...)`: If `leg.geometryPolyline` is not null (inside loop). Input: `leg.geometryPolyline`
  - `todosLosPuntosDeLaRuta.add(...)`: If `leg.positionPunto` is not null (inside loop). Input: `leg.positionPunto`
  - `state = state.copyWith(...)`: If `mounted` is true and `todosLosPuntosDeLaRuta` is not empty. Input: Named parameters to update the state

**18. `RouteOptionsOverlay._displayRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = third option with ETA
- **Calls:**
  - `print`: 100% of the time. Input: String
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `MapManager.showRoutePreview(route)`: If `mapManager` is not null (inside `try` block). Input: `route` (OpcionDeRutaMostrable)

**19. `MapManager.showRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = third option with ETA
- **Calls:**
  - `initialize()`: If `!_isInitialized`. Input: None
  - `print`: 100% of the time. Input: String
  - `_cleanup.clearRoute()`: If `_currentPreviewOptionId != route.idOption`. Input: None
  - `_routeRenderer.renderRoute(route.tramosParaPreview)`: If `needsRedraw || _activeLayers.isEmpty`. Input: `route.tramosParaPreview`
  - `_busRealtime.displayRealtimeBusesForPreview(route)`: If `needsRedraw || _activeLayers.isEmpty`. Input: `route`
  - `_cameraController.zoomToRoutePreview(route)`: 100% of the time. Input: `route`

**20. `MapBusRealtime.displayRealtimeBusesForPreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = third option with ETA
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null. Input: String
  - `_addRealtimeBusToPreview(leg, i)`: For each `leg` in `route.tramosParaPreview` if `mapboxMap` is not null and `leg.esTiempoRealBus` is true and `leg.minutosEstimadosLlegadaBus` is not null and `leg.minutosEstimadosLlegadaBus > 0`. Input: `leg`, `i`

---

## Step 4: User selects the third option shown

### User Action

The user presses the "Start Trip" button to confirm the third route option.

### Information Flow

**21. `ElevatedButton.onPressed` callback in `RouteOptionsOverlay._buildFooter()`**

- **Input:** None (button press event)
- **Calls:**
  - `AppLogicNotifier.confirmarOpcionDeRutaEIniciarViaje(options[_currentOptionIndex].idOption)`: 100% of the time. Input: `options[_currentOptionIndex].idOption` (ID of third option)

**22. `AppLogicNotifier.confirmarOpcionDeRutaEIniciarViaje()`**

- **Input:** `idOpcionSeleccionada` (String) = ID of the third option
- **Calls:**
  - `print`: 100% of the time. Input: String
  - `state.datosFaseOpcionesRuta!.opcionesDeRuta.firstWhere(...)`: If `state.faseActual` is `FaseApp.MOSTRANDO_OPCIONES_RUTA` and `state.datosFaseOpcionesRuta` is not null and `state.idOpcionRutaPrevisualizada` matches `idOpcionSeleccionada` (inside `try` block). Input: Callback `(opt) => opt.idOption == idOpcionSeleccionada`
  - `print`: If `opcionConfirmada` is null. Input: String
  - `state = state.copyWith(...)`: If `opcionConfirmada` is null. Input: Named parameters to update the state with the error
  - `state = state.copyWith(...)`: If `opcionConfirmada` is not null. Input: Named parameters to update the state to the active trip phase
  - `print`: If `opcionConfirmada` is not null. Input: String
  - `opcionConfirmada.tramosParaPreview.firstWhere(...)`: If `opcionConfirmada` is not null. Input: Callback `(leg) => leg.type == TypeLegTrip.VIAJE_EN_BUS`, orElse callback
  - `iniciarSeguimientoBusTiempoReal(...)`: If `primerTramoBus.idLeg` is not "placeholder_no_bus_tramo". Input: `idViajeActivo` (String), `idTramoBus` (String)

**23. `AppLogicNotifier.iniciarSeguimientoBusTiempoReal()`**

- **Input:** `idViajeActivo` (String) = ID of the confirmed option, `idTramoBus` (String) = ID of the first bus leg
- **Calls:**
  - `print`: If the initial phase and trip data conditions are not met. Input: String
  - `print`: 100% of the time if the initial conditions are met. Input: String
  - `_seguimientoBusTimer?.cancel()`: 100% of the time if the initial conditions are met. Input: None
  - `state.datosFaseViajeActivo!.tramosDelViaje.firstWhere(...)`: If the initial conditions are met. Input: Callback `(t) => t.idLeg == idTramoBus && t.type == TypeLegTrip.VIAJE_EN_BUS`, orElse callback
  - `state = state.copyWith(...)`: 100% of the time if the initial conditions are met and there is enough data. Input: Named parameters to update the state
  - `fetchEta()`: 100% of the time at the end of the function. Input: None
  - `Timer.periodic(...)`: If `mounted` is true and the ID of the tracked leg matches. Input: Duration, callback `(_) => fetchEta()`

**24. Transition to Active Trip - Listener in `RouteOptionsOverlay.build()`**

- **Input:** `next` (EstadoFaseViajeActivo) - new active trip state
- **Calls:**
  - `print`: 100% of the time inside the listener. Input: String
  - **Note:** The route options overlay closes and the active trip overlay is shown.

---

## Step 5: User in active trip is in the walk-to-stop step

### User Action

The system automatically shows the active trip overlay with the first step of the trip (walk to the stop).

### Information Flow

**25. `ActiveTripOverlay.initState()`**

- **Input:** None
- **Calls:**
  - `super.initState()`: 100% of the time. Input: None
  - `WidgetsBinding.instance.addPostFrameCallback(...)`: 100% of the time. Input: Callback that calls `_initializeActiveTrip()`

**26. `ActiveTripOverlay._initializeActiveTrip()`**

- **Input:** None
- **Calls:**
  - `print`: 100% of the time. Input: String
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `print`: If `mapManager` is null. Input: String
  - `ref.read(appLogicProvider)`: If `mapManager` is not null. Input: `appLogicProvider`
  - `mapManager.showActiveTrip(activeTripState)`: If `mapManager` is not null and `activeTripState` is not null and has legs (inside `try` block). Input: `activeTripState`
  - `print`: If `mapManager` is not null and `activeTripState` is not null and has legs. Input: String
  - `mapManager.updateCurrentLeg(0, activeTripState.tramosDelViaje)`: If `mapManager` is not null and `activeTripState` is not null and has legs (inside `try` block). Input: `0` (first step), `activeTripState.tramosDelViaje`

**27. `MapManager.showActiveTrip()`**

- **Input:** `activeTripState` (EstadoFaseViajeActivo)
- **Calls:**
  - `initialize()`: If `!_isInitialized`. Input: None
  - `print`: 100% of the time. Input: String
  - `_startActiveTripTracking(activeTripState)`: If `isTransitionFromPreview` is true (coming from the preview). Input: `activeTripState`
  - `_cleanup.clearAll()`: If `isTransitionFromPreview` is false. Input: None
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)`: If `isTransitionFromPreview` is false. Input: `activeTripState.tramosDelViaje`
  - `_busRealtime.initializeActiveTripTracking(activeTripState)`: If `isTransitionFromPreview` is false. Input: `activeTripState`

**28. `MapManager._startActiveTripTracking()`**

- **Input:** `activeTripState` (EstadoFaseViajeActivo)
- **Calls:**
  - `print`: 100% of the time. Input: String
  - `_busRealtime.stopPreviewAnimations()`: 100% of the time (inside `try` block). Input: None
  - `_busRealtime.initializeActiveTripTracking(activeTripState)`: 100% of the time (inside `try` block). Input: `activeTripState`
  - `_cameraController.zoomToActiveTrip(activeTripState.tramosDelViaje)`: 100% of the time (inside `try` block). Input: `activeTripState.tramosDelViaje`

**29. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 0, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: If `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (0), `legs`
  - `_cameraController.zoomToCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (0), `legs`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (0), `legs`

---

## Step 6: User presses the button to go to the next step (wait for bus at stop)

### User Action

The user presses the "Next" button in the active trip navigation panel.

### Information Flow

**30. `InkWell.onPressed` callback in `ActiveTripOverlay._buildCompactNavButton()` (next button)**

- **Input:** None (button press event)
- **Calls:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% of the time if `enabled` is true. Input: `_currentLegIndex + 1` (int) = 1

**31. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 1 (second step - wait for bus)
- **Calls:**
  - `setState(...)`: 100% of the time. Input: Callback that updates `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: If `mapManager` is not null and `activeTripState` is not null. Input: `legIndex` (1), `activeTripState.tramosDelViaje`
  - `print`: If `mapManager` is not null and `activeTripState` is not null. Input: String

**32. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 1, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: If `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (1), `legs`
  - `_cameraController.zoomToCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (1), `legs`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (1), `legs`

**33. `MapBusRealtime.updateBusTrackingForLeg()`**

- **Input:** `legIndex` (int) = 1, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null. Input: String
  - `_stopBusTracking()`: 100% of the time if `mapboxMap` is not null. Input: None
  - `_startBusTracking(nextBusSegment)`: If `mapboxMap` is not null and a `nextBusSegment` to track is found. Input: `nextBusSegment` (LegTripDisplayable)

---

## Step 7: User presses the button to go to the next step (go to destination stop)

### User Action

The user presses the "Next" button in the active trip navigation panel.

### Information Flow

**34. `InkWell.onPressed` callback in `ActiveTripOverlay._buildCompactNavButton()` (next button)**

- **Input:** None (button press event)
- **Calls:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% of the time if `enabled` is true. Input: `_currentLegIndex + 1` (int) = 2

**35. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 2 (third step - bus ride)
- **Calls:**
  - `setState(...)`: 100% of the time. Input: Callback that updates `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: If `mapManager` is not null and `activeTripState` is not null. Input: `legIndex` (2), `activeTripState.tramosDelViaje`
  - `print`: If `mapManager` is not null and `activeTripState` is not null. Input: String

**36. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 2, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: If `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (2), `legs`
  - `_cameraController.zoomToCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (2), `legs`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (2), `legs`

**37. `MapCameraController.zoomToCurrentLeg()`**

- **Input:** `legIndex` (int) = 2, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null and `legIndex` is valid. Input: String
  - `_addBusCoordinatesForWaitingLeg(legs, legIndex, coordinatesForZoom)`: If `mapboxMap` is not null, `legIndex` is valid and `leg.type` is `TypeLegTrip.ESPERAR_BUS` (inside `try` block). Input: `legs`, `legIndex` (2), `coordinatesForZoom`
  - `_zoomToCoordinates(coordinatesForZoom, _getCurrentLegPadding())`: If `mapboxMap` is not null, `legIndex` is valid, `coordinatesForZoom.length > 1` and there is no exception (inside `try` block). Input: `coordinatesForZoom`, padding
  - `mapboxMap!.flyTo(...)`: If `mapboxMap` is not null, `legIndex` is valid, `coordinatesForZoom.length == 1` and there is no exception (inside `try` block). Input: `CameraOptions`, `MapAnimationOptions`

---

## Step 8: User presses the button to go to the next step (wait for second bus)

### User Action

The user presses the "Next" button in the active trip navigation panel.

### Information Flow

**38. `InkWell.onPressed` callback in `ActiveTripOverlay._buildCompactNavButton()` (next button)**

- **Input:** None (button press event)
- **Calls:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% of the time if `enabled` is true. Input: `_currentLegIndex + 1` (int) = 3

**39. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 3 (fourth step - wait for second bus)
- **Calls:**
  - `setState(...)`: 100% of the time. Input: Callback that updates `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: If `mapManager` is not null and `activeTripState` is not null. Input: `legIndex` (3), `activeTripState.tramosDelViaje`
  - `print`: If `mapManager` is not null and `activeTripState` is not null. Input: String

**40. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 3, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: If `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (3), `legs`
  - `_cameraController.zoomToCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (3), `legs`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (3), `legs`

**41. `MapBusRealtime.updateBusTrackingForLeg()`**

- **Input:** `legIndex` (int) = 3, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null. Input: String
  - `_stopBusTracking()`: 100% of the time if `mapboxMap` is not null. Input: None
  - `_startBusTracking(nextBusSegment)`: If `mapboxMap` is not null and a `nextBusSegment` to track is found (using `_findNextBusSegment`). Input: `nextBusSegment` (second bus leg)

**42. `MapBusRealtime._findNextBusSegment()`**

- **Input:** `legs` (List<LegTripDisplayable>), `currentLegIndex` (int) = 3
- **Calls:**
  - `print`: Conditionally, for debugging purposes. Input: String
  - **Note:** Looks for the next leg of type `VIAJE_EN_BUS` after the current index.

---

## Step 9: User presses the button to go to the next step (walk to destination)

### User Action

The user presses the "Next" button in the active trip navigation panel to go to the final step.

### Information Flow

**43. `InkWell.onPressed` callback in `ActiveTripOverlay._buildCompactNavButton()` (next button)**

- **Input:** None (button press event)
- **Calls:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% of the time if `enabled` is true. Input: `_currentLegIndex + 1` (int) = 4

**44. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 4 (fifth step - walk to destination)
- **Calls:**
  - `setState(...)`: 100% of the time. Input: Callback that updates `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% of the time. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% of the time. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: If `mapManager` is not null and `activeTripState` is not null. Input: `legIndex` (4), `activeTripState.tramosDelViaje`
  - `print`: If `mapManager` is not null and `activeTripState` is not null. Input: String

**45. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 4, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: If `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (4), `legs`
  - `_cameraController.zoomToCurrentLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (4), `legs`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, legs)`: If `_currentPhase == 'active_trip'`. Input: `legIndex` (4), `legs`

**46. `MapBusRealtime.updateBusTrackingForLeg()`**

- **Input:** `legIndex` (int) = 4, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null. Input: String
  - `_stopBusTracking()`: 100% of the time if `mapboxMap` is not null. Input: None
  - `_startBusTracking(nextBusSegment)`: If `mapboxMap` is not null and a `nextBusSegment` to track is found. Input: `nextBusSegment`
  - **Note:** Since this is the last step (walk to destination), there will be no more bus legs to track.

**47. `MapCameraController.zoomToCurrentLeg()`**

- **Input:** `legIndex` (int) = 4, `legs` (List<LegTripDisplayable>)
- **Calls:**
  - `print`: 100% of the time if `mapboxMap` is not null and `legIndex` is valid. Input: String
  - `_zoomToCoordinates(coordinatesForZoom, _getCurrentLegPadding())`: If `mapboxMap` is not null, `legIndex` is valid, `coordinatesForZoom.length > 1` and there is no exception (inside `try` block). Input: `coordinatesForZoom` (coordinates of the last walk leg), padding
  - `mapboxMap!.flyTo(...)`: If `mapboxMap` is not null, `legIndex` is valid, `coordinatesForZoom.length == 1` and there is no exception (inside `try` block). Input: `CameraOptions`, `MapAnimationOptions`

---

## Complete Flow Summary

### Main Components Involved

1. **RouteOptionsOverlay** - Handles route option selection (steps 1-4)
2. **ActiveTripOverlay** - Handles active trip navigation (steps 5-9)
3. **AppLogicNotifier** - Coordinates the global application state
4. **MapManager** - Orchestrates all map operations
5. **MapBusRealtime** - Manages real-time bus display
6. **MapCameraController** - Controls zoom and camera positioning
7. **MapRouteRenderer** - Renders the routes on the map

### Flow Pattern

Every user action follows a consistent pattern:

**UI Component → State Notifier → Map Manager → Specialized Map Components**

1. The UI component detects the user action
2. It updates the state through the AppLogicNotifier
3. The MapManager coordinates the visual response
4. The specialized components (BusRealtime, CameraController, RouteRenderer) execute the specific operations

This flow ensures a clear separation of responsibilities and allows the system to respond coherently to each user interaction.
