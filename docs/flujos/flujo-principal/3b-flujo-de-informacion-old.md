# Flujo de Información Completo - Navegación de Usuario (9 Pasos)

## Paso 1: Usuario entra en la fase de opciones de viaje y ve la preview de la primera opción (con ETA)

### Acción del Usuario

El usuario llega a la pantalla de opciones de ruta después de hacer una búsqueda.

### Flujo de Información

**1. `RouteOptionsOverlay.initState()`**

- **Input:** Ninguno
- **Llama a:**
  - `super.initState()`: 100% de las veces. Input: Ninguno
  - `WidgetsBinding.instance.addPostFrameCallback(...)`: 100% de las veces. Input: Callback que llama a `_initializeCarousel()`

**2. `RouteOptionsOverlay._initializeCarousel()`**

- **Input:** Ninguno
- **Llama a:**
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `print`: 100% de las veces. Input: String
  - `_showInitialPreview()`: Si `routeOptionsState != null && routeOptionsState.opcionesDeRuta.isNotEmpty`. Input: Ninguno

**3. `RouteOptionsOverlay._showInitialPreview()`**

- **Input:** Ninguno
- **Llama a:**
  - `Future.delayed(Duration(milliseconds: 100)).then(...)`: Si `mounted` es true
    - `_showRoutePreview(_currentOptionIndex)`: Input: `_currentOptionIndex` (int)
  - `Future.delayed(Duration(milliseconds: 800)).then(...)`: Si `mounted` es true
    - `_showRoutePreview(_currentOptionIndex)`: Input: `_currentOptionIndex` (int)
  - `Future.delayed(Duration(milliseconds: 1500)).then(...)`: Si `mounted` es true
    - `_showRoutePreview(_currentOptionIndex)`: Input: `_currentOptionIndex` (int)
  - `print`: 100% de las veces. Input: String

**4. `RouteOptionsOverlay._showRoutePreview()`**

- **Input:** `optionIndex` (int) = 0 (primera opción)
- **Llama a:**
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `print`: 100% de las veces. Input: String
  - `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar(option.idOpcion)`: Si `routeOptionsState` no es null y `optionIndex` está en rango válido. Input: `option.idOpcion`
  - `_displayRoutePreview(option)`: Si `routeOptionsState` no es null y `optionIndex` está en rango válido. Input: `option` (OpcionDeRutaMostrable)

**5. `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar()`**

- **Input:** `idOpcionRuta` (String) = ID de la primera opción
- **Llama a:**
  - `state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhereOrNull(...)`: 100% de las veces si `state.datosFaseOpcionesRuta` no es null. Input: Callback `(opt) => opt.idOpcion == idOpcionRuta`
  - `todosLosPuntosDeLaRuta.addAll(...)`: Si `tramo.geometriaPolilinea` no es null (dentro de bucle). Input: `tramo.geometriaPolilinea`
  - `todosLosPuntosDeLaRuta.add(...)`: Si `tramo.posicionPunto` no es null (dentro de bucle). Input: `tramo.posicionPunto`
  - `state = state.copyWith(...)`: Si `mounted` es true y `todosLosPuntosDeLaRuta` no está vacío. Input: Parámetros nombrados para actualizar estado

**6. `RouteOptionsOverlay._displayRoutePreview()`**

- **Input:** `ruta` (OpcionDeRutaMostrable) = primera opción con ETA
- **Llama a:**
  - `print`: 100% de las veces. Input: String
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `MapManager.showRoutePreview(ruta)`: Si `mapManager` no es null (dentro de bloque `try`). Input: `ruta` (OpcionDeRutaMostrable)

