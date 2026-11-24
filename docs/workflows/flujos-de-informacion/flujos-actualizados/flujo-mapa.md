# Map Drawing Functions (Unified for Preview and Active Trip)

This document details the functions identified in the `lib/ui` and `lib/map_manager` modules that are responsible for drawing elements on the map. After the unification, the methods now work both for the route preview phase and for the active trip phase.

## `lib/map_manager/map_route_renderer.dart`

### renderRoute

- Function name
  renderRoute
- Input this function receives (each parameter and its types)
  legs: List<LegTripDisplayable>
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_drawWalkSegment:
    - Input: leg (LegTripDisplayable), i (int)
    - Condition: Called if `leg.type` is `TypeLegTrip.CAMINAR`. This condition is evaluated inside a loop that iterates over `legs`.
  - \_drawBusSegment:
    - Input: leg (LegTripDisplayable), i (int)
    - Condition: Called if `leg.type` is `TypeLegTrip.VIAJE_EN_BUS`. This condition is evaluated inside a loop that iterates over `legs`.
  - \_drawWaitPoint:
    - Input: leg (LegTripDisplayable), i (int)
    - Condition: Called if `leg.type` is `TypeLegTrip.ESPERAR_BUS`. This condition is evaluated inside a loop that iterates over `legs`.
  - \_addBusStopsForSegment:
    - Input: leg (LegTripDisplayable), i (int)
    - Condition: Called if `leg.type` is `TypeLegTrip.VIAJE_EN_BUS`. This condition is evaluated inside a second loop that iterates over `legs`.
  - \_startArrowAnimation:
    - Input: None
    - Condition: Called 100% of the time after the loops, if `mapboxMap` is not null.

### highlightCurrentLeg

- Function name
  highlightCurrentLeg
- Input this function receives (each parameter and its types)
  legIndex: int
  legs: List<LegTripDisplayable>
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - mapboxMap!.style.styleLayerExists:
    - Input: layerId (String)
    - Condition: Called inside a loop that iterates over `legs`. The call happens only if `mapboxMap` is not null.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: layerId (String), 'line-width' (String), lineWidth (double) OR layerId (String), 'circle-radius' (String), circleRadius (double)
    - Condition: Called inside a loop that iterates over `legs`, and only if `mapboxMap` is not null and `mapboxMap!.style.styleLayerExists(layerId)` returns `true`. In addition, the property to modify (`line-width` or `circle-radius`) depends on `leg.type`. If `leg.type` is `TypeLegTrip.CAMINAR` or `TypeLegTrip.VIAJE_EN_BUS`, it attempts to modify `'line-width'` if `lineWidth` is not null. If `leg.type` is `TypeLegTrip.ESPERAR_BUS`, it attempts to modify `'circle-radius'` if `circleRadius` is not null.

### \_drawWalkSegment

- Function name
  \_drawWalkSegment
- Input this function receives (each parameter and its types)
  leg: LegTripDisplayable
  index: int
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_coordenadasToGeoJsonPositionList:
    - Input: leg.geometryPolyline! (List<Coordinate>)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty, to generate the GeoJSON data.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)) (Source)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to add the data source.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to register the source with the MapManager.
  - mapboxMap!.style.addLayer (for the border layer):
    - Input: LineLayer(...) (Layer)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to add the border layer.
  - mapManager.registerLayer (for the border layer):
    - Input: shadowLayerId (String)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to register the border layer.
  - mapboxMap!.style.addLayer (for the main layer):
    - Input: LineLayer(...) (Layer)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to add the main walking layer.
  - mapManager.registerLayer (for the main layer):
    - Input: mainLayerId (String)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to register the main walking layer.

### \_drawBusSegment

- Function name
  \_drawBusSegment
