## Funciones en lib/ui/overlays/route_options_overlay.dart

### initState

- **Input:** Ninguno.
- **Llama a:**
  - `super.initState()`: Llamada el 100% de las veces. Input: Ninguno.
  - `_initializeCarousel()`: Llamada el 100% de las veces (a través de `WidgetsBinding.instance.addPostFrameCallback`). Input: Ninguno.

### \_initializeCarousel

- **Input:** Ninguno.
- **Llama a:**
  - `ref.read(appLogicProvider)`: Llamada el 100% de las veces. Input: `appLogicProvider`.
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_showInitialPreview()`: Llamada si `routeOptionsState != null && routeOptionsState.opcionesDeRuta.isNotEmpty`. Input: Ninguno.

### \_showInitialPreview

- **Input:** Ninguno.
- **Llama a:**
  - `Future.delayed(...).then(...)`: Se programan tres llamadas a `_showRoutePreview` con diferentes delays.
    - `_showRoutePreview(_currentOptionIndex)`: Llamada si `mounted` es true. Input: `_currentOptionIndex` (int). Esto ocurre tres veces con delays de 100ms, 800ms y 1500ms.
  - `print`: Llamada el 100% de las veces. Input: String.

### didUpdateWidget

- **Input:** `oldWidget` (RouteOptionsOverlay).
- **Llama a:**
  - `super.didUpdateWidget(oldWidget)`: Llamada el 100% de las veces. Input: `oldWidget` (RouteOptionsOverlay).
  - `_showRoutePreview(_currentOptionIndex)`: Llamada si `oldWidget.mapboxMap != widget.mapboxMap` y `mounted` es true (después de un delay de 500ms). Input: `_currentOptionIndex` (int).
  - `WidgetsBinding.instance.addPostFrameCallback(...)`: Llamada si `!_hasInitializedRecommendedOption` es true. Input: Callback function.
    - Dentro del callback, se llama a:
      - `ref.read(appLogicProvider)`: Llamada el 100% de las veces dentro del callback. Input: `appLogicProvider`.
      - `print`: Llamada el 100% de las veces dentro del callback. Input: String.
      - `setState(...)`: Llamada si `backendSelectedIndex >= 0 && backendSelectedIndex != _currentOptionIndex`. Input: Callback function que actualiza `_currentOptionIndex`.
      - `_pageController.animateToPage(...)`: Llamada si `_pageController.hasClients` es true y `backendSelectedIndex >= 0 && backendSelectedIndex != _currentOptionIndex`. Input: `_currentOptionIndex` (int), `duration` (Duration), `curve` (Curve).
      - `_showRoutePreview(_currentOptionIndex)`: Llamada el 100% de las veces dentro del callback (después de un delay de 400ms) si `mounted` es true. Input: `_currentOptionIndex` (int).

### dispose

- **Input:** Ninguno.
- **Llama a:**
  - `_pageController.dispose()`: Llamada el 100% de las veces. Input: Ninguno.
  - `super.dispose()`: Llamada el 100% de las veces. Input: Ninguno.

### \_showRoutePreview

- **Input:** `optionIndex` (int).
- **Llama a:**
  - `ref.read(appLogicProvider)`: Llamada el 100% de las veces. Input: `appLogicProvider`.
  - `print`: Llamada el 100% de las veces. Input: String.
  - `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar(option.idOpcion)`: Llamada si `routeOptionsState` no es null y `optionIndex` está dentro del rango válido. Se llama en el notifier obtenido de `ref.read(appLogicProvider.notifier)`. Input: `option.idOpcion` (tipo de dato de `idOpcion`).
  - `_displayRoutePreview(option)`: Llamada si `routeOptionsState` no es null y `optionIndex` está dentro del rango válido. Input: `option` (OpcionDeRutaMostrable).

### \_displayRoutePreview

- **Input:** `ruta` (OpcionDeRutaMostrable).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `ref.read(mapManagerProvider)`: Llamada el 100% de las veces. Input: `mapManagerProvider`.
  - `MapManager.showRoutePreview(ruta)`: Llamada si `mapManager` no es null (dentro de un bloque `try`). Se llama en la instancia obtenida de `ref.read(mapManagerProvider)`. Input: `ruta` (OpcionDeRutaMostrable).

### build

- **Input:** `context` (BuildContext).
- **Llama a:**
  - `ref.watch(appLogicProvider)`: Llamada el 100% de las veces. Input: `appLogicProvider`.
  - `ref.read(appLogicProvider.notifier)`: Llamada el 100% de las veces. Input: `appLogicProvider.notifier`.
  - `ref.listen(...)`: Llamada el 100% de las veces para configurar un listener.
    - Dentro del listener, se llama a:
      - `print`: Llamada el 100% de las veces dentro del listener. Input: String.
      - `ref.read(appLogicProvider)`: Llamada si `next` no es null. Input: `appLogicProvider`.
      - `setState(...)`: Llamada si `backendSelectedIndex >= 0` y `backendSelectedIndex != _currentOptionIndex` y `mounted` es true (dentro de `WidgetsBinding.instance.addPostFrameCallback`). Input: Callback function que actualiza `_currentOptionIndex`.
      - `_pageController.animateToPage(...)`: Llamada si `_pageController.hasClients` es true y `backendSelectedIndex >= 0` y `backendSelectedIndex != _currentOptionIndex` y `mounted` es true. Input: `_currentOptionIndex` (int), `duration` (Duration), `curve` (Curve).
      - `_displayRoutePreview(option)`: Llamada si `backendSelectedIndex >= 0` y `backendSelectedIndex != _currentOptionIndex` y `mounted` es true. Input: `option` (OpcionDeRutaMostrable).
  - `_buildEmptyState(appLogic)`: Llamada si `routeOptionsState == null || routeOptionsState.opcionesDeRuta.isEmpty`. Input: `appLogic` (AppLogicNotifier).
  - `_buildHeader(appLogic, isSmallScreen)`: Llamada si `routeOptionsState` no es null y `routeOptionsState.opcionesDeRuta` no está vacío. Input: `appLogic` (AppLogicNotifier), `isSmallScreen` (bool).
  - `PageView.builder(...)`: Llamada si `routeOptionsState` no es null y `routeOptionsState.opcionesDeRuta` no está vacío. El `onPageChanged` callback llama a:
    - `setState(...)`: Llamada el 100% de las veces en `onPageChanged`. Input: Callback function que actualiza `_currentOptionIndex`.
    - `_showRoutePreview(index)`: Llamada el 100% de las veces en `onPageChanged`. Input: `index` (int).
      El `itemBuilder` callback llama a:
    - `_buildModernRouteCard(option, index == _currentOptionIndex, isSmallScreen)`: Llamada el 100% de las veces en `itemBuilder`. Input: `option` (OpcionDeRutaMostrable), `index == _currentOptionIndex` (bool), `isSmallScreen` (bool).
  - `_buildFooter(options, appLogic, isSmallScreen)`: Llamada si `routeOptionsState` no es null y `routeOptionsState.opcionesDeRuta` no está vacío. Input: `options` (List<OpcionDeRutaMostrable>), `appLogic` (AppLogicNotifier), `isSmallScreen` (bool).

### \_buildHeader

- **Input:** `appLogic` (AppLogicNotifier), `isSmallScreen` (bool).
- **Llama a:**
  - `Theme.of(context).textTheme.titleLarge?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `Theme.of(context).textTheme.bodySmall?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `AppLogicNotifier.usuarioCanceloBusquedaOSeleccionRuta()`: Llamada cuando se presiona el `GestureDetector`. Se llama en la instancia `appLogic`. Input: Ninguno.

### \_buildModernRouteCard

- **Input:** `option` (OpcionDeRutaMostrable), `isSelected` (bool), `isSmallScreen` (bool).
- **Llama a:**
  - `_formatDuration(option.duracionTotalSegundos)`: Llamada el 100% de las veces. Input: `option.duracionTotalSegundos` (int).
  - `Theme.of(context).textTheme.headlineMedium?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `TimeOfDay.fromDateTime(option.horaLlegadaEstimada).format(context)`: Llamada el 100% de las veces. Input: `option.horaLlegadaEstimada` (DateTime), `context` (BuildContext).
  - `Theme.of(context).textTheme.bodyMedium?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `Theme.of(context).textTheme.labelSmall?.copyWith(...)`: Llamada si `option.esRecomendada` es true. Input: Propiedades de estilo.
  - `_buildModernModeIcons(context, option.secuenciaModosIconos, isSelected, isSmallScreen)`: Llamada el 100% de las veces. Input: `context` (BuildContext), `option.secuenciaModosIconos` (List<TipoTramoViaje>), `isSelected` (bool), `isSmallScreen` (bool).
  - `Theme.of(context).textTheme.bodyMedium?.copyWith(...)`: Llamada condicionalmente para mostrar el ETA o la distancia de caminata. Input: Propiedades de estilo.

### \_buildModernModeIcons

- **Input:** `context` (BuildContext), `modos` (List<TipoTramoViaje>), `isSelected` (bool), `isSmallScreen` (bool).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_buildFooter

- **Input:** `options` (List<OpcionDeRutaMostrable>), `appLogic` (AppLogicNotifier), `isSmallScreen` (bool).
- **Llama a:**
  - `AppLogicNotifier.confirmarOpcionDeRutaEIniciarViaje(options[_currentOptionIndex].idOpcion)`: Llamada cuando se presiona el `ElevatedButton`. Se llama en la instancia `appLogic`. Input: `options[_currentOptionIndex].idOpcion` (tipo de dato de `idOpcion`).
  - `Theme.of(context).textTheme.titleSmall?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.

### \_buildEmptyState

- **Input:** `appLogic` (AppLogicNotifier).
- **Llama a:**
  - `Theme.of(context).textTheme.titleMedium?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `Theme.of(context).textTheme.bodySmall?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `AppLogicNotifier.usuarioCanceloBusquedaOSeleccionRuta()`: Llamada cuando se presiona el `ElevatedButton`. Se llama en la instancia `appLogic`. Input: Ninguno.

### \_formatDuration

- **Input:** `totalSeconds` (int).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

## Funciones en lib/backend/providers/app_logic_provider.dart

### cargarParadasInicialesDelViewport

- **Input:** `centroActual` (Coordenada), `zoomActual` (double).
- **Llama a:**
  - `_montevideoApiService.getAllStops()`: Llamada si `_todasLasParadas` es null o está vacío. Input: Ninguno.
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `try`). Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si ocurre una excepción. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `catch`). Input: Parámetros nombrados para actualizar el estado.

### viewportDelMapaCambio

- **Input:** `nuevoCentro` (Coordenada), `nuevoZoom` (double), `esquinaSupIzq` (Coordenada), `esquinaInfDer` (Coordenada).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `cargarParadasInicialesDelViewport(nuevoCentro, nuevoZoom)`: Llamada el 100% de las veces. Input: `nuevoCentro` (Coordenada), `nuevoZoom` (double).

### solicitarInformacionDetalladaParada