**7. `MapManager.showRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = primera opción con ETA
- **Llama a:**
  - `initialize()`: Si `!_isInitialized`. Input: Ninguno
  - `print`: 100% de las veces. Input: String
  - `_cleanup.clearRoute()`: Si `_currentPreviewOptionId != route.idOpcion`. Input: Ninguno
  - `_routeRenderer.renderRoute(route.tramosParaPreview)`: Si `needsRedraw || _activeLayers.isEmpty`. Input: `route.tramosParaPreview`
  - `_busRealtime.displayRealtimeBusesForPreview(route)`: Si `needsRedraw || _activeLayers.isEmpty`. Input: `route`
  - `_cameraController.zoomToRoutePreview(route)`: 100% de las veces. Input: `route`

**8. `MapBusRealtime.displayRealtimeBusesForPreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = primera opción con ETA
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null. Input: String
  - `_addRealtimeBusToPreview(tramo, i)`: Para cada `tramo` en `route.tramosParaPreview` si `mapboxMap` no es null y `tramo.esTiempoRealBus` es true y `tramo.minutosEstimadosLlegadaBus` no es null y `tramo.minutosEstimadosLlegadaBus > 0`. Input: `tramo`, `i`

---

## Paso 2: Usuario cambia a la segunda opción (sin ETA)

### Acción del Usuario

El usuario desliza el carousel o toca para cambiar a la segunda opción de ruta.

### Flujo de Información

**9. `PageView.onPageChanged` callback en `RouteOptionsOverlay.build()`**

- **Input:** `index` (int) = 1 (segunda opción)
- **Llama a:**
  - `setState(...)`: 100% de las veces. Input: Callback que actualiza `_currentOptionIndex = index`
  - `_showRoutePreview(index)`: 100% de las veces. Input: `index` (int) = 1

**10. `RouteOptionsOverlay._showRoutePreview()`**

- **Input:** `optionIndex` (int) = 1 (segunda opción)
- **Llama a:**
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `print`: 100% de las veces. Input: String
  - `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar(option.idOpcion)`: Si `routeOptionsState` no es null y `optionIndex` está en rango válido. Input: `option.idOpcion` (ID de segunda opción)
  - `_displayRoutePreview(option)`: Si `routeOptionsState` no es null y `optionIndex` está en rango válido. Input: `option` (OpcionDeRutaMostrable de segunda opción)

**11. `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar()`**

- **Input:** `idOpcionRuta` (String) = ID de la segunda opción
- **Llama a:**
  - `state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhereOrNull(...)`: 100% de las veces si `state.datosFaseOpcionesRuta` no es null. Input: Callback `(opt) => opt.idOpcion == idOpcionRuta`
  - `todosLosPuntosDeLaRuta.addAll(...)`: Si `tramo.geometriaPolilinea` no es null (dentro de bucle). Input: `tramo.geometriaPolilinea`
  - `todosLosPuntosDeLaRuta.add(...)`: Si `tramo.posicionPunto` no es null (dentro de bucle). Input: `tramo.posicionPunto`
  - `state = state.copyWith(...)`: Si `mounted` es true y `todosLosPuntosDeLaRuta` no está vacío. Input: Parámetros nombrados para actualizar estado

**12. `RouteOptionsOverlay._displayRoutePreview()`**

- **Input:** `ruta` (OpcionDeRutaMostrable) = segunda opción sin ETA
- **Llama a:**
  - `print`: 100% de las veces. Input: String
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `MapManager.showRoutePreview(ruta)`: Si `mapManager` no es null (dentro de bloque `try`). Input: `ruta` (OpcionDeRutaMostrable)

**13. `MapManager.showRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = segunda opción sin ETA
- **Llama a:**
  - `initialize()`: Si `!_isInitialized`. Input: Ninguno
  - `print`: 100% de las veces. Input: String
  - `_cleanup.clearRoute()`: Si `_currentPreviewOptionId != route.idOpcion`. Input: Ninguno
  - `_routeRenderer.renderRoute(route.tramosParaPreview)`: Si `needsRedraw || _activeLayers.isEmpty`. Input: `route.tramosParaPreview`
  - `_busRealtime.displayRealtimeBusesForPreview(route)`: Si `needsRedraw || _activeLayers.isEmpty`. Input: `route`
  - `_cameraController.zoomToRoutePreview(route)`: 100% de las veces. Input: `route`

**14. `MapBusRealtime.displayRealtimeBusesForPreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = segunda opción sin ETA
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null. Input: String
  - `_addRealtimeBusToPreview(tramo, i)`: Para cada `tramo` en `route.tramosParaPreview` si `mapboxMap` no es null y `tramo.esTiempoRealBus` es true y `tramo.minutosEstimadosLlegadaBus` no es null y `tramo.minutosEstimadosLlegadaBus > 0`. Input: `tramo`, `i`
  - **Nota:** Como esta opción no tiene ETA, no se renderizarán buses en tiempo real.