- Input this function receives (each parameter and its types)
  leg: LegTripDisplayable
  index: int
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_coordenadasToGeoJsonPositionList:
    - Input: leg.geometryPolyline! (List<Coordinate>)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty, to generate the GeoJSON data.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)) (Source)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to add the data source.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to register the source with the MapManager.
  - mapboxMap!.style.addLayer (for the border layer):
    - Input: LineLayer(...) (Layer)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to add the border layer.
  - mapManager.registerLayer (for the border layer):
    - Input: shadowLayerId (String)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to register the border layer.
  - mapboxMap!.style.addLayer (for the main layer):
    - Input: LineLayer(...) (Layer)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to add the main bus layer.
  - mapManager.registerLayer (for the main layer):
    - Input: mainLayerId (String)
    - Condition: Called 100% of the time if `leg.geometryPolyline` is not null nor empty and `mapboxMap` is not null, to register the main bus layer.

### \_drawWaitPoint

- Function name
  \_drawWaitPoint
- Input this function receives (each parameter and its types)
  leg: LegTripDisplayable
  index: int
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)) (Source)
    - Condition: Called 100% of the time if `leg.positionPunto` is not null and `mapboxMap` is not null, to add the data source.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condition: Called 100% of the time if `leg.positionPunto` is not null and `mapboxMap` is not null, to register the source with the MapManager.
  - mapboxMap!.style.addLayer:
    - Input: CircleLayer(...) (Layer)
    - Condition: Called 100% of the time if `leg.positionPunto` is not null and `mapboxMap` is not null, to add the circle layer.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condition: Called 100% of the time if `leg.positionPunto` is not null and `mapboxMap` is not null, to register the circle layer.

### \_addBusStopsForSegment

- Function name
  \_addBusStopsForSegment
- Input this function receives (each parameter and its types)
  leg: LegTripDisplayable
  segmentIndex: int
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_addBusStopMarker:
    - Input: 'bus-boarding-stop-$segmentIndex' (String), 'bus-boarding-layer-$segmentIndex' (String), boardingStop.latitude (double), boardingStop.longitude (double), 'Subir al bus' (String)
    - Condition: Called if `mapboxMap` is not null, `leg.geometryPolyline` is not null nor empty, `mapManager.iconsLoader.areIconsLoaded` is true, and `polyline` (which is `leg.geometryPolyline!`) is not empty.
  - \_addBusStopMarker:
    - Input: 'bus-alighting-stop-$segmentIndex' (String), 'bus-alighting-layer-$segmentIndex' (String), alightingStop.latitude (double), alightingStop.longitude (double), 'Bajar del bus' (String)
    - Condition: Called if `mapboxMap` is not null, `leg.geometryPolyline` is not null nor empty, `mapManager.iconsLoader.areIconsLoaded` is true, and `polyline` (which is `leg.geometryPolyline!`) has more than one element.

### \_addBusStopMarker

- Function name
  \_addBusStopMarker
- Input this function receives (each parameter and its types)
  sourceId: String
  layerId: String
  lat: double
  lng: double
  label: String
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode({...})) (Source)
    - Condition: Called 100% of the time if `mapboxMap` is not null.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condition: Called 100% of the time if `mapboxMap` is not null.
  - mapboxMap!.style.addLayer:
    - Input: SymbolLayer(...) (Layer)
    - Condition: Called 100% of the time if `mapboxMap` is not null. Uses iconSize: 0.5, textSize: 28, text color green (0xFF4CAF50) for boarding and red (0xFFF44336) for alighting, textOffset [-1.25] for boarding and [1.25] for alighting.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condition: Called 100% of the time if `mapboxMap` is not null.
  - \_animatedArrowLayerIds.add:
    - Input: layerId (String)
    - Condition: Called 100% of the time if `mapboxMap` is not null.

### \_startArrowAnimation

- Function name
  \_startArrowAnimation
- Input this function receives (each parameter and its types)
  This function receives no parameters.
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_stopArrowAnimation:
    - Input: None
    - Condition: Called 100% of the time at the start to make sure there are no previous timers.
  - Timer.periodic:
    - Input: const Duration(milliseconds: 100) (Duration), (timer) => \_updateArrowAnimation() (Function)
    - Condition: Called 100% of the time if `mapboxMap` is not null. Creates a periodic timer that calls `_updateArrowAnimation`.

### \_updateArrowAnimation

- Function name
  \_updateArrowAnimation
