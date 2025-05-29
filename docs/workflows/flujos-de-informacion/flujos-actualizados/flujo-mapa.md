# Funciones de Dibujado en el Mapa (Unificadas para Preview y Viaje Activo)

Este documento detalla las funciones identificadas en los módulos `lib/ui` y `lib/map_manager` responsables de dibujar elementos en el mapa. Después de la unificación, los métodos ahora funcionan tanto para la fase de previsualización de rutas como para la fase de viaje activo.

## `lib/map_manager/map_route_renderer.dart`

### renderRoute

- Nombre de la funcion
  renderRoute
- Input que recibe esta funcion (cada parametro y sus types)
  tramos: List<TramoViajeMostrable>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_drawWalkSegment:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.CAMINAR`. Esta condición se evalúa dentro de un bucle que itera sobre `tramos`.
  - \_drawBusSegment:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.VIAJE_EN_BUS`. Esta condición se evalúa dentro de un bucle que itera sobre `tramos`.
  - \_drawWaitPoint:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.ESPERAR_BUS`. Esta condición se evalúa dentro de un bucle que itera sobre `tramos`.
  - \_addBusStopsForSegment:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.VIAJE_EN_BUS`. Esta condición se evalúa dentro de un segundo bucle que itera sobre `tramos`.
  - \_startArrowAnimation:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de los bucles, si `mapboxMap` no es nulo.

### highlightCurrentLeg

- Nombre de la funcion
  highlightCurrentLeg
- Input que recibe esta funcion (cada parametro y sus types)
  legIndex: int
  tramos: List<TramoViajeMostrable>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleLayerExists:
    - Input: layerId (String)
    - Condición: Llamada dentro de un bucle que itera sobre `tramos`. La llamada ocurre solo si `mapboxMap` no es nulo.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: layerId (String), 'line-width' (String), lineWidth (double) O layerId (String), 'circle-radius' (String), circleRadius (double)
    - Condición: Llamada dentro de un bucle que itera sobre `tramos`, y solo si `mapboxMap` no es nulo y `mapboxMap!.style.styleLayerExists(layerId)` devuelve `true`. Además, la propiedad a modificar (`line-width` o `circle-radius`) depende del `tramo.tipo`. Si `tramo.tipo` es `TipoTramoViaje.CAMINAR` o `TipoTramoViaje.VIAJE_EN_BUS`, se intenta modificar `'line-width'` si `lineWidth` no es nulo. Si `tramo.tipo` es `TipoTramoViaje.ESPERAR_BUS`, se intenta modificar `'circle-radius'` si `circleRadius` no es nulo.

### \_drawWalkSegment

- Nombre de la funcion
  \_drawWalkSegment
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_coordenadasToGeoJsonPositionList:
    - Input: tramo.geometriaPolilinea! (List<Coordenada>)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío, para generar los datos GeoJSON.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)) (Source)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para agregar la fuente de datos.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para registrar la fuente con el MapManager.
  - mapboxMap!.style.addLayer (para capa de borde):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para agregar la capa de borde.
  - mapManager.registerLayer (para capa de borde):
    - Input: shadowLayerId (String)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para registrar la capa de borde.
  - mapboxMap!.style.addLayer (para capa principal):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para agregar la capa principal de caminata.
  - mapManager.registerLayer (para capa principal):
    - Input: mainLayerId (String)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para registrar la capa principal de caminata.

### \_drawBusSegment

- Nombre de la funcion
  \_drawBusSegment
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_coordenadasToGeoJsonPositionList:
    - Input: tramo.geometriaPolilinea! (List<Coordenada>)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío, para generar los datos GeoJSON.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)) (Source)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para agregar la fuente de datos.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para registrar la fuente con el MapManager.
  - mapboxMap!.style.addLayer (para capa de borde):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para agregar la capa de borde.
  - mapManager.registerLayer (para capa de borde):
    - Input: shadowLayerId (String)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para registrar la capa de borde.
  - mapboxMap!.style.addLayer (para capa principal):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para agregar la capa principal de bus.
  - mapManager.registerLayer (para capa principal):
    - Input: mainLayerId (String)
    - Condición: Llamada el 100% de las veces si `tramo.geometriaPolilinea` no es nulo ni vacío y `mapboxMap` no es nulo, para registrar la capa principal de bus.

### \_drawWaitPoint

- Nombre de la funcion
  \_drawWaitPoint
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)) (Source)
    - Condición: Llamada el 100% de las veces si `tramo.posicionPunto` no es nulo y `mapboxMap` no es nulo, para agregar la fuente de datos.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si `tramo.posicionPunto` no es nulo y `mapboxMap` no es nulo, para registrar la fuente con el MapManager.
  - mapboxMap!.style.addLayer:
    - Input: CircleLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si `tramo.posicionPunto` no es nulo y `mapboxMap` no es nulo, para agregar la capa del círculo.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si `tramo.posicionPunto` no es nulo y `mapboxMap` no es nulo, para registrar la capa del círculo.

### \_addBusStopsForSegment