---

## Paso 3: Usuario cambia a la tercera opción (con ETA)

### Acción del Usuario

El usuario desliza el carousel o toca para cambiar a la tercera opción de ruta.

### Flujo de Información

**15. `PageView.onPageChanged` callback en `RouteOptionsOverlay.build()`**

- **Input:** `index` (int) = 2 (tercera opción)
- **Llama a:**
  - `setState(...)`: 100% de las veces. Input: Callback que actualiza `_currentOptionIndex = index`
  - `_showRoutePreview(index)`: 100% de las veces. Input: `index` (int) = 2

**16. `RouteOptionsOverlay._showRoutePreview()`**

- **Input:** `optionIndex` (int) = 2 (tercera opción)
- **Llama a:**
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `print`: 100% de las veces. Input: String
  - `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar(option.idOpcion)`: Si `routeOptionsState` no es null y `optionIndex` está en rango válido. Input: `option.idOpcion` (ID de tercera opción)
  - `_displayRoutePreview(option)`: Si `routeOptionsState` no es null y `optionIndex` está en rango válido. Input: `option` (OpcionDeRutaMostrable de tercera opción)

**17. `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar()`**

- **Input:** `idOpcionRuta` (String) = ID de la tercera opción
- **Llama a:**
  - `state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhereOrNull(...)`: 100% de las veces si `state.datosFaseOpcionesRuta` no es null. Input: Callback `(opt) => opt.idOpcion == idOpcionRuta`
  - `todosLosPuntosDeLaRuta.addAll(...)`: Si `tramo.geometriaPolilinea` no es null (dentro de bucle). Input: `tramo.geometriaPolilinea`
  - `todosLosPuntosDeLaRuta.add(...)`: Si `tramo.posicionPunto` no es null (dentro de bucle). Input: `tramo.posicionPunto`
  - `state = state.copyWith(...)`: Si `mounted` es true y `todosLosPuntosDeLaRuta` no está vacío. Input: Parámetros nombrados para actualizar estado

**18. `RouteOptionsOverlay._displayRoutePreview()`**

- **Input:** `ruta` (OpcionDeRutaMostrable) = tercera opción con ETA
- **Llama a:**
  - `print`: 100% de las veces. Input: String
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `MapManager.showRoutePreview(ruta)`: Si `mapManager` no es null (dentro de bloque `try`). Input: `ruta` (OpcionDeRutaMostrable)