- **Input:** `idParada` (String).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state.datosFaseInicial!.paradasVisiblesEnMapa.firstWhereOrNull(...)`: Llamada si `state.datosFaseInicial` no es null (dentro de un bloque `try`). Input: Callback function.
  - `print`: Llamada si ocurre una excepción al buscar la parada visible. Input: String.
  - `print`: Llamada si `paradaInfo` es null. Input: String.
  - `state = state.copyWith(...)`: Llamada si `paradaInfo` es null y `mounted` es true. Input: Parámetros nombrados para actualizar el estado.
  - `state = state.copyWith(...)`: Llamada el 100% de las veces después de la verificación inicial. Input: Parámetros nombrados para actualizar el estado.
  - `_montevideoApiService.getStopDetailsWithEta(...)`: Llamada el 100% de las veces dentro del bloque `try`. Input: `idParada` (String), `paradaInfo.nombre` (String), `paradaInfo.posicion` (Coordenada).
  - `print`: Llamada si `detalles` no es null y `mounted` es true. Input: String.
  - `state = state.copyWith(...)`: Llamada si `detalles` no es null y `mounted` es true. Input: Parámetros nombrados para actualizar el estado.
  - `state = state.copyWith(...)`: Llamada si `detalles` es null y `mounted` es true. Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si `detalles` es null. Input: String.
  - `print`: Llamada si ocurre una excepción al solicitar detalles. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `catch`). Input: Parámetros nombrados para actualizar el estado.

### iniciarBusquedaDeRutas

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada si `state.puntoOrigenParaBusqueda` o `state.puntoDestinoParaBusqueda` son null. Input: String.
  - `state = state.copyWith(...)`: Llamada si `state.puntoOrigenParaBusqueda` o `state.puntoDestinoParaBusqueda` son null y `mounted` es true. Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada el 100% de las veces después de la verificación inicial. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true (después de la verificación inicial). Input: Parámetros nombrados para actualizar el estado.
  - `_itineraryPlanningService.planRoute(...)`: Llamada el 100% de las veces dentro del bloque `try`. Input: `origenCoords` (Coordenada), `origenNombre` (String), `destinoCoords` (Coordenada), `destinoNombre` (String).
  - `print`: Llamada el 100% de las veces si no hay excepción. Input: String.
  - `opciones.firstWhere(...)`: Llamada si `opciones.isNotEmpty` (dentro del bloque `try`). Input: Callback function (`(opt) => opt.esRecomendada`), `orElse` callback function.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `try`, después de obtener opciones). Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si no hay excepción y `mounted` es true. Input: String.
  - `print`: Llamada si ocurre una excepción. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `catch`). Input: Parámetros nombrados para actualizar el estado.

### usuarioCanceloBusquedaOSeleccionRuta

- **Input:** Ninguno.
- **Llama a:**
  - `_seguimientoBusTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `AppUiState.inicial()`: Llamada si `mounted` es true. Input: Ninguno.
  - `state = AppUiState.inicial().copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si `mounted` es true. Input: String.

### usuarioSeleccionoTramoDelViaje

- **Input:** `idViajeActivo` (String), `idTramoSeleccionado` (String).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `print`: Llamada si `state.faseActual` no es `FaseApp.VIAJE_ACTIVO_EN_CURSO` o datos de viaje son null o ID no coincide. Input: String.
  - `state.datosFaseViajeActivo!.tramosDelViaje.firstWhere(...)`: Llamada si las condiciones iniciales son verdaderas (dentro de un bloque `try`). Input: Callback function (`(t) => t.idTramo == idTramoSeleccionado`).
  - `print`: Llamada si ocurre una excepción al buscar el tramo. Input: String.
  - `print`: Llamada si `tramoSeleccionado.tipo` es `TipoTramoViaje.VIAJE_EN_BUS` y existen datos de parada/línea. Input: String.
  - `iniciarSeguimientoBusTiempoReal(...)`: Llamada si `tramoSeleccionado.tipo` es `TipoTramoViaje.VIAJE_EN_BUS` y existen datos de parada/línea. Input: `idViajeActivo` (String), `idTramoBus` (String).
  - `print`: Llamada si `tramoSeleccionado.tipo` NO es `TipoTramoViaje.VIAJE_EN_BUS` o faltan datos. Input: String.
  - `detenerSeguimientoBusTiempoReal()`: Llamada si `tramoSeleccionado.tipo` NO es `TipoTramoViaje.VIAJE_EN_BUS` o faltan datos. Input: Ninguno.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true y `state.datosFaseViajeActivo` no es null (después de llamar a `detenerSeguimientoBusTiempoReal`). Input: Parámetros nombrados para actualizar el estado.

### usuarioDeseleccionoInformacionDeParada

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### limpiarMensajeDeErrorGlobal

- **Input:** Ninguno.
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada si `mounted` es true y `state.mensajeErrorGlobal` no es null. Input: Parámetros nombrados para actualizar el estado.

### usuarioEscribioEnCampoOrigen

- **Input:** `textoQuery` (String).
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada el 100% de las veces. Input: Parámetros nombrados para actualizar el estado.
  - `_origenDebounceTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `Timer(...)`: Llamada el 100% de las veces para configurar un timer.
    - Dentro del callback del timer, se llama a:
      - `state = state.copyWith(...)`: Llamada si `!mounted` es false y `textoQuery.isEmpty` es true. Input: Parámetros nombrados para actualizar el estado.
      - `_geocodingService.fetchSuggestions(...)`: Llamada si `!mounted` es false y `textoQuery.isEmpty` es false (dentro de un bloque `try`). Input: `textoQuery` (String), `proximity` (Coordenada o null).
      - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `try` del timer, después de obtener sugerencias). Input: Parámetros nombrados para actualizar el estado.
      - `print`: Llamada si ocurre una excepción. Input: String.
      - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `catch` del timer). Input: Parámetros nombrados para actualizar el estado.

### usuarioEscribioEnCampoDestino

- **Input:** `textoQuery` (String).
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada el 100% de las veces. Input: Parámetros nombrados para actualizar el estado.
  - `_destinoDebounceTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `Timer(...)`: Llamada el 100% de las veces para configurar un timer.
    - Dentro del callback del timer, se llama a:
      - `state = state.copyWith(...)`: Llamada si `!mounted` es false y `textoQuery.isEmpty` es true. Input: Parámetros nombrados para actualizar el estado.
      - `_geocodingService.fetchSuggestions(...)`: Llamada si `!mounted` es false y `textoQuery.isEmpty` es false (dentro de un bloque `try`). Input: `textoQuery` (String), `proximity` (Coordenada o null).
      - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `try` del timer, después de obtener sugerencias). Input: Parámetros nombrados para actualizar el estado.
      - `print`: Llamada si ocurre una excepción. Input: String.
      - `state = state.copyWith(...)`: Llamada si `mounted` es true (dentro del bloque `catch` del timer). Input: Parámetros nombrados para actualizar el estado.

### seleccionarSugerenciaOrigen

- **Input:** `sugerencia` (SugerenciaLugar).
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### seleccionarSugerenciaDestino

- **Input:** `sugerencia` (SugerenciaLugar).
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### limpiarSugerenciasOrigen

- **Input:** Ninguno.
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada el 100% de las veces. Input: Parámetros nombrados para actualizar el estado.

### limpiarSugerenciasDestino

- **Input:** Ninguno.
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada el 100% de las veces. Input: Parámetros nombrados para actualizar el estado.

### limpiarOrigenSeleccionado

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### limpiarDestinoSeleccionado

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### intercambiarOrigenYDestino

- **Input:** Ninguno.
- **Llama a:**
  - `state = nuevoEstado`: Llamada si `mounted` es true. Input: `nuevoEstado` (AppUiState).
  - `state.copyWith(...)`: Llamada si `mounted` es true para crear el nuevo estado. Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si `mounted` es true. Input: String.

### seleccionarOpcionDeRutaParaPrevisualizar

- **Input:** `idOpcionRuta` (String).
- **Llama a:**
  - `state.datosFaseOpcionesRuta?.opcionesDeRuta.firstWhereOrNull(...)`: Llamada el 100% de las veces si `state.datosFaseOpcionesRuta` no es null. Input: Callback function (`(opt) => opt.idOpcion == idOpcionRuta`).
  - `todosLosPuntosDeLaRuta.addAll(...)`: Llamada si `tramo.geometriaPolilinea` no es null (dentro de un bucle). Input: `tramo.geometriaPolilinea` (List<Coordenada>).
  - `todosLosPuntosDeLaRuta.add(...)`: Llamada si `tramo.posicionPunto` no es null (dentro de un bucle). Input: `tramo.posicionPunto` (Coordenada).
  - `state = state.copyWith(...)`: Llamada si `mounted` es true y `todosLosPuntosDeLaRuta` no está vacío. Input: Parámetros nombrados para actualizar el estado.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true y `todosLosPuntosDeLaRuta` está vacío. Input: Parámetros nombrados para actualizar el estado.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true y `opcionSeleccionada` es null. Input: Parámetros nombrados para actualizar el estado.

### limpiarSeleccionDeRutaPrevisualizada

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### confirmarOpcionDeRutaEIniciarViaje

- **Input:** `idOpcionSeleccionada` (String).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state.datosFaseOpcionesRuta!.opcionesDeRuta.firstWhere(...)`: Llamada si `state.faseActual` es `FaseApp.MOSTRANDO_OPCIONES_RUTA`, `state.datosFaseOpcionesRuta` no es null y `state.idOpcionRutaPrevisualizada` coincide con `idOpcionSeleccionada` (dentro de un bloque `try`). Input: Callback function (`(opt) => opt.idOpcion == idOpcionSeleccionada`).
  - `print`: Llamada si `opcionConfirmada` es null (ocurre si la opción no se encuentra). Input: String.
  - `state = state.copyWith(...)`: Llamada si `opcionConfirmada` es null. Input: Parámetros nombrados para actualizar el estado.
  - `state = state.copyWith(...)`: Llamada si `opcionConfirmada` no es null. Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si `opcionConfirmada` no es null. Input: String.
  - `opcionConfirmada.tramosParaPreview.firstWhere(...)`: Llamada si `opcionConfirmada` no es null. Input: Callback function (`(tramo) => tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS`), `orElse` callback function.
  - `iniciarSeguimientoBusTiempoReal(...)`: Llamada si `primerTramoBus.idTramo` no es "placeholder_no_bus_tramo". Input: `idViajeActivo` (String, `opcionConfirmada.idOpcion`), `idTramoBus` (String, `primerTramoBus.idTramo`).
  - `print`: Llamada si las condiciones iniciales NO son verdaderas. Input: String.
  - `state = state.copyWith(...)`: Llamada si las condiciones iniciales NO son verdaderas. Input: Parámetros nombrados para actualizar el estado.

### iniciarSeguimientoBusTiempoReal

- **Input:** `idViajeActivo` (String), `idTramoBus` (String).
- **Llama a:**
  - `print`: Llamada si las condiciones iniciales de fase y datos de viaje no se cumplen. Input: String.
  - `print`: Llamada el 100% de las veces si las condiciones iniciales se cumplen. Input: String.
  - `_seguimientoBusTimer?.cancel()`: Llamada el 100% de las veces si las condiciones iniciales se cumplen. Input: Ninguno.
  - `state.datosFaseViajeActivo!.tramosDelViaje.firstWhere(...)`: Llamada si las condiciones iniciales se cumplen. Input: Callback function (`(t) => t.idTramo == idTramoBus && t.tipo == TipoTramoViaje.VIAJE_EN_BUS`), `orElse` callback function.
  - `print`: Llamada si el tramo target no se encuentra. Input: String.
  - `print`: Llamada si faltan datos en el tramo target. Input: String.
  - `state = state.copyWith(...)`: Llamada si faltan datos en el tramo target y `mounted` es true. Input: Parámetros nombrados para actualizar el estado.
  - `state = state.copyWith(...)`: Llamada el 100% de las veces si las condiciones iniciales se cumplen y hay datos suficientes. Input: Parámetros nombrados para actualizar el estado.
  - `fetchEta()`: Llamada el 100% de las veces al final de la función (primera ejecución inmediata). Input: Ninguno.
  - `Timer.periodic(...)`: Llamada si `mounted` es true y `state.datosFaseViajeActivo?.idTramoBusEnSeguimiento == idTramoBus` (después de la primera ejecución de `fetchEta`). Input: `duration` (Duration), callback function (`(_) => fetchEta()`).
    - Dentro del callback `fetchEta`, se llama a:
      - `_seguimientoBusTimer?.cancel()`: Llamada si `!mounted` o el ID del tramo en seguimiento ha cambiado.
      - `print`: Llamada el 100% de las veces dentro de `fetchEta`. Input: String.
      - `_montevideoApiService.getStopDetailsWithEta(...)`: Llamada el 100% de las veces dentro del bloque `try` de `fetchEta`. Input: `idParadaOrigen` (String), `nombreParadaOrigen` (String), `coordsParadaOrigen` (Coordenada).
      - `detallesParada.etas.firstWhere(...)`: Llamada si `detallesParada` no es null, `!mounted` es false y el ID del tramo en seguimiento no ha cambiado (dentro de un bloque `try`). Input: Callback function (`(eta) => eta.linea == lineaBus && eta.esTiempoReal`).
      - `state = state.copyWith(...)`: Llamada si `etaRelevante` no es null y `etaRelevante.minutosParaLlegada > 0`. Input: Parámetros nombrados para actualizar el estado.
      - `print`: Llamada si `etaRelevante` no es null y `etaRelevante.minutosParaLlegada > 0`. Input: String.
      - `state = state.copyWith(...)`: Llamada si `etaRelevante` es null o `etaRelevante.minutosParaLlegada <= 0`. Input: Parámetros nombrados para actualizar el estado.
      - `print`: Llamada si `etaRelevante` es null o `etaRelevante.minutosParaLlegada <= 0`. Input: String.
      - `_seguimientoBusTimer?.cancel()`: Llamada si `etaRelevante` no es null y `etaRelevante.minutosParaLlegada <= 0`. Input: Ninguno.
      - `print`: Llamada si `etaRelevante` no es null y `etaRelevante.minutosParaLlegada <= 0`. Input: String.
      - `state = state.copyWith(...)`: Llamada si `detallesParada` es null. Input: Parámetros nombrados para actualizar el estado.
      - `print`: Llamada si `detallesParada` es null. Input: String.
      - `print`: Llamada si ocurre una excepción en `fetchEta`. Input: String.
      - `state = state.copyWith(...)`: Llamada si `mounted` es true y el ID del tramo en seguimiento no ha cambiado (dentro del bloque `catch` de `fetchEta`). Input: Parámetros nombrados para actualizar el estado.

### detenerSeguimientoBusTiempoReal

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces si las condiciones iniciales de fase y datos de viaje se cumplen. Input: String.
  - `_seguimientoBusTimer?.cancel()`: Llamada el 100% de las veces si las condiciones iniciales se cumplen. Input: Ninguno.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true y las condiciones iniciales se cumplen. Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si `mounted` es true y las condiciones iniciales se cumplen. Input: String.

### setErrorGlobal

- **Input:** `mensaje` (String o null).
- **Llama a:**
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### dispose