- Nombre de la funcion
  \_addBusStopsForSegment
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  segmentIndex: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_addBusStopMarker:
    - Input: 'bus-boarding-stop-$segmentIndex' (String), 'bus-boarding-layer-$segmentIndex' (String), boardingStop.latitud (double), boardingStop.longitud (double), 'Subir al bus' (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `tramo.geometriaPolilinea` no es nulo ni vacío, `mapManager.iconsLoader.areIconsLoaded` es verdadero, y `polyline` (que es `tramo.geometriaPolilinea!`) no está vacío.
  - \_addBusStopMarker:
    - Input: 'bus-alighting-stop-$segmentIndex' (String), 'bus-alighting-layer-$segmentIndex' (String), alightingStop.latitud (double), alightingStop.longitud (double), 'Bajar del bus' (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `tramo.geometriaPolilinea` no es nulo ni vacío, `mapManager.iconsLoader.areIconsLoaded` es verdadero, y `polyline` (que es `tramo.geometriaPolilinea!`) tiene más de un elemento.

### \_addBusStopMarker

- Nombre de la funcion
  \_addBusStopMarker
- Input que recibe esta funcion (cada parametro y sus types)
  sourceId: String
  layerId: String
  lat: double
  lng: double
  label: String
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(id: sourceId, data: jsonEncode({...})) (Source)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.addLayer:
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Usa iconSize: 0.5, textSize: 28, textColor verde (0xFF4CAF50) para subir y rojo (0xFFF44336) para bajar, textOffset [-1.25] para subir y [1.25] para bajar.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - \_animatedArrowLayerIds.add:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.

### \_startArrowAnimation

- Nombre de la funcion
  \_startArrowAnimation
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_stopArrowAnimation:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces al inicio para asegurar que no hay timers previos.
  - Timer.periodic:
    - Input: const Duration(milliseconds: 100) (Duration), (timer) => \_updateArrowAnimation() (Function)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Crea un timer periódico que llama a `_updateArrowAnimation`.

### \_updateArrowAnimation

- Nombre de la funcion
  \_updateArrowAnimation
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros directamente, es llamada por un Timer.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleLayerExists:
    - Input: layerId (String)
    - Condición: Llamada dentro de un bucle que itera sobre `_animatedArrowLayerIds`. La llamada ocurre solo si `mapboxMap` no es nulo y `_animatedArrowLayerIds` no está vacío.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: layerId (String), 'text-offset' (String), [0.0, animatedOffset] (List<double>)
    - Condición: Llamada si `mapboxMap` no es nulo, `mapboxMap!.style.styleLayerExists(layerId)` devuelve `true`. Los boarding/origin usan offset negativo (arriba), alighting/destination usan offset positivo (abajo).

## `lib/map_manager/map_bus_realtime.dart`

### displayRealtimeBusesForPreview

- Nombre de la funcion
  displayRealtimeBusesForPreview
- Input que recibe esta funcion (cada parametro y sus types)
  ruta: OpcionDeRutaMostrable
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_addRealtimeBusToPreview:
    - Input: primerTramoBus (TramoViajeMostrable), indicePrimerTramoBus (int)
    - Condición: Llamada si `primerTramoBus` no es nulo Y (`primerTramoBus.posicionActualBus` no es nulo Y `primerTramoBus.minutosEstimadosLlegadaBus` no es nulo Y `primerTramoBus.nombreLineaBus` no es nulo). Se llama el 100% de las veces si se cumplen estas condiciones.
  - \_addRealtimeBusFromEta:
    - Input: ruta.etaProximoBus! (InfoETAProximoBus), indicePrimerTramoBus (int)
    - Condición: Llamada si `primerTramoBus` no es nulo Y (NO (`primerTramoBus.posicionActualBus` no es nulo Y `primerTramoBus.minutosEstimadosLlegadaBus` no es nulo Y `primerTramoBus.nombreLineaBus` no es nulo)) Y (`ruta.etaProximoBus` no es nulo Y `ruta.etaProximoBus!.posicionBus` no es nulo). Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - \_addRealtimeBusFromEta:
    - Input: ruta.etaProximoBus! (InfoETAProximoBus), 0 (int)
    - Condición: Llamada si `primerTramoBus` es nulo Y (`ruta.etaProximoBus` no es nulo Y `ruta.etaProximoBus!.posicionBus` no es nulo). Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### updateBusPosition

- Nombre de la funcion
  updateBusPosition
- Input que recibe esta funcion (cada parametro y sus types)
  position: Coordenada
  etaMinutes: int
  isRealTime: bool
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_tryUpdatePreviewBusElements:
    - Input: position (Coordenada), etaMinutes (int), isRealTime (bool)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - \_displayBusOnMap:
    - Input: position (Coordenada)
    - Condición: Llamada si `mapboxMap` no es nulo Y `usingPreviewElements` (el resultado de `_tryUpdatePreviewBusElements`) es falso. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - \_updateBusApproachLineForActiveTrip:
    - Input: position (Coordenada), \_currentStopPosition! (Coordenada)
    - Condición: Llamada si `mapboxMap` no es nulo Y `_currentStopPosition` no es nulo Y `_currentTrackedSegment` no es nulo. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

## `lib/map_manager/map_manager.dart`

### showRoutePreview

- Nombre de la funcion
  showRoutePreview
- Input que recibe esta funcion (cada parametro y sus types)
  route: OpcionDeRutaMostrable
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - initialize:
    - Input: Ninguno
    - Condición: Llamada si `_isInitialized` es falso. Se llama el 100% de las veces si se cumple esta condición.
  - \_cleanup.clearRoute:
    - Input: Ninguno
    - Condición: Llamada si `_currentPreviewOptionId` es diferente a `route.idOpcion`. Se llama el 100% de las veces si se cumple esta condición.
  - \_routeRenderer.renderRoute:
    - Input: route.tramosParaPreview (List<TramoViajeMostrable>)
    - Condición: Llamada si `needsRedraw` es verdadero O `_activeLayers` está vacío. Se llama el 100% de las veces si se cumple alguna de estas condiciones.
  - \_busRealtime.displayRealtimeBusesForPreview:
    - Input: route (OpcionDeRutaMostrable)
    - Condición: Llamada si `needsRedraw` es verdadero O `_activeLayers` está vacío. Se llama el 100% de las veces si se cumple alguna de estas condiciones.
  - \_cameraController.zoomToRoutePreview:
    - Input: route (OpcionDeRutaMostrable)
    - Condición: Llamada el 100% de las veces después de las llamadas condicionales a renderizado.

### showActiveTrip

- Nombre de la funcion
  showActiveTrip
- Input que recibe esta funcion (cada parametro y sus types)
  activeTripState: EstadoFaseViajeActivo
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - initialize:
    - Input: Ninguno
    - Condición: Llamada si `_isInitialized` es falso. Se llama el 100% de las veces si se cumple esta condición.
  - \_startActiveTripTracking:
    - Input: activeTripState (EstadoFaseViajeActivo)
    - Condición: Llamada si `_currentPhase` es 'route_preview' (transición optimizada). Se llama el 100% de las veces si se cumple esta condición.
  - \_cleanup.clearAll:
    - Input: Ninguno
    - Condición: Llamada si `_currentPhase` NO es 'route_preview'. Se llama el 100% de las veces si se cumple esta condición.
  - \_routeRenderer.renderRoute:
    - Input: activeTripState.tramosDelViaje (List<TramoViajeMostrable>)
    - Condición: Llamada si `_currentPhase` NO es 'route_preview'. Se llama el 100% de las veces si se cumple esta condición.
  - \_busRealtime.initializeActiveTripTracking:
    - Input: activeTripState (EstadoFaseViajeActivo)
    - Condición: Llamada si `_currentPhase` NO es 'route_preview'. Se llama el 100% de las veces si se cumple esta condición.

## `lib/map_manager/map_cleanup.dart`

### clearRoute

- Nombre de la funcion
  clearRoute
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_clearLayersWithPrefix:
    - Input: prefix (String, varios valores como 'route-walk-layer-', 'route-bus-layer-', 'route-wait-layer-', 'bus-boarding-layer-', 'bus-alighting-layer-')
    - Condición: Llamada varias veces con diferentes prefijos unificados para limpiar capas dinámicas. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_clearSourcesWithPrefix:
    - Input: prefix (String, varios valores como 'route-walk-source-', 'route-bus-source-', 'route-wait-source-', 'bus-boarding-stop-', 'bus-alighting-stop-')
    - Condición: Llamada varias veces con diferentes prefijos unificados para limpiar fuentes dinámicas. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - clearBusElements:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces para limpiar elementos de buses en tiempo real.

### clearBusElements

- Nombre de la funcion
  clearBusElements
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_clearLayersWithPrefix:
    - Input: prefix (String, valores como 'bus-realtime-layer-', 'bus-tooltip-layer-', 'bus-approach-layer-')
    - Condición: Llamada varias veces con prefijos unificados de buses. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_clearSourcesWithPrefix:
    - Input: prefix (String, valores como 'bus-realtime-source-', 'bus-approach-source-')
    - Condición: Llamada varias veces con prefijos unificados de buses. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.

## Cambios Principales en la Unificación

1. **Eliminación de duplicación**: Se eliminaron los métodos separados `*Preview` y `*Active`, reemplazándolos por métodos unificados.

2. **Prefijos unificados**:

   - Rutas: `route-walk-*`, `route-bus-*`, `route-wait-*`
   - Paradas: `bus-boarding-*`, `bus-alighting-*`
   - Buses en tiempo real: `bus-realtime-*`, `bus-tooltip-*`, `bus-approach-*`

3. **Comportamiento visual idéntico**: Los iconos de paradas mantienen las mismas propiedades visuales (iconSize: 0.5, textSize: 28, colores verde/rojo).

4. **Optimización de transiciones**: El sistema detecta automáticamente transiciones de preview a active trip para evitar redibujar elementos innecesariamente.

5. **Limpieza simplificada**: Un solo método `clearRoute()` maneja la limpieza tanto para preview como active trip.