**19. `MapManager.showRoutePreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = tercera opción con ETA
- **Llama a:**
  - `initialize()`: Si `!_isInitialized`. Input: Ninguno
  - `print`: 100% de las veces. Input: String
  - `_cleanup.clearRoute()`: Si `_currentPreviewOptionId != route.idOpcion`. Input: Ninguno
  - `_routeRenderer.renderRoute(route.tramosParaPreview)`: Si `needsRedraw || _activeLayers.isEmpty`. Input: `route.tramosParaPreview`
  - `_busRealtime.displayRealtimeBusesForPreview(route)`: Si `needsRedraw || _activeLayers.isEmpty`. Input: `route`
  - `_cameraController.zoomToRoutePreview(route)`: 100% de las veces. Input: `route`

**20. `MapBusRealtime.displayRealtimeBusesForPreview()`**

- **Input:** `route` (OpcionDeRutaMostrable) = tercera opción con ETA
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null. Input: String
  - `_addRealtimeBusToPreview(tramo, i)`: Para cada `tramo` en `route.tramosParaPreview` si `mapboxMap` no es null y `tramo.esTiempoRealBus` es true y `tramo.minutosEstimadosLlegadaBus` no es null y `tramo.minutosEstimadosLlegadaBus > 0`. Input: `tramo`, `i`

---

## Paso 4: Usuario selecciona la tercera opción mostrada

### Acción del Usuario

El usuario presiona el botón "Iniciar Viaje" para confirmar la tercera opción de ruta.

### Flujo de Información

**21. `ElevatedButton.onPressed` callback en `RouteOptionsOverlay._buildFooter()`**

- **Input:** Ninguno (evento de presión del botón)
- **Llama a:**
  - `AppLogicNotifier.confirmarOpcionDeRutaEIniciarViaje(options[_currentOptionIndex].idOpcion)`: 100% de las veces. Input: `options[_currentOptionIndex].idOpcion` (ID de tercera opción)

**22. `AppLogicNotifier.confirmarOpcionDeRutaEIniciarViaje()`**

- **Input:** `idOpcionSeleccionada` (String) = ID de la tercera opción
- **Llama a:**
  - `print`: 100% de las veces. Input: String
  - `state.datosFaseOpcionesRuta!.opcionesDeRuta.firstWhere(...)`: Si `state.faseActual` es `FaseApp.MOSTRANDO_OPCIONES_RUTA` y `state.datosFaseOpcionesRuta` no es null y `state.idOpcionRutaPrevisualizada` coincide con `idOpcionSeleccionada` (dentro de bloque `try`). Input: Callback `(opt) => opt.idOpcion == idOpcionSeleccionada`
  - `print`: Si `opcionConfirmada` es null. Input: String
  - `state = state.copyWith(...)`: Si `opcionConfirmada` es null. Input: Parámetros nombrados para actualizar estado con error
  - `state = state.copyWith(...)`: Si `opcionConfirmada` no es null. Input: Parámetros nombrados para actualizar estado a fase de viaje activo
  - `print`: Si `opcionConfirmada` no es null. Input: String
  - `opcionConfirmada.tramosParaPreview.firstWhere(...)`: Si `opcionConfirmada` no es null. Input: Callback `(tramo) => tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS`, orElse callback
  - `iniciarSeguimientoBusTiempoReal(...)`: Si `primerTramoBus.idTramo` no es "placeholder_no_bus_tramo". Input: `idViajeActivo` (String), `idTramoBus` (String)

**23. `AppLogicNotifier.iniciarSeguimientoBusTiempoReal()`**

- **Input:** `idViajeActivo` (String) = ID de la opción confirmada, `idTramoBus` (String) = ID del primer tramo de bus
- **Llama a:**
  - `print`: Si las condiciones iniciales de fase y datos de viaje no se cumplen. Input: String
  - `print`: 100% de las veces si las condiciones iniciales se cumplen. Input: String
  - `_seguimientoBusTimer?.cancel()`: 100% de las veces si las condiciones iniciales se cumplen. Input: Ninguno
  - `state.datosFaseViajeActivo!.tramosDelViaje.firstWhere(...)`: Si las condiciones iniciales se cumplen. Input: Callback `(t) => t.idTramo == idTramoBus && t.tipo == TipoTramoViaje.VIAJE_EN_BUS`, orElse callback
  - `state = state.copyWith(...)`: 100% de las veces si las condiciones iniciales se cumplen y hay datos suficientes. Input: Parámetros nombrados para actualizar estado
  - `fetchEta()`: 100% de las veces al final de la función. Input: Ninguno
  - `Timer.periodic(...)`: Si `mounted` es true y el ID del tramo en seguimiento coincide. Input: Duration, callback `(_) => fetchEta()`

**24. Transición a Active Trip - Listener en `RouteOptionsOverlay.build()`**

- **Input:** `next` (EstadoFaseViajeActivo) - nuevo estado del viaje activo
- **Llama a:**
  - `print`: 100% de las veces dentro del listener. Input: String
  - **Nota:** El overlay de route options se cierra y se muestra el active trip overlay.

---

## Paso 5: Usuario en active trip está en el paso de caminar hasta la parada

### Acción del Usuario

El sistema automáticamente muestra el active trip overlay con el primer paso del viaje (caminar hasta la parada).

### Flujo de Información

**25. `ActiveTripOverlay.initState()`**

- **Input:** Ninguno
- **Llama a:**
  - `super.initState()`: 100% de las veces. Input: Ninguno
  - `WidgetsBinding.instance.addPostFrameCallback(...)`: 100% de las veces. Input: Callback que llama a `_initializeActiveTrip()`

**26. `ActiveTripOverlay._initializeActiveTrip()`**

- **Input:** Ninguno
- **Llama a:**
  - `print`: 100% de las veces. Input: String
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `print`: Si `mapManager` es null. Input: String
  - `ref.read(appLogicProvider)`: Si `mapManager` no es null. Input: `appLogicProvider`
  - `mapManager.showActiveTrip(activeTripState)`: Si `mapManager` no es null y `activeTripState` no es null y tiene tramos (dentro de bloque `try`). Input: `activeTripState`
  - `print`: Si `mapManager` no es null y `activeTripState` no es null y tiene tramos. Input: String
  - `mapManager.updateCurrentLeg(0, activeTripState.tramosDelViaje)`: Si `mapManager` no es null y `activeTripState` no es null y tiene tramos (dentro de bloque `try`). Input: `0` (primer paso), `activeTripState.tramosDelViaje`

**27. `MapManager.showActiveTrip()`**

- **Input:** `activeTripState` (EstadoFaseViajeActivo)
- **Llama a:**
  - `initialize()`: Si `!_isInitialized`. Input: Ninguno
  - `print`: 100% de las veces. Input: String
  - `_startActiveTripTracking(activeTripState)`: Si `isTransitionFromPreview` es true (viene del preview). Input: `activeTripState`
  - `_cleanup.clearAll()`: Si `isTransitionFromPreview` es false. Input: Ninguno
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)`: Si `isTransitionFromPreview` es false. Input: `activeTripState.tramosDelViaje`
  - `_busRealtime.initializeActiveTripTracking(activeTripState)`: Si `isTransitionFromPreview` es false. Input: `activeTripState`