- Input this function receives (each parameter and its types)
  This function does not receive parameters directly; it is called by a Timer.
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - mapboxMap!.style.styleLayerExists:
    - Input: layerId (String)
    - Condition: Called inside a loop that iterates over `_animatedArrowLayerIds`. The call happens only if `mapboxMap` is not null and `_animatedArrowLayerIds` is not empty.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: layerId (String), 'text-offset' (String), [0.0, animatedOffset] (List<double>)
    - Condition: Called if `mapboxMap` is not null and `mapboxMap!.style.styleLayerExists(layerId)` returns `true`. Boarding/origin use a negative offset (up), alighting/destination use a positive offset (down).

## `lib/map_manager/map_bus_realtime.dart`

### displayRealtimeBusesForPreview

- Function name
  displayRealtimeBusesForPreview
- Input this function receives (each parameter and its types)
  route: OpcionDeRutaMostrable
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_addRealtimeBusToPreview:
    - Input: primerTramoBus (LegTripDisplayable), indicePrimerTramoBus (int)
    - Condition: Called if `primerTramoBus` is not null AND (`primerTramoBus.posicionActualBus` is not null AND `primerTramoBus.minutosEstimadosLlegadaBus` is not null AND `primerTramoBus.nameLineBus` is not null). Called 100% of the time if these conditions are met.
  - \_addRealtimeBusFromEta:
    - Input: route.etaProximoBus! (InfoETAProximoBus), indicePrimerTramoBus (int)
    - Condition: Called if `primerTramoBus` is not null AND (NOT (`primerTramoBus.posicionActualBus` is not null AND `primerTramoBus.minutosEstimadosLlegadaBus` is not null AND `primerTramoBus.nameLineBus` is not null)) AND (`route.etaProximoBus` is not null AND `route.etaProximoBus!.posicionBus` is not null). Called 100% of the time if these nested conditions are met.
  - \_addRealtimeBusFromEta:
    - Input: route.etaProximoBus! (InfoETAProximoBus), 0 (int)
    - Condition: Called if `primerTramoBus` is null AND (`route.etaProximoBus` is not null AND `route.etaProximoBus!.posicionBus` is not null). Called 100% of the time if these nested conditions are met.

### updateBusPosition

- Function name
  updateBusPosition
- Input this function receives (each parameter and its types)
  position: Coordinate
  etaMinutes: int
  isRealTime: bool
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_tryUpdatePreviewBusElements:
    - Input: position (Coordinate), etaMinutes (int), isRealTime (bool)
    - Condition: Called 100% of the time if `mapboxMap` is not null.
  - \_displayBusOnMap:
    - Input: position (Coordinate)
    - Condition: Called if `mapboxMap` is not null AND `usingPreviewElements` (the result of `_tryUpdatePreviewBusElements`) is false. Called 100% of the time if these nested conditions are met.
  - \_updateBusApproachLineForActiveTrip:
    - Input: position (Coordinate), \_currentStopPosition! (Coordinate)
    - Condition: Called if `mapboxMap` is not null AND `_currentStopPosition` is not null AND `_currentTrackedSegment` is not null. Called 100% of the time if these nested conditions are met.

## `lib/map_manager/map_manager.dart`

### showRoutePreview

- Function name
  showRoutePreview
- Input this function receives (each parameter and its types)
  route: OpcionDeRutaMostrable
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - initialize:
    - Input: None
    - Condition: Called if `_isInitialized` is false. Called 100% of the time if this condition is met.
  - \_cleanup.clearRoute:
    - Input: None
    - Condition: Called if `_currentPreviewOptionId` is different from `route.idOption`. Called 100% of the time if this condition is met.
  - \_routeRenderer.renderRoute:
    - Input: route.tramosParaPreview (List<LegTripDisplayable>)
    - Condition: Called if `needsRedraw` is true OR `_activeLayers` is empty. Called 100% of the time if any of these conditions is met.
  - \_busRealtime.displayRealtimeBusesForPreview:
    - Input: route (OpcionDeRutaMostrable)
    - Condition: Called if `needsRedraw` is true OR `_activeLayers` is empty. Called 100% of the time if any of these conditions is met.
  - \_cameraController.zoomToRoutePreview:
    - Input: route (OpcionDeRutaMostrable)
    - Condition: Called 100% of the time after the conditional rendering calls.

