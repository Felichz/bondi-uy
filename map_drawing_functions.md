# Funciones de Dibujado en el Mapa (Fases Preview y Viaje Activo)

Este documento detalla las funciones identificadas en los módulos `lib/ui` y `lib/map_manager` responsables de dibujar elementos en el mapa durante la fase de previsualización de rutas y la fase de viaje activo.

## `lib/map_manager/map_route_renderer.dart`

### renderRoutePreview

- Nombre de la funcion
  renderRoutePreview
- Input que recibe esta funcion (cada parametro y sus types)
  ruta: OpcionDeRutaMostrable
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_drawWalkSegmentPreview:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.CAMINAR`. Esta condición se evalúa dentro de un bucle que itera sobre `ruta.tramosParaPreview`.
  - \_drawBusSegmentPreview:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.VIAJE_EN_BUS`. Esta condición se evalúa dentro de un bucle que itera sobre `ruta.tramosParaPreview`.
  - \_drawWaitPointPreview:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.ESPERAR_BUS`. Esta condición se evalúa dentro de un bucle que itera sobre `ruta.tramosParaPreview`.
  - \_addBusStopsForSegmentPreview:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.VIAJE_EN_BUS`. Esta condición se evalúa dentro de un segundo bucle que itera sobre `ruta.tramosParaPreview`.
  - \_startArrowAnimation:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de los bucles, si `mapboxMap` no es nulo.

### renderActiveTrip

- Nombre de la funcion
  renderActiveTrip
- Input que recibe esta funcion (cada parametro y sus types)
  tramos: List<TramoViajeMostrable>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_drawWalkSegmentActive:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.CAMINAR`. Esta condición se evalúa dentro de un bucle que itera sobre `tramos`.
  - \_drawBusSegmentActive:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.VIAJE_EN_BUS`. Esta condición se evalúa dentro de un bucle que itera sobre `tramos`.
  - \_drawWaitPointActive:
    - Input: tramo (TramoViajeMostrable), i (int)
    - Condición: Llamada si `tramo.tipo` es `TipoTramoViaje.ESPERAR_BUS`. Esta condición se evalúa dentro de un bucle que itera sobre `tramos`.
  - \_addBusStopsForSegmentActive:
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

### convertPreviewStylesToActiveTrip

- Nombre de la funcion
  convertPreviewStylesToActiveTrip
- Input que recibe esta funcion (cada parametro y sus types)
  tramos: List<TramoViajeMostrable>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - N/A (Según el código proporcionado, esta función no realiza llamadas a otras funciones de dibujado, solo menciona la posibilidad de actualizar estilos en el futuro y asume que los elementos de preview ya están dibujados).
- Por otra parte, si esta funcion no llama a ninguna otra funcion, debes indicarlo
  Esta función no llama a otras funciones de dibujado de manera explícita en el código actual, se basa en que los elementos de preview ya existen.

### \_drawWalkSegmentPreview

- Nombre de la funcion
  \_drawWalkSegmentPreview
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

### \_drawBusSegmentPreview

- Nombre de la funcion
  \_drawBusSegmentPreview
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

### \_drawWaitPointPreview

- Nombre de la funcion
  \_drawWaitPointPreview
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

### \_addBusStopsForSegmentPreview