**28. `MapManager._startActiveTripTracking()`**

- **Input:** `activeTripState` (EstadoFaseViajeActivo)
- **Llama a:**
  - `print`: 100% de las veces. Input: String
  - `_busRealtime.stopPreviewAnimations()`: 100% de las veces (dentro de bloque `try`). Input: Ninguno
  - `_busRealtime.initializeActiveTripTracking(activeTripState)`: 100% de las veces (dentro de bloque `try`). Input: `activeTripState`
  - `_cameraController.zoomToActiveTrip(activeTripState.tramosDelViaje)`: 100% de las veces (dentro de bloque `try`). Input: `activeTripState.tramosDelViaje`

**29. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 0, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: Si `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (0), `tramos`
  - `_cameraController.zoomToCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (0), `tramos`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (0), `tramos`

---

## Paso 6: Usuario presiona botón para pasar al siguiente paso (esperar bus en parada)

### Acción del Usuario

El usuario presiona el botón "Siguiente" en el navigation panel del active trip.

### Flujo de Información

**30. `InkWell.onPressed` callback en `ActiveTripOverlay._buildCompactNavButton()` (botón siguiente)**

- **Input:** Ninguno (evento de presión del botón)
- **Llama a:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% de las veces si `enabled` es true. Input: `_currentLegIndex + 1` (int) = 1

**31. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 1 (segundo paso - esperar bus)
- **Llama a:**
  - `setState(...)`: 100% de las veces. Input: Callback que actualiza `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: Si `mapManager` no es null y `activeTripState` no es null. Input: `legIndex` (1), `activeTripState.tramosDelViaje`
  - `print`: Si `mapManager` no es null y `activeTripState` no es null. Input: String

**32. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 1, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: Si `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (1), `tramos`
  - `_cameraController.zoomToCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (1), `tramos`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (1), `tramos`

**33. `MapBusRealtime.updateBusTrackingForLeg()`**

- **Input:** `legIndex` (int) = 1, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null. Input: String
  - `_stopBusTracking()`: 100% de las veces si `mapboxMap` no es null. Input: Ninguno
  - `_startBusTracking(nextBusSegment)`: Si `mapboxMap` no es null y se encuentra un `nextBusSegment` para trackear. Input: `nextBusSegment` (TramoViajeMostrable)

---

## Paso 7: Usuario presiona botón para pasar al siguiente paso (ir hasta parada de destino)

### Acción del Usuario

El usuario presiona el botón "Siguiente" en el navigation panel del active trip.

### Flujo de Información

**34. `InkWell.onPressed` callback en `ActiveTripOverlay._buildCompactNavButton()` (botón siguiente)**

- **Input:** Ninguno (evento de presión del botón)
- **Llama a:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% de las veces si `enabled` es true. Input: `_currentLegIndex + 1` (int) = 2

**35. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 2 (tercer paso - viaje en bus)
- **Llama a:**
  - `setState(...)`: 100% de las veces. Input: Callback que actualiza `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: Si `mapManager` no es null y `activeTripState` no es null. Input: `legIndex` (2), `activeTripState.tramosDelViaje`
  - `print`: Si `mapManager` no es null y `activeTripState` no es null. Input: String