### showActiveTrip

- Function name
  showActiveTrip
- Input this function receives (each parameter and its types)
  activeTripState: EstadoFaseViajeActivo
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - initialize:
    - Input: None
    - Condition: Called if `_isInitialized` is false. Called 100% of the time if this condition is met.
  - \_startActiveTripTracking:
    - Input: activeTripState (EstadoFaseViajeActivo)
    - Condition: Called if `_currentPhase` is 'route_preview' (optimized transition). Called 100% of the time if this condition is met.
  - \_cleanup.clearAll:
    - Input: None
    - Condition: Called if `_currentPhase` is NOT 'route_preview'. Called 100% of the time if this condition is met.
  - \_routeRenderer.renderRoute:
    - Input: activeTripState.tramosDelViaje (List<LegTripDisplayable>)
    - Condition: Called if `_currentPhase` is NOT 'route_preview'. Called 100% of the time if this condition is met.
  - \_busRealtime.initializeActiveTripTracking:
    - Input: activeTripState (EstadoFaseViajeActivo)
    - Condition: Called if `_currentPhase` is NOT 'route_preview'. Called 100% of the time if this condition is met.

## `lib/map_manager/map_cleanup.dart`

### clearRoute

- Function name
  clearRoute
- Input this function receives (each parameter and its types)
  This function receives no parameters.
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_clearLayersWithPrefix:
    - Input: prefix (String, several values such as 'route-walk-layer-', 'route-bus-layer-', 'route-wait-layer-', 'bus-boarding-layer-', 'bus-alighting-layer-')
    - Condition: Called several times with different unified prefixes to clean up dynamic layers. Each call happens 100% of the time if `mapboxMap` is not null.
  - \_clearSourcesWithPrefix:
    - Input: prefix (String, several values such as 'route-walk-source-', 'route-bus-source-', 'route-wait-source-', 'bus-boarding-stop-', 'bus-alighting-stop-')
    - Condition: Called several times with different unified prefixes to clean up dynamic sources. Each call happens 100% of the time if `mapboxMap` is not null.
  - clearBusElements:
    - Input: None
    - Condition: Called 100% of the time to clean up real-time bus elements.

### clearBusElements

- Function name
  clearBusElements
- Input this function receives (each parameter and its types)
  This function receives no parameters.
- If this function calls another function or other functions, you must list the functions it calls and what input it sends to each one. For each of these functions you must indicate whether it is called 100% of the time, or, if the call is under conditionals, you must state precisely under which conditions, including nested conditions. I want you to keep 100% of the information about the cases in which each function is called.
  - \_clearLayersWithPrefix:
    - Input: prefix (String, values such as 'bus-realtime-layer-', 'bus-tooltip-layer-', 'bus-approach-layer-')
    - Condition: Called several times with unified bus prefixes. Each call happens 100% of the time if `mapboxMap` is not null.
  - \_clearSourcesWithPrefix:
    - Input: prefix (String, values such as 'bus-realtime-source-', 'bus-approach-source-')
    - Condition: Called several times with unified bus prefixes. Each call happens 100% of the time if `mapboxMap` is not null.

## Main Changes in the Unification

1. **Removal of duplication**: The separate `*Preview` and `*Active` methods were removed and replaced with unified methods.

2. **Unified prefixes**:

   - Routes: `route-walk-*`, `route-bus-*`, `route-wait-*`
   - Stops: `bus-boarding-*`, `bus-alighting-*`
   - Real-time buses: `bus-realtime-*`, `bus-tooltip-*`, `bus-approach-*`

3. **Visually identical behavior**: The stop icons keep the same visual properties (iconSize: 0.5, textSize: 28, green/red colors).

4. **Transition optimization**: The system automatically detects transitions from preview to active trip to avoid redrawing elements unnecessarily.

5. **Simplified cleanup**: A single `clearRoute()` method handles cleanup for both the preview and the active trip.