- Nombre de la funcion
  \_addBusStopsForSegmentPreview
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  segmentIndex: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_addBusStopMarkerPreview:
    - Input: 'bus-boarding-stop-$segmentIndex' (String), 'bus-boarding-layer-$segmentIndex' (String), boardingStop.latitud (double), boardingStop.longitud (double), 'Subir al bus' (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `tramo.geometriaPolilinea` no es nulo ni vacío, `mapManager.iconsLoader.areIconsLoaded` es verdadero, y `polyline` (que es `tramo.geometriaPolilinea!`) no está vacío.
  - \_addBusStopMarkerPreview:
    - Input: 'bus-alighting-stop-$segmentIndex' (String), 'bus-alighting-layer-$segmentIndex' (String), alightingStop.latitud (double), alightingStop.longitud (double), 'Bajar del bus' (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `tramo.geometriaPolilinea` no es nulo ni vacío, `mapManager.iconsLoader.areIconsLoaded` es verdadero, y `polyline` (que es `tramo.geometriaPolilinea!`) tiene más de un elemento.

### \_addBusStopMarkerPreview

- Nombre de la funcion
  \_addBusStopMarkerPreview
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
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - \_animatedArrowLayerIds.add:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.

### \_drawWalkSegmentActive

- Nombre de la funcion
  \_drawWalkSegmentActive
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
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

### \_drawBusSegmentActive

- Nombre de la funcion
  \_drawBusSegmentActive
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
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

### \_drawWaitPointActive

- Nombre de la funcion
  \_drawWaitPointActive
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

### \_addBusStopsForSegmentActive

- Nombre de la funcion
  \_addBusStopsForSegmentActive
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_addBusStopMarkerActive:
    - Input: 'active-bus-origin-$index' (String), 'active-bus-origin-layer-$index' (String), origen.latitud (double), origen.longitud (double), 'Subir al bus' (String)
    - Condición: Llamada si `mapManager.iconsLoader.areIconsLoaded` es verdadero, `tramo.geometriaPolilinea` no es nulo ni vacío. La llamada se produce si `coordenadas` (que es `tramo.geometriaPolilinea!`) no está vacío.
  - \_addBusStopMarkerActive:
    - Input: 'active-bus-destination-$index' (String), 'active-bus-destination-layer-$index' (String), destino.latitud (double), destino.longitud (double), 'Bajar del bus' (String)
    - Condición: Llamada si `mapManager.iconsLoader.areIconsLoaded` es verdadero, `tramo.geometriaPolilinea` no es nulo ni vacío. La llamada se produce si `coordenadas` (que es `tramo.geometriaPolilinea!`) tiene más de un elemento.

### \_addBusStopMarkerActive

- Nombre de la funcion
  \_addBusStopMarkerActive
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
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
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
    - Condición: Llamada el 100% de las veces al inicio para asegurar que no haya timers previos.
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
  - mapboxMap!.style.getLayer:
    - Input: layerId (String)
    - Condición: Llamada si `mapboxMap` no es nulo y `mapboxMap!.style.styleLayerExists(layerId)` devuelve `true`.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: layerId (String), 'text-offset' (String), [0.0, animatedOffset] (List<double>)
    - Condición: Llamada si `mapboxMap` no es nulo, `mapboxMap!.style.styleLayerExists(layerId)` devuelve `true`, y `layer` (el resultado de `mapboxMap!.style.getLayer`) no es nulo y es de tipo `SymbolLayer`.

## `lib/map_manager/map_bus_realtime.dart`

### displayRealtimeBusesForPreview

- Nombre de la funcion
  displayRealtimeBusesForPreview
- Input que recibe esta funcion (cada parametro y sus types)
  ruta: OpcionDeRutaMostrable
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_findNextBusSegment:
    - Input: ruta.tramosParaPreview (List<TramoViajeMostrable>), -1 (int)
    - Condición: Llamada para encontrar el primer tramo de bus (solo se considera TipoTramoViaje.VIAJE_EN_BUS).
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

### initializeActiveTripTracking

- Nombre de la funcion
  initializeActiveTripTracking
- Input que recibe esta funcion (cada parametro y sus types)
  activeTripState: EstadoFaseViajeActivo
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - N/A (Según el código proporcionado, esta función no realiza llamadas a otras funciones de dibujado, solo inicializa el tracking sin dibujar explícitamente).
- Por otra parte, si esta funcion no llama a ninguna otra funcion, debes indicarlo
  Esta función no llama directamente a otras funciones de dibujado en el código actual.

### updateBusTrackingForLeg

- Nombre de la funcion
  updateBusTrackingForLeg
- Input que recibe esta funcion (cada parametro y sus types)
  legIndex: int
  tramos: List<TramoViajeMostrable>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_findNextBusSegment:
    - Input: tramos (List<TramoViajeMostrable>), legIndex (int)
    - Condición: Llamada el 100% de las veces si `tramos` no está vacío y `legIndex` es válido. Se usa para determinar el próximo tramo de bus a trackear (solo considera TipoTramoViaje.VIAJE_EN_BUS).
  - \_startBusTracking:
    - Input: proximoTramoBus (TramoViajeMostrable)
    - Condición: Llamada si el resultado de `_findNextBusSegment` (`proximoTramoBus`) no es nulo. Se llama el 100% de las veces si se cumple esta condición.
  - \_stopBusTracking:
    - Input: Ninguno
    - Condición: Llamada si el resultado de `_findNextBusSegment` (`proximoTramoBus`) es nulo. Se llama el 100% de las veces si se cumple esta condición.

### \_addRealtimeBusToPreview

- Nombre de la funcion
  \_addRealtimeBusToPreview
- Input que recibe esta funcion (cada parametro y sus types)
  tramo: TramoViajeMostrable
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_addBusApproachLineToPreview:
    - Input: busPosition (Coordenada), paradaOrigen (Coordenada), segmentIndex (int), tramo (TramoViajeMostrable)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo, `tramo.posicionActualBus` no es nulo, y `tramo.geometriaPolilinea` no es nulo ni vacío. Se llama antes de agregar el bus para asegurar que la línea de aproximación esté debajo.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo, `tramo.posicionActualBus` no es nulo, y se agregó la línea de aproximación previamente.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapboxMap!.style.addLayer:
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si se agregó la capa previamente.
  - \_startTooltipFloatingAnimationPreview:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de agregar la capa del tooltip.

### \_addRealtimeBusFromEta

- Nombre de la funcion
  \_addRealtimeBusFromEta
- Input que recibe esta funcion (cada parametro y sus types)
  etaInfo: InfoETAProximoBus
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y `etaInfo.posicionBus` no es nulo.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapboxMap!.style.addLayer (bus):
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapManager.registerLayer (bus):
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si se agregó la capa del bus previamente.
  - mapboxMap!.style.addLayer (tooltip):
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si se agregó la fuente del bus previamente.
  - mapManager.registerLayer (tooltip):
    - Input: tooltipLayerId (String)
    - Condición: Llamada el 100% de las veces si se agregó la capa del tooltip previamente.
  - \_startTooltipFloatingAnimationPreview:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de agregar la capa del tooltip.

### \_displayBusOnMap

- Nombre de la funcion
  \_displayBusOnMap
- Input que recibe esta funcion (cada parametro y sus types)
  position: Coordenada
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleSourceExists:
    - Input: INCOMING_BUS_SOURCE_ID (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.getSource:
    - Input: INCOMING_BUS_SOURCE_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existe.
  - (GeoJsonSource).updateGeoJSON:
    - Input: json.encode(sourceData) (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existente es de tipo `GeoJsonSource`. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerSource:
    - Input: INCOMING_BUS_SOURCE_ID (String)
    - Condición: Llamada si la fuente no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.styleLayerExists (bus):
    - Input: INCOMING_BUS_LAYER_ID (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y la fuente ya fue manejada (existente o creada).
  - mapboxMap!.style.addLayer (bus):
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada si `mapboxMap` no es nulo y la capa del bus no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerLayer (bus):
    - Input: INCOMING_BUS_LAYER_ID (String)
    - Condición: Llamada si la capa del bus no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.styleLayerExists (tooltip):
    - Input: BUS_TOOLTIP_LAYER_ID (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y la capa del bus ya fue manejada.
  - mapboxMap!.style.addLayer (tooltip):
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada si `mapboxMap` no es nulo y la capa del tooltip no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerLayer (tooltip):
    - Input: BUS_TOOLTIP_LAYER_ID (String)
    - Condición: Llamada si la capa del tooltip no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - \_startTooltipFloatingAnimation:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y la capa del tooltip ya fue manejada (existente o creada).

### \_updateBusApproachLineForActiveTrip

- Nombre de la funcion
  \_updateBusApproachLineForActiveTrip
- Input que recibe esta funcion (cada parametro y sus types)
  busPosition: Coordenada
  stopPosition: Coordenada
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - loadShapeGeometries:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y `_currentTrackedSegment` no es nulo.
  - getFullShapeGeometry:
    - Input: \_currentTrackedSegment!.shapeId (String)
    - Condición: Llamada si `_currentTrackedSegment` no es nulo y tiene `shapeId`.
  - findClosestPointIndexOnShape:
    - Input: fullLineGeometry (List<Coordenada>), busPosition (Coordenada) O fullLineGeometry (List<Coordenada>), stopPosition (Coordenada)
    - Condición: Llamada si `fullLineGeometry` no es nulo ni vacío. Se llama dos veces (una para bus, otra para stop).
  - getGeometrySegment:
    - Input: fullLineGeometry (List<Coordenada>), busIndex (int), stopIndex (int)
    - Condición: Llamada si `fullLineGeometry` no es nulo ni vacío y los índices `busIndex` y `stopIndex` son válidos.
  - \_tryUpdatePreviewApproachLine:
    - Input: geoJsonFeatureCollection (Map<String, dynamic>)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Intenta actualizar líneas de aproximación del preview.
  - \_updateOrCreateActiveTripApproachLine:
    - Input: geoJsonFeatureCollection (Map<String, dynamic>)
    - Condición: Llamada si `mapboxMap` no es nulo Y el resultado de `_tryUpdatePreviewApproachLine` es falso. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### \_tryUpdatePreviewBusElements

- Nombre de la funcion
  \_tryUpdatePreviewBusElements
- Input que recibe esta funcion (cada parametro y sus types)
  position: Coordenada
  etaMinutes: int
  isRealTime: bool
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleSourceExists:
    - Input: sourceId (String)
    - Condición: Llamada dentro de un bucle que itera sobre posibles sourceIds del preview. Se llama si `mapboxMap` no es nulo y `_lastPreviewIndex` no es -1.
  - mapboxMap!.style.getSource:
    - Input: sourceId (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_lastPreviewIndex` no es -1, y la fuente existe.
  - (GeoJsonSource).updateGeoJSON:
    - Input: json.encode(sourceData) (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_lastPreviewIndex` no es -1, la fuente existe y es de tipo `GeoJsonSource`. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### \_displayBusOnMapPreview

- Nombre de la funcion
  \_displayBusOnMapPreview
- Input que recibe esta funcion (cada parametro y sus types)
  position: Coordenada
  index: int
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y `mapManager.iconsLoader.areIconsLoaded` es verdadero.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapboxMap!.style.addLayer:
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si se agregó la capa previamente.

### \_addBusTooltipPreview

- Nombre de la funcion
  \_addBusTooltipPreview
- Input que recibe esta funcion (cada parametro y sus types)
  position: Coordenada
  index: int
  line: String
  eta: int
  isRealTime: bool
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_addBusTooltipBase:
    - Input: sourceId (String), layerId (String), position (Coordenada), text (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y `mapManager.iconsLoader.areIconsLoaded` es verdadero.
  - \_startTooltipFloatingAnimationPreview:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de llamar a `_addBusTooltipBase`.

### \_addBusTooltipActive

- Nombre de la funcion
  \_addBusTooltipActive
- Input que recibe esta funcion (cada parametro y sus types)
  position: Coordenada
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_addBusTooltipBase:
    - Input: BUS_TOOLTIP_SOURCE_ID (String), BUS_TOOLTIP_LAYER_ID (String), position (Coordenada), text (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y la información del bus actual (`_currentBusLine`, `_currentBusEta`, `_currentBusIsRealTime`) no es nula.
  - \_startTooltipFloatingAnimation:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de llamar a `_addBusTooltipBase`.

### \_addBusTooltipBase

- Nombre de la funcion
  \_addBusTooltipBase
- Input que recibe esta funcion (cada parametro y sus types)
  sourceId: String
  layerId: String
  position: Coordenada
  text: String
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleSourceExists:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.getSource:
    - Input: sourceId (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existe.
  - (GeoJsonSource).updateGeoJSON:
    - Input: jsonEncode(featureCollection) (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existente es de tipo `GeoJsonSource`. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada si la fuente no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.styleLayerExists:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y la fuente ya fue manejada.
  - mapboxMap!.style.removeStyleLayer:
    - Input: layerId (String)
    - Condición: Llamada si `mapboxMap` no es nulo, la fuente ya fue manejada, y la capa existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.addLayer:
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada si `mapboxMap` no es nulo, la fuente ya fue manejada, y la capa no existe (o fue removida). Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerLayer:
    - Input: layerId (String)
    - Condición: Llamada si la capa no existe (o fue removida) y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### \_addBusApproachLinePreview

- Nombre de la funcion
  \_addBusApproachLinePreview
- Input que recibe esta funcion (cada parametro y sus types)
  busPosition: Coordenada
  stopPosition: Coordenada
  index: int
  tramo: TramoViajeMostrable
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - loadShapeGeometries:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - getFullShapeGeometry:
    - Input: tramo.shapeId (String)
    - Condición: Llamada si `tramo` tiene `shapeId`.
  - findClosestPointIndexOnShape:
    - Input: fullLineGeometry (List<Coordenada>), busPosition (Coordenada) O fullLineGeometry (List<Coordenada>), stopPosition (Coordenada)
    - Condición: Llamada si `fullLineGeometry` no es nulo ni vacío. Se llama dos veces (una para bus, otra para stop).
  - getGeometrySegment:
    - Input: fullLineGeometry (List<Coordenada>), busIndex (int), stopIndex (int)
    - Condición: Llamada si `fullLineGeometry` no es nulo ni vacío y los índices `busIndex` y `stopIndex` son válidos.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapManager.registerSource:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapboxMap!.style.addLayer (borde):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapManager.registerLayer (borde):
    - Input: shadowLayerId (String)
    - Condición: Llamada el 100% de las veces si se agregó la capa de borde previamente.
  - mapboxMap!.style.addLayer (principal):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada el 100% de las veces si se agregó la fuente previamente.
  - mapManager.registerLayer (principal):
    - Input: mainLayerId (String)
    - Condición: Llamada el 100% de las veces si se agregó la capa principal previamente.

### \_updateBusApproachLinePreview

- Nombre de la funcion
  \_updateBusApproachLinePreview
- Input que recibe esta funcion (cada parametro y sus types)
  busPosition: Coordenada
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleSourceExists:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo y `_lastPreviewSegment` no es nulo y tiene `paradaOrigenBus`. Se busca la fuente usando `_lastPreviewIndex`.
  - mapboxMap!.style.getSource:
    - Input: sourceId (String)
    - Condición: Llamada si la fuente existe. Se llama el 100% de las veces si se cumple esta condición.
  - (GeoJsonSource).updateGeoJSON:
    - Input: jsonEncode(feature) (String)
    - Condición: Llamada si la fuente existente es de tipo `GeoJsonSource`. Se llama el 100% de las veces si se cumple esta condición.

### \_startTooltipFloatingAnimation

- Nombre de la funcion
  \_startTooltipFloatingAnimation
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_stopTooltipFloatingAnimation:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces al inicio para asegurar que no haya timers previos.
  - Timer.periodic:
    - Input: const Duration(milliseconds: 16) (Duration), (timer) async {...} (Function)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Crea un timer periódico.
  - mapboxMap!.style.styleLayerExists:
    - Input: BUS_TOOLTIP_LAYER_ID (String)
    - Condición: Llamada dentro del callback del timer. Se llama el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: BUS_TOOLTIP_LAYER_ID (String), 'icon-offset' (String), [0.0, offsetY] (List<double>)
    - Condición: Llamada dentro del callback del timer si `mapboxMap` no es nulo y la capa existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### \_startTooltipFloatingAnimationPreview

- Nombre de la funcion
  \_startTooltipFloatingAnimationPreview
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_stopTooltipFloatingAnimation:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces al inicio para asegurar que no haya timers previos.
  - Timer.periodic:
    - Input: const Duration(milliseconds: 16) (Duration), (timer) async {...} (Function)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Crea un timer periódico.
  - mapboxMap!.style.styleLayerExists:
    - Input: layerId (String)
    - Condición: Llamada dentro del callback del timer, dentro de un bucle que itera sobre posibles layerIds del preview. Se llama el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: layerId (String), 'icon-offset' (String), [0.0, offsetY] (List<double>)
    - Condición: Llamada dentro del callback del timer si `mapboxMap` no es nulo y la capa existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### \_stopTooltipFloatingAnimation

- Nombre de la funcion
  \_stopTooltipFloatingAnimation
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - Timer.cancel:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `_tooltipFloatTimer` no es nulo.
  - mapboxMap!.style.styleLayerExists:
    - Input: BUS_TOOLTIP_LAYER_ID (String) O layerId (String)
    - Condición: Llamada si `mapboxMap` no es nulo. Se llama una vez para la capa activa y dentro de un bucle para posibles capas del preview.
  - mapboxMap!.style.setStyleLayerProperty:
    - Input: BUS_TOOLTIP_LAYER_ID (String) O layerId (String), 'icon-offset' (String), [0.0, -5.0] (List<double>)
    - Condición: Llamada si `mapboxMap` no es nulo y la capa correspondiente existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### \_tryUpdatePreviewApproachLine

- Nombre de la funcion
  \_tryUpdatePreviewApproachLine
- Input que recibe esta funcion (cada parametro y sus types)
  geoJsonFeatureCollection: Map<String, dynamic>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleSourceExists:
    - Input: sourceId (String)
    - Condición: Llamada dentro de un bucle que itera sobre posibles sourceIds de líneas de aproximación del preview. Se llama el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.getSource:
    - Input: sourceId (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existe. Se llama el 100% de las veces si se cumple esta condición.
  - (GeoJsonSource).updateGeoJSON:
    - Input: json.encode(geoJsonFeatureCollection) (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existente es de tipo `GeoJsonSource`. Se llama el 100% de las veces si se cumple esta condición.

### \_updateOrCreateActiveTripApproachLine

- Nombre de la funcion
  \_updateOrCreateActiveTripApproachLine
- Input que recibe esta funcion (cada parametro y sus types)
  geoJsonFeatureCollection: Map<String, dynamic>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleSourceExists:
    - Input: BUS_APPROACH_LINE_SOURCE_ID (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.getSource:
    - Input: BUS_APPROACH_LINE_SOURCE_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existe. Se llama el 100% de las veces si se cumple esta condición.
  - (GeoJsonSource).updateGeoJSON:
    - Input: json.encode(geoJsonFeatureCollection) (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existente es de tipo `GeoJsonSource`. Se llama el 100% de las veces si se cumple esta condición.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerSource:
    - Input: BUS_APPROACH_LINE_SOURCE_ID (String)
    - Condición: Llamada si la fuente no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.styleLayerExists (borde):
    - Input: BUS_APPROACH_LINE_BORDER_LAYER_ID (String)
    - Condición: Llamada si la fuente no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.addLayer (borde):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada si la fuente no existe, se agregó, y la capa de borde no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerLayer (borde):
    - Input: BUS_APPROACH_LINE_BORDER_LAYER_ID (String)
    - Condición: Llamada si la capa de borde no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.styleLayerExists (principal):
    - Input: BUS_APPROACH_LINE_LAYER_ID (String)
    - Condición: Llamada si la fuente no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.addLayer (principal):
    - Input: LineLayer(...) (Layer)
    - Condición: Llamada si la fuente no existe, se agregó, la capa principal no existe, Y la capa de borde ya fue manejada. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapManager.registerLayer (principal):
    - Input: BUS_APPROACH_LINE_LAYER_ID (String)
    - Condición: Llamada si la capa principal no existe y se agregó. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

## `lib/ui/initial_phase_view.dart`

### \_displayStops

- Nombre de la funcion
  \_displayStops
- Input que recibe esta funcion (cada parametro y sus types)
  stops: List<InfoParadaEnMapa>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.getLayer:
    - Input: STOPS_LAYER_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, y `stops` está vacío O si `stops` no está vacío y se verifica si la capa existe. Se llama el 100% de las veces si se cumplen las condiciones principales (mapa e iconos cargados).
  - mapboxMap!.style.removeStyleLayer:
    - Input: STOPS_LAYER_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, `stops` está vacío, y la capa existente no es nula. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.getSource:
    - Input: STOPS_SOURCE_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, y `stops` está vacío O si `stops` no está vacío y se verifica/obtiene la fuente. Se llama el 100% de las veces si se cumplen las condiciones principales (mapa e iconos cargados).
  - mapboxMap!.style.removeStyleSource:
    - Input: STOPS_SOURCE_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, `stops` está vacío, y la fuente existente no es nula. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.styleSourceExists:
    - Input: STOPS_SOURCE_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, y `stops` no está vacío. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.addSource:
    - Input: GeoJsonSource(...) (Source)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, `stops` no está vacío, y la fuente no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - (GeoJsonSource).updateGeoJSON:
    - Input: json.encode(geoJsonSource) (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, `stops` no está vacío, la fuente existe, y la fuente obtenida es de tipo `GeoJsonSource`. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.styleLayerExists:
    - Input: STOPS_LAYER_ID (String)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, y `stops` no está vacío. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
  - mapboxMap!.style.addLayer:
    - Input: SymbolLayer(...) (Layer)
    - Condición: Llamada si `mapboxMap` no es nulo, `_iconsLoaded` es verdadero, `stops` no está vacío, la fuente existe (después de crearla o actualizarla), y la capa no existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

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
  - \_cleanup.clearRoutePreview:
    - Input: Ninguno
    - Condición: Llamada si `_currentPreviewOptionId` es diferente a `route.idOpcion`. Se llama el 100% de las veces si se cumple esta condición.
  - \_routeRenderer.renderRoutePreview:
    - Input: route (OpcionDeRutaMostrable)
    - Condición: Llamada si `needsRedraw` es verdadero O `_activeLayers` está vacío. Se llama el 100% de las veces si se cumple alguna de estas condiciones.
  - \_busRealtime.displayRealtimeBusesForPreview:
    - Input: route (OpcionDeRutaMostrable)
    - Condición: Llamada si `needsRedraw` es verdadero O `_activeLayers` está vacío. Se llama el 100% de las veces si se cumple alguna de estas condiciones.
  - \_cameraController.zoomToRoutePreview:
    - Input: route (OpcionDeRutaMostrable)
    - Condición: Llamada el 100% de las veces después de las llamadas condicionales a `_routeRenderer.renderRoutePreview` y `_busRealtime.displayRealtimeBusesForPreview`.

### showActiveTrip

- Nombre de la funcion
  showActiveTrip
- Input que recibe esta funcion (cada parametro y sus types)
  activeTripState: EstadoFaseViajeActivo
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - initialize:
    - Input: Ninguno
    - Condición: Llamada si `_isInitialized` es falso. Se llama el 100% de las veces si se cumple esta condición.
  - \_convertPreviewToActiveTrip:
    - Input: activeTripState (EstadoFaseViajeActivo)
    - Condición: Llamada si `_currentPhase` es 'route_preview'. Se llama el 100% de las veces si se cumple esta condición.
  - \_cleanup.clearAll:
    - Input: Ninguno
    - Condición: Llamada si `_currentPhase` NO es 'route_preview'. Se llama el 100% de las veces si se cumple esta condición.
  - \_routeRenderer.renderActiveTrip:
    - Input: activeTripState.tramosDelViaje (List<TramoViajeMostrable>)
    - Condición: Llamada si `_currentPhase` NO es 'route_preview'. Se llama el 100% de las veces si se cumple esta condición.
  - \_busRealtime.initializeActiveTripTracking:
    - Input: activeTripState (EstadoFaseViajeActivo)
    - Condición: Llamada si `_currentPhase` NO es 'route_preview'. Se llama el 100% de las veces si se cumple esta condición.

### updateCurrentLeg

- Nombre de la funcion
  updateCurrentLeg
- Input que recibe esta funcion (cada parametro y sus types)
  legIndex: int
  tramos: List<TramoViajeMostrable>
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_routeRenderer.highlightCurrentLeg:
    - Input: legIndex (int), tramos (List<TramoViajeMostrable>)
    - Condición: Llamada el 100% de las veces si `_currentPhase` es 'active_trip'.
  - \_cameraController.zoomToCurrentLeg:
    - Input: legIndex (int), tramos (List<TramoViajeMostrable>)
    - Condición: Llamada el 100% de las veces si `_currentPhase` es 'active_trip'.
  - \_busRealtime.updateBusTrackingForLeg:
    - Input: legIndex (int), tramos (List<TramoViajeMostrable>)
    - Condición: Llamada el 100% de las veces si `_currentPhase` es 'active_trip'.

### updateBusPosition

- Nombre de la funcion
  updateBusPosition
- Input que recibe esta funcion (cada parametro y sus types)
  position: Coordenada
  etaMinutes: int
  isRealTime: bool
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_busRealtime.updateBusPosition:
    - Input: position (Coordenada), etaMinutes (int), isRealTime (bool)
    - Condición: Llamada el 100% de las veces.

### showInitialPhase

- Nombre de la funcion
  showInitialPhase
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - initialize:
    - Input: Ninguno
    - Condición: Llamada si `_isInitialized` es falso. Se llama el 100% de las veces si se cumple esta condición.
  - \_cleanup.clearAll:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de la posible llamada a `initialize`.
  - \_routeRenderer.renderBusStops:
    - Input: Ninguno
    - Condición: Esta llamada está comentada con un TODO, por lo que actualmente no se llama.

### \_convertPreviewToActiveTrip

- Nombre de la funcion
  \_convertPreviewToActiveTrip
- Input que recibe esta funcion (cada parametro y sus types)
  activeTripState: EstadoFaseViajeActivo
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_busRealtime.stopPreviewAnimations:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Se llama dentro de un bloque `try`.
  - \_cleanup.clearPreviewBusElements:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Se llama dentro de un bloque `try`.
  - \_routeRenderer.convertPreviewStylesToActiveTrip:
    - Input: activeTripState.tramosDelViaje (List<TramoViajeMostrable>)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Se llama dentro de un bloque `try`.
  - \_busRealtime.initializeActiveTripTracking:
    - Input: activeTripState (EstadoFaseViajeActivo)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Se llama dentro de un bloque `try`. También llamada en el bloque `catch` como fallback.
  - \_cameraController.zoomToActiveTrip:
    - Input: activeTripState.tramosDelViaje (List<TramoViajeMostrable>)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo. Se llama dentro de un bloque `try`.
  - \_cleanup.clearAll:
    - Input: Ninguno
    - Condición: Llamada en el bloque `catch` si ocurre un error en el bloque `try`, como fallback. Se llama el 100% de las veces si se ejecuta el bloque `catch`.
  - \_routeRenderer.renderActiveTrip:
    - Input: activeTripState.tramosDelViaje (List<TramoViajeMostrable>)
    - Condición: Llamada en el bloque `catch` si ocurre un error en el bloque `try`, como fallback. Se llama el 100% de las veces si se ejecuta el bloque `catch`.

### clearAll

- Nombre de la funcion
  clearAll
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_cleanup.clearAll:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces.

## `lib/map_manager/map_cleanup.dart`

Este módulo contiene funciones para limpiar elementos dibujados en el mapa.

### clearAll

- Nombre de la funcion
  clearAll
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - clearRoutePreview:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - clearActiveTrip:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - clearInitialPhaseElements:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapManager.clearRegistrations:
    - Input: Ninguno
    - Condición: Llamada el 100% de las veces después de las llamadas a `clear...`.

### clearRoutePreview

- Nombre de la funcion
  clearRoutePreview
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_clearLayersWithPrefix:
    - Input: prefix (String, varios valores como 'preview-walk-layer-', 'preview-bus-layer-', etc.)
    - Condición: Llamada varias veces con diferentes prefijos para limpiar capas dinámicas. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_clearSourcesWithPrefix:
    - Input: prefix (String, varios valores como 'preview-walk-source-', 'preview-bus-source-', etc.)
    - Condición: Llamada varias veces con diferentes prefijos para limpiar fuentes dinámicas. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_removeLayerSafely:
    - Input: layerId (String, varios valores de `previewLayerIds`)
    - Condición: Llamada dentro de un bucle que itera sobre una lista de IDs de capas predefinidos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_removeSourceSafely:
    - Input: sourceId (String, varios valores de `previewSourceIds`)
    - Condición: Llamada dentro de un bucle que itera sobre una lista de IDs de fuentes predefinidos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.

### clearActiveTrip

- Nombre de la funcion
  clearActiveTrip
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_clearLayersWithPrefix:
    - Input: prefix (String, varios valores como 'active-walk-layer-', 'active-bus-layer-', etc.)
    - Condición: Llamada varias veces con diferentes prefijos para limpiar capas dinámicas. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_clearSourcesWithPrefix:
    - Input: prefix (String, varios valores como 'active-walk-source-', 'active-bus-source-', etc.)
    - Condición: Llamada varias veces con diferentes prefijos para limpiar fuentes dinámicas. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_removeLayerSafely:
    - Input: layerId (String, varios valores de `activeTripLayerIds`)
    - Condición: Llamada dentro de un bucle que itera sobre una lista de IDs de capas predefinidos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_removeSourceSafely:
    - Input: sourceId (String, varios valores de `activeTripSourceIds`)
    - Condición: Llamada dentro de un bucle que itera sobre una lista de IDs de fuentes predefinidos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.

### clearInitialPhaseElements

- Nombre de la funcion
  clearInitialPhaseElements
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_removeLayerSafely:
    - Input: layerId (String, varios valores de `initialPhaseLayerIds`)
    - Condición: Llamada dentro de un bucle que itera sobre una lista de IDs de capas predefinidos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_removeSourceSafely:
    - Input: sourceId (String, varios valores de `initialPhaseSourceIds`)
    - Condición: Llamada dentro de un bucle que itera sobre una lista de IDs de fuentes predefinidos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.

### clearPreviewBusElements

- Nombre de la funcion
  clearPreviewBusElements
- Input que recibe esta funcion (cada parametro y sus types)
  Esta función no recibe parámetros.
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_clearLayersWithPrefix:
    - Input: prefix (String, 'preview-bus-realtime-layer-' o 'preview-bus-tooltip-layer-' o 'preview-bus-realtime-layer-eta*' o 'preview-bus-tooltip-layer-eta*')
    - Condición: Llamada varias veces con prefijos específicos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.
  - \_clearSourcesWithPrefix:
    - Input: prefix (String, 'preview-bus-realtime-source-' o 'preview-bus-realtime-source-eta\_')
    - Condición: Llamada varias veces con prefijos específicos. Cada llamada se realiza el 100% de las veces si `mapboxMap` no es nulo.

### \_clearLayersWithPrefix

- Nombre de la funcion
  \_clearLayersWithPrefix
- Input que recibe esta funcion (cada parametro y sus types)
  prefix: String
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_removeLayerSafely:
    - Input: layerId (String)
    - Condición: Llamada dentro de un bucle que itera sobre las capas registradas en `mapManager.activeLayers` que empiezan con el prefijo dado. También se llama dentro de otro bucle para intentar remover IDs con índices numéricos comunes (0-9). Cada llamada se realiza si `mapboxMap` no es nulo.

### \_clearSourcesWithPrefix

- Nombre de la funcion
  \_clearSourcesWithPrefix
- Input que recibe esta funcion (cada parametro y sus types)
  prefix: String
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - \_removeSourceSafely:
    - Input: sourceId (String)
    - Condición: Llamada dentro de un bucle que itera sobre las fuentes registradas en `mapManager.activeSources` que empiezan con el prefijo dado. También se llama dentro de otro bucle para intentar remover IDs con índices numéricos comunes (0-9). Cada llamada se realiza si `mapboxMap` no es nulo.

### \_removeLayerSafely

- Nombre de la funcion
  \_removeLayerSafely
- Input que recibe esta funcion (cada parametro y sus types)
  layerId: String
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleLayerExists:
    - Input: layerId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.removeStyleLayer:
    - Input: layerId (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la capa existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.

### \_removeSourceSafely

- Nombre de la funcion
  \_removeSourceSafely
- Input que recibe esta funcion (cada parametro y sus types)
  sourceId: String
- Si esta funcion llama a otra funcion o otras funciones, debes listar las funciones a las que llama y que input le envia a cada una de estas, para cada una de estas funciones debes indicar si es llamada el 100% de las veces, de lo contrario si esta llamada es bajo condicionales debes indicar de manera precisa sobre que condiciones, incluyendo si hay condiciones anidadas, quiero que conserves el 100% de la informacion sobre en que caso se llama a cada funcion
  - mapboxMap!.style.styleSourceExists:
    - Input: sourceId (String)
    - Condición: Llamada el 100% de las veces si `mapboxMap` no es nulo.
  - mapboxMap!.style.removeStyleSource:
    - Input: sourceId (String)
    - Condición: Llamada si `mapboxMap` no es nulo y la fuente existe. Se llama el 100% de las veces si se cumplen estas condiciones anidadas.