**36. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 2, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: Si `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (2), `tramos`
  - `_cameraController.zoomToCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (2), `tramos`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (2), `tramos`

**37. `MapCameraController.zoomToCurrentLeg()`**

- **Input:** `legIndex` (int) = 2, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null y `legIndex` es válido. Input: String
  - `_addBusCoordinatesForWaitingLeg(tramos, legIndex, coordinatesForZoom)`: Si `mapboxMap` no es null, `legIndex` es válido y `tramo.tipo` es `TipoTramoViaje.ESPERAR_BUS` (dentro de bloque `try`). Input: `tramos`, `legIndex` (2), `coordinatesForZoom`
  - `_zoomToCoordinates(coordinatesForZoom, _getCurrentLegPadding())`: Si `mapboxMap` no es null, `legIndex` es válido, `coordinatesForZoom.length > 1` y no hay excepción (dentro de bloque `try`). Input: `coordinatesForZoom`, padding
  - `mapboxMap!.flyTo(...)`: Si `mapboxMap` no es null, `legIndex` es válido, `coordinatesForZoom.length == 1` y no hay excepción (dentro de bloque `try`). Input: `CameraOptions`, `MapAnimationOptions`

---

## Paso 8: Usuario presiona botón para pasar al siguiente paso (esperar segundo bus)

### Acción del Usuario

El usuario presiona el botón "Siguiente" en el navigation panel del active trip.

### Flujo de Información

**38. `InkWell.onPressed` callback en `ActiveTripOverlay._buildCompactNavButton()` (botón siguiente)**

- **Input:** Ninguno (evento de presión del botón)
- **Llama a:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% de las veces si `enabled` es true. Input: `_currentLegIndex + 1` (int) = 3