- **Input:** Ninguno.
- **Llama a:**
  - `_seguimientoBusTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `_origenDebounceTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `_destinoDebounceTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `super.dispose()`: Llamada el 100% de las veces. Input: Ninguno.

### pantallaDeInicioCargada

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual (comentado).

### usuarioMovioMapaManualente

- **Input:** `nuevoCentro` (Coordenada), `nuevoZoom` (double).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual.

### usuarioHizoTapEnMapa

- **Input:** `tocada` (Coordenada).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual (la llamada a `cerrarDetallesDeParada()` está comentada).

### usuarioHizoTapEnParadaDelMapa

- **Input:** `idParada` (String).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `solicitarInformacionDetalladaParada(idParada)`: Llamada el 100% de las veces. Input: `idParada` (String).

### cerrarDetallesDeParada

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.

### navegarAAnteriorPasoInstrucciones

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual (tiene un comentario indicando qué lógica debe haber).

### navegarASiguientePasoInstrucciones

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual (tiene un comentario indicando qué lógica debe haber).

### usuarioSeleccionoPasoInstrucciones

- **Input:** `indicePaso` (int).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual (tiene un comentario indicando qué lógica debe haber).

### usuarioPresionoSeguirEsteViaje

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual.

### detenerSeguimientoActivo

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_seguimientoBusTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `state = state.copyWith(...)`: Llamada si `mounted` es true. Input: Parámetros nombrados para actualizar el estado.
  - `print`: Llamada si `mounted` es true. Input: String.

## Funciones en lib/ui/overlays/active_trip_overlay.dart

### initState

- **Input:** Ninguno.
- **Llama a:**
  - `super.initState()`: Llamada el 100% de las veces. Input: Ninguno.
  - `WidgetsBinding.instance.addPostFrameCallback(...)`: Llamada el 100% de las veces. Input: Callback function.
    - Dentro del callback, se llama a:
      - `_initializeActiveTrip()`: Llamada el 100% de las veces dentro del callback. Input: Ninguno.

### dispose

- **Input:** Ninguno.
- **Llama a:**
  - `_arrowAnimationTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `_busTrackingTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `_tooltipFloatTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `super.dispose()`: Llamada el 100% de las veces. Input: Ninguno.

### \_clearPreviousRoutePreview

- **Input:** Ninguno.
- **Llama a:**
  - `widget.mapboxMap!.style.styleLayerExists(layerId)`: Llamada para cada `layerId` en `previewLayerIds` si `widget.mapboxMap` no es null (dentro de un bloque `try`). Input: `layerId` (String).
  - `widget.mapboxMap!.style.removeStyleLayer(layerId)`: Llamada para cada `layerId` en `previewLayerIds` si `widget.mapboxMap` no es null y la capa existe (dentro de un bloque `try`). Input: `layerId` (String).
  - `print`: Llamada para cada `layerId` en `previewLayerIds` si la capa se elimina correctamente (dentro del bloque `try`). Input: String.
  - `print`: Llamada para cada `layerId` en `previewLayerIds` si ocurre una excepción al eliminar la capa (dentro del bloque `catch`). Input: String.
  - `widget.mapboxMap!.style.styleSourceExists(sourceId)`: Llamada para cada `sourceId` en `previewSourceIds` si `widget.mapboxMap` no es null (dentro de un bloque `try`). Input: `sourceId` (String).
  - `widget.mapboxMap!.style.removeStyleSource(sourceId)`: Llamada para cada `sourceId` en `previewSourceIds` si `widget.mapboxMap` no es null y la fuente existe (dentro de un bloque `try`). Input: `sourceId` (String).
  - `print`: Llamada para cada `sourceId` en `previewSourceIds` si la fuente se elimina correctamente (dentro del bloque `try`). Input: String.
  - `print`: Llamada para cada `sourceId` en `previewSourceIds` si ocurre una excepción al eliminar la fuente (dentro del bloque `catch`). Input: String.
  - `print`: Llamada el 100% de las veces al inicio y al final de la función si `widget.mapboxMap` no es null. Input: String.

### \_initializeActiveTrip

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `ref.read(mapManagerProvider)`: Llamada el 100% de las veces. Input: `mapManagerProvider`.
  - `print`: Llamada si `mapManager` es null. Input: String.
  - `ref.read(appLogicProvider)`: Llamada si `mapManager` no es null. Input: `appLogicProvider`.
  - `mapManager.showActiveTrip(activeTripState)`: Llamada si `mapManager` no es null y `activeTripState` no es null y tiene tramos (dentro de un bloque `try`). Input: `activeTripState` (EstadoFaseViajeActivo).
  - `print`: Llamada si `mapManager` no es null y `activeTripState` no es null y tiene tramos. Input: String.
  - `mapManager.updateCurrentLeg(0, activeTripState.tramosDelViaje)`: Llamada si `mapManager` no es null y `activeTripState` no es null y tiene tramos (dentro de un bloque `try`). Input: `0` (int), `activeTripState.tramosDelViaje` (List<TramoViajeMostrable>).
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_loadMapIcons