**39. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 3 (cuarto paso - esperar segundo bus)
- **Llama a:**
  - `setState(...)`: 100% de las veces. Input: Callback que actualiza `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: Si `mapManager` no es null y `activeTripState` no es null. Input: `legIndex` (3), `activeTripState.tramosDelViaje`
  - `print`: Si `mapManager` no es null y `activeTripState` no es null. Input: String

**40. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 3, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: Si `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (3), `tramos`
  - `_cameraController.zoomToCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (3), `tramos`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (3), `tramos`

**41. `MapBusRealtime.updateBusTrackingForLeg()`**

- **Input:** `legIndex` (int) = 3, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null. Input: String
  - `_stopBusTracking()`: 100% de las veces si `mapboxMap` no es null. Input: Ninguno
  - `_startBusTracking(nextBusSegment)`: Si `mapboxMap` no es null y se encuentra un `nextBusSegment` para trackear (usando `_findNextBusSegment`). Input: `nextBusSegment` (segundo tramo de bus)

**42. `MapBusRealtime._findNextBusSegment()`**

- **Input:** `tramos` (List<TramoViajeMostrable>), `currentLegIndex` (int) = 3
- **Llama a:**
  - `print`: Condicionalmente para propósitos de depuración. Input: String
  - **Nota:** Busca el siguiente tramo de tipo `VIAJE_EN_BUS` después del índice actual.

---

## Paso 9: Usuario presiona botón para pasar al siguiente paso (caminar hasta destino)

### Acción del Usuario

El usuario presiona el botón "Siguiente" en el navigation panel del active trip para ir al paso final.

### Flujo de Información

**43. `InkWell.onPressed` callback en `ActiveTripOverlay._buildCompactNavButton()` (botón siguiente)**

- **Input:** Ninguno (evento de presión del botón)
- **Llama a:**
  - `_onLegSelected(_currentLegIndex + 1)`: 100% de las veces si `enabled` es true. Input: `_currentLegIndex + 1` (int) = 4

**44. `ActiveTripOverlay._onLegSelected()`**

- **Input:** `legIndex` (int) = 4 (quinto paso - caminar hasta destino)
- **Llama a:**
  - `setState(...)`: 100% de las veces. Input: Callback que actualiza `_currentLegIndex = legIndex`
  - `ref.read(mapManagerProvider)`: 100% de las veces. Input: `mapManagerProvider`
  - `ref.read(appLogicProvider)`: 100% de las veces. Input: `appLogicProvider`
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: Si `mapManager` no es null y `activeTripState` no es null. Input: `legIndex` (4), `activeTripState.tramosDelViaje`
  - `print`: Si `mapManager` no es null y `activeTripState` no es null. Input: String

**45. `MapManager.updateCurrentLeg()`**

- **Input:** `legIndex` (int) = 4, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: Si `_currentPhase == 'active_trip'`. Input: String
  - `_routeRenderer.highlightCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (4), `tramos`
  - `_cameraController.zoomToCurrentLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (4), `tramos`
  - `_busRealtime.updateBusTrackingForLeg(legIndex, tramos)`: Si `_currentPhase == 'active_trip'`. Input: `legIndex` (4), `tramos`

**46. `MapBusRealtime.updateBusTrackingForLeg()`**

- **Input:** `legIndex` (int) = 4, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null. Input: String
  - `_stopBusTracking()`: 100% de las veces si `mapboxMap` no es null. Input: Ninguno
  - `_startBusTracking(nextBusSegment)`: Si `mapboxMap` no es null y se encuentra un `nextBusSegment` para trackear. Input: `nextBusSegment`
  - **Nota:** Como este es el último paso (caminar al destino), no habrá más tramos de bus para trackear.

**47. `MapCameraController.zoomToCurrentLeg()`**

- **Input:** `legIndex` (int) = 4, `tramos` (List<TramoViajeMostrable>)
- **Llama a:**
  - `print`: 100% de las veces si `mapboxMap` no es null y `legIndex` es válido. Input: String
  - `_zoomToCoordinates(coordinatesForZoom, _getCurrentLegPadding())`: Si `mapboxMap` no es null, `legIndex` es válido, `coordinatesForZoom.length > 1` y no hay excepción (dentro de bloque `try`). Input: `coordinatesForZoom` (coordenadas del último tramo de caminata), padding
  - `mapboxMap!.flyTo(...)`: Si `mapboxMap` no es null, `legIndex` es válido, `coordinatesForZoom.length == 1` y no hay excepción (dentro de bloque `try`). Input: `CameraOptions`, `MapAnimationOptions`

---

## Resumen del Flujo Completo

### Componentes Principales Involucrados

1. **RouteOptionsOverlay** - Maneja la selección de opciones de ruta (pasos 1-4)
2. **ActiveTripOverlay** - Maneja la navegación del viaje activo (pasos 5-9)
3. **AppLogicNotifier** - Coordina el estado global de la aplicación
4. **MapManager** - Orquesta todas las operaciones del mapa
5. **MapBusRealtime** - Gestiona la visualización de buses en tiempo real
6. **MapCameraController** - Controla el zoom y posicionamiento de la cámara
7. **MapRouteRenderer** - Renderiza las rutas en el mapa

### Patrón de Flujo

Cada acción del usuario sigue un patrón consistente:

**UI Component → State Notifier → Map Manager → Specialized Map Components**

1. El componente de UI detecta la acción del usuario
2. Actualiza el estado a través del AppLogicNotifier
3. El MapManager coordina la respuesta visual
4. Los componentes especializados (BusRealtime, CameraController, RouteRenderer) ejecutan las operaciones específicas

Este flujo asegura una separación clara de responsabilidades y permite que el sistema responda de manera coherente a cada interacción del usuario.