- **Input:** Ninguno.
- **Llama a:**
  - `_loadIconImageFromAsset('stop_icon.png')`: Llamada si `widget.mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`). Input: `'stop_icon.png'` (String).
  - `widget.mapboxMap!.style.addStyleImage(...)`: Llamada si `widget.mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`) después de cargar el icono de parada. Input: `STOP_ICON_IMAGE_ID` (String), `1.0` (double), `stopImage` (MbxImage), `false` (bool), `[]` (List), `[]` (List), `null`.
  - `_loadIconImageFromAsset('incoming_bus.png')`: Llamada si `widget.mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`). Input: `'incoming_bus.png'` (String).
  - `widget.mapboxMap!.style.addStyleImage(...)`: Llamada si `widget.mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`) después de cargar el icono de bus. Input: `BUS_ICON_IMAGE_ID` (String), `1.0` (double), `busImage` (MbxImage), `false` (bool), `[]` (List), `[]` (List), `null`.
  - `print`: Llamada si los iconos se cargan exitosamente (dentro del bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_loadIconImageFromAsset

- **Input:** `assetName` (String).
- **Llama a:**
  - `rootBundle.load('assets/icons/$assetName')`: Llamada el 100% de las veces. Input: `'assets/icons/$assetName'` (String).
  - `data.buffer.asUint8List()`: Llamada el 100% de las veces. Input: Ninguno.
  - `ui.instantiateImageCodec(bytes)`: Llamada el 100% de las veces. Input: `bytes` (Uint8List).
  - `codec.getNextFrame()`: Llamada el 100% de las veces. Input: Ninguno.
  - `frameInfo.image`: Llamada el 100% de las veces. Input: Ninguno.
  - `image.toByteData(format: ui.ImageByteFormat.png)`: Llamada el 100% de las veces. Input: `format: ui.ImageByteFormat.png`.
  - No llama a otras funciones definidas en este archivo.

### \_onLegSelected

- **Input:** `legIndex` (int).
- **Llama a:**
  - `setState(...)`: Llamada el 100% de las veces. Input: Callback function que actualiza `_currentLegIndex`.
  - `ref.read(mapManagerProvider)`: Llamada el 100% de las veces. Input: `mapManagerProvider`.
  - `ref.read(appLogicProvider)`: Llamada el 100% de las veces. Input: `appLogicProvider`.
  - `mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje)`: Llamada si `mapManager` no es null y `activeTripState` no es null. Input: `legIndex` (int), `activeTripState.tramosDelViaje` (List<TramoViajeMostrable>).
  - `print`: Llamada si `mapManager` no es null y `activeTripState` no es null. Input: String.

### build

- **Input:** `context` (BuildContext).
- **Llama a:**
  - `ref.watch(appLogicProvider)`: Llamada el 100% de las veces. Input: `appLogicProvider`.
  - `ref.read(appLogicProvider.notifier)`: Llamada el 100% de las veces. Input: `appLogicProvider.notifier`.
  - `ref.listen(...)`: Llamada el 100% de las veces para configurar un listener.
    - Dentro del listener, se llama a:
      - `_handleRealtimeBusUpdate(nextState)`: Llamada si la información del bus en tiempo real ha cambiado. Input: `nextState` (EstadoFaseViajeActivo o null).
  - `_buildMainInstructionCard(context, tramoActual, theme)`: Llamada si `activeTripState` no es null y tiene tramos. Input: `context` (BuildContext), `tramoActual` (TramoViajeMostrable), `theme` (ThemeData).
  - `_buildNavigationPanel(context, theme)`: Llamada si `activeTripState` no es null y tiene tramos. Input: `context` (BuildContext), `theme` (ThemeData).
  - `_buildEmptyState(...)`: No se llama, el bloque `if (activeTripState == null)` devuelve un `Container` directamente que contiene un `ElevatedButton` que llama a `appLogic.usuarioCanceloBusquedaOSeleccionRuta()`.

### \_handleRealtimeBusUpdate

- **Input:** `activeTripState` (EstadoFaseViajeActivo o null).
- **Llama a:**
  - `ref.read(mapManagerProvider)`: Llamada si `activeTripState` no es null. Input: `mapManagerProvider`.
  - `print`: Llamada si `activeTripState.seguimientoBusRealDisponibleEnTramoActual` es true y existen datos de posición/ETA. Input: String.
  - `mapManager.busRealtime.updateBusPosition(...)`: Llamada si `activeTripState` no es null, `mapManager` no es null, `activeTripState.seguimientoBusRealDisponibleEnTramoActual` es true y existen datos de posición/ETA. Input: `activeTripState.posicionActualBusReal!` (Coordenada), `activeTripState.minutosParaLlegadaBusReal!` (int), `true` (bool).
  - No llama a otras funciones definidas en este archivo.

### \_buildMainInstructionCard

- **Input:** `context` (BuildContext), `tramo` (TramoViajeMostrable), `theme` (ThemeData).
- **Llama a:**
  - `_getInstructionColor(tramo)`: Llamada el 100% de las veces. Input: `tramo` (TramoViajeMostrable).
  - `_getInstructionIcon(tramo)`: Llamada el 100% de las veces. Input: `tramo` (TramoViajeMostrable).
  - `theme.textTheme.bodySmall?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `theme.textTheme.titleLarge?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `appLogic.detenerSeguimientoActivo()`: Llamada cuando se presiona el `InkWell`. Input: Ninguno.
  - `theme.textTheme.bodyMedium?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `_buildAdditionalInfo(context, tramo, theme)`: Llamada el 100% de las veces. Input: `context` (BuildContext), `tramo` (TramoViajeMostrable), `theme` (ThemeData).

### \_buildAdditionalInfo

- **Input:** `context` (BuildContext), `tramo` (TramoViajeMostrable), `theme` (ThemeData).
- **Llama a:**
  - `_buildCompactInfoChip(...)`: Llamada el 100% de las veces (para el tiempo), condicionalmente para distancia, línea de bus y ETA del bus. Input: `icon` (IconData), `label` (String), `color` (Color), `theme` (ThemeData).
  - `_formatDuration(tramo.duracionEstimadaSegundos)`: Llamada el 100% de las veces. Input: `tramo.duracionEstimadaSegundos` (int).
  - No llama a otras funciones definidas en este archivo.

### \_buildCompactInfoChip

- **Input:** `icon` (IconData), `label` (String), `color` (Color), `theme` (ThemeData).
- **Llama a:**
  - `theme.textTheme.bodySmall?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - No llama a otras funciones definidas en este archivo.

### \_buildNavigationPanel

- **Input:** `context` (BuildContext), `theme` (ThemeData).
- **Llama a:**
  - `_buildCompactNavButton(...)`: Llamada el 100% de las veces (para el botón anterior y siguiente). Input: `context` (BuildContext), `icon` (IconData), `enabled` (bool), `onPressed` (VoidCallback o null), `theme` (ThemeData), `isPrimary` (bool).
  - `theme.textTheme.titleMedium?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - `theme.textTheme.bodySmall?.copyWith(...)`: Llamada el 100% de las veces. Input: Propiedades de estilo.
  - No llama a otras funciones definidas en este archivo.

### \_buildCompactNavButton

- **Input:** `context` (BuildContext), `icon` (IconData), `enabled` (bool), `onPressed` (VoidCallback o null), `theme` (ThemeData), `isPrimary` (bool).
- **Llama a:**
  - `onPressed()`: Llamada cuando se presiona el `InkWell` si `enabled` es true. Input: Ninguno.
  - No llama a otras funciones definidas en este archivo.

### \_getInstructionTitle

- **Input:** `tramo` (TramoViajeMostrable).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_getInstructionIcon

- **Input:** `tramo` (TramoViajeMostrable).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_getInstructionColor

- **Input:** `tramo` (TramoViajeMostrable).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_getDetailedInstruction

- **Input:** `tramo` (TramoViajeMostrable).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_formatDuration

- **Input:** `totalSeconds` (int).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

## Funciones en lib/map_manager/map_bus_realtime.dart

### MapBusRealtime (Constructor)

- **Input:** `mapboxMap` (MapboxMap o null), `mapManager` (MapManager).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo (inicializa campos).

### displayRealtimeBusesForPreview

- **Input:** `route` (OpcionDeRutaMostrable).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `_addRealtimeBusToPreview(tramo, i)`: Llamada para cada `tramo` en `route.tramosParaPreview` si `mapboxMap` no es null y `tramo.esTiempoRealBus` es true y `tramo.minutosEstimadosLlegadaBus` no es null y `tramo.minutosEstimadosLlegadaBus > 0`. Input: `tramo` (TramoViajeMostrable), `i` (int).

### initializeActiveTripTracking

- **Input:** `activeTripState` (EstadoFaseViajeActivo).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `_stopBusTracking()`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: Ninguno.
  - `_startBusTracking(tramoBus)`: Llamada si `mapboxMap` no es null y se encuentra un `tramoBus` para trackear.
    - Se busca el primer tramo de tipo `VIAJE_EN_BUS` en `activeTripState.tramosDelViaje` usando `firstWhereOrNull`.
      Input: `tramoBus` (TramoViajeMostrable).

### updateBusTrackingForLeg

- **Input:** `legIndex` (int), `tramos` (List<TramoViajeMostrable>).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `_stopBusTracking()`: Llamada el 100% de las veces si `mapboxMap` no es null.
  - `_startBusTracking(nextBusSegment)`: Llamada si `mapboxMap` no es null y se encuentra un `nextBusSegment` para trackear (usando `_findNextBusSegment`). Input: `nextBusSegment` (TramoViajeMostrable).

### updateBusPosition

- **Input:** `position` (Coordenada), `etaMinutes` (int), `isRealTime` (bool).
- **Llama a:**
  - `_tryUpdatePreviewBusElements(position, etaMinutes, isRealTime)`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: `position` (Coordenada), `etaMinutes` (int), `isRealTime` (bool).
  - `_displayBusOnMap(position)`: Llamada si `mapboxMap` no es null y `usingPreviewElements` es false. Input: `position` (Coordenada).
  - `_updateBusApproachLineForActiveTrip(position, _currentStopPosition!)`: Llamada si `mapboxMap` no es null, `_currentStopPosition` no es null y `_currentTrackedSegment` no es null. Input: `position` (Coordenada), `_currentStopPosition!` (Coordenada).

### \_findNextBusSegment

- **Input:** `tramos` (List<TramoViajeMostrable>), `currentLegIndex` (int).
- **Llama a:**
  - `print`: Llamada condicionalmente para propósitos de depuración. Input: String.
  - No llama a otras funciones definidas en este archivo.

### \_startBusTracking

- **Input:** `tramo` (TramoViajeMostrable).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_busTrackingTimer?.cancel()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `Timer.periodic(...)`: Llamada si `mapboxMap` no es null para configurar un timer. Input: `duration` (Duration), callback function (`(timer) => _fetchBusUpdate(tramo)`).
  - `print`: Llamada si `mapboxMap` no es null. Input: String.

### \_stopBusTracking

- **Input:** Ninguno.
- **Llama a:**
  - `_busTrackingTimer?.cancel()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `_clearBusDisplay()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `print`: Llamada si `mapboxMap` no es null. Input: String.

### \_fetchBusUpdate

- **Input:** `tramo` (TramoViajeMostrable).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - No llama a otras funciones definidas en este archivo de manera activa en la implementación actual (tiene un comentario TODO).

### \_displayBusOnMap

- **Input:** `position` (Coordenada).
- **Llama a:**
  - `json.encode(...)`: Llamada si `mapboxMap` no es null. Input: Map con datos GeoJSON.
  - `mapboxMap!.style.styleSourceExists('bus-realtime-source-main')`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.getSource('bus-realtime-source-main')`: Llamada si `mapboxMap` no es null y la fuente existe (dentro de un bloque `try`). Input: String.
  - `source.updateGeoJSON(json.encode(sourceData))`: Llamada si `mapboxMap` no es null y la fuente existe (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción al actualizar la fuente (dentro del bloque `catch`). Input: String.
  - `mapboxMap!.style.addSource(...)`: Llamada si `mapboxMap` no es null y la fuente no existe (dentro de un bloque `try`). Input: `GeoJsonSource`.
  - `mapManager.registerSource('bus-realtime-source-main')`: Llamada si `mapboxMap` no es null y la fuente no existe (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.styleLayerExists('bus-realtime-layer-main')`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.addLayer(...)`: Llamada si `mapboxMap` no es null y la capa del bus no existe (dentro de un bloque `try`). Input: `SymbolLayer`.
  - `mapManager.registerLayer('bus-realtime-layer-main')`: Llamada si `mapboxMap` no es null y la capa del bus no existe (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.styleLayerExists('bus-tooltip-layer-main')`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.addLayer(...)`: Llamada si `mapboxMap` no es null y la capa del tooltip no existe (dentro de un bloque `try`). Input: `SymbolLayer`.
  - `mapManager.registerLayer('bus-tooltip-layer-main')`: Llamada si `mapboxMap` no es null y la capa del tooltip no existe (dentro de un bloque `try`). Input: String.
  - `_startTooltipFloatingAnimation()`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: Ninguno.
  - `print`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción general (dentro del bloque `catch`). Input: String.

### \_clearBusDisplay

- **Input:** Ninguno.
- **Llama a:**
  - `_stopTooltipFloatingAnimation()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `mapboxMap!.style.styleLayerExists(...)`: Llamada para varias capas si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.removeStyleLayer(...)`: Llamada para varias capas si `mapboxMap` no es null y la capa existe (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.styleSourceExists(...)`: Llamada para varias fuentes si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
  - `mapboxMap!.style.removeStyleSource(...)`: Llamada para varias fuentes si `mapboxMap` no es null y la fuente existe (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_updateBusApproachLineForActiveTrip

- **Input:** `busPosition` (Coordenada), `stopPosition` (Coordenada).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null, `_currentTrackedSegment` no es null. Input: String.
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null, `_currentTrackedSegment` no es null. Input: String.
  - `loadShapeGeometries()`: Llamada si `mapboxMap` no es null, `_currentTrackedSegment` no es null. Input: Ninguno.
  - `getFullShapeGeometry(_currentTrackedSegment!.shapeId)`: Llamada si `mapboxMap` no es null, `_currentTrackedSegment` no es null y `_currentTrackedSegment!.shapeId` no es null.
  - `findClosestPointIndexOnShape(fullLineGeometry, busPosition)`: Llamada si `fullLineGeometry` no es null/vacío. Input: `fullLineGeometry` (List<Coordenada>), `busPosition` (Coordenada).
  - `findClosestPointIndexOnShape(fullLineGeometry, stopPosition)`: Llamada si `fullLineGeometry` no es null/vacío. Input: `fullLineGeometry` (List<Coordenada>), `stopPosition` (Coordenada).
  - `getGeometrySegment(fullLineGeometry, busIndex, stopIndex)`: Llamada si `fullLineGeometry` no es null/vacío y `busIndex` y `stopIndex` no son -1. Input: `fullLineGeometry` (List<Coordenada>), `busIndex` (int), `stopIndex` (int).
  - `_coordenadasToGeoJsonPositionList(...)`: Llamada si `fullLineGeometry` no es null/vacío, `busIndex` y `stopIndex` no son -1 y `segment.length >= 2`. Input: `segment` (List<Coordenada>).
  - `_tryUpdatePreviewApproachLine(geoJsonFeatureCollection)`: Llamada si `mapboxMap` no es null, `_currentTrackedSegment` no es null (dentro de un bloque `try`). Input: `geoJsonFeatureCollection` (Map<String, dynamic>).
  - `_updateOrCreateActiveTripApproachLine(geoJsonFeatureCollection)`: Llamada si `mapboxMap` no es null, `_currentTrackedSegment` no es null y `updatedPreviewLine` es false (dentro de un bloque `try`). Input: `geoJsonFeatureCollection` (Map<String, dynamic>).
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_tryUpdatePreviewApproachLine

- **Input:** `geoJsonFeatureCollection` (Map<String, dynamic>).
- **Llama a:**
  - `mapboxMap!.style.styleSourceExists(sourceId)`: Llamada para cada `sourceId` en `previewApproachSourceIds` si `mapboxMap` no es null (dentro de un bloque `try`). Input: `sourceId` (String).
  - `mapboxMap!.style.getSource(sourceId)`: Llamada para cada `sourceId` si `mapboxMap` no es null y la fuente existe (dentro de un bloque `try`). Input: `sourceId` (String).
  - `source.updateGeoJSON(json.encode(geoJsonFeatureCollection))`: Llamada para cada `sourceId` si `mapboxMap` no es null y la fuente existe (dentro de un bloque `try`). Input: String.
  - `print`: Llamada para cada `sourceId` si la actualización es exitosa (dentro de un bloque `try`). Input: String.
  - `print`: Llamada para cada `sourceId` si ocurre una excepción (dentro de un bloque `catch`). Input: String.

### \_updateOrCreateActiveTripApproachLine

- **Input:** `geoJsonFeatureCollection` (Map<String, dynamic>).
- **Llama a:**
  - `mapboxMap!.style.styleSourceExists('bus-approach-source-main')`: Llamada si `mapboxMap` no es null. Input: String.
  - `mapboxMap!.style.getSource('bus-approach-source-main')`: Llamada si `mapboxMap` no es null y la fuente existe. Input: String.
  - `source.updateGeoJSON(json.encode(geoJsonFeatureCollection))`: Llamada si `mapboxMap` no es null y la fuente existe. Input: String.
  - `mapboxMap!.style.addSource(...)`: Llamada si `mapboxMap` no es null y la fuente no existe. Input: `GeoJsonSource`.
  - `mapManager.registerSource('bus-approach-source-main')`: Llamada si `mapboxMap` no es null y la fuente no existe. Input: String.
  - `mapboxMap!.style.addLayer(...)`: Llamada si `mapboxMap` no es null y la fuente no existe (para la capa de sombra y la capa principal). Input: `LineLayer`.
  - `mapManager.registerLayer('bus-approach-layer-main-shadow')`: Llamada si `mapboxMap` no es null y la fuente no existe. Input: String.
  - `mapManager.registerLayer('bus-approach-layer-main')`: Llamada si `mapboxMap` no es null y la fuente no existe. Input: String.
  - `print`: Llamada si `mapboxMap` no es null y la fuente no existe. Input: String.

### \_addRealtimeBusToPreview

- **Input:** `tramo` (TramoViajeMostrable), `segmentIndex` (int).
- **Llama a:**
  - `_addBusApproachLineToPreview(busPosition, paradaOrigen, segmentIndex, tramo)`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`). Input: `busPosition` (Coordenada), `paradaOrigen` (Coordenada), `segmentIndex` (int), `tramo` (TramoViajeMostrable).
  - `jsonEncode(geoJsonFeature)`: Llamada si `mapboxMap` no es null y existen datos de posición/geometría (dentro de un bloque `try`). Input: Map con datos GeoJSON.
  - `mapboxMap!.style.addSource(...)`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`). Input: `GeoJsonSource`.
  - `mapManager.registerSource(sourceId)`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`). Input: `sourceId` (String).
  - `mapboxMap!.style.addLayer(...)`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`) (para la capa del bus y la capa del tooltip).
  - `mapManager.registerLayer(layerId)`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`). Input: `layerId` (String).
  - `mapManager.registerLayer(tooltipLayerId)`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`). Input: `tooltipLayerId` (String).
  - `_startTooltipFloatingAnimationPreview()`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`). Input: Ninguno.
  - `print`: Llamada si `mapboxMap` no es null, existen datos de posición/geometría y no hay excepción (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_addBusApproachLineToPreview

- **Input:** `busPosition` (Coordenada), `stopPosition` (Coordenada), `segmentIndex` (int), `tramo` (TramoViajeMostrable).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `loadShapeGeometries()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `getFullShapeGeometry(tramo.shapeId)`: Llamada si `mapboxMap` no es null y `tramo.shapeId` no es null.
  - `findClosestPointIndexOnShape(fullLineGeometry, busPosition)`: Llamada si `fullLineGeometry` no es null/vacío. Input: `fullLineGeometry` (List<Coordenada>), `busPosition` (Coordenada).
  - `findClosestPointIndexOnShape(fullLineGeometry, stopPosition)`: Llamada si `fullLineGeometry` no es null/vacío. Input: `fullLineGeometry` (List<Coordenada>), `stopPosition` (Coordenada).
  - `getGeometrySegment(fullLineGeometry, busIndex, stopIndex)`: Llamada si `fullLineGeometry` no es null/vacío y `busIndex` y `stopIndex` no son -1. Input: `fullLineGeometry` (List<Coordenada>), `busIndex` (int), `stopIndex` (int).
  - `_coordenadasToGeoJsonPositionList(...)`: Llamada si `fullLineGeometry` no es null/vacío, `busIndex` y `stopIndex` no son -1 y `segment.length >= 2`. Input: `segment` (List<Coordenada>).
  - `jsonEncode(geoJsonFeatureCollection)`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: Map con datos GeoJSON.
  - `mapboxMap!.style.addSource(...)`: Llamada si `mapboxMap` no es null y no hay excepción (dentro de un bloque `try`). Input: `GeoJsonSource`.
  - `mapManager.registerSource(sourceId)`: Llamada si `mapboxMap` no es null y no hay excepción (dentro de un bloque `try`). Input: `sourceId` (String).
  - `mapboxMap!.style.addLayer(...)`: Llamada si `mapboxMap` no es null y no hay excepción (dentro de un bloque `try`) (para la capa de sombra y la capa principal).
  - `mapManager.registerLayer(shadowLayerId)`: Llamada si `mapboxMap` no es null y no hay excepción (dentro de un bloque `try`). Input: `shadowLayerId` (String).
  - `mapManager.registerLayer(mainLayerId)`: Llamada si `mapboxMap` no es null y no hay excepción (dentro de un bloque `try`). Input: `mainLayerId` (String).
  - `print`: Llamada si `mapboxMap` no es null y no hay excepción (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_addRealtimeBusFromEta

- **Input:** `eta` (EtaMostrable), `index` (int).
- **Llama a:**
  - `jsonEncode(geoJsonFeature)`: Llamada si `mapboxMap` no es null y `eta.posicionBus` no es null (dentro de un bloque `try`). Input: Map con datos GeoJSON.
  - `mapboxMap!.style.addSource(...)`: Llamada si `mapboxMap` no es null, `eta.posicionBus` no es null y no hay excepción (dentro de un bloque `try`). Input: `GeoJsonSource`.
  - `mapManager.registerSource(sourceId)`: Llamada si `mapboxMap` no es null, `eta.posicionBus` no es null y no hay excepción (dentro de un bloque `try`). Input: `sourceId` (String).
  - `mapboxMap!.style.addLayer(...)`: Llamada si `mapboxMap` no es null, `eta.posicionBus` no es null y no hay excepción (dentro de un bloque `try`) (para la capa del bus y la capa del tooltip).
  - `mapManager.registerLayer(layerId)`: Llamada si `mapboxMap` no es null, `eta.posicionBus` no es null y no hay excepción (dentro de un bloque `try`). Input: `layerId` (String).
  - `mapManager.registerLayer(tooltipLayerId)`: Llamada si `mapboxMap` no es null, `eta.posicionBus` no es null y no hay excepción (dentro de un bloque `try`). Input: `tooltipLayerId` (String).
  - `_startTooltipFloatingAnimationPreview()`: Llamada si `mapboxMap` no es null, `eta.posicionBus` no es null y no hay excepción (dentro de un bloque `try`). Input: Ninguno.
  - `print`: Llamada si `mapboxMap` no es null, `eta.posicionBus` no es null y no hay excepción (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_startTooltipFloatingAnimation

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_stopTooltipFloatingAnimation()`: Llamada el 100% de las veces. Input: Ninguno.
  - `Timer.periodic(...)`: Llamada el 100% de las veces si `mapboxMap` no es null para configurar un timer. Input: `duration` (Duration), callback function.
    - Dentro del callback del timer, se llama a:
      - `mapboxMap!.style.styleLayerExists('bus-tooltip-layer-main')`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: String.
      - `mapboxMap!.style.setStyleLayerProperty(...)`: Llamada si `mapboxMap` no es null y la capa existe (dentro de un bloque `try`). Input: `'bus-tooltip-layer-main'` (String), `'icon-offset'` (String), lista de offsets (List<double>).
      - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_startTooltipFloatingAnimationPreview

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_stopTooltipFloatingAnimation()`: Llamada el 100% de las veces. Input: Ninguno.
  - `Timer.periodic(...)`: Llamada el 100% de las veces si `mapboxMap` no es null para configurar un timer. Input: `duration` (Duration), callback function.
    - Dentro del callback del timer, se llama a:
      - `mapboxMap!.style.styleLayerExists(layerId)`: Llamada para cada `layerId` si `mapboxMap` no es null (dentro de un bucle `for` y un bloque `try`). Input: `layerId` (String).
      - `mapboxMap!.style.setStyleLayerProperty(...)`: Llamada para cada `layerId` si `mapboxMap` no es null y la capa existe (dentro de un bucle `for` y un bloque `try`). Input: `layerId` (String), `'icon-offset'` (String), lista de offsets (List<double>).
      - `print`: Llamada si ocurre una excepción (dentro de un bloque `catch`). Input: String.

### \_stopTooltipFloatingAnimation

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_tooltipFloatTimer?.cancel()`: Llamada el 100% de las veces. Input: Ninguno.
  - `mapboxMap!.style.styleLayerExists('bus-tooltip-layer-main').then(...)`: Llamada si `mapboxMap` no es null para resetear el offset del tooltip principal.
    - Dentro del `then` callback, se llama a:
      - `mapboxMap!.style.setStyleLayerProperty(...)`: Llamada si la capa existe. Input: `'bus-tooltip-layer-main'` (String), `'icon-offset'` (String), lista de offsets (List<double>).
    - Dentro del `catchError` callback, se llama a:
      - `print`: Llamada si ocurre un error. Input: String.
  - `mapboxMap!.style.styleLayerExists(layerId).then(...)`: Llamada para cada `layerId` en el bucle si `mapboxMap` no es null para resetear el offset de los tooltips de preview.
    - Dentro del `then` callback, se llama a:
      - `mapboxMap!.style.setStyleLayerProperty(...)`: Llamada si la capa existe. Input: `layerId` (String), `'icon-offset'` (String), lista de offsets (List<double>).
    - Dentro del `catchError` callback, se llama a:
      - `print`: Llamada si ocurre un error. Input: String.

### \_tryUpdatePreviewBusElements

- **Input:** `position` (Coordenada), `etaMinutes` (int), `isRealTime` (bool).
- **Llama a:**
  - `mapboxMap!.style.styleSourceExists(sourceId)`: Llamada para cada `sourceId` en `previewBusSourceIds` si `mapboxMap` no es null (dentro de un bloque `try`). Input: `sourceId` (String).
  - `json.encode(sourceData)`: Llamada para cada `sourceId` si la fuente existe (dentro de un bloque `try`). Input: Map con datos GeoJSON.
  - `mapboxMap!.style.getSource(sourceId)`: Llamada para cada `sourceId` si la fuente existe (dentro de un bloque `try`). Input: `sourceId` (String).
  - `source.updateGeoJSON(json.encode(sourceData))`: Llamada para cada `sourceId` si la fuente existe (dentro de un bloque `try`). Input: String.
  - `print`: Llamada para cada `sourceId` si la actualización es exitosa (dentro de un bloque `try`). Input: String.
  - `print`: Llamada para cada `sourceId` si ocurre una excepción (dentro de un bloque `catch`). Input: String.

### currentBusPosition (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### stopPreviewAnimations

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_stopTooltipFloatingAnimation()`: Llamada el 100% de las veces. Input: Ninguno.

### dispose

- **Input:** Ninguno.
- **Llama a:**
  - `_stopBusTracking()`: Llamada el 100% de las veces. Input: Ninguno.
  - `_stopTooltipFloatingAnimation()`: Llamada el 100% de las veces. Input: Ninguno.

## Funciones en lib/map_manager/map_camera_controller.dart

### MapCameraController (Constructor)

- **Input:** `mapboxMap` (MapboxMap o null), `mapManager` (MapManager).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo (inicializa campos).

### zoomToRoutePreview

- **Input:** `route` (OpcionDeRutaMostrable).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `_addBusCoordinatesToZoom(route, allCoordinates)`: Llamada si `mapboxMap` no es null. Input: `route` (OpcionDeRutaMostrable), `allCoordinates` (List<Coordenada>).
  - `_zoomToCoordinates(allCoordinates, _getPreviewPadding())`: Llamada si `mapboxMap` no es null y `allCoordinates` no está vacío. Input: `allCoordinates` (List<Coordenada>), padding (MbxEdgeInsets).

### zoomToActiveTrip

- **Input:** `tramos` (List<TramoViajeMostrable>).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null y `tramos` no está vacío. Input: String.
  - `_zoomToCoordinates(allCoordinates, _getActiveTripPadding())`: Llamada si `mapboxMap` no es null, `tramos` no está vacío y `allCoordinates` no está vacío. Input: `allCoordinates` (List<Coordenada>), padding (MbxEdgeInsets).

### zoomToCurrentLeg

- **Input:** `legIndex` (int), `tramos` (List<TramoViajeMostrable>).
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null y `legIndex` es válido. Input: String.
  - `_addBusCoordinatesForWaitingLeg(tramos, legIndex, coordinatesForZoom)`: Llamada si `mapboxMap` no es null, `legIndex` es válido y `tramo.tipo` es `TipoTramoViaje.ESPERAR_BUS` (dentro de un bloque `try`). Input: `tramos` (List<TramoViajeMostrable>), `legIndex` (int), `coordinatesForZoom` (List<Coordenada>).
  - `_zoomToCoordinates(coordinatesForZoom, _getCurrentLegPadding())`: Llamada si `mapboxMap` no es null, `legIndex` es válido, `coordinatesForZoom.length > 1` y no hay excepción (dentro de un bloque `try`). Input: `coordinatesForZoom` (List<Coordenada>), padding (MbxEdgeInsets).
  - `mapboxMap!.flyTo(...)`: Llamada si `mapboxMap` no es null, `legIndex` es válido, `coordinatesForZoom.length == 1` y no hay excepción (dentro de un bloque `try`). Input: `CameraOptions`, `MapAnimationOptions`.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_addBusCoordinatesToZoom

- **Input:** `route` (OpcionDeRutaMostrable), `allCoordinates` (List<Coordenada>).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `allCoordinates.add(...)`: Llamada condicionalmente para agregar coordenadas del bus si existen. Input: Coordenada.
  - `print`: Llamada condicionalmente para propósitos de depuración. Input: String.

### \_zoomToCoordinates

- **Input:** `coordinates` (List<Coordenada>), `padding` (MbxEdgeInsets).
- **Llama a:**
  - `mapboxMap!.cameraForCoordinates(...)`: Llamada si `mapboxMap` no es null y `coordinates` no está vacío (dentro de un bloque `try`). Input: `mapboxPoints` (List<Point>), `padding` (MbxEdgeInsets), null, null.
  - `mapboxMap!.flyTo(...)`: Llamada si `mapboxMap` no es null y `coordinates` no está vacío (dentro de un bloque `try`). Input: `cameraOptions` (CameraOptions), `MapAnimationOptions`.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_getPreviewPadding

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_getActiveTripPadding

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_getCurrentLegPadding

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_addBusCoordinatesForWaitingLeg

- **Input:** `tramos` (List<TramoViajeMostrable>), `currentLegIndex` (int), `coordinatesForZoom` (List<Coordenada>).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `mapManager.getCurrentBusPosition()`: Llamada el 100% de las veces. Input: Ninguno.
  - `coordinatesForZoom.add(...)`: Llamada condicionalmente para agregar coordenadas del bus si existen. Input: Coordenada.
  - `print`: Llamada condicionalmente para propósitos de depuración. Input: String.
  - `print`: Llamada si no hay coordenadas de bus disponibles. Input: String.
  - No llama a otras funciones definidas en este archivo directamente.

## Funciones en lib/map_manager/map_icons_loader.dart

### MapIconsLoader (Constructor)

- **Input:** `mapboxMap` (MapboxMap o null), `mapManager` (dynamic).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo (inicializa campos).

### loadAllIcons

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null y `_iconsLoaded` es false. Input: String.
  - `_loadIconImageFromAsset('stop_icon.png')`: Llamada si `mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`). Input: `'stop_icon.png'` (String).
  - `mapboxMap!.style.addStyleImage(...)`: Llamada si `mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`) después de cargar el icono de parada. Input: `STOP_ICON_IMAGE_ID` (String), `1.0` (double), `stopImage` (MbxImage), `false` (bool), `[]` (List), `[]` (List), `null`.
  - `_loadIconImageFromAsset('incoming_bus.png')`: Llamada si `mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`). Input: `'incoming_bus.png'` (String).
  - `mapboxMap!.style.addStyleImage(...)`: Llamada si `mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`) después de cargar el icono de bus. Input: `BUS_ICON_IMAGE_ID` (String), `1.0` (double), `busImage` (MbxImage), `false` (bool), `[]` (List), `[]` (List), `null`.
  - `_loadIconImageFromAsset('incoming_bus_tooltip.png')`: Llamada si `mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`). Input: `'incoming_bus_tooltip.png'` (String).
  - `mapboxMap!.style.addStyleImage(...)`: Llamada si `mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`) después de cargar el icono del tooltip del bus. Input: `BUS_TOOLTIP_ICON_ID` (String), `1.0` (double), `tooltipImage` (MbxImage), `false` (bool), `[]` (List), `[]` (List), `null`.
  - `mapboxMap!.style.addStyleImage(...)`: Llamada si `mapboxMap` no es null y `_iconsLoaded` es false (dentro de un bloque `try`) después de cargar el icono del tooltip para preview. Input: `PREVIEW_BUS_TOOLTIP_ICON_ID` (String), `1.0` (double), `tooltipImage` (MbxImage), `false` (bool), `[]` (List), `[]` (List), `null`.
  - `print`: Llamada si los iconos se cargan exitosamente (dentro del bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.
  - `rethrow`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: Ninguno.

### \_loadIconImageFromAsset

- **Input:** `assetName` (String).
- **Llama a:**
  - `rootBundle.load('assets/icons/$assetName')`: Llamada el 100% de las veces. Input: String.
  - `data.buffer.asUint8List()`: Llamada el 100% de las veces. Input: Ninguno.
  - `ui.instantiateImageCodec(bytes)`: Llamada el 100% de las veces. Input: Uint8List.
  - `codec.getNextFrame()`: Llamada el 100% de las veces. Input: Ninguno.
  - `frameInfo.image`: Llamada el 100% de las veces. Input: Ninguno.
  - `image.toByteData(format: ui.ImageByteFormat.png)`: Llamada el 100% de las veces. Input: `format: ui.ImageByteFormat.png`.
  - No llama a otras funciones definidas en este archivo.

### areIconsLoaded (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

## Funciones en lib/map_manager/map_cleanup.dart

### MapCleanup (Constructor)

- **Input:** `mapboxMap` (MapboxMap o null), `mapManager` (MapManager).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo (inicializa campos).

### clearAll

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `clearRoute()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `clearInitialPhaseElements()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `mapManager.clearRegistrations()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `print`: Llamada si `mapboxMap` no es null. Input: String.

### clearRoute

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces if `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('route-walk-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('route-bus-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('route-wait-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('bus-boarding-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('bus-alighting-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearSourcesWithPrefix('route-walk-source-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearSourcesWithPrefix('route-bus-source-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearSourcesWithPrefix('route-wait-source-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearSourcesWithPrefix('bus-boarding-stop-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearSourcesWithPrefix('bus-alighting-stop-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `clearBusElements()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `print`: Llamada si `mapboxMap` no es null. Input: String.

### clearRoutePreview (DEPRECATED)

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `clearRoute()`: Llamada el 100% de las veces. Input: Ninguno.

### clearActiveTrip (DEPRECATED)

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `clearRoute()`: Llamada el 100% de las veces. Input: Ninguno.

### clearInitialPhaseElements

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `_removeLayerSafely(layerId)`: Llamada para cada `layerId` en `initialPhaseLayerIds` if `mapboxMap` no es null. Input: `layerId` (String).
  - `_removeSourceSafely(sourceId)`: Llamada para cada `sourceId` in `initialPhaseSourceIds` if `mapboxMap` no es null. Input: `sourceId` (String).

### clearBusElements

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces if `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('bus-realtime-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('bus-tooltip-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearLayersWithPrefix('bus-approach-layer-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearSourcesWithPrefix('bus-realtime-source-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `_clearSourcesWithPrefix('bus-approach-source-')`: Llamada si `mapboxMap` no es null. Input: String.
  - `print`: Llamada si `mapboxMap` no es null. Input: String.

### clearPreviewBusElements

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces si `mapboxMap` no es null. Input: String.
  - `clearBusElements()`: Llamada si `mapboxMap` no es null. Input: Ninguno.
  - `print`: Llamada si `mapboxMap` no es null. Input: String.

### \_clearLayersWithPrefix

- **Input:** `prefix` (String).
- **Llama a:**
  - `mapManager.activeLayers`: Llamada el 100% de las veces if `mapboxMap` no es null. Input: Ninguno (acceso a getter).
  - `_removeLayerSafely(layerId)`: Llamada para cada `layerId` en `registeredLayers` que empieza con el `prefix` if `mapboxMap` no es null. Input: `layerId` (String).
  - `_removeLayerSafely('$prefix$i')`: Llamada para cada índice `i` de 0 a 9 if `mapboxMap` no es null. Input: String.
  - `_removeLayerSafely('$prefix$i-shadow')`: Llamada para cada índice `i` de 0 a 9 if `mapboxMap` no es null. Input: String.
  - `_removeLayerSafely('$prefix$i-border')`: Llamada para cada índice `i` de 0 a 9 if `mapboxMap` no es null. Input: String.

### \_clearSourcesWithPrefix

- **Input:** `prefix` (String).
- **Llama a:**
  - `mapManager.activeSources`: Llamada el 100% de las veces if `mapboxMap` no es null. Input: Ninguno (acceso a getter).
  - `_removeSourceSafely(sourceId)`: Llamada para cada `sourceId` in `registeredSources` that starts with `prefix` if `mapboxMap` no es null. Input: `sourceId` (String).
  - `_removeSourceSafely('$prefix$i')`: Llamada para cada índice `i` de 0 a 9 if `mapboxMap` no es null. Input: String.

### \_removeLayerSafely

- **Input:** `layerId` (String).
- **Llama a:**
  - `mapboxMap!.style.styleLayerExists(layerId)`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: `layerId` (String).
  - `mapboxMap!.style.removeStyleLayer(layerId)`: Llamada si `mapboxMap` no es null y la capa existe (dentro de un bloque `try`). Input: `layerId` (String).
  - `print`: Llamada si `mapboxMap` no es null y la capa se elimina (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_removeSourceSafely

- **Input:** `sourceId` (String).
- **Llama a:**
  - `mapboxMap!.style.styleSourceExists(sourceId)`: Llamada si `mapboxMap` no es null (dentro de un bloque `try`). Input: `sourceId` (String).
  - `mapboxMap!.style.removeStyleSource(sourceId)`: Llamada si `mapboxMap` no es null y la fuente existe (dentro de un bloque `try`). Input: `sourceId` (String).
  - `print`: Llamada si `mapboxMap` no es null y la fuente se elimina (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String).

## Funciones en lib/backend/services/itinerary_planning_service_adapter.dart

### ItineraryPlanningServiceAdapter (Constructor)

- **Input:** `_montevideoApiService` (MontevideoApiServiceAdapterBase).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo (inicializa campos).

### \_findMatchingEta

- **Input:** `etas` (List<EtaMostrable>), `targetLine` (String o null), `targetHeadsign` (String o null).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### \_fetchOtpGraphQLPlan

- **Input:** `origenCoords` (Coordenada), `destinoCoords` (Coordenada), `fechaHora` (DateTime), `numItinerarios` (int, default 3).
- **Llama a:**
  - `DateFormat(...)`: Llamada el 100% de las veces para formatear la fecha y hora. Input: String.
  - `dateFormatter.format(fechaHora)`: Llamada el 100% de las veces. Input: `fechaHora` (DateTime).
  - `timeFormatter.format(fechaHora)`: Llamada el 100% de las veces. Input: `fechaHora` (DateTime).
  - `print`: Llamada el 100% de las veces. Input: String.
  - `http.post(...)`: Llamada el 100% de las veces (dentro de un bloque `try`). Input: `Uri.parse(OTP_GRAPHQL_ENDPOINT_URL)` (Uri), headers (Map), body (String).
  - `json.decode(utf8.decode(response.bodyBytes))`: Llamada si `response.statusCode == 200`. Input: `response.bodyBytes` (Uint8List).
  - `print`: Llamada si `responseBody['errors']` no es null. Input: String.
  - `print`: Llamada si `response.statusCode != 200`. Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_decodePolyline

- **Input:** `encodedPolyline` (String).
- **Llama a:**
  - `_polylinePoints.decodePolyline(encodedPolyline)`: Llamada si `encodedPolyline` no está vacío (dentro de un bloque `try`). Input: `encodedPolyline` (String).
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.
  - No llama a otras funciones definidas en este archivo directamente.

### \_generateUniqueId

- **Input:** `prefix` (String).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### planRoute

- **Input:** `origenCoords` (Coordenada), `origenNombre` (String o null), `destinoCoords` (Coordenada), `destinoNombre` (String o null), `fechaHoraSalida` (DateTime o null), `llegarA` (bool o null), `numItinerarios` (int o null).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_fetchOtpGraphQLPlan(...)`: Llamada el 100% de las veces. Input: `origenCoords` (Coordenada), `destinoCoords` (Coordenada), `fechaHora` (DateTime), `numItinerarios` (int).
  - `print`: Llamada si `otpResponse` es null o no contiene itinerarios. Input: String.
  - `uniqueFirstBusStopIds.add(...)`: Llamada dentro de un bucle si se encuentra una parada de bus única. Input: String.
  - `firstBusLegDetailsByStopId[stopId] = (...)`: Llamada dentro de un bucle si se encuentra una parada de bus única y no está en el mapa. Input: MapEntry.
  - `stopsToQueryForEta.toList()`: Llamada si `uniqueFirstBusStopIds` no está vacío.
  - `stopsToQueryForEta.sublist(...)`: Llamada si `stopsToQueryForEta.length > MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP`.
  - `print`: Llamada si `stopsToQueryForEta` no está vacío. Input: String.
  - `_montevideoApiService.getStopDetailsWithEta(...)`: Llamada para cada `stopIdStr` en `stopsToQueryForEta` (dentro de un bucle `for`). Input: `stopIdStr` (String), String, Coordenada.
  - `print`: Llamada si ocurre una excepción al obtener ETA (dentro de un bloque `catch`). Input: String.
  - `print`: Llamada para cada itinerario OTP sin tramos. Input: String.
  - `_findMatchingEta(...)`: Llamada si `firstBusLegOfCurrentItinerary` no es null y `etasByStopIdCache` contiene el stopId. Input: List<EtaMostrable>, String o null, String o null.
  - `print`: Llamada si se encuentra un ETA. Input: String.
  - `print`: Llamada para cada tramo OTP incompleto. Input: String.
  - `_decodePolyline(leg.legGeometry?.points ?? '')`: Llamada para cada tramo OTP. Input: String.
  - `_generateUniqueId(...)`: Llamada para cada tramo mostrable. Input: String.
  - `tramosDelItinerario.add(...)`: Llamada para cada tramo mostrable (espera, caminar, bus). Input: TramoViajeMostrable.
  - `secuenciaModos.add(...)`: Llamada para cada tramo mostrable (espera, caminar, bus). Input: TipoTramoViaje.
  - `print`: Llamada si un itinerario OTP no generó tramos mostrables. Input: String.
  - `opcionesDeRuta.add(...)`: Llamada para cada itinerario OTP que generó tramos mostrables. Input: OpcionDeRutaMostrable.
  - `opcionesDeRuta.sort(...)`: Llamada el 100% de las veces después de procesar itinerarios. Input: Comparator function.
  - `mejorOpcion.copyWith(esRecomendada: true)`: Llamada si `opcionesDeRuta` no está vacío para reasignar la recomendada. Input: Parámetro nombrado.
  - `opcionesDeRuta[i].copyWith(esRecomendada: false)`: Llamada para las opciones subsiguientes si eran marcadas como recomendadas. Input: Parámetro nombrado.
  - `print`: Llamada el 100% de las veces al final de la función. Input: String.

## Funciones en lib/backend/services/montevideo_api_service_adapter.dart

### MontevideoApiServiceAdapter (Constructor)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo (inicializa campos).

### \_getApiToken

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada si el token ha expirado o es nulo. Input: String.
  - `http.post(...)`: Llamada si el token ha expirado o es nulo (dentro de un bloque `try`). Input: `Uri.parse(ACCESS_TOKEN_URL)` (Uri), headers (Map), body (Map).
  - `json.decode(response.body)`: Llamada si `response.statusCode == 200`. Input: String.
  - `DateTime.now().add(...)`: Llamada si se obtiene un nuevo token para calcular la expiración. Input: Duration.
  - `print`: Llamada si se obtiene un nuevo token. Input: String.
  - `print`: Llamada si falla la obtención del token (HTTP != 200). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### getAllStops

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `rootBundle.loadString('assets/data/stops.geojson')`: Llamada el 100% de las veces (dentro de un bloque `try`). Input: String.
  - `json.decode(geoJsonString)`: Llamada el 100% de las veces (dentro de un bloque `try`). Input: String.
  - `paradas.add(...)`: Llamada dentro de un bucle `for` para cada feature válida. Input: `InfoParadaEnMapa`.
  - `print`: Llamada para features con datos incompletos o mal formados. Input: String.
  - `print`: Llamada para features GeoJSON no válidas. Input: String.
  - `print`: Llamada si las paradas se cargan exitosamente (dentro de un bloque `try`). Input: String.
  - `print`: Llamada si el formato GeoJSON es inválido. Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

### \_fetchArrivalsForStopAPI

- **Input:** `stopId` (String).
- **Llama a:**
  - `_getApiToken()`: Llamada el 100% de las veces. Input: Ninguno.
  - `print`: Llamada si no se pudo obtener el token. Input: String.
  - `Uri.parse('$ARRIVALS_BASE_URL/siguientesParada/$stopId')`: Llamada si se obtiene el token. Input: String.
  - `print`: Llamada si se obtiene el token. Input: String.
  - `http.get(...)`: Llamada si se obtiene el token (dentro de un bloque `try`). Input: `url` (Uri), headers (Map).
  - `print`: Llamada si ocurre un timeout o error de red. Input: String.
  - `json.decode(response.body)`: Llamada si `response.statusCode == 200`. Input: String.
  - `List<Map<String, dynamic>>.from(...)`: Llamada si `response.statusCode == 200` y el cuerpo es una lista. Input: Iterable.
  - `print`: Llamada si el formato de respuesta es inesperado (HTTP 200). Input: String.
  - `print`: Llamada si el token ha expirado/inválido (HTTP 401/403). Input: String.
  - `_getApiToken()`: Llamada si el token ha expirado/inválido para intentar renovarlo. Input: Ninguno.
  - `http.get(...)`: Llamada si se obtiene un nuevo token para reintentar la consulta. Input: `url` (Uri), headers (Map).
  - `print`: Llamada si ocurre un timeout o error de red en el reintento. Input: String.
  - `json.decode(retryResponse.body)`: Llamada si `retryResponse.statusCode == 200` en el reintento. Input: String.
  - `List<Map<String, dynamic>>.from(...)`: Llamada si `retryResponse.statusCode == 200` y el cuerpo es una lista en el reintento. Input: Iterable.
  - `print`: Llamada si el formato de respuesta es inesperado (HTTP 200) en el reintento. Input: String.
  - `print`: Llamada si falla el reintento (HTTP != 200). Input: String.
  - `print`: Llamada si no se pudo obtener un nuevo token para el reintento. Input: String.
  - `print`: Llamada para otros errores HTTP. Input: String.
  - `print`: Llamada si ocurre una excepción genérica (dentro del bloque `catch`). Input: String.

### getStopDetailsWithEta

- **Input:** `idParada` (String), `nombreParadaOriginal` (String), `posicionParadaOriginal` (Coordenada).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_fetchArrivalsForStopAPI(idParada)`: Llamada el 100% de las veces. Input: `idParada` (String).
  - `print`: Llamada si `rawArrivalData` está vacío. Input: String.
  - `lineasQuePasan.add(linea)`: Llamada dentro de un bucle `for` para cada llegada válida. Input: String.
  - `print`: Llamada si una llegada no tiene nombre de línea. Input: String.
  - `print`: Llamada si `minutosDynamic` tiene formato inesperado o es nulo. Input: String.
  - `print`: Llamada si las coordenadas de bus tienen formato inesperado (no lista). Input: String.
  - `print`: Llamada si las coordenadas de bus tienen formato inesperado (lista de tamaño incorrecto o tipos incorrectos). Input: String.
  - `print`: Llamada si la posición del bus es (0,0). Input: String.
  - `etas.add(...)`: Llamada dentro de un bucle `for` para cada llegada válida. Input: `EtaMostrable`.
  - `print`: Llamada si se procesaron llegadas crudas pero resultaron 0 ETAs mostrables. Input: String.
  - `lineasQuePasan.toList()..sort()`: Llamada antes de crear `InfoDetalladaParada` si `lineasQuePasan` no está vacío. Input: Ninguno (sort es un método de lista).
  - No llama a otras funciones definidas en este archivo directamente (solo métodos de lista, set, etc.).

## Funciones en lib/backend/services/geocoding_service_adapter.dart

### GeocodingServiceAdapter (Constructor)

- **Input:** `httpClient` (http.Client o null), `apiKey` (String o null).
- **Llama a:**
  - No llama a otras funciones definidas en este archivo (inicializa campos).

### fetchSuggestions

- **Input:** `query` (String), `proximity` (Coordenada o null).
- **Llama a:**
  - `print`: Llamada si `_apiKey` está vacío. Input: String.
  - `Uri.parse(url)`: Llamada si `_apiKey` y `query` no están vacíos. Input: String.
  - `_httpClient.get(Uri.parse(url))`: Llamada si `_apiKey` y `query` no están vacíos (dentro de un bloque `try`). Input: `url` (Uri).
  - `json.decode(response.body)`: Llamada si `response.statusCode == 200`. Input: String.
  - `SugerenciaLugar.fromJson(...)`: Llamada dentro de un bucle `map` para cada feature si `features` no es null. Input: Map<String, dynamic>.
  - `print`: Llamada si `response.statusCode != 200`. Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.

## Definiciones en lib/backend/contrato_ui/app_ui_state.dart

### Clase Coordenada

- **Campos:**
  - `latitud` (double)
  - `longitud` (double)

### Clase SugerenciaLugar

- **Campos:**
  - `id` (String)
  - `nombreCompleto` (String)
  - `nombreLugar` (String o null)
  - `direccion` (String o null)
  - `coordenadas` (Coordenada)
- **Factory `fromJson`:**
  - **Input:** `json` (Map<String, dynamic>).
  - **Llama a:**
    - `Coordenada(...)`: Llamada el 100% de las veces para crear una instancia de Coordenada a partir de los datos de coordenadas en el JSON. Input: `longitud` (double), `latitud` (double).

### Clase InfoParadaEnMapa

- **Campos:**
  - `idParada` (String)
  - `posicion` (Coordenada)
  - `nombre` (String)

### Clase EtaMostrable

- **Campos:**
  - `linea` (String)
  - `destino` (String o null)
  - `minutosParaLlegada` (int)
  - `esTiempoReal` (bool)
  - `posicionBus` (Coordenada o null)

### Clase InfoDetalladaParada

- **Campos:**
  - `idParada` (String)
  - `nombreParada` (String)
  - `posicion` (Coordenada)
  - `lineasQuePasan` (List<String>)
  - `etas` (List<EtaMostrable>)

### Enumeración EstadoSolicitud

- **Valores:** `INICIAL`, `CARGANDO`, `EXITO`, `ERROR`.

### Enumeración TipoTramoViaje

- **Valores:** `CAMINAR`, `ESPERAR_BUS`, `VIAJE_EN_BUS`.

### Clase TramoViajeMostrable

- **Campos:**
  - `idTramo` (String)
  - `tipo` (TipoTramoViaje)
  - `geometriaPolilinea` (List<Coordenada> o null)
  - `posicionPunto` (Coordenada o null)
  - `descripcion` (String)
  - `duracionEstimadaSegundos` (int)
  - `distanciaMetros` (int)
  - `nombreLineaBus` (String o null)
  - `destinoFinalDelBus` (String o null)
  - `idParadaOrigenTramoBus` (String o null)
  - `idParadaDestinoTramoBus` (String o null)
  - `coordenadasParadaOrigen` (Coordenada o null)
  - `nombreParadaOrigen` (String o null)
  - `coordenadasParadaDestino` (Coordenada o null)
  - `nombreParadaDestino` (String o null)
  - `shapeId` (String o null)
  - `minutosEstimadosLlegadaBus` (int o null)
  - `esTiempoRealBus` (bool o null)
  - `posicionActualBus` (Coordenada o null)
- **Getter `coordenadasDelTramo`:**
  - **Input:** Ninguno.
  - **Llama a:** No llama a otras funciones definidas en este archivo.

### Enumeración TipoAdvertenciaItinerario

- **Valores:** `TIEMPO_CAMINATA_EXCESIVO`, `TRANSBORDO_AJUSTADO`, `RUTA_NO_ACCESIBLE_SILLA_RUEDAS`, `SERVICIO_NOCTURNO_LIMITADO`, `POSIBLE_DEMORA_EVENTO_ESPECIAL`, `ETA_NO_DISPONIBLE_PARA_PRIMER_BUS`, `ETA_NO_ES_TIEMPO_REAL_PARA_PRIMER_BUS`.

### Clase OpcionDeRutaMostrable

- **Campos:**
  - `idOpcion` (String)
  - `duracionTotalSegundos` (int)
  - `horaLlegadaEstimada` (DateTime)
  - `secuenciaModosIconos` (List<TipoTramoViaje>)
  - `distanciaTotalCaminataMetros` (int)
  - `tiempoTotalEsperaBusSegundos` (int)
  - `costoEstimadoViaje` (double o null)
  - `advertenciaPrincipal` (TipoAdvertenciaItinerario o null)
  - `esRecomendada` (bool)
  - `score` (int)
  - `tramosParaPreview` (List<TramoViajeMostrable>)
  - `etaProximoBus` (EtaMostrable o null)
- **Método `copyWith`:**
  - **Input:** Varios parámetros opcionales para cada campo de la clase, además de parámetros booleanos como `clearDatosFaseInicial` para limpiar campos opcionales.
  - **Llama a:** No llama a otras funciones definidas en este archivo.

### Enumeración FaseApp

- **Valores:** `INICIAL_SIN_BUSQUEDA`, `MOSTRANDO_OPCIONES_RUTA`, `VIAJE_ACTIVO_EN_CURSO`.

### Clase EstadoFaseInicial

- **Campos:**
  - `paradasVisiblesEnMapa` (List<InfoParadaEnMapa>)

### Clase EstadoFaseOpcionesRuta

- **Campos:**
  - `opcionesDeRuta` (List<OpcionDeRutaMostrable>)

### Clase EstadoFaseViajeActivo

- **Campos:**
  - `idViajeActivoConfirmado` (String)
  - `tramosDelViaje` (List<TramoViajeMostrable>)
  - `idTramoBusEnSeguimiento` (String o null)
  - `posicionActualBusReal` (Coordenada o null)
  - `minutosParaLlegadaBusReal` (int o null)
  - `seguimientoBusRealDisponibleEnTramoActual` (bool)
  - `opcionDeRutaSeleccionada` (OpcionDeRutaMostrable)
  - `ubicacionActualUsuario` (Coordenada o null)
- **Método `copyWith`:**
  - **Input:** Varios parámetros opcionales para cada campo de la clase, además de parámetros booleanos para limpiar campos opcionales.
  - **Llama a:** No llama a otras funciones definidas en este archivo.

### Clase AppUiState

- **Campos:**
  - `faseActual` (FaseApp)
  - `datosFaseInicial` (EstadoFaseInicial o null)
  - `datosFaseOpcionesRuta` (EstadoFaseOpcionesRuta o null)
  - `datosFaseViajeActivo` (EstadoFaseViajeActivo o null)
  - `infoParadaConsultada` (InfoDetalladaParada o null)
  - `estadoInfoParadaConsultada` (EstadoSolicitud)
  - `textoInputOrigenActual` (String o null)
  - `sugerenciasOrigen` (List<SugerenciaLugar> o null)
  - `estadoSugerenciasOrigen` (EstadoSolicitud)
  - `textoInputDestinoActual` (String o null)
  - `sugerenciasDestino` (List<SugerenciaLugar> o null)
  - `estadoSugerenciasDestino` (EstadoSolicitud)
  - `puntoOrigenParaBusqueda` (Coordenada o null)
  - `nombreLugarOrigenSeleccionado` (String o null)
  - `puntoDestinoParaBusqueda` (Coordenada o null)
  - `nombreLugarDestinoSeleccionado` (String o null)
  - `idOpcionRutaPrevisualizada` (String o null)
  - `mostrandoSpinnerGlobal` (bool)
  - `mensajeErrorGlobal` (String o null)
  - `mensajeInfoGlobal` (String o null)
  - `estadoCalculoRuta` (EstadoSolicitud)
- **Factory `inicial`:**
  - **Input:** Ninguno.
  - **Llama a:**
    - `AppUiState(...)`: Llamada el 100% de las veces para crear una instancia con valores iniciales. Input: Parámetros nombrados con valores por defecto.
    - `EstadoFaseInicial(...)`: Llamada el 100% de las veces para inicializar `datosFaseInicial`. Input: `paradasVisiblesEnMapa` (Lista vacía).
- **Método `copyWith`:**
  - **Input:** Varios parámetros opcionales para cada campo de la clase, además de parámetros booleanos para limpiar campos opcionales.
  - **Llama a:** No llama a otras funciones definidas en este archivo.
- **Método `toString`:**
  - **Input:** Ninguno.
  - **Llama a:** No llama a otras funciones definidas en este archivo.

### Interfaz IAppLogic

- **Métodos:** (Lista de métodos definidos en la interfaz. No tienen implementación aquí)
  - `cargarParadasInicialesDelViewport` (Input: `centroActual` (Coordenada), `zoomActual` (double))
  - `viewportDelMapaCambio` (Input: `nuevoCentro` (Coordenada), `nuevoZoom` (double), `esquinaSupIzq` (Coordenada), `esquinaInfDer` (Coordenada))
  - `solicitarInformacionDetalladaParada` (Input: `idParada` (String))
  - `usuarioDeseleccionoInformacionDeParada` (Input: Ninguno)
  - `usuarioEscribioEnCampoOrigen` (Input: `textoQuery` (String))
  - `usuarioEscribioEnCampoDestino` (Input: `textoQuery` (String))
  - `seleccionarSugerenciaOrigen` (Input: `sugerencia` (SugerenciaLugar))
  - `seleccionarSugerenciaDestino` (Input: `sugerencia` (SugerenciaLugar))
  - `limpiarSugerenciasOrigen` (Input: Ninguno)
  - `limpiarSugerenciasDestino` (Input: Ninguno)
  - `limpiarOrigenSeleccionado` (Input: Ninguno)
  - `limpiarDestinoSeleccionado` (Input: Ninguno)
  - `intercambiarOrigenYDestino` (Input: Ninguno)
  - `iniciarBusquedaDeRutas` (Input: Ninguno)
  - `usuarioCanceloBusquedaOSeleccionRuta` (Input: Ninguno)
  - `seleccionarOpcionDeRutaParaPrevisualizar` (Input: `idOpcionRuta` (String))
  - `limpiarSeleccionDeRutaPrevisualizada` (Input: Ninguno)
  - `confirmarOpcionDeRutaEIniciarViaje` (Input: `idOpcionRuta` (String))
  - `iniciarSeguimientoBusTiempoReal` (Input: `idViajeActivo` (String), `idTramoBus` (String))
  - `detenerSeguimientoBusTiempoReal` (Input: Ninguno)
  - `usuarioSeleccionoTramoDelViaje` (Input: `idViajeActivo` (String), `idTramoSeleccionado` (String))
  - `limpiarMensajeDeErrorGlobal` (Input: Ninguno)
  - `setErrorGlobal` (Input: `mensaje` (String o null))
  - `pantallaDeInicioCargada` (Input: Ninguno)
  - `usuarioMovioMapaManualente` (Input: `nuevoCentro` (Coordenada), `nuevoZoom` (double))
  - `usuarioHizoTapEnMapa` (Input: `tocada` (Coordenada))
  - `usuarioHizoTapEnParadaDelMapa` (Input: `idParada` (String))
  - `cerrarDetallesDeParada` (Input: Ninguno)
  - `navegarAAnteriorPasoInstrucciones` (Input: Ninguno)
  - `navegarASiguientePasoInstrucciones` (Input: Ninguno)
  - `usuarioSeleccionoPasoInstrucciones` (Input: `indicePaso` (int))
  - `usuarioPresionoSeguirEsteViaje` (Input: Ninguno)
  - `detenerSeguimientoActivo` (Input: Ninguno)

## Funciones en lib/map_manager/map_manager.dart

### MapManager (Constructor)

- **Input:** `mapboxMap` (MapboxMap o null).
- **Llama a:**
  - `MapRouteRenderer(mapboxMap, this)`: Llamada el 100% de las veces. Input: `mapboxMap` (MapboxMap o null), `this` (MapManager).
  - `MapBusRealtime(mapboxMap, this)`: Llamada el 100% de las veces. Input: `mapboxMap` (MapboxMap o null), `this` (MapManager).
  - `MapIconsLoader(mapboxMap, this)`: Llamada el 100% de las veces. Input: `mapboxMap` (MapboxMap o null), `this` (MapManager).
  - `MapCameraController(mapboxMap, this)`: Llamada el 100% de las veces. Input: `mapboxMap` (MapboxMap o null), `this` (MapManager).
  - `MapCleanup(mapboxMap, this)`: Llamada el 100% de las veces. Input: `mapboxMap` (MapboxMap o null), `this` (MapManager).

### initialize

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada si `!_isInitialized` y `mapboxMap` no es null. Input: String.
  - `_iconsLoader.loadAllIcons()`: Llamada si `!_isInitialized` y `mapboxMap` no es null (dentro de un bloque `try`). Input: Ninguno.
  - `_hideCityLabels()`: Llamada si `!_isInitialized` y `mapboxMap` no es null (dentro de un bloque `try`). Input: Ninguno.
  - `print`: Llamada si la inicialización es exitosa (dentro del bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.
  - `rethrow`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: Ninguno.

### showRoutePreview

- **Input:** `route` (OpcionDeRutaMostrable).
- **Llama a:**
  - `initialize()`: Llamada si `!_isInitialized`. Input: Ninguno.
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_cleanup.clearRoute()`: Llamada si `_currentPreviewOptionId != route.idOpcion`. Input: Ninguno.
  - `_routeRenderer.renderRoute(route.tramosParaPreview)`: Llamada si `needsRedraw || _activeLayers.isEmpty`. Input: `route.tramosParaPreview` (List<TramoViajeMostrable>).
  - `_busRealtime.displayRealtimeBusesForPreview(route)`: Llamada si `needsRedraw || _activeLayers.isEmpty`. Input: `route` (OpcionDeRutaMostrable).
  - `_cameraController.zoomToRoutePreview(route)`: Llamada el 100% de las veces. Input: `route` (OpcionDeRutaMostrable).

### showActiveTrip

- **Input:** `activeTripState` (EstadoFaseViajeActivo).
- **Llama a:**
  - `initialize()`: Llamada si `!_isInitialized`. Input: Ninguno.
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_startActiveTripTracking(activeTripState)`: Llamada si `isTransitionFromPreview` es true. Input: `activeTripState` (EstadoFaseViajeActivo).
  - `_cleanup.clearAll()`: Llamada si `isTransitionFromPreview` es false. Input: Ninguno.
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)`: Llamada si `isTransitionFromPreview` es false. Input: `activeTripState.tramosDelViaje` (List<TramoViajeMostrable>).
  - `_busRealtime.initializeActiveTripTracking(activeTripState)`: Llamada si `isTransitionFromPreview` es false. Input: `activeTripState` (EstadoFaseViajeActivo).

### \_startActiveTripTracking

- **Input:** `activeTripState` (EstadoFaseViajeActivo).
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_busRealtime.stopPreviewAnimations()`: Llamada el 100% de las veces (dentro de un bloque `try`). Input: Ninguno.
  - `_busRealtime.initializeActiveTripTracking(activeTripState)`: Llamada el 100% de las veces (dentro de un bloque `try`). Input: `activeTripState` (EstadoFaseViajeActivo).
  - `_cameraController.zoomToActiveTrip(activeTripState.tramosDelViaje)`: Llamada el 100% de las veces (dentro de un bloque `try`). Input: `activeTripState.tramosDelViaje` (List<TramoViajeMostrable>).
  - `print`: Llamada si la operación es exitosa (dentro del bloque `try`). Input: String.
  - `print`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: String.
  - `_cleanup.clearAll()`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: Ninguno.
  - `_routeRenderer.renderRoute(activeTripState.tramosDelViaje)`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: `activeTripState.tramosDelViaje` (List<TramoViajeMostrable>).
  - `_busRealtime.initializeActiveTripTracking(activeTripState)`: Llamada si ocurre una excepción (dentro del bloque `catch`). Input: `activeTripState` (EstadoFaseViajeActivo).

### updateCurrentLeg

- **Input:** `legIndex` (int), `tramos` (List<TramoViajeMostrable>).
- **Llama a:**
  - `print`: Llamada si `_currentPhase == 'active_trip'`. Input: String.
  - `_routeRenderer.highlightCurrentLeg(legIndex, tramos)`: Llamada si `_currentPhase == 'active_trip'`. Input: `legIndex` (int), `tramos` (List<TramoViajeMostrable>).
  - `_cameraController.zoomToCurrentLeg(legIndex, tramos)`: Llamada si `_currentPhase == 'active_trip'`. Input: `legIndex` (int), `tramos` (List<TramoViajeMostrable>).
  - `_busRealtime.updateBusTrackingForLeg(legIndex, tramos)`: Llamada si `_currentPhase == 'active_trip'`. Input: `legIndex` (int), `tramos` (List<TramoViajeMostrable>).

### updateBusPosition

- **Input:** `position` (Coordenada), `etaMinutes` (int), `isRealTime` (bool).
- **Llama a:**
  - `_busRealtime.updateBusPosition(position, etaMinutes, isRealTime)`: Llamada el 100% de las veces. Input: `position` (Coordenada), `etaMinutes` (int), `isRealTime` (bool).

### showInitialPhase

- **Input:** Ninguno.
- **Llama a:**
  - `initialize()`: Llamada si `!_isInitialized`. Input: Ninguno.
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_cleanup.clearAll()`: Llamada el 100% de las veces. Input: Ninguno.

### clearAll

- **Input:** Ninguno.
- **Llama a:**
  - `print`: Llamada el 100% de las veces. Input: String.
  - `_cleanup.clearAll()`: Llamada el 100% de las veces. Input: Ninguno.

### registerSource

- **Input:** `sourceId` (String).
- **Llama a:**
  - `_activeSources.add(sourceId)`: Llamada si `!_activeSources.contains(sourceId)`. Input: `sourceId` (String).

### registerLayer

- **Input:** `layerId` (String).
- **Llama a:**
  - `_activeLayers.add(layerId)`: Llamada si `!_activeLayers.contains(layerId)`. Input: `layerId` (String).

### activeSources (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - `List.unmodifiable(_activeSources)`: Llamada el 100% de las veces. Input: `_activeSources` (List<String>).

### activeLayers (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - `List.unmodifiable(_activeLayers)`: Llamada el 100% de las veces. Input: `_activeLayers` (List<String>).

### clearRegistrations

- **Input:** Ninguno.
- **Llama a:**
  - `_activeSources.clear()`: Llamada el 100% de las veces. Input: Ninguno.
  - `_activeLayers.clear()`: Llamada el 100% de las veces. Input: Ninguno.

### \_hideCityLabels

- **Input:** Ninguno.
- **Llama a:**
  - `mapboxMap!.style.styleLayerExists(layerId)`: Llamada para cada `layerId` en `labelLayerIds` si `mapboxMap` no es null (dentro de un bloque `try`). Input: `layerId` (String).
  - `mapboxMap!.style.setStyleLayerProperty(...)`: Llamada para cada `layerId` si `mapboxMap` no es null y la capa existe (dentro de un bloque `try`). Input: `layerId` (String), `'visibility'` (String), `'none'` (String).
  - `print`: Llamada si ocurre una excepción general (dentro del bloque `catch`). Input: String.

### isInitialized (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### currentPhase (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### getCurrentBusPosition

- **Input:** Ninguno.
- **Llama a:**
  - `_busRealtime.currentBusPosition`: Llamada el 100% de las veces. Input: Ninguno (acceso a getter).

### routeRenderer (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### busRealtime (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### iconsLoader (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### cameraController (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

### cleanup (Getter)

- **Input:** Ninguno.
- **Llama a:**
  - No llama a otras funciones definidas en este archivo.

## Resumen de la Documentación

### Archivos Documentados Completamente

Esta documentación cubre **TODAS** las funciones involucradas en el flujo de navegación de 9 pasos solicitado:

1. **lib/ui/overlays/route_options_overlay.dart** - Interfaz de selección de opciones de ruta (pasos 1-4)
2. **lib/backend/providers/app_logic_provider.dart** - Lógica principal de la aplicación (todos los pasos)
3. **lib/ui/overlays/active_trip_overlay.dart** - Interfaz del viaje activo (pasos 5-9)
4. **lib/map_manager/map_manager.dart** - Coordinador principal del mapa (todos los pasos)
5. **lib/map_manager/map_route_renderer.dart** - Renderizado de rutas en el mapa (pasos 1-9)
6. **lib/map_manager/map_bus_realtime.dart** - Gestión de buses en tiempo real (pasos 1-9)
7. **lib/map_manager/map_camera_controller.dart** - Control de cámara del mapa (pasos 1-9)
8. **lib/map_manager/map_icons_loader.dart** - Carga de iconos del mapa (inicialización)
9. **lib/map_manager/map_cleanup.dart** - Limpieza de elementos del mapa (transiciones)
10. **lib/backend/services/itinerary_planning_service_adapter.dart** - Planificación de rutas (pasos 1-4)
11. **lib/backend/services/montevideo_api_service_adapter.dart** - API de Montevideo (pasos 1-9)
12. **lib/backend/services/geocoding_service_adapter.dart** - Geocodificación (búsqueda de lugares)
13. **lib/backend/contrato_ui/app_ui_state.dart** - Definiciones de tipos y estados (todos los pasos)

### Flujo de 9 Pasos Cubierto

**Pasos 1-4: Selección de Ruta**

- Usuario ve opciones de viaje con preview de primera opción (ETA disponible)
- Usuario cambia a segunda opción (sin ETA)
- Usuario cambia a tercera opción (con ETA)
- Usuario selecciona la tercera opción

**Pasos 5-9: Viaje Activo**

- Usuario en active trip está en paso de caminar hasta la parada
- Usuario presiona botón para pasar al siguiente paso (esperar bus en parada)
- Usuario presiona botón para pasar al siguiente paso (ir hasta parada de destino)
- Usuario presiona botón para pasar al siguiente paso (esperar segundo bus)
- Usuario presiona botón para pasar al siguiente paso (caminar hasta destino)

### Funciones Clave por Paso

**Paso 1-3 (Cambio entre opciones):**

- `RouteOptionsOverlay._showRoutePreview()` → `AppLogicNotifier.seleccionarOpcionDeRutaParaPrevisualizar()` → `MapManager.showRoutePreview()`

**Paso 4 (Selección de opción):**

- `RouteOptionsOverlay._buildFooter()` → `AppLogicNotifier.confirmarOpcionDeRutaEIniciarViaje()` → `MapManager.showActiveTrip()`

**Pasos 5-9 (Navegación entre pasos del viaje):**

- `ActiveTripOverlay._onLegSelected()` → `MapManager.updateCurrentLeg()` → `MapRouteRenderer.highlightCurrentLeg()` + `MapCameraController.zoomToCurrentLeg()` + `MapBusRealtime.updateBusTrackingForLeg()`

### Formato de Documentación

Para cada función se documentó:

- **Nombre de la función**
- **Input que recibe** (cada parámetro y sus tipos)
- **Funciones que llama** con inputs específicos y condiciones exactas:
  - "100% de las veces" para llamadas incondicionales
  - "Condicionalmente si [condición específica]" para llamadas condicionales
  - "Si no llama a ninguna función, se indicó explícitamente"

### Estado: COMPLETO ✅

La documentación está **COMPLETA** para el flujo de navegación de 9 pasos solicitado. Todos los archivos relevantes han sido explorados y documentados siguiendo exactamente el formato requerido.
